# watch.ps1 - the local half of the auto-verification handshake.
#
# Registers a Windows scheduled task that polls the remote branch every N
# minutes. When the agent requests a check (arena_state=awaiting_check,
# local_state=pending in the handshake file), the watcher automatically:
#     sync -> run the local check (check_cmd) -> write the log ->
#     push the verdict (passed/failed) back to the branch.
# The agent then reads the verdict with agent-check.sh --read and either
# accepts (loop ends) or fixes and requests another round.
#
# Usage (inside the repo folder):
#     .\watch.ps1 -Register              # once per machine: create the task
#     .\watch.ps1 -Register -Interval 10 # poll every 10 minutes instead of 2
#     .\watch.ps1 -Status                # is the watcher alive? last run, mode, verdict
#     .\watch.ps1 -Test                  # run the task once NOW and verify it really ran
#     .\watch.ps1                        # one manual poll right now
#     .\watch.ps1 -Pause / -Resume       # stop / restart polling (task stays)
#     .\watch.ps1 -Unregister            # remove the scheduled task
#     .\watch.ps1 -Register -Flash       # old launcher (brief console flash per poll)
#     .\watch.ps1 -Register -Headless    # zero window via S4U (session 0, ADMIN console!)
#
# WINDOW BEHAVIOUR (the reason this file grew a launcher):
#   A console app started by Task Scheduler ALWAYS gets a console window first -
#   '-WindowStyle Hidden' can only hide it after the fact, so a short flash is
#   unavoidable for powershell.exe itself. The default mode therefore compiles a
#   tiny GUI-subsystem launcher (no console at all) into
#   %LOCALAPPDATA%\git-sync\ and starts powershell.exe from it with
#   CreateNoWindow - zero flash, no admin rights, nothing deprecated (v2.4.4
#   tried a wscript+vbs launcher and silently died: Windows 11 is retiring
#   VBScript). -Flash keeps the old behaviour, -Headless uses S4U/session 0
#   (needs an ELEVATED console: a normal one fails with 0x80070005, and pushes
#   need credentialStore=dpapi or the gh helper - see auth.ps1).
#   Register always SELF-TESTS (runs the task once and waits for the heartbeat)
#   and falls back to -Flash automatically if the launcher does not run. The
#   task also gets an ExecutionTimeLimit (check timeout + 10 min) so a hung
#   poll can never keep the task "Running" and block every later run.
#
# All of watch.ps1's own child processes inherit its hidden console, so they
# cannot flash either. Local state (heartbeat, log, launcher) lives in
# %LOCALAPPDATA%\git-sync\ - never in the repo, so nothing of it reaches git.
#
# ASCII-only on purpose (Windows PowerShell 5.1 decodes .ps1 as ANSI/GBK).

param(
    [int]$Interval = 2,
    [string]$Config = '',
    [switch]$Register,
    [switch]$Unregister,
    [switch]$Pause,
    [switch]$Resume,
    [switch]$Status,
    [switch]$Test,
    [switch]$Headless,
    [switch]$Flash,
    [switch]$ZeroWindow,
    [int]$CheckTimeoutMin = 0,
    [int]$SelfTestSec = 90
)

$ErrorActionPreference = 'Continue'

# repo root = walk up from this script until .git appears, so the script also
# works when run straight from skills\git-sync\scripts\
$repo = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
while ($repo -and -not (Test-Path -LiteralPath (Join-Path $repo '.git'))) {
    $up = Split-Path -Parent $repo
    if (-not $up -or $up -eq $repo) { break }
    $repo = $up
}
Set-Location -LiteralPath $repo
$repoName = Split-Path -Leaf $repo

# ------------------------------------------------------------------- config
if ($Config -and -not (Test-Path -LiteralPath $Config)) {
    Write-Host "[ERROR] config not found: $Config" -ForegroundColor Red
    exit 1
}
$cfgPath = @()
if ($Config) { $cfgPath += $Config }
if ($env:GIT_SYNC_PROFILE) {
    $prof = 'sync.config.' + $env:GIT_SYNC_PROFILE + '.json'
    $cfgPath += @(
        (Join-Path $repo ('skills\git-sync\' + $prof)),
        (Join-Path $repo $prof),
        (Join-Path $PSScriptRoot $prof)
    )
}
$cfgPath += @(
    (Join-Path $repo 'skills\git-sync\sync.config.json'),
    (Join-Path $PSScriptRoot 'sync.config.json')
)
$cfgPath = $cfgPath | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

$cfg = $null
$Branch = ''; $Remote = 'origin'
$Handshake = 'results/status/handshake.json'
$CheckCmd  = 'powershell -NoProfile -ExecutionPolicy Bypass -File code/local_check.ps1'
$TimeoutMin = 30
$LockStaleMin = 45
if ($cfgPath) {
    $cfg = Get-Content -LiteralPath $cfgPath -Encoding UTF8 -Raw | ConvertFrom-Json
    if ($cfg.branch) { $Branch = [string]$cfg.branch }
    if ($cfg.remote) { $Remote = [string]$cfg.remote }
    if ($cfg.handshake) { $Handshake = [string]$cfg.handshake }
    if ($cfg.check_cmd) { $CheckCmd = [string]$cfg.check_cmd }
    if ($cfg.check_timeout_min) { $TimeoutMin = [int]$cfg.check_timeout_min }
    if ($cfg.lock_stale_min) { $LockStaleMin = [int]$cfg.lock_stale_min }
}
if (-not $Branch) { $Branch = (git rev-parse --abbrev-ref HEAD).Trim() }
if ($CheckTimeoutMin -gt 0) { $TimeoutMin = $CheckTimeoutMin }
if ($LockStaleMin -lt ($TimeoutMin + 15)) { $LockStaleMin = $TimeoutMin + 15 }

$taskName = 'git-sync-watch-' + $repoName
$skillVer = ''
$verFile = Join-Path $repo 'skills\git-sync\VERSION'
if (Test-Path -LiteralPath $verFile) { $skillVer = (Get-Content -LiteralPath $verFile -Raw).Trim() }

# local state (heartbeat / log / launcher) - outside the repo on purpose
$stateDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'git-sync' } else { Join-Path $env:TEMP 'git-sync' }
if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Force -Path $stateDir | Out-Null }
$stateFile = Join-Path $stateDir ('watch-' + $repoName + '.json')
$hostLog   = Join-Path $stateDir ('watch-' + $repoName + '.log')
$hostExe   = Join-Path $stateDir ('watchhost-' + $repoName + '.exe')

# ------------------------------------------------------------- state helpers
function Get-State {
    if (-not (Test-Path -LiteralPath $stateFile)) { return $null }
    try { return (Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}
function Set-State {
    param([hashtable]$Fields)
    $cur = Get-State
    $h = [ordered]@{}
    if ($cur) { foreach ($p in $cur.PSObject.Properties) { $h[$p.Name] = $p.Value } }
    foreach ($k in $Fields.Keys) { $h[$k] = $Fields[$k] }
    try {
        $json = ($h | ConvertTo-Json -Depth 6)
        [System.IO.File]::WriteAllText($stateFile, $json + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}
function Add-Log {
    param([string]$Line)
    try {
        $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        [System.IO.File]::AppendAllText($hostLog, ("[$stamp] $Line`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}
function Get-LogTail {
    param([int]$Lines = 12)
    if (-not (Test-Path -LiteralPath $hostLog)) { return @() }
    return @(Get-Content -LiteralPath $hostLog -Tail $Lines -ErrorAction SilentlyContinue)
}

# ------------------------------------------------------- launcher (no window)
# GUI-subsystem launcher: it starts powershell.exe with CreateNoWindow, which
# means Windows never allocates a console window for it. Task Scheduler starts
# THIS exe, so nothing can flash - and no admin rights are needed.
$hostSrc = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;

class GitSyncWatchHost
{
    static StreamWriter log = null;

    static void Say(string s)
    {
        if (log == null || s == null) return;
        try { log.WriteLine(s); log.Flush(); } catch { }
    }

    static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("usage: watchhost <powershell.exe> <script.ps1> [workdir] [logfile]");
            return 2;
        }
        try
        {
            if (args.Length > 3 && args[3].Length > 0)
            {
                string dir = Path.GetDirectoryName(args[3]);
                if (dir != null && dir.Length > 0) Directory.CreateDirectory(dir);
                log = new StreamWriter(new FileStream(args[3], FileMode.Append, FileAccess.Write, FileShare.ReadWrite), new UTF8Encoding(false));
                log.AutoFlush = true;
                Say("== host start " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            }
            ProcessStartInfo psi = new ProcessStartInfo(args[0]);
            psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File \"" + args[1] + "\"";
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WindowStyle = ProcessWindowStyle.Hidden;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            if (args.Length > 2 && args[2].Length > 0) psi.WorkingDirectory = args[2];
            using (Process p = Process.Start(psi))
            {
                p.OutputDataReceived += delegate(object s, DataReceivedEventArgs e) { Say(e.Data); };
                p.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e) { Say(e.Data); };
                p.BeginOutputReadLine();
                p.BeginErrorReadLine();
                p.WaitForExit();
                Say("== host done exit=" + p.ExitCode.ToString() + " " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
                return p.ExitCode;
            }
        }
        catch (Exception ex)
        {
            Say("== host FAILED: " + ex.GetType().Name + ": " + ex.Message);
            return 3;
        }
        finally
        {
            if (log != null) { try { log.Flush(); log.Dispose(); } catch { } }
        }
    }
}
'@

function Get-PowerShellExe {
    $cand = $null
    try { $cand = (Get-Process -Id $PID).Path } catch { }
    if ($cand -and ($cand -match 'powershell\.exe$' -or $cand -match 'pwsh\.exe$')) { return $cand }
    $sys = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path -LiteralPath $sys) { return $sys }
    return 'powershell.exe'
}

function New-WatchHost {
    # compile the launcher; returns the exe path, or '' when compilation fails
    $exe = $hostExe
    $cs  = [System.IO.Path]::ChangeExtension($hostExe, '.cs')
    $tmp = $hostExe + '.new'
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    $ok = $false
    try {
        Add-Type -TypeDefinition $hostSrc -OutputAssembly $tmp -OutputType WindowsApplication -ErrorAction Stop
        $ok = $true
    } catch {
        $ok = $false
    }
    if (-not $ok) {
        # fallback: call the C# compiler of .NET Framework directly
        try {
            [System.IO.File]::WriteAllText($cs, $hostSrc, (New-Object System.Text.UTF8Encoding($false)))
            $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
            if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
            if (Test-Path -LiteralPath $csc) {
                & $csc /nologo /target:winexe /out:$tmp $cs | Out-Null
                if (Test-Path -LiteralPath $tmp) { $ok = $true }
            }
        } catch { $ok = $false }
    }
    if (-not $ok) { return '' }
    # swap in; if the current launcher is running (a poll is in flight) keep a
    # versioned copy instead of failing
    try {
        Move-Item -LiteralPath $tmp -Destination $exe -Force -ErrorAction Stop
        return $exe
    } catch {
        $alt = $hostExe -replace '\.exe$', ('-v' + (Get-Date -Format 'HHmmss') + '.exe')
        try { Move-Item -LiteralPath $tmp -Destination $alt -Force -ErrorAction Stop; return $alt } catch { return '' }
    }
}

function Get-TaskInfo {
    $t = $null
    try { $t = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop } catch { return $null }
    $i = $null
    try { $i = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop } catch { }
    return @{ task = $t; info = $i }
}

function Get-TaskMode {
    param($Task)
    if (-not $Task) { return 'unknown' }
    $exec = ''
    $argstr = ''
    try { $exec = [string]$Task.Actions[0].Execute } catch { }
    try { $argstr = [string]$Task.Actions[0].Arguments } catch { }
    $logon = ''
    try { $logon = [string]$Task.Principal.LogonType } catch { }
    if ($logon -eq 'S4U' -or $logon -eq 'Password') { return 'headless (session 0)' }
    if ($exec -match 'watchhost') { return 'zero-window (launcher exe)' }
    if ($exec -match 'powershell' -or $exec -match 'pwsh') { return 'flash (hidden powershell)' }
    return ("other: $exec $argstr")
}

function Start-TaskNow {
    try { Start-ScheduledTask -TaskName $taskName -ErrorAction Stop; return $true } catch { }
    & schtasks /Run /TN $taskName 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Wait-ForRun {
    param([datetime]$After, [int]$TimeoutSec = 90)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $s = Get-State
        if ($s -and $s.last_run) {
            try { if ([datetime]$s.last_run -ge $After) { return $s } } catch { }
        }
        Start-Sleep -Seconds 3
    }
    return $null
}

# ----------------------------------------------------------- pause / resume
if ($Pause) {
    $null = Disable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($?) { Write-Host "== paused : $taskName  (no polling until .\watch.ps1 -Resume)" -ForegroundColor Green }
    else { Write-Host "[ERROR] task not found: $taskName (nothing to pause)" -ForegroundColor Red }
    exit 0
}
if ($Resume) {
    $null = Enable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($?) { Write-Host "== resumed: $taskName  (polling again)" -ForegroundColor Green }
    else { Write-Host "[ERROR] task not found: $taskName - run .\watch.ps1 -Register first" -ForegroundColor Red }
    exit 0
}

# ------------------------------------------------------------------- status
if ($Status) {
    Write-Host "== watcher status" -ForegroundColor Cyan
    Write-Host ("   repo        : {0}" -f $repo)
    Write-Host ("   branch      : {0} (remote {1})" -f $Branch, $Remote)
    Write-Host ("   task        : {0}" -f $taskName)
    Write-Host ("   skill       : {0}" -f $(if ($skillVer) { "v$skillVer" } else { '(unknown)' }))
    Write-Host ("   state dir   : {0}" -f $stateDir)
    $ti = Get-TaskInfo
    if (-not $ti) {
        Write-Host "   scheduled   : NOT REGISTERED - run .\watch.ps1 -Register" -ForegroundColor Red
    } else {
        $state = ''
        try { $state = [string]$ti.task.State } catch { }
        Write-Host ("   scheduled   : {0} | mode: {1}" -f $state, (Get-TaskMode $ti.task))
        if ($ti.info) {
            Write-Host ("   last run    : {0} | last result: {1}" -f $ti.info.LastRunTime, $ti.info.LastTaskResult)
            Write-Host ("   next run    : {0}" -f $ti.info.NextRunTime)
        }
    }
    $st = Get-State
    if ($st) {
        Write-Host ""
        Write-Host "   heartbeat   :" -ForegroundColor Cyan
        foreach ($p in $st.PSObject.Properties) { Write-Host ("     {0,-14} {1}" -f $p.Name, $p.Value) }
    } else {
        Write-Host "   heartbeat   : (none yet - the task has never completed a poll)" -ForegroundColor Yellow
    }
    $logs = @(Get-ChildItem -Path (Join-Path $repo 'results\status') -Filter 'check_r*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1)
    if ($logs.Count -gt 0) {
        Write-Host ""
        Write-Host ("   last check  : {0}" -f $logs[0].FullName) -ForegroundColor Cyan
        Get-Content -LiteralPath $logs[0].FullName -Tail 6 | ForEach-Object { Write-Host ("     " + $_) }
    }
    Write-Host ""
    Write-Host "   host log    : $hostLog (tail)" -ForegroundColor Cyan
    Get-LogTail 10 | ForEach-Object { Write-Host ("     " + $_) }
    exit 0
}

# --------------------------------------------------------------------- test
if ($Test) {
    $ti = Get-TaskInfo
    if (-not $ti) { Write-Host "[ERROR] not registered yet - run .\watch.ps1 -Register" -ForegroundColor Red; exit 1 }
    Write-Host "== running the scheduled task once (proves the launcher really runs) ..." -ForegroundColor Cyan
    $before = Get-Date
    if (-not (Start-TaskNow)) { Write-Host "[ERROR] could not start the task" -ForegroundColor Red; exit 1 }
    $s = Wait-ForRun -After $before -TimeoutSec $SelfTestSec
    if ($s) {
        Write-Host ("== OK: the watcher ran ({0}) - last action: {1}" -f $s.last_run, $s.last_action) -ForegroundColor Green
        exit 0
    }
    Write-Host "== FAILED: no heartbeat appeared - the task did not really run." -ForegroundColor Red
    Write-Host "   re-register with the fallback launcher:  .\watch.ps1 -Register -Flash" -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------ register task
if ($Register -or $Unregister) {
    if ($Unregister) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        if ($?) { Write-Host "== removed scheduled task: $taskName" -ForegroundColor Green }
        else { schtasks /Delete /TN $taskName /F 2>$null; Write-Host "== removed (schtasks): $taskName" }
        Write-Host "   (the launcher and heartbeat in $stateDir were kept)"
        exit 0
    }

    # which launcher?  zero-window (default) > flash (fallback) > headless (admin)
    $wantHeadless = $Headless.IsPresent
    $wantFlash = $Flash.IsPresent
    $psExe = Get-PowerShellExe
    $taskScript = Join-Path $repo 'watch.ps1'
    if (-not (Test-Path -LiteralPath $taskScript)) { $taskScript = $PSCommandPath }

    $modes = @()
    if ($wantHeadless) { $modes = @('headless') }
    elseif ($wantFlash) { $modes = @('flash') }
    else { $modes = @('zero-window', 'flash') }

    $registered = $false
    $activeMode = ''
    foreach ($mode in $modes) {
        $exe = ''; $arg = ''
        if ($mode -eq 'zero-window') {
            Write-Host "== building the zero-window launcher (no admin needed) ..." -ForegroundColor Cyan
            $exe = New-WatchHost
            if (-not $exe) {
                Write-Host "   [warn] could not compile the launcher - falling back to -Flash" -ForegroundColor Yellow
                Add-Log "register: launcher compilation failed, falling back to flash"
                continue
            }
            Write-Host "   launcher: $exe"
            $arg = '"{0}" "{1}" "{2}" "{3}"' -f $psExe, $taskScript, $repo, $hostLog
        } elseif ($mode -eq 'flash') {
            $exe = $psExe
            $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $taskScript
        } else {
            $exe = $psExe
            $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $taskScript
        }

        $desc = "git-sync v$skillVer watcher | mode=$mode | every ${Interval}m | $repo"
        try {
            $action  = New-ScheduledTaskAction -Execute $exe -Argument $arg -WorkingDirectory $repo
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
                        -RepetitionInterval (New-TimeSpan -Minutes $Interval) `
                        -RepetitionDuration (New-TimeSpan -Days 3650)
            # Task Scheduler must be able to KILL a stuck instance: the launcher
            # waits for the poll to finish, and without a time limit a hung fetch
            # would keep the task "Running" forever (IgnoreNew then blocks every
            # later poll - a silent stall). The limit is the check timeout +10.
            $settings = $null
            try {
                $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
                    -MultipleInstances IgnoreNew `
                    -ExecutionTimeLimit (New-TimeSpan -Minutes ($TimeoutMin + 10)) -ErrorAction Stop
            } catch { $settings = $null }
            $regArgs = @{ TaskName = $taskName; Action = $action; Trigger = $trigger; Description = $desc; Force = $true }
            if ($settings) { $regArgs['Settings'] = $settings }
            if ($mode -eq 'headless') {
                $regArgs['Principal'] = (New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Limited)
            }
            Register-ScheduledTask @regArgs | Out-Null
            $registered = $true
        } catch {
            Write-Host "   [warn] Register-ScheduledTask failed: $($_.Exception.Message)" -ForegroundColor Yellow
            if ($mode -eq 'headless') {
                Write-Host "          S4U needs an ELEVATED PowerShell (access denied 0x80070005 otherwise)." -ForegroundColor Yellow
            } else {
                Write-Host "          trying schtasks.exe instead ..." -ForegroundColor Yellow
                schtasks /Create /F /TN $taskName /SC MINUTE /MO $Interval /TR "`"$exe`" $arg" | Out-Null
                if ($LASTEXITCODE -eq 0) { $registered = $true }
            }
        }
        if (-not $registered) { continue }

        Write-Host "== registered: $taskName (mode=$mode, every $Interval min)" -ForegroundColor Green
        Set-State @{ mode = $mode; interval = $Interval; repo = $repo; branch = $Branch; remote = $Remote; skill = $skillVer; task = $taskName; registered = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
        Add-Log "registered: mode=$mode interval=${Interval}m skill=v$skillVer"

        # SELF-TEST: v2.4.4 taught that "registered" does not mean "runs" -
        # run the task once and wait for the heartbeat before believing it
        Write-Host "== self-test: running the task once and waiting for a heartbeat (max ${SelfTestSec}s) ..." -ForegroundColor Cyan
        $before = Get-Date
        if (Start-TaskNow) {
            $s = Wait-ForRun -After $before -TimeoutSec $SelfTestSec
            if ($s) {
                Write-Host ("== self-test PASSED: the watcher really ran at {0}" -f $s.last_run) -ForegroundColor Green
                $activeMode = $mode
                break
            }
            Write-Host "== self-test FAILED: no heartbeat - this launcher does not work here." -ForegroundColor Red
            Add-Log "self-test FAILED for mode=$mode"
            $registered = $false
        } else {
            Write-Host "== self-test SKIPPED: the task could not be started on demand." -ForegroundColor Yellow
            Write-Host "   (check later with .\watch.ps1 -Status - the trigger fires every $Interval min)" -ForegroundColor Yellow
            $activeMode = $mode
            break
        }
    }

    if (-not $registered) {
        Write-Host ""
        Write-Host "[ERROR] could not register a working watcher." -ForegroundColor Red
        Write-Host "        run .\watch.ps1 -Register -Flash   (visible flash, proven reliable)" -ForegroundColor Yellow
        Write-Host "        output above + '$hostLog' say what failed." -ForegroundColor Yellow
        exit 1
    }

    Write-Host ""
    Write-Host ("== mode: {0}" -f $activeMode) -ForegroundColor Green
    Write-Host "== this watcher will now:"
    Write-Host "   poll $Remote/$Branch every $Interval minutes"
    Write-Host "   and run this check when the agent requests one:"
    Write-Host "     $CheckCmd"
    Write-Host "   verify it any time with: .\watch.ps1 -Status   /   .\watch.ps1 -Test"
    Write-Host "   remove any time with:    .\watch.ps1 -Unregister"
    Write-Host "   pause / resume:          .\watch.ps1 -Pause  /  .\watch.ps1 -Resume"
    Write-Host "   if a push needs a login window, fix it once with .\auth.ps1 -Setup"
    exit 0
}

# ------------------------------------------------------------- single poll
# The poll body is a function on purpose: every exit path returns an exit code
# and the lock is removed by the caller, so a "return" deep inside can never
# leave a stale lock behind (which would stall the watcher until it expires).
function Invoke-PollRound {
    $pollStart = Get-Date
    try {
        Set-State @{ last_run = $pollStart.ToString('yyyy-MM-dd HH:mm:ss'); last_action = 'poll'; host = $env:COMPUTERNAME; pid = $PID }
        Add-Log "poll start (pid $PID)"

        # low-speed timeouts: a stalled network must not hang the poll forever
        git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=60 fetch $Remote --quiet 2>$null

        # read the handshake from the REMOTE tip - do not touch the worktree yet
        # (decode git output as UTF-8 so the Chinese note survives PS 5.1's GBK)
        $hsGit = $Handshake -replace '\\', '/'
        $prevEnc = [Console]::OutputEncoding
        try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
        $raw = git show "$Remote/$Branch`:$hsGit" 2>$null
        try { [Console]::OutputEncoding = $prevEnc } catch { }
        if (-not $raw) { Add-Log 'no handshake yet - idle'; Set-State @{ last_action = 'idle'; last_note = 'no handshake' }; return 0 }
        $hs = (($raw -join "`n") | ConvertFrom-Json)
        if ($hs.arena_state -ne 'awaiting_check' -or $hs.local_state -ne 'pending') {
            Add-Log ("idle (arena={0} local={1})" -f $hs.arena_state, $hs.local_state)
            Set-State @{ last_action = 'idle'; last_note = ("arena={0} local={1}" -f $hs.arena_state, $hs.local_state); last_round = [int]$hs.round }
            return 0
        }

        $round = [int]$hs.round
        Write-Host ("== round {0}: the agent requested a local check - syncing ..." -f $round)
        Add-Log "round $round requested: $($hs.note)"

        # 1. sync (stash + pull; the same command the user runs by hand)
        $sync = Join-Path $repo 'sync.ps1'
        if (-not (Test-Path -LiteralPath $sync)) { $sync = Join-Path $PSScriptRoot 'sync.ps1' }
        $global:LASTEXITCODE = 0
        & $sync
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] sync failed - retrying next poll" -ForegroundColor Red
            Add-Log "round $round: sync FAILED (exit $LASTEXITCODE)"
            Set-State @{ last_action = 'error'; last_note = 'sync failed' }
            return 1
        }

        # 1b. re-read the handshake from the synced worktree (UTF-8, BOM-tolerant)
        $hsAbs = Join-Path $repo $hsGit
        $hs = Get-Content -LiteralPath $hsAbs -Encoding UTF8 -Raw | ConvertFrom-Json

        # 1c. another watcher (another clone) may have answered this round in the
        #     meantime: if the remote tip is no longer "pending", leave it alone
        $prevEnc = [Console]::OutputEncoding
        try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
        $rawRemote = git show "$Remote/$Branch`:$hsGit" 2>$null
        try { [Console]::OutputEncoding = $prevEnc } catch { }
        if ($rawRemote) {
            try {
                $hsRemote = (($rawRemote -join "`n") | ConvertFrom-Json)
                if ($hsRemote.round -eq $round -and $hsRemote.local_state -ne 'pending') {
                    Write-Host ("== round {0} was already answered elsewhere ({1}) - nothing to do" -f $round, $hsRemote.local_state) -ForegroundColor Yellow
                    Add-Log "round $round already answered remotely ($($hsRemote.local_state)) - skipping"
                    Set-State @{ last_action = 'skipped'; last_note = 'round already answered elsewhere'; last_round = $round }
                    return 0
                }
            } catch { }
        }

        # 2. run the local check: stdout+stderr captured separately, real exit
        #    code, hard timeout. -NoNewWindow -> the child inherits this
        #    process's (hidden) console, so no window can appear.
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $logRel = "results/status/check_r${round}_${stamp}.txt"
        $logAbs = Join-Path $repo ($logRel -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logAbs) | Out-Null
        Write-Host ("== running: {0}" -f $CheckCmd)
        Add-Log "round $round: running $CheckCmd"

        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()
        $code = 1
        $timedOut = $false
        $t0 = Get-Date
        try {
            $parts = @([regex]::Matches($CheckCmd, '"([^"]*)"' + '|' + '(\S+)') | ForEach-Object {
                if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } })
            if ($parts.Count -eq 0) { throw 'empty check_cmd' }
            $exe = $parts[0]
            $exeArgs = @()
            if ($parts.Count -gt 1) { $exeArgs = @($parts[1..($parts.Count - 1)]) }
            $p = Start-Process -FilePath $exe -ArgumentList $exeArgs -WorkingDirectory $repo -NoNewWindow -PassThru `
                    -RedirectStandardOutput $outFile -RedirectStandardError $errFile
            if (-not $p.WaitForExit($TimeoutMin * 60 * 1000)) {
                $timedOut = $true
                try { $p.Kill() } catch { }
                try { $null = $p.WaitForExit(10000) } catch { }
            }
            $code = $p.ExitCode
        } catch {
            $stdout = "check_cmd could not be started: $($_.Exception.Message)"
            $code = 1
        }
        $secs = [int]((Get-Date) - $t0).TotalSeconds
        if (-not $stdout) { $stdout = '' }
        $stderr = ''
        if ($outFile -and (Test-Path -LiteralPath $outFile)) {
            $t = (Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue)
            if ($t) { $stdout = $t }
        }
        if ($errFile -and (Test-Path -LiteralPath $errFile)) {
            $t = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
            if ($t) { $stderr = $t }
        }
        Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue

        if ($timedOut) { $code = 1 }
        $verdict = if ($code -eq 0 -and -not $timedOut) { 'passed' } else { 'failed' }
        # field lesson 2026-09-15 (agentarena-w1): a dead check_cmd chain can
        # exit 0 with ZERO output and every round then "passes" vacuously.
        # Record the elapsed time and make an empty run explicit.
        $body = @()
        if ($stdout) { $body += ($stdout -split "`r?`n") }
        if ($stderr) {
            $body += @('', '--- stderr ---')
            $body += ($stderr -split "`r?`n")
        }
        $outLines = @($body | Where-Object { "$_" -match '\S' })
        if ($outLines.Count -eq 0) { $outLines = @('(check_cmd produced no output; if elapsed is near 0 this pass may be a silent no-op - verify the check really ran)') }
        $head = @("check round $round on $env:COMPUTERNAME - $verdict (exit $code)", "cmd: $CheckCmd", "elapsed: ${secs}s")
        if ($timedOut) { $head += "TIMEOUT: killed after $TimeoutMin min" }
        $text = $head + @('') + $outLines
        [System.IO.File]::WriteAllText($logAbs, ($text -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
        Write-Host ("== check {0} (log: {1}, {2}s)" -f $verdict, $logRel, $secs) -ForegroundColor $(if ($code -eq 0) { 'Green' } else { 'Red' })
        Add-Log "round $round: check $verdict (exit $code, ${secs}s)"
        Set-State @{ last_action = 'check'; last_round = $round; last_verdict = $verdict; last_check = $logRel; last_check_secs = $secs }

        # 3. update the handshake (worktree) with the verdict - UTF-8 WITHOUT BOM
        #    (PS 5.1 Set-Content -Encoding UTF8 adds a BOM that breaks json.load
        #     on the agent side, so write the bytes explicitly)
        $hs.local_state   = $verdict
        $hs.local_updated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $hs.host          = $env:COMPUTERNAME
        $hsJson = $hs | ConvertTo-Json -Depth 6
        [System.IO.File]::WriteAllText($hsAbs, $hsJson + "`r`n", (New-Object System.Text.UTF8Encoding($false)))

        # 4. push the verdict back (silent mode: a prompt here would hang the poll)
        $push = Join-Path $repo 'push.ps1'
        if (-not (Test-Path -LiteralPath $push)) { $push = Join-Path $PSScriptRoot 'push.ps1' }
        $pushed = $false
        $pushNote = ''
        for ($try = 1; $try -le 3; $try++) {
            $global:LASTEXITCODE = 0
            & $push -NoPrompt ("check: round {0} {1}" -f $round, $verdict)
            $pushCode = $LASTEXITCODE
            if ($pushCode -eq 0) { $pushed = $true; break }
            if ($pushCode -eq 4) {
                $pushNote = 'auth: no silent credential (run auth.ps1 -Setup)'
                Add-Log "round $round: push BLOCKED by auth - run .\auth.ps1 -Setup"
                Write-Host '[AUTH] the verdict could not be pushed silently - run .\auth.ps1 -Setup' -ForegroundColor Red
                break
            }
            $pushNote = "push failed (exit $pushCode), attempt $try"
            Add-Log "round $round: push attempt $try failed (exit $pushCode)"
            if ($try -lt 3) { Start-Sleep -Seconds 20 }
        }
        if ($pushed) {
            Set-State @{ last_action = 'push'; last_push = 'ok'; last_round = $round }
            Write-Host "== verdict pushed back to $Remote/$Branch" -ForegroundColor Green
            return 0
        }
        Set-State @{ last_action = 'push'; last_push = $pushNote; last_round = $round }
        Write-Host "== [WARN] verdict NOT pushed ($pushNote) - the agent keeps waiting" -ForegroundColor Red
        return 1
    } finally {
        Add-Log ("poll took {0}s" -f [int]((Get-Date) - $pollStart).TotalSeconds)
    }
}

$lock = Join-Path $env:TEMP ($taskName + '.lock')
$skip = $false
if (Test-Path -LiteralPath $lock) {
    # a hard crash can leave the lock behind and stall the watcher forever - a
    # lock older than LockStaleMin (default: check timeout + 15) is stale
    try {
        $lockAge = ((Get-Date) - (Get-Item -LiteralPath $lock).LastWriteTime).TotalMinutes
        if ($lockAge -gt $LockStaleMin) {
            Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
            Add-Log ("stale lock removed (age: {0} min)" -f [int]$lockAge)
            Write-Output ("stale lock removed (age: {0} min)" -f [int]$lockAge)
        } else { $skip = $true }
    } catch { $skip = $true }
}
if ($skip) { exit 0 }

Set-Content -LiteralPath $lock -Value (Get-Date).ToString('s')
$pollCode = 1
try {
    $pollCode = Invoke-PollRound
} catch {
    Add-Log "poll crashed: $($_.Exception.Message)"
    Write-Host "[ERROR] poll crashed: $($_.Exception.Message)" -ForegroundColor Red
    $pollCode = 1
} finally {
    Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
}
exit $pollCode
