# t58_recon_install.ps1 - round 71 task: recon for the cell_su7 + Illustrator
# 2020 rebuild task. (1) locate fig1_graphical_abstract.png (local AERS copy
# or clone), copy it into the repo so the agent can analyze it; (2) check
# Adobe Illustrator install + COM registration; (3) check py launcher +
# python; (4) check ~/.codex, existing cell_su7 / cell_no_ai, existing
# xiaomiao key file (existence ONLY, never print contents); (5) clone
# cell_su7 to E:\cell_su7. READ-ONLY + clone + one file copy into repo.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function FmtB {
    param([double]$b)
    if ($b -ge 1MB) { return ('{0:N2} MB' -f ($b / 1MB)) }
    if ($b -ge 1KB) { return ('{0:N1} KB' -f ($b / 1KB)) }
    return ('{0:N0} B' -f $b)
}

Write-Output '--- task t58: cell_su7 / Illustrator recon ---'

# ---------------------------------------------- 1. locate fig1 image
Write-Output '--- 1. locate fig1_graphical_abstract.png ---'
$fig = $null
foreach ($cand in @(
    'E:\0writing\Auto-Empirical-Research-Skills\projects\1yzy-pg-ad-mechanism\manuscript\figures\fig1_graphical_abstract.png',
    'E:\1yzy\1yzy-pg-ad-mechanism\manuscript\figures\fig1_graphical_abstract.png',
    'E:\0writing\1yzy\1yzy-pg-ad-mechanism\manuscript\figures\fig1_graphical_abstract.png'
)) {
    if (Test-Path -LiteralPath $cand) { $fig = $cand; break }
}
if (-not $fig) {
    foreach ($root in @('E:\0writing\Auto-Empirical-Research-Skills', 'E:\1yzy')) {
        if (Test-Path -LiteralPath $root) {
            $hit = Get-ChildItem -LiteralPath $root -Recurse -Filter 'fig1_graphical_abstract.png' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hit) { $fig = $hit.FullName; break }
        }
    }
}
if (-not $fig) {
    Write-Output '   not found locally - downloading from github ...'
    $dl = 'E:\fig1_download'
    $null = New-Item -ItemType Directory -Path $dl -Force
    $url = 'https://raw.githubusercontent.com/shaohuawen03-cyber/Auto-Empirical-Research-Skills/arena/01a00dab-auto-empirical-research-skills/projects/1yzy-pg-ad-mechanism/manuscript/figures/fig1_graphical_abstract.png'
    & curl.exe -sL --max-time 120 -o (Join-Path $dl 'fig1_graphical_abstract.png') $url
    if (Test-Path -LiteralPath (Join-Path $dl 'fig1_graphical_abstract.png')) { $fig = Join-Path $dl 'fig1_graphical_abstract.png' }
}
if ($fig) {
    $fi = Get-Item -LiteralPath $fig
    Write-Output ('   FOUND: ' + (San $fig) + '  ' + (FmtB ([double]$fi.Length)))
    try {
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile($fig)
        Write-Output ('   dimensions: ' + $img.Width + ' x ' + $img.Height)
        $img.Dispose()
    } catch { Write-Output ('   [WARN] dims: ' + (San $_.Exception.Message)) }
    $refDir = Join-Path (Get-Location) 'results\reference'
    $null = New-Item -ItemType Directory -Path $refDir -Force
    Copy-Item -LiteralPath $fig -Destination (Join-Path $refDir 'fig1_graphical_abstract.png') -Force
    Write-Output ('   copied into repo: results\reference\fig1_graphical_abstract.png')
} else {
    Write-Output '   [FAIL] fig1 not found and download failed'
}

# ---------------------------------------------- 2. Adobe Illustrator
Write-Output '--- 2. Adobe Illustrator ---'
foreach ($up in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    foreach ($it in @(Get-ItemProperty -Path $up -ErrorAction SilentlyContinue)) {
        $dn = [string]$it.DisplayName
        if ($dn -match 'Illustrator') {
            Write-Output ('   INSTALLED: ' + (San $dn) + '  ' + (San ([string]$it.DisplayVersion)) + '  @ ' + (San ([string]$it.InstallLocation)))
        }
    }
}
foreach ($root in @('C:\Program Files\Adobe', 'E:\', 'D:\')) {
    foreach ($d in @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })) {
        $exe = Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'
        $alt = Join-Path $d.FullName 'Adobe Illustrator 2020.exe'
        if (Test-Path -LiteralPath $exe) { Write-Output ('   EXE: ' + (San $exe)) }
        elseif (Test-Path -LiteralPath $alt) { Write-Output ('   EXE: ' + (San $alt)) }
        else { Write-Output ('   dir: ' + (San $d.FullName)) }
    }
}
try {
    $t = [Type]::GetTypeFromProgID('Illustrator.Application')
    Write-Output ('   COM Illustrator.Application: registered (' + (San $t.GUID.ToString()) + ')')
} catch { Write-Output '   COM Illustrator.Application: NOT registered' }
try {
    foreach ($v in @(24, 25, 26)) {
        $t2 = [Type]::GetTypeFromProgID('Illustrator.Application.' + $v)
        if ($t2) { Write-Output ('   COM Illustrator.Application.' + $v + ': registered') }
    }
} catch { }

# ---------------------------------------------- 3. python / py
Write-Output '--- 3. python + py launcher ---'
foreach ($c in @('py', 'python', 'python3')) {
    $g = Get-Command -Name $c -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($g) { Write-Output ('   ' + $c.PadRight(9) + ' -> ' + (San ([string]$g.Source))) }
    else { Write-Output ('   ' + $c.PadRight(9) + ' -> MISSING') }
}

# ---------------------------------------------- 4. codex skills + key
Write-Output '--- 4. codex skills / xiaomiao key ---'
$codexDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
Write-Output ('   ~/.codex exists: ' + (Test-Path -LiteralPath $codexDir))
foreach ($sub in @('skills\cell_su7', 'skills\cell_no_ai')) {
    $p = Join-Path $codexDir $sub
    Write-Output ('   ' + $sub + ' installed: ' + (Test-Path -LiteralPath $p))
}
$keyFile = Join-Path $codexDir 'secrets\xiaomiao-api-key.dpapi'
$keyExists = Test-Path -LiteralPath $keyFile
Write-Output ('   xiaomiao key file exists: ' + $keyExists + ' (contents never printed)')

# ---------------------------------------------- 5. clone cell_su7
Write-Output '--- 5. clone cell_su7 ---'
$dst = 'E:\cell_su7'
if (Test-Path -LiteralPath $dst) {
    Write-Output ('   already exists: ' + $dst + ' (pulling latest)')
    try { Push-Location $dst; git pull --ff-only 2>&1 | ForEach-Object { Write-Output ('   git: ' + (San ([string]$_))) }; Pop-Location } catch { Pop-Location }
} else {
    try {
        $out = git clone --depth 1 https://github.com/yrui-cmd/cell_su7 $dst 2>&1
        foreach ($l in @($out | Select-Object -First 4)) { Write-Output ('   git: ' + (San ([string]$l))) }
        Write-Output ('   cloned: ' + (Test-Path -LiteralPath (Join-Path $dst 'setup.ps1')))
    } catch { Write-Output ('   [WARN] clone: ' + (San $_.Exception.Message)) }
}
exit 0
