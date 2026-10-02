# t130_vpn_agy_wps.ps1 - round 172 combined operations.
# 1) Fix local Green VPN autostart from the public desktop shortcut.
# 2) Diagnose/refresh desktop Antigravity agent error state.
# 3) Continue prior desktop WPS work by rebuilding/verifying the AMP deck.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m }
function Write-Utf8([string]$Path, [string[]]$Lines) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outRoot = Join-Path $repo 'results\ops_r172'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$fail = 0

L '--- task t130: vpn autostart + Antigravity diag + WPS continue ---'
L ('repo: ' + $repo)

# ---------------------------------------------------------------- task 1
L '--- task 1: Green VPN autostart ---'
$vpnReport = @()
function VR([string]$m) { $script:vpnReport += $m; L ('   ' + $m) }
$script:vpnReport = @()
$greenName = ([string][char]0x7EFF) + ([string][char]0x76DF) + 'VPN' + ([string][char]0x5BA2) + ([string][char]0x6237) + ([string][char]0x7AEF) + '.lnk'
$desktopDirs = @('C:\Users\Public\Desktop')
if ($env:PUBLIC) { $desktopDirs += (Join-Path $env:PUBLIC 'Desktop') }
if ($env:USERPROFILE) { $desktopDirs += (Join-Path $env:USERPROFILE 'Desktop') }
$desktopDirs = @($desktopDirs | Select-Object -Unique)
$cands = @()
foreach ($d in $desktopDirs) {
    $cands += (Join-Path $d $greenName)
    if (Test-Path -LiteralPath $d) {
        $cands += @(Get-ChildItem -LiteralPath $d -Filter '*VPN*.lnk' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
}
$lnk = $null
foreach ($c in @($cands | Select-Object -Unique)) { if (Test-Path -LiteralPath $c) { $lnk = $c; break } }
VR ('shortcut_found=' + [bool]$lnk)
if ($lnk) {
    VR ('shortcut=' + (San $lnk))
    try {
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($lnk)
        VR ('target=' + (San ([string]$sc.TargetPath)))
        VR ('arguments=' + (San ([string]$sc.Arguments)))
        VR ('working_dir=' + (San ([string]$sc.WorkingDirectory)))
    } catch { VR ('shortcut_resolve_WARN=' + (San $_.Exception.Message)) }

    try {
        $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
        New-Item -ItemType Directory -Force -Path $startup | Out-Null
        $startupLink = Join-Path $startup 'GreenVPN-Autostart.lnk'
        Copy-Item -LiteralPath $lnk -Destination $startupLink -Force
        VR ('startup_folder_link=OK ' + (San $startupLink))
    } catch { VR ('startup_folder_link=FAIL ' + (San $_.Exception.Message)); $fail = 1 }

    $taskName = 'git-sync-autostart-green-vpn'
    $taskOk = $false
    $cmd = Join-Path $env:SystemRoot 'System32\cmd.exe'
    $arg = '/c start "" "' + $lnk + '"'
    try {
        $action = New-ScheduledTaskAction -Execute $cmd -Argument $arg
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
        $userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel LeastPrivilege
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Launch Green VPN from public desktop shortcut at user logon' -Force | Out-Null
        $taskOk = $true
        VR ('scheduled_task=OK principal=' + (San $userId))
    } catch {
        VR ('scheduled_task_primary=FAIL ' + (San $_.Exception.Message))
        try {
            $tr = $cmd + ' ' + $arg
            $so = (& schtasks /Create /TN $taskName /SC ONLOGON /TR $tr /F 2>&1 | Out-String).Trim()
            VR ('scheduled_task_fallback=' + (San $so))
            $taskOk = ($LASTEXITCODE -eq 0)
        } catch { VR ('scheduled_task_fallback=FAIL ' + (San $_.Exception.Message)) }
    }
    try {
        $t = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        VR ('scheduled_task_state=' + $t.State)
        VR ('scheduled_task_action=' + (San ([string]$t.Actions[0].Execute + ' ' + [string]$t.Actions[0].Arguments)))
    } catch { VR ('scheduled_task_verify=FAIL ' + (San $_.Exception.Message)); $taskOk = $false }
    try {
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
        VR 'run_now=OK Start-ScheduledTask issued'
    } catch { VR ('run_now=WARN ' + (San $_.Exception.Message)) }
    if ($taskOk) { VR 'FINAL: VPN_AUTOSTART_OK registered at user logon plus Startup-folder fallback.' }
    else { VR 'FINAL: VPN_AUTOSTART_FAIL could not verify scheduled task.'; $fail = 1 }
} else {
    VR 'FINAL: VPN_AUTOSTART_FAIL shortcut not found.'
    $fail = 1
}
Write-Utf8 (Join-Path $outRoot 'VPN_AUTOSTART.md') $vpnReport

# ---------------------------------------------------------------- desktop helpers
L '--- task 2/3: desktop dispatch ---'
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$stageDir = $fshare
$remoteStage = 'F:\fig1_rebuild'

function Stage-DesktopFile([string]$LocalRel, [string]$RemoteRel) {
    $src = Join-Path $repo $LocalRel
    $dst = Join-Path $stageDir $RemoteRel
    if (-not (Test-Path -LiteralPath $src)) { L ('   [FAIL] missing local stage file: ' + $LocalRel); $script:fail = 1; return }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
    L ('   staged ' + $LocalRel + ' -> ' + (San $dst))
}
function Run-DesktopScript([string]$RemotePath, [int]$TimeoutSec) {
    L ('   run remote: ' + $RemotePath)
    $job = Start-Job -ScriptBlock {
        param($o, $u, $h, $rp)
        & ssh @o ($u + '@' + $h) ('powershell -NoProfile -ExecutionPolicy Bypass -File ' + $rp) 2>&1 | Out-String
        exit $LASTEXITCODE
    } -ArgumentList $sshBase, $duser, $desktop, $RemotePath
    if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        L ('   [FAIL] remote timeout: ' + $RemotePath)
        return 124
    }
    $out = (Receive-Job $job | Out-String)
    $state = $job.State
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    foreach ($ln in ($out -split "`r?`n")) { if ($ln.Trim()) { L ('   desk| ' + (San $ln)) } }
    if ($out -match 'FINAL: WPS_CONTINUE_FAIL|FAIL - no deck|\[FAIL\] WPS') { return 2 }
    if ($out -match 'FINAL: WPS_CONTINUE_OK') { return 0 }
    if ($state -eq 'Completed') { return 0 }
    return 1
}
function Copy-Back([string]$RemoteRel, [string]$LocalRel) {
    $src = Join-Path $stageDir $RemoteRel
    $dst = Join-Path $repo $LocalRel
    if (Test-Path -LiteralPath $src) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
        L ('   collected ' + (San $RemoteRel) + ' -> ' + $LocalRel)
    } else { L ('   collect missing: ' + (San $RemoteRel)) }
}

$netOk = $false
try {
    $netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -eq 0 -or $netOut -match 'successfully|command completed') { $netOk = $true }
    L ('   net_use=' + (San $netOut))
} catch { L ('   net_use=FAIL ' + (San $_.Exception.Message)) }
if (-not $netOk) {
    L '   [FAIL] desktop F$ share unreachable; VPN/Tailscale path may be down.'
    $fail = 1
} else {
    try {
        Stage-DesktopFile 'code\tasks\desk_antigravity_agent_error.ps1' 'fig1_rebuild\desk_antigravity_agent_error.ps1'
        Stage-DesktopFile 'code\tasks\desk_wps_continue.ps1' 'fig1_rebuild\desk_wps_continue.ps1'
        Stage-DesktopFile 'code\tasks\amp_deck_v2_build.py' 'fig1_rebuild\harness_results\amp_deck_v2_build.py'
        Stage-DesktopFile 'code\tasks\verify_pptx.py' 'fig1_rebuild\verify_pptx.py'
    } finally {
        & net use $fshare /delete 2>&1 | Out-Null
    }

    $rc1 = Run-DesktopScript ($remoteStage + '\desk_antigravity_agent_error.ps1') 420
    if ($rc1 -ne 0) { L ('   [WARN] Antigravity diag remote exit ' + $rc1) }

    $rc2 = Run-DesktopScript ($remoteStage + '\desk_wps_continue.ps1') 900
    if ($rc2 -ne 0) { L ('   [FAIL] WPS continue remote exit ' + $rc2); $fail = 1 }

    try {
        $null = & net use $fshare /persistent:no 2>&1
        Copy-Back 'fig1_rebuild\agy_agent_diag_r172.md' 'results\antigravity\agy_agent_diag_r172.md'
        Copy-Back 'fig1_rebuild\harness_results\wps_continue_r172.md' 'results\wps_continue\wps_continue_r172.md'
        Copy-Back 'fig1_rebuild\harness_results\amp_ml_prediction_v2_r172.pptx' 'results\wps_continue\amp_ml_prediction_v2_r172.pptx'
        Copy-Back 'fig1_rebuild\harness_results\amp_deck_v2_log.txt' 'results\wps_continue\amp_deck_v2_log.txt'
    } finally {
        & net use $fshare /delete 2>&1 | Out-Null
    }
}

if ($fail -eq 0) { L '--- task t130 done: PASS ---'; exit 0 }
else { L ('--- task t130 done: FAIL code=' + $fail + ' ---'); exit 2 }
