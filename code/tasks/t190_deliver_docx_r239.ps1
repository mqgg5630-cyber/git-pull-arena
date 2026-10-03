# t190_deliver_docx_r239.ps1 - round 239.
# Deliver the converted docx files back to the user's Downloads folder (the
# same folder the source PDFs came from) and verify their sha256 against
# deliverable/OFFICE_HASHES.json. The user folder name is non-ASCII, so
# Downloads is located via wildcards / environment. ASCII-only on purpose.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')   # repo root

$names = @('plag_English.docx', 'AI_English.docx')

# locate the Downloads folder: prefer the one that still holds the source PDFs
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

# expected hashes from the manifest
$man = Get-Content -LiteralPath '.\deliverable\OFFICE_HASHES.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$fail = 0
foreach ($n in $names) {
    $src = Join-Path '.\deliverable' $n
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Output ('[FAIL] missing in repo: deliverable/' + $n + ' (run .\sync.ps1?)')
        $fail = 1
        continue
    }
    $exp = $null
    foreach ($f in @($man.files)) { if (([string]$f.path) -eq ('deliverable/' + $n)) { $exp = $f } }
    $h = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash.ToLower()
    if ($exp -and ($h -ne ([string]$exp.sha256).ToLower())) {
        Write-Output ('[FAIL] sha256 mismatch for ' + $n + ' (stale pull?) got=' + $h)
        $fail = 1
        continue
    }
    $dst = Join-Path $dl $n
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $ok = Test-Path -LiteralPath $dst
    $sz = (Get-Item -LiteralPath $dst).Length
    Write-Output ('== delivered ' + $n + ' -> Downloads (bytes=' + $sz + ' sha256=' + $h + ' verified=' + $ok + ')')
}

if ($fail -ne 0) { exit 1 }
Write-Output '== t190 done: both docx verified and copied to Downloads'
exit 0
