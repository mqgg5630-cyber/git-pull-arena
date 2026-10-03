# t194_deliver_pdfs_r243.ps1 - round 243.
# Deliver the two format-identical PDFs (original Turnitin layout, dates on
# both covers unified to Oct 2, 2026, 9:18 AM GMT; AI report keeps the 57%
# heading edit) to the user's Downloads folder, sha-pinned. Overwrites the
# previous AI_English_from_docx.pdf. ASCII-only; the non-ASCII user folder is
# located via wildcards.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')   # repo root

$files = @(
    @{ name = 'AI_English_from_docx.pdf';   sha = '1c8097f1d0a8058d18e8ba957f3a2885c72b18f86cfd11157b71dde211a970cd'; bytes = 1573132 },
    @{ name = 'plag_English_from_docx.pdf'; sha = 'f61f7157a9f8a53500a05be164003c5a6ebe2f6a040f072a43cf349deac0ba0b'; bytes = 1625071 }
)

# locate Downloads (prefer the folder holding the source PDFs)
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
Write-Output '== t194 done: both PDFs delivered and verified'
exit 0
