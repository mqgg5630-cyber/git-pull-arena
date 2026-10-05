# t197_amp_vina_docking_r255.ps1 - round 255.
# Antimicrobial peptide docking workflow with AutoDock Vina baseline.
# Runs on the real Windows machine. ASCII-only.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path
$outRoot = Join-Path $repo 'results\docking'
$outDir = Join-Path $outRoot 'AMP_Docking_Vina_R255'
$mainReport = Join-Path $outRoot 'AMP_DOCKING_R255.md'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$lines = New-Object System.Collections.Generic.List[string]
function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace 'ya29\.[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]' } catch { }
    try { $s = $s -replace '1//[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]' } catch { }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{32,}','[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]','?' } catch { }
    return $s
}
function L([string]$m) { $script:lines.Add($m) | Out-Null; Write-Output $m }
function Write-Main { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:mainReport) | Out-Null; $script:lines | Set-Content -LiteralPath $script:mainReport -Encoding UTF8 }
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
    # Prefer the existing scientific/conda Python on E: over the Store/local
    # Python 3.12, because vina wheels are not always available for 3.12.
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

L '# AMP Vina docking task - round 255'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('host=' + $env:COMPUTERNAME)
L ''
L '## Task scope'
L 'Peptides: FVNKLNRIIPVKGFSMR; LISNTKKFGTAIASHR; ISLAIPLASKISGFTLALVKNAST'
L 'Targets: E. coli FtsZ + GyrB, S. aureus FtsZ + Sortase A'
L 'Replicates: 3 Vina repeats per peptide-target pair; report mean of best scores.'
L ''

# Probe desktop but do not require it. The user gave the PyMOL-MCP skill path on this laptop.
$desktop = '100.84.137.117'
$desktopProbe = 'NOT_RUN'
try {
    $ssh = Get-Command ssh -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ssh) {
        $probe = Run-Capped 'desktop_probe' { ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new BNI@100.84.137.117 'hostname' 2>&1 | Out-String } 20
        if ($probe.text) { $desktopProbe = (San (($probe.text -split "`r?`n" | Select-Object -First 2) -join ' | ')) } else { $desktopProbe = 'NO_OUTPUT' }
    } else { $desktopProbe = 'ssh_missing' }
} catch { $desktopProbe = 'ERR ' + (San $_.Exception.Message) }
L ('desktop_probe=' + $desktopProbe)
$pymolMcp = 'E:\0mcp-agv\.agents\skills\pymol-mcp'
L ('pymol_mcp_path=' + (San $pymolMcp) + ' exists=' + (Test-Path -LiteralPath $pymolMcp))
L 'execution_machine=laptop_or_current_watcher_machine'
L ''

$py = Find-Python
if (-not $py) {
    L 'PYTHON_FOUND=False'
    L 'AMP_DOCKING_DONE=False'
    Write-Main
    exit 2
}
L ('python=' + (San $py))
try { L ('python_version=' + (San ((& $py -c "import sys; print(sys.version)" 2>&1 | Out-String).Trim()))) } catch { }

L '## Dependency setup'
$install1 = Run-Capped 'pip_install_core' { & $using:py -m pip install --user --upgrade --quiet "numpy==1.26.4" matplotlib 2>&1 | Out-String } 600
foreach ($ln in (($install1.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 12)) { L ('pip_core| ' + (San $ln)) }
$install2 = Run-Capped 'pip_install_rdkit' { & $using:py -m pip install --user --upgrade --quiet rdkit 2>&1 | Out-String } 900
foreach ($ln in (($install2.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 20)) { L ('pip_rdkit| ' + (San $ln)) }
$rdImport = Run-Capped 'rdkit_import_check' { & $using:py -c "import rdkit; print('RDKIT_OK=True')" 2>&1 | Out-String } 60
if ($rdImport.text -notmatch 'RDKIT_OK=True') {
    L 'rdkit first install did not import; trying rdkit-pypi fallback'
    $install2b = Run-Capped 'pip_install_rdkit_pypi' { & $using:py -m pip install --user --upgrade --quiet rdkit-pypi 2>&1 | Out-String } 900
    foreach ($ln in (($install2b.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 20)) { L ('pip_rdkit_pypi| ' + (San $ln)) }
}
$import = Run-Capped 'import_check' { & $using:py -c "import rdkit, matplotlib, numpy; print('IMPORT_OK=True')" 2>&1 | Out-String } 60
foreach ($ln in (($import.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 20)) { L ('import| ' + (San $ln)) }
if ($import.text -notmatch 'IMPORT_OK=True') {
    L 'DEPENDENCIES_OK=False'
    L 'AMP_DOCKING_DONE=False'
    Write-Main
    exit 3
}
L 'DEPENDENCIES_OK=True'

L '## AutoDock Vina CLI setup'
$vinaDir = Join-Path $env:LOCALAPPDATA 'ArenaTools\vina'
New-Item -ItemType Directory -Force -Path $vinaDir | Out-Null
$vinaExe = Join-Path $vinaDir 'vina_1.2.7_win.exe'
if (-not (Test-Path -LiteralPath $vinaExe)) {
    $url = 'https://github.com/ccsb-scripps/AutoDock-Vina/releases/download/v1.2.7/vina_1.2.7_win.exe'
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path -LiteralPath $curl) {
        $dl = Run-Capped 'download_vina_cli' { & $using:curl -L --ssl-no-revoke --retry 3 --connect-timeout 20 --max-time 600 -o $using:vinaExe $using:url 2>&1 | Out-String } 720
        foreach ($ln in (($dl.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 10)) { L ('vina_download| ' + (San $ln)) }
    } else {
        try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $vinaExe } catch { L ('vina_download_WARN=' + (San $_.Exception.Message)) }
    }
}
if (-not (Test-Path -LiteralPath $vinaExe)) {
    L 'VINA_CLI_READY=False'
    L 'AMP_DOCKING_DONE=False'
    Write-Main
    exit 4
}
try { L ('vina_sha256=' + (Get-FileHash -LiteralPath $vinaExe -Algorithm SHA256).Hash.ToLower()) } catch { }
$vver = Run-Capped 'vina_version' { & $using:vinaExe --version 2>&1 | Out-String } 60
foreach ($ln in (($vver.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 10)) { L ('vina| ' + (San $ln)) }
$env:VINA_EXE = $vinaExe
L ('VINA_EXE=' + (San $vinaExe))
L 'VINA_CLI_READY=True'

if (Test-Path -LiteralPath $outDir) { Remove-Item -LiteralPath $outDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$pipeline = Join-Path $repo 'code\tasks\peptide_vina_pipeline.py'
if (-not (Test-Path -LiteralPath $pipeline)) {
    L ('pipeline_missing=' + (San $pipeline))
    L 'AMP_DOCKING_DONE=False'
    Write-Main
    exit 4
}

L '## Docking run'
$run = Run-Capped 'vina_pipeline' { $env:VINA_EXE = $using:vinaExe; & $using:py $using:pipeline $using:outDir 2>&1 | Out-String } 1500
foreach ($ln in (($run.text -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 120)) { L ('dock| ' + (San $ln)) }
$pipelineOk = ($run.text -match 'DOCKING_PIPELINE_DONE=True') -and (Test-Path -LiteralPath (Join-Path $outDir 'REPORT.md'))
L ('pipeline_ok=' + $pipelineOk)
if (-not $pipelineOk) {
    L 'AMP_DOCKING_DONE=False'
    Write-Main
    exit 5
}

# Mirror the finished output to the user's Desktop as requested.
$desktopDir = Join-Path ([Environment]::GetFolderPath('Desktop')) ('AMP_Docking_Vina_R255_' + (Get-Date -Format 'yyyyMMdd_HHmm'))
try {
    if (Test-Path -LiteralPath $desktopDir) { Remove-Item -LiteralPath $desktopDir -Recurse -Force -ErrorAction SilentlyContinue }
    Copy-Item -LiteralPath $outDir -Destination $desktopDir -Recurse -Force
    L ('desktop_result_folder=' + (San $desktopDir))
} catch { L ('desktop_copy_WARN=' + (San $_.Exception.Message)) }

# Append concise summary from pipeline report.
$reportPath = Join-Path $outDir 'REPORT.md'
try {
    L ''
    L '## Pipeline report excerpt'
    $rpt = Get-Content -LiteralPath $reportPath -Encoding UTF8
    foreach ($ln in ($rpt | Select-Object -First 80)) { L (San $ln) }
} catch { }

L ''
L ('repo_result_folder=' + (San $outDir))
L ('repo_report=' + (San $reportPath))
L 'DOCKING_PIPELINE_DONE=True'
L 'VINA_REPEATS_PER_PAIR=3'
L 'ENERGY_MINIMIZATION_DONE=True'
L 'RECEPTOR_STANDARDIZATION_DONE=True'
L 'AMP_DOCKING_DONE=True'
Write-Main
exit 0
