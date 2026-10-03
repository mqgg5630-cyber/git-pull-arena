# t190_deliver_timeonly_pdfs_r239.ps1 - round 239.
# Deliver the time-only regenerated PDFs to the user's Downloads folder.
# These PDFs are based on the original source PDFs from branch
# arena/01a0ff64-git-pull-arena: only the cover timestamp changed; all other
# visible content stays original. ASCII-only; non-ASCII user folder is located
# through wildcards.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')

$files = @(
    @{ name = 'AI_English_from_docx.pdf';   sha = '31bfb47299dd58210b79d3207d26fb48251d9ee1523828a42419491dc6f48c31'; bytes = 1527133 },
    @{ name = 'plag_English_from_docx.pdf'; sha = 'b2eb8c9a9b7e263c364c19e1c7863f47ce92971fc1c1243370c947e1b2fe603e'; bytes = 1625379 }
)

$dl = $null
$cands = @()
if ($env:USERPROFILE) { $cands += (Join-Path $env:USERPROFILE 'Downloads') }
foreach ($pat in @('E:\Users\*\Downloads', 'C:\Users\*\Downloads', 'D:\Users\*\Downloads')) {
    try {
        $hit = Get-ChildItem -Path (Join-Path $pat 'plag_English.pdf') -File -ErrorAction SilentlyContinue |
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

$fail = 0
foreach ($f in $files) {
    $src = Join-Path '.\deliverable' $f.name
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Output ('[FAIL] missing in repo: deliverable/' + $f.name + ' (stale pull?)')
        $fail = 1
        continue
    }
    $h = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash.ToLower()
    $len = (Get-Item -LiteralPath $src).Length
    if ($h -ne $f.sha -or $len -ne $f.bytes) {
        Write-Output ('[FAIL] repo copy mismatch for ' + $f.name + ' sha=' + $h + ' bytes=' + $len)
        $fail = 1
        continue
    }
    $dst = Join-Path $dl $f.name
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $h2 = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLower()
    $len2 = (Get-Item -LiteralPath $dst).Length
    if ($h2 -ne $f.sha -or $len2 -ne $f.bytes) {
        Write-Output ('[FAIL] Downloads copy does not verify for ' + $f.name + ' sha=' + $h2 + ' bytes=' + $len2)
        $fail = 1
        continue
    }
    Write-Output ('== delivered ' + $f.name + ' -> Downloads (sha256 verified, bytes=' + $len + ')')
}

if ($fail -ne 0) { exit 1 }
Write-Output '== t190 done: time-only PDFs delivered and verified'
exit 0
