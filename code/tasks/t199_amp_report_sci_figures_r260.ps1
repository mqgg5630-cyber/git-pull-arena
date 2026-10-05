# t199_amp_report_sci_figures_r260.ps1 - literature report + PyMOL SCI figures.
# Runs on the real Windows machine. ASCII-only source; output documents may contain Unicode.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path
$outRoot = Join-Path $repo 'results\docking'
$outDir = Join-Path $outRoot 'AMP_Docking_Vina_R255'
$taskReport = Join-Path $outRoot 'AMP_REPORT_SCI_FIGURES_R260.md'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$lines = New-Object System.Collections.Generic.List[string]
function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace 'ya29\.[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]' } catch { }
    try { $s = $s -replace '1//[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]' } catch { }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{40,}','[REDACTED]' } catch { }
    return $s
}
function L([string]$m) { $script:lines.Add($m) | Out-Null; Write-Output $m }
function Write-TaskReport { $script:lines | Set-Content -LiteralPath $script:taskReport -Encoding UTF8 }
function Run-Capped([string]$Name,[scriptblock]$Block,[int]$TimeoutSec) {
    $job = Start-Job -ScriptBlock $Block
    if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return @{ ok=$false; text='TIMEOUT'; name=$Name }
    }
    $txt = (Receive-Job $job 2>&1 | Out-String).Trim()
    $state = [string]$job.State
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return @{ ok=($state -eq 'Completed'); text=$txt; name=$Name }
}
function Find-Python {
    $cands = @()
    foreach ($p in @('E:\spider\python.exe','E:\spider\envs\mcp_pymol\python.exe','E:\spider\envs\spyder-runtime\python.exe','C:\Python311\python.exe')) { if (Test-Path -LiteralPath $p) { $cands += $p } }
    try { $cmd = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1; if ($cmd) { $cands += [string]$cmd.Source } } catch { }
    foreach ($p in ($cands | Select-Object -Unique)) {
        try {
            $v = (& $p -c "import sys; print(sys.version.split()[0])" 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $v) { return $p }
        } catch { }
    }
    return ''
}
function Escape-Unicode([string]$s) {
    if ($null -eq $s) { return '' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $code = [int][char]$ch
        if ($code -ge 32 -and $code -le 126) { [void]$sb.Append($ch) } else { [void]$sb.Append(('\u{0:X4}' -f $code)) }
    }
    return $sb.ToString()
}

L '# AMP docking literature report and SCI PyMOL figures - round 260'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('host=' + $env:COMPUTERNAME)
L ('repo=' + $repo)
L ('out_dir=' + $outDir)
if (-not (Test-Path -LiteralPath $outDir)) {
    L 'AMP_OUTPUT_FOLDER_EXISTS=False'
    L 'AMP_REPORT_SCI_FIGURES_DONE=False'
    Write-TaskReport
    exit 2
}
L 'AMP_OUTPUT_FOLDER_EXISTS=True'

$py = Find-Python
if (-not $py) {
    L 'PYTHON_FOUND=False'
    L 'AMP_REPORT_SCI_FIGURES_DONE=False'
    Write-TaskReport
    exit 3
}
L ('python=' + (San $py))
try { L ('python_version=' + (San ((& $py -c "import sys; print(sys.version)" 2>&1 | Out-String).Trim()))) } catch { }

L '## Dependency setup'
$install = Run-Capped 'pip_install_report_deps' { & $using:py -m pip install --user --quiet --upgrade "pillow" "python-docx" 2>&1 | Out-String } 900
foreach ($ln in (($install.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 20)) { L ('pip| ' + (San $ln)) }
$import = Run-Capped 'import_report_deps' { & $using:py -c "import PIL, docx; print('REPORT_DEPS_OK=True')" 2>&1 | Out-String } 60
foreach ($ln in (($import.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 20)) { L ('import| ' + (San $ln)) }
if ($import.text -notmatch 'REPORT_DEPS_OK=True') {
    L 'REPORT_DEPS_OK=False'
    L 'AMP_REPORT_SCI_FIGURES_DONE=False'
    Write-TaskReport
    exit 4
}
L 'REPORT_DEPS_OK=True'

# Confirm PyMOL before running the figure generator.
$pymolCandidates = @('E:\spider\Scripts\pymol.EXE','E:\spider\Scripts\pymol.exe','D:\Pymol\PyMOLWin.exe','D:\Pymol\pymol.exe','E:\Pymol\PyMOLWin.exe','C:\Program Files\PyMOL\PyMOLWin.exe')
$pymolFound = ''
foreach ($p in $pymolCandidates) { if (Test-Path -LiteralPath $p) { $pymolFound = $p; break } }
if (-not $pymolFound) {
    try { $cmd = Get-Command pymol -ErrorAction SilentlyContinue | Select-Object -First 1; if ($cmd) { $pymolFound = [string]$cmd.Source } } catch { }
}
L ('pymol_found=' + (San $pymolFound))
if (-not $pymolFound) {
    L 'PYMOL_FOUND=False'
    L 'AMP_REPORT_SCI_FIGURES_DONE=False'
    Write-TaskReport
    exit 5
}
L 'PYMOL_FOUND=True'

$script = Join-Path $repo 'code\tasks\amp_docking_report_and_sci_figures.py'
if (-not (Test-Path -LiteralPath $script)) {
    L ('script_missing=' + $script)
    L 'AMP_REPORT_SCI_FIGURES_DONE=False'
    Write-TaskReport
    exit 6
}

L '## Generate literature report and PyMOL SCI figures'
$run = Run-Capped 'amp_report_sci_figures' { & $using:py $using:script $using:outDir 2>&1 | Out-String } 3600
foreach ($ln in (($run.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 160)) { L ('run| ' + (San $ln)) }
$md = Join-Path $outDir 'AMP_Docking_Targets_Methods_Results.md'
$docx = Join-Path $outDir 'AMP_Docking_Targets_Methods_Results.docx'
$figDir = Join-Path $outDir 'complexes_best_vina\sci_composite_figures'
$part1 = Join-Path $figDir 'Figure_4_Part1_A-F_300dpi.png'
$part2 = Join-Path $figDir 'Figure_4_Part2_G-L_300dpi.png'
$supp = Join-Path $figDir 'Figure_S1_12_Combined_300dpi.png'
$ok = ($run.text -match 'AMP_DOC_REPORT_DONE=True') -and (Test-Path -LiteralPath $md) -and (Test-Path -LiteralPath $docx) -and (Test-Path -LiteralPath $part1) -and (Test-Path -LiteralPath $part2) -and (Test-Path -LiteralPath $supp)
L ('generation_ok=' + $ok)
if (-not $ok) {
    L 'AMP_REPORT_SCI_FIGURES_DONE=False'
    Write-TaskReport
    exit 7
}

# Update the existing Desktop result folder if present; otherwise create a fresh one.
$desktopRoot = [Environment]::GetFolderPath('Desktop')
$desktopDir = $null
try {
    $desktopDir = Get-ChildItem -LiteralPath $desktopRoot -Directory -Filter 'AMP_Docking_Vina_R255_*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} catch { }
if ($desktopDir) {
    $desktopPath = [string]$desktopDir.FullName
} else {
    $desktopPath = Join-Path $desktopRoot ('AMP_Docking_Vina_R255_' + (Get-Date -Format 'yyyyMMdd_HHmm'))
    New-Item -ItemType Directory -Force -Path $desktopPath | Out-Null
}
try {
    Copy-Item -Path (Join-Path $outDir '*') -Destination $desktopPath -Recurse -Force
    L ('desktop_updated_raw=' + $desktopPath)
    L ('desktop_updated_escaped=' + (Escape-Unicode $desktopPath))
    L ('DESKTOP_FOLDER_UPDATED=True')
} catch {
    L ('desktop_update_error=' + (San $_.Exception.Message))
    L 'DESKTOP_FOLDER_UPDATED=False'
    Write-TaskReport
    exit 8
}

try {
    Add-Content -LiteralPath (Join-Path $outRoot 'AMP_DOCKING_R255.md') -Encoding UTF8 -Value ''
    Add-Content -LiteralPath (Join-Path $outRoot 'AMP_DOCKING_R255.md') -Encoding UTF8 -Value '## Round 260 literature report and SCI figure update'
    Add-Content -LiteralPath (Join-Path $outRoot 'AMP_DOCKING_R255.md') -Encoding UTF8 -Value ('desktop_updated_raw=' + $desktopPath)
    Add-Content -LiteralPath (Join-Path $outRoot 'AMP_DOCKING_R255.md') -Encoding UTF8 -Value ('markdown_report=' + $md)
    Add-Content -LiteralPath (Join-Path $outRoot 'AMP_DOCKING_R255.md') -Encoding UTF8 -Value ('docx_report=' + $docx)
    Add-Content -LiteralPath (Join-Path $outRoot 'AMP_DOCKING_R255.md') -Encoding UTF8 -Value ('sci_composite_figures=' + $figDir)
    Add-Content -LiteralPath (Join-Path $outRoot 'AMP_DOCKING_R255.md') -Encoding UTF8 -Value 'AMP_DOC_REPORT_DONE=True'
    Add-Content -LiteralPath (Join-Path $outRoot 'AMP_DOCKING_R255.md') -Encoding UTF8 -Value 'SCI_COMPOSITE_FIGURES_DONE=True'
} catch { }

L ''
L ('markdown_report=' + $md)
L ('docx_report=' + $docx)
L ('sci_composite_figures=' + $figDir)
L 'AMP_MD_DONE=True'
L 'AMP_DOCX_DONE=True'
L 'AMP_DOC_REPORT_DONE=True'
L 'SCI_COMPOSITE_FIGURES_DONE=True'
L 'AMP_REPORT_SCI_FIGURES_DONE=True'
Write-TaskReport
exit 0
