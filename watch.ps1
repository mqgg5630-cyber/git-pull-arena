# watch.ps1 - the local half of the auto-verification handshake.
#
# Registers a Windows scheduled task that polls the remote branch. When the
# agent requests a check (arena_state=awaiting_check, local_state=pending in
# the handshake file), the watcher automatically:
#     sync -> run the local check (check_cmd) -> write the log ->
#     push the verdict (passed/failed) back to the branch.
# The agent then reads the verdict with agent-check.sh --read and either
# accepts (loop ends) or fixes and requests another round.
#
# Usage (inside the repo folder):
#     .\watch.ps1 -Register              # once per machine: create the task
#     .\watch.ps1 -Register -Interval 10 # poll every 10 minutes instead of 2
#     .\watch.ps1 -Status                # is the watcher alive? mode, heartbeat, verdict
#     .\watch.ps1 -Test                  # run the task once NOW and verify it really ran
#     .\watch.ps1                        # one manual poll right now
#     .\watch.ps1 -Loop                  # poll forever in this console (what the task runs)
#     .\watch.ps1 -Pause / -Resume       # stop / restart polling (task stays)
#     .\watch.ps1 -Unregister            # remove the scheduled task
#     .\watch.ps1 -Register -Flash       # fallback launcher (brief flash per LOGON)
#     .\watch.ps1 -Register -Headless    # zero window via S4U (session 0, ADMIN console!)
#
# WINDOW BEHAVIOUR - why v2.6.0 went "one process per logon":
#   A console app started by Task Scheduler ALWAYS gets a console window first;
#   '-WindowStyle Hidden' can only hide it afterwards. That is why the old design
#   flashed every poll (720 times a day at 2-minute polling) - user requirement
#   #1 is "no popup", so v2.6.0 registers ONE long-lived process per logon
#   (`watch.ps1 -Loop`) and lets it poll inside itself. Consequences:
#     * launcher mode (default): the task starts a tiny GUI-subsystem launcher
#       (compiled into %LOCALAPPDATA%\git-sync\, no admin, no VBScript) which
#       starts powershell with CreateNoWindow -> ZERO windows, ever;
#     * flash mode (fallback, automatic if the launcher fails its smoke test):
#       exactly ONE brief flash per logon/session, not one per poll;
#     * -Headless (S4U/session 0): zero windows too, but needs an ELEVATED
#       console to register and a credential store GCM can read from session 0
#       (gh auth setup-git is the easy one - see auth.ps1).
#   The task also gets a KeeperMin repetition trigger: if the long-lived process
#   ever dies, the next keeper tick starts it again (IgnoreNew means it does
#   nothing while the process is alive, so no extra windows).
#   Register always SMOKE-TESTS the launcher with a throwaway script, then
#   SELF-TESTS the registered task, and falls back to -Flash automatically if
#   the launcher does not run. After upgrading the skill, re-register
#   (.\watch.ps1 -Unregister ; .\watch.ps1 -Register) so the loop uses the new
#   code - a running loop keeps the code it started with.
#
# All of watch.ps1's own child processes inherit its hidden console, so they
# cannot flash either. Local state (heartbeat, log, launcher) lives in
# %LOCALAPPDATA%\git-sync\ - never in the repo, so nothing of it reaches git.
#
# NB: inside a double-quoted string write "${name}:" - a bare "$name:" parses as
# a drive-qualified variable name and kills the whole file at parse time.
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
    [switch]$Loop,
    [switch]$Headless,
    [switch]$Flash,
    [int]$CheckTimeoutMin = 0,
    [int]$SelfTestSec = 90,
    [int]$KeeperMin = 30
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
$lockFile  = Join-Path $env:TEMP ($taskName + '.lock')

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
        # keep the log bounded: rotate at 2 MB (a long-lived loop logs a lot)
        if (Test-Path -LiteralPath $hostLog) {
            $len = (Get-Item -LiteralPath $hostLog -ErrorAction SilentlyContinue).Length
            if ($len -gt 2MB) {
                $keep = @(Get-Content -LiteralPath $hostLog -Tail 200 -ErrorAction SilentlyContinue)
                [System.IO.File]::WriteAllLines($hostLog, (@('(log rotated)') + $keep), (New-Object System.Text.UTF8Encoding($false)))
            }
        }
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
# GUI-subsystem launcher: Task Scheduler starts THIS exe, it starts powershell
# with CreateNoWindow, so Windows never allocates a console window at all.
# Extra arguments after the logfile are forwarded to the script (used for -Loop).
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
            Console.Error.WriteLine("usage: watchhost <powershell.exe> <script.ps1> [workdir] [logfile] [extra args...]");
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
            string cmd = "-NoProfile -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File \"" + args[1] + "\"";
            for (int i = 4; i < args.Length; i++) cmd += " " + args[i];
            psi.Arguments = cmd;
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
                & $csc /nologo /target:winexe /out:$tmp $cs 2>&1 | Out-Null
                if (Test-Path -LiteralPath $tmp) { $ok = $true }
            }
        } catch { $ok = $false }
    }
    if (-not $ok) { return '' }
    try {
        Move-Item -LiteralPath $tmp -Destination $exe -Force -ErrorAction Stop
        return $exe
    } catch {
        $alt = $hostExe -replace '\.exe$', ('-v' + (Get-Date -Format 'HHmmss') + '.exe')
        try { Move-Item -LiteralPath $tmp -Destination $alt -Force -ErrorAction Stop; return $alt } catch { return '' }
    }
}

function Test-WatchHost {
    # run the launcher ONCE on a throwaway script and see whether the marker
    # file appears. This isolates "the launcher works" from "Task Scheduler
    # starts it" - the two can fail independently and used to look the same.
    param([string]$Exe, [string]$PsExe)
    if (-not $Exe) { return $false }
    $marker = Join-Path $stateDir ('smoke-' + $repoName + '.txt')
    Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
    $smokePs = Join-Path $stateDir ('smoke-' + $repoName + '.ps1')
    # BOM on purpose: PS 5.1 reads a BOM-less file as ANSI and the marker path
    # may contain non-ASCII characters (e.g. a user name)
    $line = "[System.IO.File]::WriteAllText('" + $marker + "', (Get-Date).ToString('o'))"
    [System.IO.File]::WriteAllText($smokePs, $line, (New-Object System.Text.UTF8Encoding($true)))
    $markerB = Join-Path $stateDir ('hostmark-' + $repoName + '.txt')
    Remove-Item -LiteralPath $markerB -Force -ErrorAction SilentlyContinue
    $p = $null
    try {
        $p = Start-Process -FilePath $Exe -ArgumentList @($PsExe, $smokePs, $repo, $markerB) -NoNewWindow -PassThru
    } catch {
        Add-Log "launcher smoke test could not start: $($_.Exception.Message)"
        return $false
    }
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $marker) {
            try { $p.Kill() } catch { }
            return $true
        }
        if ($p -and $p.HasExited -and -not (Test-Path -LiteralPath $marker)) { break }
        Start-Sleep -Milliseconds 700
    }
    try { if ($p -and -not $p.HasExited) { $p.Kill() } } catch { }
    Add-Log "launcher smoke test FAILED (no marker) - see the host log lines above"
    return $false
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
    if ($exec -match 'watchhost') {
        if ($argstr -match '-Loop') { return 'zero-window loop (launcher exe)' }
        return 'zero-window (launcher exe)'
    }
    if ($exec -match 'powershell' -or $exec -match 'pwsh') {
        if ($argstr -match '-Loop') { return 'loop (one flash per logon)' }
        return 'flash (hidden powershell)'
    }
    return ("other: $exec $argstr")
}

function Start-TaskNow {
    try { Start-ScheduledTask -TaskName $taskName -ErrorAction Stop; return $true } catch { }
    & schtasks /Run /TN $taskName 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}
function Stop-TaskNow {
    try { Stop-ScheduledTask -TaskName $taskName -ErrorAction Stop; return $true } catch { }
    & schtasks /End /TN $taskName 2>&1 | Out-Null
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

function Test-ProxyHint {
    $gp = ''
    try { $gp = ((git config --get http.proxy 2>$null | Out-String).Trim()) } catch { }
    if (-not $gp) { try { $gp = ((git config --get https.proxy 2>$null | Out-String).Trim()) } catch { } }
    if ($gp -and -not $env:HTTPS_PROXY) {
        Write-Host ("   hint: git uses proxy $gp but HTTPS_PROXY is not set -") -ForegroundColor Yellow
        Write-Host "         gh and other tools will NOT use it:  $env:HTTPS_PROXY = '$gp'" -ForegroundColor Yellow
    }
}

function Show-TaskDiagnostics {
    $ti = Get-TaskInfo
    if ($ti -and $ti.info) {
        Write-Host ("     task: last run {0} | result {1} | next {2}" -f $ti.info.LastRunTime, $ti.info.LastTaskResult, $ti.info.NextRunTime) -ForegroundColor DarkGray
    }
    if (Test-Path -LiteralPath $hostLog) {
        Write-Host "     host log (tail):" -ForegroundColor DarkGray
        Get-LogTail 12 | ForEach-Object { Write-Host ("       " + $_) -ForegroundColor DarkGray }
    }
}

# ----------------------------------------------------------- pause / resume
if ($Pause) {
    $null = Stop-TaskNow
    $null = Disable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($?) { Write-Host "== paused : $taskName  (stopped + disabled until .\watch.ps1 -Resume)" -ForegroundColor Green }
    else { Write-Host "[ERROR] task not found: $taskName (nothing to pause)" -ForegroundColor Red }
    exit 0
}
if ($Resume) {
    $null = Enable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($?) {
        $null = Start-TaskNow
        Write-Host "== resumed: $taskName  (polling again)" -ForegroundColor Green
    } else { Write-Host "[ERROR] task not found: $taskName - run .\watch.ps1 -Register first" -ForegroundColor Red }
    exit 0
}

# ------------------------------------------------------------------- status
if ($Status) {
    $ti = Get-TaskInfo
    $st = Get-State
    Write-Host "== watcher status" -ForegroundColor Cyan
    Test-ProxyHint
    Write-Host ("   repo        : {0}" -f $repo)
    Write-Host ("   branch      : {0} (remote {1})" -f $Branch, $Remote)
    Write-Host ("   task        : {0}" -f $taskName)
    Write-Host ("   skill       : {0}" -f $(if ($skillVer) { "v$skillVer" } else { '(unknown)' }))
    Write-Host ("   state dir   : {0}" -f $stateDir)
    if (-not $ti) {
        Write-Host "   scheduled   : NOT REGISTERED - run .\watch.ps1 -Register" -ForegroundColor Red
    } else {
        $state = ''
        try { $state = [string]$ti.task.State } catch { }
        Write-Host ("   scheduled   : {0} | mode: {1}" -f $state, (Get-TaskMode $ti.task))
        if ($ti.info) {
            Write-Host ("   last run    : {0} | schedule result: {1}" -f $ti.info.LastRunTime, $ti.info.LastTaskResult)
            Write-Host ("   next keeper : {0}" -f $ti.info.NextRunTime)
        }
    }
    if ($st) {
        Write-Host ""
        Write-Host "   heartbeat   :" -ForegroundColor Cyan
        foreach ($p in $st.PSObject.Properties) { Write-Host ("     {0,-14} {1}" -f $p.Name, $p.Value) }
        $alive = 'unknown'
        if ($st.pid) {
            if (Get-Process -Id ([int]$st.pid) -ErrorAction SilentlyContinue) { $alive = "yes (pid $($st.pid) is running)" }
            else { $alive = "no (pid $($st.pid) exited)" }
        }
        if ($st.last_run) {
            try {
                $age = [int]((Get-Date) - [datetime]$st.last_run).TotalMinutes
                $limit = [int]($Interval * 2 + 2)
                $verdict = if ($age -le $limit) { 'fresh' } else { "STALE (${age} min > ${limit}) - the loop may be dead" }
                Write-Host ("   loop alive  : {0} | heartbeat age: {1} min ({2})" -f $alive, $age, $verdict) -ForegroundColor $(if ($age -le $limit) { 'Green' } else { 'Yellow' })
            } catch { Write-Host ("   loop alive  : {0}" -f $alive) }
        } else {
            Write-Host ("   loop alive  : {0}" -f $alive)
        }
    } else {
        Write-Host "   heartbeat   : (none yet - the task has never completed a poll)" -ForegroundColor Yellow
    }
    $logs = @(Get-ChildItem -Path (Join-Path $repo 'results\status') -Filter 'check_r*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1)
    if ($logs.Count -gt 0) {
        Write-Host ""
        Write-Host ("   last check  : {0}" -f $logs[0].FullName) -ForegroundColor Cyan
        Get-Content -LiteralPath $logs[0].FullName -Tail 8 | ForEach-Object { Write-Host ("     " + $_) }
    }
    Write-Host ""
    Write-Host "   host log    : $hostLog (tail)" -ForegroundColor Cyan
    Get-LogTail 12 | ForEach-Object { Write-Host ("     " + $_) }
    exit 0
}

# --------------------------------------------------------------------- test
if ($Test) {
    $ti = Get-TaskInfo
    if (-not $ti) { Write-Host "[ERROR] not registered yet - run .\watch.ps1 -Register" -ForegroundColor Red; exit 1 }
    # a long-lived loop is meant to keep running: if it is alive and its
    # heartbeat is fresh, that IS the proof - do not wait for a new launch
    $st0 = Get-State
    $taskState = ''
    try { $taskState = [string]$ti.task.State } catch { }
    if ($taskState -eq 'Running' -and $st0 -and $st0.last_run) {
        try {
            $age0 = [int]((Get-Date) - [datetime]$st0.last_run).TotalMinutes
            if ($age0 -le ($Interval * 2 + 2)) {
                Write-Host ("== OK: the watcher loop is already running (heartbeat {0}, {1} min ago)" -f $st0.last_run, $age0) -ForegroundColor Green
                exit 0
            }
        } catch { }
    }
    Write-Host "== running the scheduled task once (proves the launcher really runs) ..." -ForegroundColor Cyan
    $before = Get-Date
    if (-not (Start-TaskNow)) { Write-Host "[ERROR] could not start the task" -ForegroundColor Red; exit 1 }
    $s = Wait-ForRun -After $before -TimeoutSec $SelfTestSec
    if ($s) {
        Write-Host ("== OK: the watcher ran ({0}) - last action: {1}" -f $s.last_run, $s.last_action) -ForegroundColor Green
        exit 0
    }
    Write-Host "== FAILED: no heartbeat appeared - the task did not really run." -ForegroundColor Red
    Show-TaskDiagnostics
    Write-Host "   re-register with the fallback launcher:  .\watch.ps1 -Register -Flash" -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------ register task
if ($Register -or $Unregister) {
    if ($Unregister) {
        $null = Stop-TaskNow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        if ($?) { Write-Host "== removed scheduled task: $taskName" -ForegroundColor Green }
        else { schtasks /Delete /TN $taskName /F 2>$null; Write-Host "== removed (schtasks): $taskName" }
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
        Write-Host "   (the launcher and heartbeat in $stateDir were kept)"
        exit 0
    }

    # stop a previous instance first: a running (old-code) loop would otherwise
    # survive the re-registration and keep polling with stale scripts
    if (Get-TaskInfo) { $null = Stop-TaskNow; Start-Sleep -Seconds 2; Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue }

    $psExe = Get-PowerShellExe
    $taskScript = Join-Path $repo 'watch.ps1'
    if (-not (Test-Path -LiteralPath $taskScript)) { $taskScript = $PSCommandPath }

    # environment preflight: the task inherits the USER environment, which is
    # not always the PATH this console has (custom git installs, conda tools)
    $gitExe = ''
    $gcmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gcmd) {
        $gitExe = [string]$gcmd.Source
        if (-not $gitExe) { $gitExe = [string]$gcmd.Path }
        if (-not $gitExe) { $gitExe = [string]$gcmd.Definition }
    }
    if (-not $gitExe) {
        Write-Host "[ERROR] git is not on PATH in this console - the watcher will not find it." -ForegroundColor Red
        Write-Host "        add git to the PATH of your USER account and register again." -ForegroundColor Yellow
        exit 1
    }
    $bashExe = ''
    $bcmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bcmd) {
        $bashExe = [string]$bcmd.Source
        if (-not $bashExe) { $bashExe = [string]$bcmd.Path }
        if (-not $bashExe) { $bashExe = [string]$bcmd.Definition }
    }
    $gitProxy = ''
    try { $gitProxy = ((git config --get http.proxy 2>$null | Out-String).Trim()) } catch { }
    if (-not $gitProxy) { try { $gitProxy = ((git config --get https.proxy 2>$null | Out-String).Trim()) } catch { } }
    Write-Host "== environment for the task:"
    Write-Host ("   git  : {0}" -f $gitExe)
    Write-Host ("   bash : {0}" -f $(if ($bashExe) { $bashExe } else { '(missing - the repo gate needs it)' }))
    Write-Host ("   ps   : {0}" -f $psExe)
    Write-Host ("   proxy: {0}" -f $(if ($gitProxy) { "$gitProxy (git config http.proxy)" } else { '(none in git config - gh/other tools need HTTPS_PROXY)' }))

    # ---- decide the launch mode -------------------------------------------
    $mode = ''
    $exe  = ''
    $arg  = ''
    if ($Headless) {
        $mode = 'headless'
        $exe = $psExe
        $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Loop' -f $taskScript
    } else {
        if (-not $Flash) {
            Write-Host "== building the zero-window launcher (no admin needed) ..." -ForegroundColor Cyan
            $hostPath = New-WatchHost
            if ($hostPath) {
                Write-Host ("   launcher: {0}" -f $hostPath)
                Write-Host "== smoke-testing the launcher (throwaway script, 60s max) ..." -ForegroundColor Cyan
                if (Test-WatchHost -Exe $hostPath -PsExe $psExe) {
                    Write-Host "   launcher works - the task will run with ZERO windows" -ForegroundColor Green
                    $mode = 'zero-window'
                    $exe = $hostPath
                    $arg = '"{0}" "{1}" "{2}" "{3}" -Loop' -f $psExe, $taskScript, $repo, $hostLog
                } else {
                    Write-Host "   [warn] launcher did not produce its marker - falling back to -Flash" -ForegroundColor Yellow
                    Write-Host "          (details are in $hostLog)" -ForegroundColor DarkGray
                }
            } else {
                Write-Host "   [warn] could not compile the launcher - falling back to -Flash" -ForegroundColor Yellow
            }
        }
        if (-not $mode) {
            # fallback: one brief flash per LOGON (not per poll - the task runs
            # the whole -Loop in that one process)
            $mode = 'flash'
            $exe = $psExe
            $arg = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Loop' -f $taskScript
        }
    }

    $desc = "git-sync v$skillVer watcher | mode=$mode | loop every ${Interval}m | $repo"
    $registered = $false
    try {
        $action  = New-ScheduledTaskAction -Execute $exe -Argument $arg -WorkingDirectory $repo
        $triggers = @()
        try {
            $triggers += New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME -ErrorAction Stop
        } catch {
            $triggers += New-ScheduledTaskTrigger -AtLogOn -ErrorAction SilentlyContinue
        }
        # keeper tick: restarts the loop if it ever died (IgnoreNew = a no-op
        # while the loop is alive, so it costs no window and no work)
        $triggers += New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
                        -RepetitionInterval (New-TimeSpan -Minutes $KeeperMin) `
                        -RepetitionDuration (New-TimeSpan -Days 3650)
        # the loop is meant to live forever: no execution time limit
        $settings = $null
        try {
            $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
                -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
                -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ErrorAction Stop
        } catch { $settings = $null }
        $regArgs = @{ TaskName = $taskName; Action = $action; Trigger = $triggers; Description = $desc; Force = $true }
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
            schtasks /Create /F /TN $taskName /SC MINUTE /MO $KeeperMin /TR "`"$exe`" $arg" | Out-Null
            if ($LASTEXITCODE -eq 0) { $registered = $true }
        }
    }

    if (-not $registered) {
        Write-Host ""
        Write-Host "[ERROR] could not register the watcher." -ForegroundColor Red
        Write-Host "        run .\watch.ps1 -Register -Flash   (visible flash once per logon)" -ForegroundColor Yellow
        Write-Host "        output above + '$hostLog' say what failed." -ForegroundColor Yellow
        exit 1
    }

    Set-State @{ mode = $mode; interval = $Interval; repo = $repo; branch = $Branch; remote = $Remote;
                 skill = $skillVer; task = $taskName; git = $gitExe; bash = $bashExe; powershell = $psExe; proxy = $gitProxy;
                 launcher = $(if ($mode -eq 'zero-window') { $exe } else { '' });
                 registered = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
    Add-Log "registered: mode=$mode interval=${Interval}m keeper=${KeeperMin}m skill=v$skillVer git=$gitExe bash=$bashExe proxy=$gitProxy"
    Write-Host "== registered: $taskName (mode=$mode, loop every $Interval min, keeper tick every $KeeperMin min)" -ForegroundColor Green

    # ---- self-test: start it now and wait for a real heartbeat -------------
    Write-Host "== self-test: starting the task and waiting for a heartbeat (max ${SelfTestSec}s) ..." -ForegroundColor Cyan
    $before = Get-Date
    if (Start-TaskNow) {
        $s = Wait-ForRun -After $before -TimeoutSec $SelfTestSec
        if ($s) {
            Write-Host ("== self-test PASSED: the watcher is running (heartbeat {0})" -f $s.last_run) -ForegroundColor Green
        } else {
            Write-Host "== self-test FAILED: no heartbeat - this launch mode does not work here." -ForegroundColor Red
            Show-TaskDiagnostics
            Add-Log "self-test FAILED for mode=$mode"
            if ($mode -eq 'zero-window') {
                Write-Host "   retrying automatically in the fallback mode (-Flash) ..." -ForegroundColor Yellow
                Write-Host "   run:  .\watch.ps1 -Register -Flash" -ForegroundColor Yellow
            }
            exit 1
        }
    } else {
        Write-Host "== self-test SKIPPED: the task could not be started on demand." -ForegroundColor Yellow
        Write-Host "   (it will start at logon and on the keeper tick - check .\watch.ps1 -Status)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host ("== mode: {0}" -f $mode) -ForegroundColor Green
    if ($mode -eq 'zero-window') {
        Write-Host "   the watcher runs as ONE windowless process per logon (no flash at all)" -ForegroundColor Gray
    } elseif ($mode -eq 'flash') {
        Write-Host "   the watcher runs as ONE process per logon: expect ONE brief flash" -ForegroundColor Gray
        Write-Host "   per logon - not per poll. For zero: -Register -Headless (admin) or" -ForegroundColor Gray
        Write-Host "   fix the launcher (see the host log) and re-register." -ForegroundColor Gray
    } else {
        Write-Host "   session 0 (S4U): no window, but the credential helper must work there" -ForegroundColor Gray
        Write-Host "   (gh auth setup-git is the easy one - see .\auth.ps1)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "== this watcher will now:"
    Write-Host "   poll $Remote/$Branch every $Interval minutes (inside one process)"
    Write-Host "   and run this check when the agent requests one:"
    Write-Host "     $CheckCmd"
    Write-Host "   verify it any time with: .\watch.ps1 -Status   /   .\watch.ps1 -Test"
    Write-Host "   remove any time with:    .\watch.ps1 -Unregister"
    Write-Host "   pause / resume:          .\watch.ps1 -Pause  /  .\watch.ps1 -Resume"
    Write-Host "   after upgrading the skill, re-register so the loop runs the new code"
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
        Add-Log "round ${round} requested: $($hs.note)"

        # 1. sync (stash + pull; the same command the user runs by hand)
        $sync = Join-Path $repo 'sync.ps1'
        if (-not (Test-Path -LiteralPath $sync)) { $sync = Join-Path $PSScriptRoot 'sync.ps1' }
        $global:LASTEXITCODE = 0
        & $sync
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] sync failed - retrying next poll" -ForegroundColor Red
            Add-Log "round ${round}: sync FAILED (exit $LASTEXITCODE)"
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
                    Add-Log "round ${round} already answered remotely ($($hsRemote.local_state)) - skipping"
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
        Add-Log "round ${round}: running $CheckCmd"

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
        Add-Log "round ${round}: check $verdict (exit $code, ${secs}s)"
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
        $pushDetail = ''
        for ($try = 1; $try -le 3; $try++) {
            $global:LASTEXITCODE = 0
            # capture the output so the heartbeat/log can say WHY it failed -
            # "exit 3" alone tells nobody anything (field lesson 2026-09-15)
            $pushOut = (& $push -NoPrompt ("check: round {0} {1}" -f $round, $verdict) 2>&1 | Out-String)
            $pushCode = $LASTEXITCODE
            $pushDetail = (($pushOut -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 4) -join ' / ')
            if ($pushOut) { Write-Host $pushOut }
            if ($pushCode -eq 0) { $pushed = $true; break }
            if ($pushCode -eq 4) {
                $pushNote = 'auth: no silent credential (run auth.ps1 -Setup)'
                Add-Log "round ${round}: push BLOCKED by auth - run .\auth.ps1 -Setup"
                Write-Host '[AUTH] the verdict could not be pushed silently - run .\auth.ps1 -Setup' -ForegroundColor Red
                break
            }
            $pushNote = "push failed (exit $pushCode), attempt $try"
            Add-Log "round ${round}: push attempt $try failed (exit $pushCode): $pushDetail"
            if ($try -lt 3) { Start-Sleep -Seconds 20 }
        }
        if ($pushed) {
            Set-State @{ last_action = 'push'; last_push = 'ok'; last_push_detail = ''; last_round = $round }
            Write-Host "== verdict pushed back to $Remote/$Branch" -ForegroundColor Green
            return 0
        }
        Set-State @{ last_action = 'push'; last_push = $pushNote; last_push_detail = $pushDetail; last_round = $round }
        Write-Host "== [WARN] verdict NOT pushed ($pushNote) - the agent keeps waiting" -ForegroundColor Red
        return 1
    } finally {
        Add-Log ("poll took {0}s" -f [int]((Get-Date) - $pollStart).TotalSeconds)
    }
}

# one poll, guarded by a lock (manual runs and the loop can coexist)
function Invoke-PollOnce {
    $skip = $false
    if (Test-Path -LiteralPath $lockFile) {
        # a hard crash can leave the lock behind and stall the watcher forever -
        # a lock older than LockStaleMin (default: check timeout + 15) is stale
        try {
            $lockAge = ((Get-Date) - (Get-Item -LiteralPath $lockFile).LastWriteTime).TotalMinutes
            if ($lockAge -gt $LockStaleMin) {
                Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
                Add-Log ("stale lock removed (age: {0} min)" -f [int]$lockAge)
            } else { $skip = $true }
        } catch { $skip = $true }
    }
    if ($skip) { return 0 }

    Set-Content -LiteralPath $lockFile -Value (Get-Date).ToString('s')
    $code = 1
    try {
        $code = Invoke-PollRound
    } catch {
        Add-Log "poll crashed: $($_.Exception.Message)"
        Write-Host "[ERROR] poll crashed: $($_.Exception.Message)" -ForegroundColor Red
        $code = 1
    } finally {
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
    }
    return $code
}

if ($Loop) {
    Add-Log "loop start (pid $PID, every ${Interval}m, skill v$skillVer)"
    while ($true) {
        $null = Invoke-PollOnce
        Start-Sleep -Seconds ($Interval * 60)
    }
} else {
    exit (Invoke-PollOnce)
}
