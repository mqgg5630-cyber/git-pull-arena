# t131_vpn_autostart_fix.ps1 - round 174: fix Green VPN autostart only.
# ASCII-only. Uses the public desktop shortcut to register both Startup-folder
# and a per-user at-logon scheduled task that launches the resolved target exe.

$ErrorActionPreference = 'Continue'

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

$script:Lines = @()
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outRoot = Join-Path $repo 'results\ops_r174'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$reportPath = Join-Path $outRoot 'VPN_AUTOSTART.md'

L '--- task t131: Green VPN autostart fix ---'
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
L ('shortcut_found=' + [bool]$lnk)
if (-not $lnk) {
    L 'FINAL: VPN_AUTOSTART_FAIL shortcut not found.'
    Write-Utf8 $reportPath $script:Lines
    exit 2
}
L ('shortcut=' + (San $lnk))

$targetPath = ''
$targetArgs = ''
$targetWork = ''
try {
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnk)
    $targetPath = [string]$sc.TargetPath
    $targetArgs = [string]$sc.Arguments
    $targetWork = [string]$sc.WorkingDirectory
    L ('target=' + (San $targetPath))
    L ('arguments=' + (San $targetArgs))
    L ('working_dir=' + (San $targetWork))
} catch { L ('shortcut_resolve_WARN=' + (San $_.Exception.Message)) }

$startupOk = $false
try {
    $startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    New-Item -ItemType Directory -Force -Path $startup | Out-Null
    $startupLink = Join-Path $startup 'GreenVPN-Autostart.lnk'
    Copy-Item -LiteralPath $lnk -Destination $startupLink -Force
    $startupOk = Test-Path -LiteralPath $startupLink
    L ('startup_folder_link=' + $startupOk + ' ' + (San $startupLink))
} catch { L ('startup_folder_link=FAIL ' + (San $_.Exception.Message)) }

$taskName = 'git-sync-autostart-green-vpn'
$taskOk = $false
$taskExe = $targetPath
$taskArg = $targetArgs
$taskWork = $targetWork
if (-not ($taskExe -and (Test-Path -LiteralPath $taskExe))) {
    $taskExe = Join-Path $env:SystemRoot 'System32\cmd.exe'
    $taskArg = '/c start "" "' + $lnk + '"'
    $taskWork = ''
}
L ('task_exe=' + (San $taskExe))
L ('task_arg=' + (San $taskArg))
try {
    $action = $null
    if ($taskWork -and $taskArg) { $action = New-ScheduledTaskAction -Execute $taskExe -Argument $taskArg -WorkingDirectory $taskWork }
    elseif ($taskWork) { $action = New-ScheduledTaskAction -Execute $taskExe -WorkingDirectory $taskWork }
    elseif ($taskArg) { $action = New-ScheduledTaskAction -Execute $taskExe -Argument $taskArg }
    else { $action = New-ScheduledTaskAction -Execute $taskExe }
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
    $userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Launch Green VPN at user logon' -Force | Out-Null
    L ('scheduled_task_register=OK principal=' + (San $userId))
} catch {
    L ('scheduled_task_register=FAIL ' + (San $_.Exception.Message))
    try {
        $tr = '"' + $taskExe + '"'
        if ($taskArg) { $tr += ' ' + $taskArg }
        $so = (& schtasks /Create /TN $taskName /SC ONLOGON /TR $tr /F 2>&1 | Out-String).Trim()
        L ('scheduled_task_fallback=' + (San $so))
    } catch { L ('scheduled_task_fallback=FAIL ' + (San $_.Exception.Message)) }
}
try {
    $t = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $taskOk = $true
    L ('scheduled_task_state=' + $t.State)
    L ('scheduled_task_action=' + (San ([string]$t.Actions[0].Execute + ' ' + [string]$t.Actions[0].Arguments)))
} catch { L ('scheduled_task_verify=FAIL ' + (San $_.Exception.Message)) }

# Do not fail if run-now cannot open UI from the watcher session; at-logon is
# the contract. Try once only as a smoke trigger.
try { Start-ScheduledTask -TaskName $taskName -ErrorAction Stop; L 'run_now=OK Start-ScheduledTask issued' }
catch { L ('run_now=WARN ' + (San $_.Exception.Message)) }

if ($taskOk -or $startupOk) {
    L ('FINAL: VPN_AUTOSTART_OK scheduled_task=' + $taskOk + ' startup_folder=' + $startupOk)
    Write-Utf8 $reportPath $script:Lines
    exit 0
}
L 'FINAL: VPN_AUTOSTART_FAIL no autostart mechanism verified.'
Write-Utf8 $reportPath $script:Lines
exit 2
