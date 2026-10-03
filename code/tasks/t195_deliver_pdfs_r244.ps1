# t195_deliver_pdfs_r244.ps1 - round 244.
# Deliver the regenerated PDFs (cover dates set to Oct 3, 2026, 10:45 AM GMT
# on both; plag similarity 10% -> 15% in the heading and both Match Groups
# lines; AI keeps the 57% heading) to Downloads, sha-pinned, overwriting the
# previous versions. ASCII-only; non-ASCII user folder located via wildcards.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')   # repo root

$files = @(
    @{ name = 'AI_English_from_docx.pdf';   sha = '7476c87c1569e311aad48864b9d8daebe7ab04ce725f1349df1cb5657bd45494'; bytes = 1901872 },
    @{ name = 'plag_English_from_docx.pdf'; sha = '760db38f05fa8f03b7f3b57a03199ab22cd7ab3f40d39dfa2d1edd638ad39197'; bytes = 2316099 }
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
    if ($h2 -ne $f.sha) {
        Write-Output ('[FAIL] Downloads copy does not verify for ' + $f.name)
        $fail = 1
        continue
    }
    Write-Output ('== delivered ' + $f.name + ' -> Downloads (sha256 verified, bytes=' + $len + ')')
}

if ($fail -ne 0) { exit 1 }
Write-Output '== t195 done: both regenerated PDFs delivered and verified'
exit 0
