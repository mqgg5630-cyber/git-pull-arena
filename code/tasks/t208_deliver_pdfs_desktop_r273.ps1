$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
Write-Output "HOST=$env:COMPUTERNAME"

$folder = "AMP_Docking_Vina_R255_20261005_1552"
$desk = $null
foreach ($d in @([Environment]::GetFolderPath("Desktop"), ("D:\" + [char]0x684C + [char]0x9762), (Join-Path $env:USERPROFILE "Desktop"))) {
    if ($d -and (Test-Path -LiteralPath $d)) { if (Test-Path -LiteralPath (Join-Path $d $folder)) { $desk = $d; break } }
}
if (-not $desk) { foreach ($d in @(("D:\" + [char]0x684C + [char]0x9762), [Environment]::GetFolderPath("Desktop"))) { if (Test-Path -LiteralPath $d) { $desk = $d; break } } }
if (-not $desk) { Write-Output "NO_DESKTOP"; exit 1 }
Write-Output "DESKTOP=$desk"

$out = Join-Path $desk "Turnitin_Reports_20261007"
New-Item -ItemType Directory -Force -Path $out | Out-Null
Write-Output "OUTDIR=$out"

function DeliverNoOverwrite($srcRel, $baseName) {
    $src = Join-Path $repo $srcRel
    if (-not (Test-Path -LiteralPath $src)) { Write-Output "MISSING_SRC=$srcRel"; return $null }
    $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $dst = Join-Path $out $baseName
    if (Test-Path -LiteralPath $dst) {
        $dstHash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
        if ($dstHash -eq $srcHash) { Write-Output ("KEPT_IDENTICAL={0}" -f $baseName); return $dst }
        $i = 2
        $stem = [IO.Path]::GetFileNameWithoutExtension($baseName)
        $ext  = [IO.Path]::GetExtension($baseName)
        while (Test-Path -LiteralPath (Join-Path $out ("{0}_copy{1}{2}" -f $stem,$i,$ext))) { $i++ }
        $dst = Join-Path $out ("{0}_copy{1}{2}" -f $stem,$i,$ext)
        Write-Output ("RENAMED_TO={0}" -f (Split-Path $dst -Leaf))
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $h = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
    Write-Output ("DELIVERED={0} size={1} sha256={2}" -f (Split-Path $dst -Leaf), (Get-Item -LiteralPath $dst).Length, $h)
    if ($h -ne $srcHash) { Write-Output "HASH_MISMATCH"; return $null }
    return $dst
}

$a = DeliverNoOverwrite "deliverable\AI_English_20261007_1610.pdf"   "AI_English_20261007_1610.pdf"
$b = DeliverNoOverwrite "deliverable\plag_English_20261007_1610.pdf" "plag_English_20261007_1610.pdf"
if (-not $a -or -not $b) { Write-Output "DELIVERY_FAILED"; exit 1 }

# verify the two cover markers survived the copy
$py = $null
foreach ($c in @("E:\spider\python.exe","python.exe")) { try { & $c -c "import fitz" 2>$null; if ($LASTEXITCODE -eq 0) { $py = $c; break } } catch {} }
if (-not $py) {
    foreach ($c in @("E:\spider\python.exe","python.exe")) {
        try { & $c -m pip install --user --quiet pymupdf 2>&1 | Out-Null; & $c -c "import fitz" 2>$null; if ($LASTEXITCODE -eq 0) { $py = $c; break } } catch {}
    }
}
Write-Output "PY_WITH_FITZ=$py"
if ($py) {
    $code = @"
import fitz, re, sys
for f, pat in [(r'$a', r'\*%\s*detected as AI'), (r'$b', r'10%\s*Overall Similarity')]:
    d = fitz.open(f)
    t = ''.join(p.get_text() for p in d)
    p1 = d[0].get_text()
    print('FILE', f)
    print('  PAGES', d.page_count)
    print('  MARKER', bool(re.search(pat, t)))
    print('  COVER_DATES', re.findall(r'(?:Sep|Oct|Nov|Dec) \d{1,2}, \d{4}, \d{1,2}:\d{2} [AP]M GMT', p1))
"@
    $tmp = Join-Path $repo "verify_pdfs.py"
    [IO.File]::WriteAllText($tmp, $code, (New-Object Text.UTF8Encoding($false)))
    & $py $tmp 2>&1 | ForEach-Object { Write-Output ("v| " + $_) }
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
}

Write-Output "PDF_DESKTOP_DELIVERY_DONE=True"
