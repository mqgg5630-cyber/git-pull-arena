# t192_deliver_pdf_r241.ps1 - round 241.
# Deliver the format-preserving PDF (original 32-page Turnitin layout with the
# user's two text edits applied in place) to the user's Downloads folder,
# REPLACING the earlier Word-exported 41-page file of the same name. The file
# is verified against a pinned sha256 before and after the copy. ASCII-only;
# the non-ASCII user folder is located via wildcards.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')   # repo root

$name = 'AI_English_from_docx.pdf'
$expSha = 'e875a7d14ee1f4ec286f18ebf2563de864951891fdbf4e93df164565bf73906d'
$expBytes = 1573119

$src = Join-Path '.\deliverable' $name
if (-not (Test-Path -LiteralPath $src)) {
    Write-Output ('[FAIL] missing in repo: deliverable/' + $name)
    exit 1
}
$h = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash.ToLower()
$len = (Get-Item -LiteralPath $src).Length
if ($h -ne $expSha -or $len -ne $expBytes) {
    Write-Output ('[FAIL] repo copy mismatch (stale pull?) sha=' + $h + ' bytes=' + $len)
    exit 1
}
Write-Output ('== repo copy verified: sha256=' + $h + ' bytes=' + $len)

# locate Downloads (prefer the folder holding the source PDFs)
$dl = $null
$cands = @()
if ($env:USERPROFILE) { $cands += (Join-Path $env:USERPROFILE 'Downloads') }
foreach ($pat in @('E:\Users\*\Downloads', 'C:\Users\*\Downloads', 'D:\Users\*\Downloads')) {
    try {
        $hit = Get-ChildItem -Path (Join-Path $pat 'AI_English.pdf') -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { $cands = @((Split-Path -Parent $hit.FullName)) + $cands; break }
    } catch {}
}
foreach ($c in $cands) {
    if ($c -and (Test-Path -LiteralPath $c)) { $dl = $c; break }
}
if (-not $dl) {
    Write-Output '[FAIL] no Downloads folder found'
    exit 1
}
Write-Output ('== deliver target: ' + ($dl -replace '[^\x20-\x7E]', '?'))

$dst = Join-Path $dl $name
Copy-Item -LiteralPath $src -Destination $dst -Force
$h2 = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLower()
if ($h2 -ne $expSha) {
    Write-Output ('[FAIL] copy in Downloads does not verify: ' + $h2)
    exit 1
}
Write-Output ('== delivered ' + $name + ' -> Downloads (sha256 verified, 32-page original layout)')
Write-Output '== t192 done'
exit 0
