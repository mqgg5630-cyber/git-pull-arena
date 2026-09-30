# t59_install_bridge.ps1 - round 72 task: (1) registry dig for Illustrator
# COM (ProgIDs + CLSID LocalServer32), (2) launch Illustrator 2020 and test
# COM ProgIDs + ROT enumeration, (3) install Python 3.12 + py launcher via
# winget, (4) patch run_cell_lct*.ps1 (ProgID fallback + version>=24 gate)
# in E:\cell_su7, (5) run cell_su7 setup.ps1 (no API key yet).
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t59: install cell_su7 + Illustrator 2020 bridge recon ---'

# ---------------------------------------- 1. registry dig
Write-Output '--- 1. registry: Illustrator ProgIDs / CLSIDs ---'
foreach ($hive in @('HKLM:\SOFTWARE\Classes', 'HKCU:\Software\Classes')) {
    try {
        foreach ($k in @(Get-ChildItem -Path $hive -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^Illustrator' })) {
            Write-Output ('   PROGID ' + $hive.Replace(':\SOFTWARE\Classes','').Replace(':\Software\Classes','(hkcu)') + ' ' + (San ([string]$k.PSChildName)))
            $clsid = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue).'(default)'
            if ($clsid) { Write-Output ('      CLSID: ' + (San ([string]$clsid))) }
        }
    } catch { }
}
try {
    $hits = reg query 'HKLM\SOFTWARE\Classes\CLSID' /s /f 'Illustrator.exe' /d 2>$null | Select-String 'HKEY_CLASSES_ROOT\\CLSID|Illustrator.exe' | Select-Object -First 12
    foreach ($h in @($hits)) { Write-Output ('   CLSID-HIT ' + (San ([string]$h).Trim())) }
} catch { Write-Output ('   [WARN] clsid search: ' + (San $_.Exception.Message)) }

# ---------------------------------------- 2. launch + COM/ROT test
Write-Output '--- 2. launch Illustrator + COM/ROT probe ---'
$aiExe = $null
foreach ($d in @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
    $cand = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
    if (Test-Path -LiteralPath $cand) { $aiExe = $cand; break }
}
Write-Output ('   Illustrator.exe: ' + $(if ($aiExe) { (San $aiExe) } else { 'NOT FOUND' }))
$app = $null
if ($aiExe) {
    $already = Get-Process -Name Illustrator -ErrorAction SilentlyContinue
    if (-not $already) {
        Start-Process -FilePath $aiExe
        Write-Output '   launched, waiting 30s for startup ...'
        Start-Sleep -Seconds 30
    } else { Write-Output '   already running' }
    # ProgID attempts
    foreach ($pid_ in @('Illustrator.Application.24', 'Illustrator.Application.25', 'Illustrator.Application.26', 'Illustrator.Application.27', 'Illustrator.Application.28', 'Illustrator.Application.29', 'Illustrator.Application.30', 'Illustrator.Application')) {
        try {
            $t = New-Object -ComObject $pid_
            if ($t) {
                Write-Output ('   COM CONNECTED via ' + $pid_ + '  version=' + (San ([string]$t.Version)) + ' docs=' + $t.Documents.Count)
                $app = $t
                break
            }
        } catch { Write-Output ('   COM fail: ' + $pid_) }
    }
    if (-not $app) {
        # ROT enumeration probe
        Write-Output '   ProgID COM failed -> trying ROT enumeration ...'
        try {
            $src = @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class RotEnum {
    [DllImport("ole32.dll")] public static extern int GetRunningObjectTable(int reserved, out IRunningObjectTable prot);
    [DllImport("ole32.dll")] public static extern int CreateBindCtx(int reserved, out IBindCtx ppbc);
    public static void List(Action<string> emit) {
        IRunningObjectTable rot; GetRunningObjectTable(0, out rot);
        IEnumMoniker enumMon; rot.EnumRunning(out enumMon);
        monikers = null;
        IBindCtx ctx; CreateBindCtx(0, out ctx);
        IMoniker[] mons = new IMoniker[1];
        IntPtr fetched = IntPtr.Zero;
        while (enumMon.Next(1, mons, fetched) == 0) {
            string name = string.Empty;
            try { mons[0].GetDisplayName(ctx, null, out name); } catch { }
            if (name != null && (name.IndexOf("Illustrator", StringComparison.OrdinalIgnoreCase) >= 0 || name.IndexOf("!{", StringComparison.Ordinal) >= 0)) { emit(name); }
        }
    }
}
'@
            Add-Type -TypeDefinition $src
            [RotEnum]::List({ param($n) Write-Output ('   ROT: ' + (San ([string]$n))) })
        } catch { Write-Output ('   [WARN] ROT: ' + (San $_.Exception.Message)) }
    }
    if ($app) {
        try { $app.Quit() ; Write-Output '   Illustrator closed via COM Quit' } catch { Write-Output ('   [WARN] quit: ' + (San $_.Exception.Message)) }
        Start-Sleep -Seconds 5
        try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue } catch { }
    } else {
        Write-Output '   leaving Illustrator running (no COM handle to quit it)'
        try { Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue; Write-Output '   (stopped Illustrator process to leave a clean state)' } catch { }
    }
}

# ---------------------------------------- 3. Python 3.12 + py
Write-Output '--- 3. install Python 3.12 (py launcher) ---'
$py = Get-Command py -ErrorAction SilentlyContinue
if ($py) {
    Write-Output ('   py already present: ' + (San ([string]$py.Source)))
} else {
    try {
        $out = winget install --id Python.Python.3.12 --exact --scope user --silent --accept-package-agreements --accept-source-agreements 2>&1
        foreach ($l in @($out | Select-Object -Last 5)) { Write-Output ('   winget: ' + (San ([string]$l))) }
    } catch { Write-Output ('   [WARN] winget: ' + (San $_.Exception.Message)) }
    Start-Sleep -Seconds 3
    $py = Get-Command py -ErrorAction SilentlyContinue
    Write-Output ('   py after install: ' + $(if ($py) { (San ([string]$py.Source)) } else { 'STILL MISSING' }))
    if ($py) { & py -3 -X utf8 -c "import sys; print('   py -3 ->', sys.version)" }
}

# ---------------------------------------- 4. patch run_cell_lct*.ps1
Write-Output '--- 4. patch Illustrator ProgID + version gate ---'
$patchTargets = @(
    @{ f = 'E:\cell_su7\plugins\cell_su7\skills\cell_su7\scripts\run_cell_lct.ps1'; old = "    `$illustrator = New-Object -ComObject 'Illustrator.Application.30'`r`n    if ([version]`$illustrator.Version -lt [version]'30.0') {`r`n        throw `"Illustrator 2026 or newer is required; connected version is `$(`$illustrator.Version).`"" },
    @{ f = 'E:\cell_su7\plugins\cell_su7\skills\cell_su7\scripts\run_cell_lct_direct.ps1'; old = "    if ([version]`$illustrator.Version -lt [version]'30.0') {`r`n        throw `"Illustrator 2026 or newer is required; connected version is `$(`$illustrator.Version).`"" }
)
$newBlock = @'
$illustrator = $null
    foreach ($csProgid in @('Illustrator.Application.30','Illustrator.Application.29','Illustrator.Application.28','Illustrator.Application.27','Illustrator.Application.26','Illustrator.Application.25','Illustrator.Application.24','Illustrator.Application')) {
        try { $illustrator = New-Object -ComObject $csProgid; break } catch { }
    }
    if (-not $illustrator) { throw 'Illustrator COM not available (no ProgID connected; AI 2020 bridge needs registry/ROT fix)' }
    if ([version]$illustrator.Version -lt [version]'24.0') {
        throw "Illustrator 24.0 (2020) or newer is required; connected version is $($illustrator.Version)."
'@
foreach ($t in $patchTargets) {
    if (Test-Path -LiteralPath $t.f) {
        $raw = [System.IO.File]::ReadAllText($t.f)
        if ($raw.Contains($t.old)) {
            $raw2 = $raw.Replace($t.old, $newBlock)
            [System.IO.File]::WriteAllText($t.f, $raw2, (New-Object System.Text.UTF8Encoding($false)))
            Write-Output ('   PATCHED (main block): ' + $t.f)
        } elseif ($raw -match 'csProgid') {
            Write-Output ('   already patched: ' + $t.f)
        } else {
            Write-Output ('   [WARN] pattern not found in ' + $t.f)
        }
    } else { Write-Output ('   [WARN] missing file ' + $t.f) }
}
# direct variant default ProgId param
$df = 'E:\cell_su7\plugins\cell_su7\skills\cell_su7\scripts\run_cell_lct_direct.ps1'
if (Test-Path -LiteralPath $df) {
    $raw = [System.IO.File]::ReadAllText($df)
    $raw2 = $raw.Replace("[string]`$IllustratorProgId = 'Illustrator.Application.30'", "[string]`$IllustratorProgId = 'Illustrator.Application.24'")
    if ($raw2 -ne $raw) { [System.IO.File]::WriteAllText($df, $raw2, (New-Object System.Text.UTF8Encoding($false))); Write-Output '   PATCHED (direct default ProgId -> .24)' }
}

# ---------------------------------------- 5. setup.ps1
Write-Output '--- 5. run cell_su7 setup.ps1 ---'
if (Test-Path -LiteralPath 'E:\cell_su7\setup.ps1') {
    $j = Start-Job -ScriptBlock {
        Set-Location E:\cell_su7
        & .\setup.ps1 2>&1 | Out-String
    }
    if (Wait-Job $j -Timeout 600) {
        $txt = (Receive-Job $j | Out-String)
        foreach ($l in @($txt -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 25)) { Write-Output ('   ' + (San ([string]$l))) }
    } else { Write-Output '   [TIMEOUT] setup' }
    Remove-Job $j -Force -ErrorAction SilentlyContinue
} else { Write-Output '   [WARN] E:\cell_su7\setup.ps1 missing' }
$skillDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\skills\cell_su7'
Write-Output ('   installed skill dir: ' + (Test-Path -LiteralPath $skillDir))
if (Test-Path -LiteralPath $skillDir) {
    foreach ($s in @('scripts\run_cell_lct.ps1', 'scripts\run_illustrator_from_image.ps1', 'scripts\xiaomiao.ps1')) {
        Write-Output ('   ' + $s + ': ' + (Test-Path -LiteralPath (Join-Path $skillDir $s)))
    }
    $raw = [System.IO.File]::ReadAllText((Join-Path $skillDir 'scripts\run_cell_lct.ps1'))
    Write-Output ('   installed copy has ProgID fallback: ' + ($raw -match 'csProgid'))
}
exit 0
