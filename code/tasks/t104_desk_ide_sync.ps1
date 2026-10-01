# t104_desk_ide_sync.ps1 - round 140 task: (task 1) sync the laptop's
# Antigravity IDE to the desktop: diagnose laptop WPS COM (E_FAIL seen in
# r139, needed for task 2), pick the 2.15.1 payload (updater installer if
# its version matches, else robocopy the whole install tree), stage it on
# F$, then run the desktop-side install/relaunch/verify over ssh.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t104: IDE sync to desktop + laptop WPS COM diagnosis ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$deskSrc = Join-Path $repoRoot 'code\tasks\desk_sync_ide.ps1'

foreach ($f in @($deskSrc)) {
    $tok = $null; $perrs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tok, [ref]$perrs)
    if ($perrs -and $perrs.Count -gt 0) {
        L ('   [FAIL] parse errors in ' + (San $f) + ': ' + $perrs.Count)
        foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
        exit 2
    }
}
L '   parse checks: OK'

# ================= A. laptop WPS COM diagnosis =================
L '--- A: laptop WPS COM diagnosis ---'
function Resolve-ProgId([string]$progid) {
    foreach ($root in @('HKLM:\SOFTWARE\Classes', 'HKCU:\SOFTWARE\Classes')) {
        $ck = Join-Path $root ($progid + '\CLSID')
        if (Test-Path -LiteralPath $ck) {
            $clsid = (Get-ItemProperty -LiteralPath $ck -ErrorAction SilentlyContinue).'(default)'
            if ($clsid) {
                $lk = Join-Path $root ('CLSID\' + $clsid + '\LocalServer32')
                if (Test-Path -LiteralPath $lk) {
                    $srv = (Get-ItemProperty -LiteralPath $lk -ErrorAction SilentlyContinue).'(default)'
                    return @{ clsid = $clsid; server = $srv }
                }
                return @{ clsid = $clsid; server = '(no LocalServer32)' }
            }
        }
    }
    return $null
}
foreach ($pg in @('KWPP.Application', 'KET.Application', 'KWPS.Application')) {
    $r = Resolve-ProgId $pg
    if ($r) { L ('   ' + $pg + ' -> ' + (San $r.clsid) + ' server: ' + (San $r.server)) }
    else { L ('   ' + $pg + ' -> NOT RESOLVED') }
}
function TryCom([string]$pg) {
    try {
        $k = New-Object -ComObject $pg
        $k.Visible = $false
        $v = [string]$k.Version
        $k.Quit()
        return 'OK v' + $v
    } catch {
        $hr = ''
        try { $hr = ('0x{0:X8}' -f $_.Exception.HResult) } catch { }
        return 'FAIL ' + $hr + ' ' + (San $_.Exception.Message)
    }
}
L ('   headless COM KWPP: ' + (TryCom 'KWPP.Application'))
L ('   headless COM KET: ' + (TryCom 'KET.Application'))
L ('   headless COM KWPS: ' + (TryCom 'KWPS.Application'))
$r = Resolve-ProgId 'KWPP.Application'
if ($r -and $r.server -and $r.server -notmatch '^\(') {
    $exe = $r.server.Trim('"')
    if (Test-Path -LiteralPath $exe) {
        L ('   warm-starting ' + (San $exe) + ' then retrying KWPP...')
        try { Start-Process -FilePath $exe -ErrorAction Stop | Out-Null } catch { L ('   warm start failed: ' + (San $_.Exception.Message)) }
        Start-Sleep -Seconds 12
        L ('   warm KWPP retry: ' + (TryCom 'KWPP.Application'))
        foreach ($w in @(Get-Process -Name wpp -ErrorAction SilentlyContinue)) { try { & taskkill /f /im wpp.exe 2>&1 | Out-Null } catch { } }
    } else { L '   LocalServer32 path does not exist' }
}

# ================= B. pick + stage the 2.15.1 payload =================
L '--- B: staging IDE payload ---'
$upd = Join-Path $env:LOCALAPPDATA 'antigravity-updater\installer.exe'
$stg = Join-Path $env:LOCALAPPDATA 'antigravity\staging\agy.exe'
foreach ($f in @($upd, $stg)) {
    if (Test-Path -LiteralPath $f) { L ('   ' + (San (Split-Path $f -Leaf)) + ' [' + (San (Split-Path (Split-Path $f) -Leaf)) + ']: v' + (San ([string](Get-Item -LiteralPath $f).VersionInfo.ProductVersion)) + ' ' + [math]::Round((Get-Item -LiteralPath $f).Length/1MB) + 'MB') }
    else { L ('   missing: ' + (San $f)) }
}
$mode = ''
$instV = ''
if (Test-Path -LiteralPath $upd) { $instV = [string](Get-Item -LiteralPath $upd).VersionInfo.ProductVersion }
if ($instV -match '^2\.15') { $mode = 'installer' }
else { $mode = 'robocopy' }
L ('   payload mode: ' + $mode + $(if ($mode -eq 'robocopy') { ' (installer is v' + (San $instV) + ', need exact 2.15.1 tree)' } else { '' }))

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    $t0 = Get-Date
    if ($mode -eq 'installer') {
        $cj = Start-Job -ScriptBlock { param($s, $d) Copy-Item -LiteralPath $s -Destination $d -Force } -ArgumentList $upd, ($fshare + '\fig1_rebuild\agy_installer_2151.exe')
        if (-not (Wait-Job $cj -Timeout 600)) { Stop-Job $cj -Force; L '   [FAIL] installer copy timed out'; exit 2 }
        $e = @(Receive-Job $cj); Remove-Job $cj -Force
        L ('   installer staged: ' + [math]::Round((Get-Item ($fshare + '\fig1_rebuild\agy_installer_2151.exe') -ErrorAction SilentlyContinue).Length/1MB) + 'MB in ' + [int]((Get-Date) - $t0).TotalSeconds + 's')
    }
    else {
        $src = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity'
        $rj = Start-Job -ScriptBlock {
            param($s, $d)
            & robocopy $s $d /E /MT:16 /NFL /NDL /NJH /NP 2>&1 | Select-Object -Last 8 | Out-String
        } -ArgumentList $src, ($fshare + '\fig1_rebuild\agy_install_src')
        if (-not (Wait-Job $rj -Timeout 720)) { Stop-Job $rj -Force; L '   [WARN] robocopy staging timed out (will resume next round)' }
        else { foreach ($ln in @((Receive-Job $rj | Out-String) -split "`r?`n")) { if ($ln.Trim()) { L ('      ' + (San $ln.Trim())) } }; Remove-Job $rj -Force }
    }
    $lsf = Join-Path $env:APPDATA 'Antigravity\User\settings.json'
    if (Test-Path -LiteralPath $lsf) {
        Copy-Item -LiteralPath $lsf -Destination ($fshare + '\fig1_rebuild\agy_settings_laptop.json') -Force
        L '   laptop settings.json staged'
    }
    try {
        [IO.File]::WriteAllText(($fshare + '\fig1_rebuild\deskidesync.ps1'), ([IO.File]::ReadAllText($deskSrc)), (New-Object System.Text.UTF8Encoding($false)))
        L '   desk_sync_ide.ps1 staged'
    } catch { L ('   [FAIL] stage desk script: ' + (San $_.Exception.Message)); exit 2 }
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

# ================= C. run the desktop-side sync =================
$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\deskidesync.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 1080)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L '   [FAIL] remote sync timed out (installer may still be running - recheck next round)'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach ($ln in ($out -split "`r?`n")) {
    $x = San $ln
    if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $x) }
}
L '--- task t104 done ---'
exit 0
