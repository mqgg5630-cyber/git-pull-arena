# t105_laptop_wps_harness.ps1 - round 141 task: (task 2, laptop half)
# 1. deep-dive the KWPP.Application E_FAIL (KET/KWPS COM work, only the
#    Impress/PPT component fails): dump CLSID registration, find wpp.exe,
#    try /regserver + warm start + alternate ProgIDs
# 2. offline-install the vendored harness-anything (cli-anything-wps)
# 3. smoke test the WRITER flow (real WPS COM) -> editable docx
# 4. if KWPP recovers: full IMPRESS flow -> editable pptx + reopen verify
# ASCII-only. Runs entirely on the LAPTOP.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t105: laptop KWPP fix + harness install + smoke tests ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$haDir = Join-Path $repoRoot 'skills\harness-anything'
$workDir = Join-Path $repoRoot 'results\harness_wps\laptop'
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

function TryCom([string]$pg) {
    try {
        $k = New-Object -ComObject $pg
        try { $k.Visible = $false } catch { }
        $v = ''
        try { $v = [string]$k.Version } catch { }
        try { $k.Quit() } catch { }
        return 'OK v' + $v
    } catch {
        $hr = ''
        try { $hr = ('0x{0:X8}' -f $_.Exception.HResult) } catch { }
        return 'FAIL ' + $hr
    }
}

# ================= A. KWPP deep-dive =================
L '--- A: KWPP.Application diagnosis ---'
$kwppClsid = '{44720441-94BF-4940-926D-4F38FECF2A48}'
$ketClsid = '{45540001-5750-5300-4B49-4E47534F4655}'
function Dump-Clsid([string]$clsid, [string]$tag) {
    $roots = @(
        ('HKLM:\SOFTWARE\Classes\CLSID\' + $clsid),
        ('HKLM:\SOFTWARE\Classes\WOW6432Node\CLSID\' + $clsid),
        ('HKCU:\SOFTWARE\Classes\CLSID\' + $clsid)
    )
    $any = $false
    foreach ($r in $roots) {
        if (Test-Path -LiteralPath $r) {
            $any = $true
            L ('   ' + $tag + ' @ ' + ($r -replace '.*SOFTWARE\\Classes', 'HKCR'))
            foreach ($k in @(Get-ChildItem -LiteralPath $r -Recurse -ErrorAction SilentlyContinue)) {
                $vals = ''
                foreach ($p in $k.Property) { $vals += ($p + '=' + (San ([string]$k.GetValue($p))) + ' ') }
                if ($vals.Length -gt 220) { $vals = $vals.Substring(0, 220) + '...' }
                L ('      ' + (San ($k.Name -replace '.*CLSID', 'CLSID')) + ' :: ' + $vals.Trim())
            }
            $rootProps = ''
            $rk = Get-Item -LiteralPath $r -ErrorAction SilentlyContinue
            if ($rk) { foreach ($p in $rk.Property) { $rootProps += ($p + '=' + (San ([string]$rk.GetValue($p))) + ' ') } }
            if ($rootProps) { L ('      (root) ' + $rootProps.Trim()) }
        }
    }
    if (-not $any) { L ('   ' + $tag + ' : no CLSID key found anywhere') }
}
Dump-Clsid $kwppClsid 'KWPP'
Dump-Clsid $ketClsid 'KET (working reference)'

$wpsRoots = @((Join-Path $env:LOCALAPPDATA 'Kingsoft\WPS Office'), 'C:\Program Files (x86)\Kingsoft\WPS Office', 'C:\Program Files\Kingsoft\WPS Office')
$office6 = $null
foreach ($wr in $wpsRoots) {
    if (-not (Test-Path -LiteralPath $wr)) { continue }
    foreach ($vd in @(Get-ChildItem -LiteralPath $wr -Directory -ErrorAction SilentlyContinue)) {
        $o6 = Join-Path $vd.FullName 'office6'
        if (Test-Path -LiteralPath $o6) {
            $office6 = $o6
            L ('   WPS install: ' + (San $vd.FullName))
            foreach ($e in @('wps.exe', 'et.exe', 'wpp.exe', 'wpspdf.exe', 'ksomisc.exe', 'wpsoffice.exe')) {
                $f = Join-Path $o6 $e
                if (Test-Path -LiteralPath $f) { L ('      ' + $e + ' OK v' + (San ([string](Get-Item -LiteralPath $f).VersionInfo.ProductVersion))) }
                else { L ('      ' + $e + ' MISSING') }
            }
            break
        }
    }
    if ($office6) { break }
}
if (-not $office6) { L '   [WARN] no office6 dir found' }

$kwppOk = $false
$wpp = $null
if ($office6) { $wpp = Join-Path $office6 'wpp.exe' }
if ($wpp -and (Test-Path -LiteralPath $wpp)) {
    L ('   warm start wpp.exe then retry...')
    try { Start-Process -FilePath $wpp -ErrorAction Stop | Out-Null } catch { L ('   warm start failed: ' + (San $_.Exception.Message)) }
    Start-Sleep -Seconds 12
    $alive = @(Get-Process -Name wpp -ErrorAction SilentlyContinue).Count
    L ('   wpp.exe processes after start: ' + $alive)
    $r1 = TryCom 'KWPP.Application'
    L ('   KWPP after warm start: ' + $r1)
    if ($r1 -match '^OK') { $kwppOk = $true }
    if (-not $kwppOk) {
        foreach ($w in @(Get-Process -Name wpp -ErrorAction SilentlyContinue)) { try { & taskkill /f /im wpp.exe 2>&1 | Out-Null } catch { } }
        Start-Sleep -Seconds 3
        L '   trying wpp.exe /regserver...'
        try { $p = Start-Process -FilePath $wpp -ArgumentList '/regserver' -PassThru -Wait -ErrorAction Stop; L ('   /regserver exit: ' + $p.ExitCode) } catch { L ('   /regserver failed: ' + (San $_.Exception.Message)) }
        Start-Sleep -Seconds 3
        $r2 = TryCom 'KWPP.Application'
        L ('   KWPP after /regserver: ' + $r2)
        if ($r2 -match '^OK') { $kwppOk = $true }
    }
}
elseif ($wpp -and -not (Test-Path -LiteralPath $wpp)) {
    L '   wpp.exe MISSING -> Impress component not installed (modular WPS 2019)'
}
if (-not $kwppOk) {
    foreach ($pg in @('wpp.Application', 'Kwpp.Application', 'WPP.Application', 'KPresent.Application')) {
        $rr = TryCom $pg
        if ($rr -match '^OK') { L ('   ALTERNATE ProgID works: ' + $pg + ' -> ' + $rr); $kwppOk = $true; break }
        else { L ('   alternate ' + $pg + ': ' + $rr) }
    }
}
try {
    $g = [Guid]'44720441-94BF-4940-926D-4F38FECF2A48'
    $t = [type]::GetTypeFromCLSID($g)
    $o = [Activator]::CreateInstance($t)
    L '   CLSID direct CreateInstance: OK'
    try { $o.Quit() } catch { }
    $kwppOk = $true
} catch { L ('   CLSID direct CreateInstance: ' + (San $_.Exception.Message)) }
L ('   A RESULT: KWPP usable = ' + $kwppOk)

# ================= B. harness offline install =================
L '--- B: harness-anything offline install ---'
$vendor = Join-Path $haDir 'vendor_wheels'
& python -m pip install --no-index --find-links $vendor setuptools wheel 2>&1 | Select-Object -Last 2 | ForEach-Object { L ('   ' + (San ([string]$_))) }
$inst = & python -m pip install --no-index --no-build-isolation --find-links $vendor $haDir 2>&1
foreach ($ln in @($inst | Select-Object -Last 6)) { L ('   ' + (San ([string]$ln))) }
$help = & python -m cli_anything.wps --help 2>&1 | Select-Object -First 6
foreach ($ln in $help) { L ('   cli: ' + (San ([string]$ln))) }
$pyw = & python -c "import win32com.client; print('pywin32 import OK')" 2>&1
L ('   ' + (San ([string]$pyw)))

# ================= C. writer flow (KWPS works) =================
L '--- C: writer smoke test (editable docx) ---'
$cj = Start-Job -ScriptBlock {
    param($wd, $repo)
    Set-Location -LiteralPath $wd
    $o = @()
    $o += ('new: ' + ((& python -m cli_anything.wps document new --type writer --name 'harness smoke' -o proj_writer.json 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('heading: ' + ((& python -m cli_anything.wps --project proj_writer.json writer add-heading -t 'Harness Smoke Test' -l 1 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('para: ' + ((& python -m cli_anything.wps --project proj_writer.json writer add-paragraph -t 'Editable paragraph generated by cli-anything-wps via WPS COM.' 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('export: ' + ((& python -m cli_anything.wps --project proj_writer.json export render test_writer.docx -p docx 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o
} -ArgumentList $workDir, $repoRoot
if (-not (Wait-Job $cj -Timeout 300)) { Stop-Job $cj -Force; L '   [FAIL] writer flow timed out' }
else { foreach ($ln in @(Receive-Job $cj)) { L ('   ' + (San ([string]$ln))) } }
Remove-Job $cj -Force -ErrorAction SilentlyContinue
$docx = Join-Path $workDir 'test_writer.docx'
if (Test-Path -LiteralPath $docx) {
    L ('   docx: ' + [math]::Round((Get-Item -LiteralPath $docx).Length/1KB) + 'KB')
    try {
        $w = New-Object -ComObject KWPS.Application
        $d = $w.Documents.Open($docx)
        $n = $d.Paragraphs.Count
        $txt = ''
        try { $txt = [string]$d.Paragraphs.Item(1).Range.Text } catch { }
        $d.Close($false)
        $w.Quit()
        L ('   REOPEN OK: paragraphs=' + $n + ' first=' + (San $txt.Trim()))
    } catch { L ('   reopen failed: ' + (San $_.Exception.Message)) }
}
else { L '   [FAIL] test_writer.docx not produced' }

# ================= D. impress flow (only if KWPP usable) =================
L '--- D: impress test (editable pptx) ---'
if ($kwppOk) {
    $dj = Start-Job -ScriptBlock {
        param($wd)
        Set-Location -LiteralPath $wd
        $o = @()
        $o += ('new: ' + ((& python -m cli_anything.wps document new --type impress --name 'harness pptx' -o proj_impress.json 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
        $o += ('slide: ' + ((& python -m cli_anything.wps --project proj_impress.json impress add-slide -t 'Harness PPTX Test' -c 'Editable body via WPS COM' 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
        $o += ('elem: ' + ((& python -m cli_anything.wps --project proj_impress.json impress add-element 0 --type text_box --text 'Hello editable pptx' 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
        $o += ('export: ' + ((& python -m cli_anything.wps --project proj_impress.json export render test_impress.pptx -p pptx 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
        $o
    } -ArgumentList $workDir
    if (-not (Wait-Job $dj -Timeout 360)) { Stop-Job $dj -Force; L '   [FAIL] impress flow timed out' }
    else { foreach ($ln in @(Receive-Job $dj)) { L ('   ' + (San ([string]$ln))) } }
    Remove-Job $dj -Force -ErrorAction SilentlyContinue
    $pptx = Join-Path $workDir 'test_impress.pptx'
    if (Test-Path -LiteralPath $pptx) {
        L ('   pptx: ' + [math]::Round((Get-Item -LiteralPath $pptx).Length/1KB) + 'KB')
        try {
            $k = New-Object -ComObject KWPP.Application
            $pres = $k.Presentations.Open($pptx, $true, $false, $false)
            $sc = $pres.Slides.Count
            $shc = 0
            try { $shc = $pres.Slides.Item(1).Shapes.Count } catch { }
            $k.Quit()
            L ('   REOPEN OK: slides=' + $sc + ' slide1 shapes=' + $shc)
        } catch { L ('   reopen failed: ' + (San $_.Exception.Message)) }
    }
    else { L '   [FAIL] test_impress.pptx not produced' }
}
else { L '   SKIPPED - KWPP still broken (fix needed first)' }

# ================= E. WPS installer cache search =================
L '--- E: WPS installer cache search ---'
$hits = 0
foreach ($root in @((Join-Path $env:LOCALAPPDATA 'Kingsoft'), (Join-Path $env:APPDATA 'kingsoft'), (Join-Path $env:USERPROFILE 'Downloads'))) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $root -Recurse -Depth 3 -Include 'WPS*.exe', 'wps*setup*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 6)) {
        L ('      ' + (San $f.FullName) + ' (' + [math]::Round($f.Length/1MB) + 'MB ' + $f.LastWriteTime.ToString('yyyy-MM-dd') + ')')
        $hits++
    }
}
if ($hits -eq 0) { L '      (no cached WPS installer - desktop will download from wpscdn)' }
L '--- task t105 done ---'
exit 0
