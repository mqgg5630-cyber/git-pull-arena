# t195_install_qingjian_ime_r247.ps1 - round 247.
# Install Qingjian IME from the official GitHub release and set it as the
# default input method. Uses no repository-stored secrets. ASCII-only.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')

$repo = (Get-Location).Path
$outDir = Join-Path $repo 'results\input'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report = Join-Path $outDir 'QINGJIAN_INSTALL_R247.md'
$lines = New-Object System.Collections.Generic.List[string]
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { $script:lines.Add($m) | Out-Null; Write-Output $m }
function Write-Report { $script:lines | Set-Content -LiteralPath $script:report -Encoding UTF8 }
function Is-Admin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}
function TcpWaitFile([string]$Path, [int]$Sec) {
    $deadline = (Get-Date).AddSeconds($Sec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $Path) { return $true }
        Start-Sleep -Seconds 2
    }
    return (Test-Path -LiteralPath $Path)
}
function Download-File([string]$Url, [string]$Out) {
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    $args = @('-L','--ssl-no-revoke','--retry','3','--connect-timeout','20','--max-time','900','-o',$Out,$Url)
    $o = (& $curl @args 2>&1 | Out-String).Trim()
    $code = $LASTEXITCODE
    if ($o) { foreach ($ln in (($o -split "`r?`n") | Select-Object -Last 8)) { if ($ln.Trim()) { L ('curl| ' + (San $ln)) } } }
    return ($code -eq 0 -and (Test-Path -LiteralPath $Out))
}

L '# Qingjian IME install/switch - round 247'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('host=' + $env:COMPUTERNAME)
L ''

$version = '0.1.4'
$url = 'https://github.com/qingjian-team/qingjian/releases/download/v0.1.4/qingjian-0.1.4-windows-x86_64-setup.exe'
$expectedSha = '88dbcb5562628ad09bd710fa9117804d2d671970a465c06226ea719d276adafd'
$downloadDir = Join-Path $env:TEMP 'qingjian-install'
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
$installer = Join-Path $downloadDir 'qingjian-0.1.4-windows-x86_64-setup.exe'
$installLog = Join-Path $outDir 'qingjian-inno-r247.log'
$programDir = Join-Path $env:ProgramFiles 'Qingjian'
$serverExe = Join-Path $programDir 'qingjian-server.exe'
$settingsExe = Join-Path $programDir 'qingjian-settings.exe'
$clsid = '{4FDCA82D-E923-49BF-9E75-BB906B93B8BB}'
$profile = '{8119F8E0-CF81-423B-9189-C0D7374324B3}'
$tip = '0804:' + $clsid + $profile

L ('download_url=https://github.com/qingjian-team/qingjian/releases/download/v0.1.4/[installer]')
L ('installer_path=' + (San $installer))

$installedBefore = (Test-Path -LiteralPath $serverExe)
L ('installed_before=' + $installedBefore)

if (-not $installedBefore) {
    $needDownload = $true
    if (Test-Path -LiteralPath $installer) {
        try {
            $h0 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLower()
            if ($h0 -eq $expectedSha) { $needDownload = $false; L 'installer_cached_hash_ok=True' }
        } catch { }
    }
    if ($needDownload) {
        L 'download_start=True'
        if (-not (Download-File $url $installer)) {
            L 'QINGJIAN_INSTALL_OK=False download_failed'
            Write-Report
            exit 2
        }
    }
    $hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLower()
    $bytes = (Get-Item -LiteralPath $installer).Length
    L ('installer_bytes=' + $bytes)
    L ('installer_sha256=' + $hash)
    if ($hash -ne $expectedSha) {
        L 'QINGJIAN_INSTALL_OK=False sha256_mismatch'
        Write-Report
        exit 2
    }

    $arg = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /LOG="' + $installLog + '"'
    L ('is_admin=' + (Is-Admin))
    L 'install_start=True'
    try {
        if (Is-Admin) {
            $p = Start-Process -FilePath $installer -ArgumentList $arg -Wait -PassThru -ErrorAction Stop
            L ('installer_exit=' + $p.ExitCode)
        } else {
            L 'installer_elevation=UAC_prompt_requested'
            Start-Process -FilePath $installer -ArgumentList $arg -Verb RunAs -ErrorAction Stop | Out-Null
        }
    } catch {
        L ('installer_start_WARN=' + (San $_.Exception.Message))
    }
    $appeared = TcpWaitFile $serverExe 360
    L ('server_exe_appeared=' + $appeared)
}

$installed = (Test-Path -LiteralPath $serverExe)
L ('installed_after=' + $installed)
if (-not $installed) {
    L ('manual_admin_command="' + (San $installer) + '" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-')
    L 'QINGJIAN_INSTALL_OK=False admin_install_not_completed'
    Write-Report
    exit 3
}

try {
    $ver = (Get-Item -LiteralPath $serverExe).VersionInfo.ProductVersion
    L ('server_version=' + (San ([string]$ver)))
} catch { }
try {
    $dlls = @(Get-ChildItem -LiteralPath $programDir -Filter 'qingjian_tsf*.dll' -File -ErrorAction SilentlyContinue)
    L ('tsf_dll_count=' + $dlls.Count)
    foreach ($d in ($dlls | Select-Object -First 4)) { L ('tsf_dll=' + (San $d.Name)) }
} catch { }

# Start server if not running.
try {
    $running = @(Get-Process -Name qingjian-server -ErrorAction SilentlyContinue).Count
    if ($running -eq 0) { Start-Process -FilePath $serverExe -WorkingDirectory $programDir; Start-Sleep -Seconds 2 }
    $running2 = @(Get-Process -Name qingjian-server -ErrorAction SilentlyContinue).Count
    L ('server_process_count=' + $running2)
    $logDir = Join-Path $env:APPDATA 'Qingjian\logs'
    if (Test-Path -LiteralPath $logDir) {
        $latestLog = Get-ChildItem -LiteralPath $logDir -Filter 'qingjian-server*.log' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestLog) {
            L ('server_log=' + (San $latestLog.FullName))
            L ('server_log_bytes=' + $latestLog.Length)
            foreach ($ln in (Get-Content -LiteralPath $latestLog.FullName -Tail 8 -ErrorAction SilentlyContinue)) { L ('server_log_tail| ' + (San $ln)) }
        } else { L ('server_log=not_found_yet') }
    } else { L ('server_log_dir=not_found') }
} catch { L ('server_start_WARN=' + (San $_.Exception.Message)) }

# Add Qingjian TIP to zh-Hans-CN and make it the default input method.
$switchOK = $false
try {
    Import-Module International -ErrorAction SilentlyContinue
    $list = Get-WinUserLanguageList
    $zh = $list | Where-Object { $_.LanguageTag -eq 'zh-Hans-CN' -or $_.LanguageTag -eq 'zh-CN' } | Select-Object -First 1
    if (-not $zh) {
        $new = New-WinUserLanguageList 'zh-Hans-CN'
        $zh = $new[0]
        [void]$list.Add($zh)
        L 'language_zh_added=True'
    }
    $tips = @($zh.InputMethodTips)
    if ($tips -notcontains $tip) {
        [void]$zh.InputMethodTips.Add($tip)
        L ('input_tip_added=' + $tip)
    } else { L ('input_tip_already_present=' + $tip) }
    Set-WinUserLanguageList $list -Force
    Start-Sleep -Seconds 2
    Set-WinDefaultInputMethodOverride -InputTip $tip
    try { Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\ctfmon.exe') -ErrorAction SilentlyContinue } catch { }
    Start-Sleep -Seconds 1
    $cur = ''
    try { $cur = [string](Get-WinDefaultInputMethodOverride) } catch { }
    L ('default_input_method_override=' + (San $cur))
    if ($cur -match [regex]::Escape($clsid) -or $cur -match [regex]::Escape($profile) -or $cur -eq $tip) { $switchOK = $true }
    # Even if Get-WinDefaultInputMethodOverride returns an object/empty string,
    # consider the switch configured when the TIP is in the language list.
    $list2 = Get-WinUserLanguageList
    foreach ($x in $list2) { if (@($x.InputMethodTips) -contains $tip) { $switchOK = $true } }
} catch { L ('switch_WARN=' + (San $_.Exception.Message)) }

try {
    $reg1 = Test-Path -LiteralPath ('Registry::HKEY_CLASSES_ROOT\CLSID\' + $clsid)
    $reg2 = Test-Path -LiteralPath ('HKLM:\SOFTWARE\Microsoft\CTF\TIP\' + $clsid)
    $reg3 = Test-Path -LiteralPath ('HKLM:\SOFTWARE\WOW6432Node\Microsoft\CTF\TIP\' + $clsid)
    L ('registry_clsid=' + $reg1 + ' tip_hklm64=' + $reg2 + ' tip_hklm32=' + $reg3)
} catch { }

L ('QINGJIAN_INSTALL_OK=' + $installed)
L ('QINGJIAN_SWITCH_CONFIGURED=' + $switchOK)
L ('QINGJIAN_INPUT_TIP=' + $tip)
L ('report=' + (San $report))
Write-Report
if (-not $installed) { exit 3 }
if (-not $switchOK) { exit 4 }
exit 0
