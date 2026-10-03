# t191_docx_to_pdf_r240.ps1 - round 240.
# Convert AI_English.docx (the copy in the user's Downloads folder, which may
# contain the user's edits) back to PDF with REAL Word on this machine
# (ExportAsFixedFormat), so the PDF renders exactly like the docx does in
# Word. Output: Downloads\AI_English_from_docx.pdf (never overwrites the
# original AI_English.pdf). A copy also goes to deliverable/ and is committed
# so the agent can inspect it. ASCII-only; the non-ASCII user folder is
# located via wildcards, never a literal path.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')   # repo root
$repo = (Get-Location).Path

# ---- locate the Downloads folder (prefer the one holding AI_English.docx)
$dl = $null
$srcDocx = $null
$pats = @()
if ($env:USERPROFILE) { $pats += (Join-Path $env:USERPROFILE 'Downloads') }
$pats += 'E:\Users\*\Downloads'
$pats += 'C:\Users\*\Downloads'
$pats += 'D:\Users\*\Downloads'
foreach ($pat in $pats) {
    try {
        $hit = Get-ChildItem -Path (Join-Path $pat 'AI_English.docx') -File -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($hit) { $srcDocx = $hit.FullName; $dl = Split-Path -Parent $hit.FullName; break }
    } catch {}
}
if (-not $srcDocx) {
    Write-Output '[FAIL] AI_English.docx not found in any Downloads folder'
    exit 1
}
$san = ($srcDocx -replace '[^\x20-\x7E]', '?')
Write-Output ('== source docx: ' + $san)
$h0 = (Get-FileHash -LiteralPath $srcDocx -Algorithm SHA256).Hash.ToLower()
Write-Output ('== source sha256=' + $h0 + ' bytes=' + (Get-Item -LiteralPath $srcDocx).Length)

$outPdf = Join-Path $dl 'AI_English_from_docx.pdf'

# ---- export with real Word (wdExportFormatPDF = 17)
$word = $null; $doc = $null; $ok = $false
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $doc = $word.Documents.Open($srcDocx, $false, $true)   # no conversion dialog, read-only
    $doc.ExportAsFixedFormat($outPdf, 17)
    $ok = $true
    Write-Output '== Word.Application ExportAsFixedFormat done (format=17 PDF)'
} catch {
    Write-Output ('[FAIL] Word export threw: ' + $_.Exception.Message)
} finally {
    try { if ($doc) { $doc.Close($false) } } catch {}
    try { if ($word) { $word.Quit() } } catch {}
    try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word) } catch {}
}

if (-not $ok -or -not (Test-Path -LiteralPath $outPdf)) {
    Write-Output '[FAIL] PDF was not produced'
    exit 1
}
$pdfItem = Get-Item -LiteralPath $outPdf
$h1 = (Get-FileHash -LiteralPath $outPdf -Algorithm SHA256).Hash.ToLower()
Write-Output ('== pdf in Downloads: AI_English_from_docx.pdf bytes=' + $pdfItem.Length + ' sha256=' + $h1)
if ($pdfItem.Length -lt 50000) {
    Write-Output '[FAIL] PDF suspiciously small (<50 KB)'
    exit 1
}

# ---- copy into the repo and commit, so it travels back to the agent
New-Item -ItemType Directory -Force -Path (Join-Path $repo 'deliverable') | Out-Null
$repoPdf = Join-Path $repo 'deliverable\AI_English_from_docx.pdf'
Copy-Item -LiteralPath $outPdf -Destination $repoPdf -Force
$repoDocx = Join-Path $repo 'sources\AI_English_as_converted.docx'
Copy-Item -LiteralPath $srcDocx -Destination $repoDocx -Force
try {
    git add -- 'deliverable/AI_English_from_docx.pdf' 'sources/AI_English_as_converted.docx' 2>&1 | Out-String | Write-Output
    $st = (git status --porcelain -- 'deliverable/AI_English_from_docx.pdf' 'sources/AI_English_as_converted.docx' | Out-String).Trim()
    if ($st) {
        git commit -m 'local: AI_English.docx exported to PDF with real Word (r240)' -- 'deliverable/AI_English_from_docx.pdf' 'sources/AI_English_as_converted.docx' 2>&1 | Out-String | Write-Output
    } else {
        Write-Output '== repo copies unchanged (already committed)'
    }
} catch {
    Write-Output ('[WARN] git add/commit failed: ' + $_.Exception.Message)
}

Write-Output '== t191 done: PDF exported by real Word and delivered to Downloads + repo'
exit 0
