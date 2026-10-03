# t191_deliver_no_overwrite_pdfs_r241.ps1 - round 241.
# Deliver both PDF sets to Downloads WITHOUT overwriting any existing file:
#   1) current time-only PDFs (timestamp 2026-10-03 15:45 local / GMT label)
#   2) previous successful outputs from arena/01a0ff64 r244 (10:45 set)
# If a target filename already exists with the same sha256, it is kept. If a
# different file exists, a _copyN suffix is used. ASCII-only.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')

$manifestPath = '.\results\status\no_overwrite_pdf_manifest_r241.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Output ('[FAIL] missing manifest: ' + $manifestPath)
    exit 1
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-UniqueDestination {
    param([string]$Folder, [string]$Name, [string]$ExpectedSha)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    $ext = [System.IO.Path]::GetExtension($Name)
    $cand = Join-Path $Folder $Name
    if (-not (Test-Path -LiteralPath $cand)) { return $cand }
    try {
        $h = (Get-FileHash -LiteralPath $cand -Algorithm SHA256).Hash.ToLower()
        if ($h -eq $ExpectedSha.ToLower()) { return $cand }
    } catch { }
    for ($i = 2; $i -lt 100; $i++) {
        $n = $base + '_copy' + $i + $ext
        $cand = Join-Path $Folder $n
        if (-not (Test-Path -LiteralPath $cand)) { return $cand }
        try {
            $h = (Get-FileHash -LiteralPath $cand -Algorithm SHA256).Hash.ToLower()
            if ($h -eq $ExpectedSha.ToLower()) { return $cand }
        } catch { }
    }
    throw 'could not choose non-overwriting destination for ' + $Name
}

# locate Downloads; prefer the one with the original source PDFs.
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
foreach ($f in @($manifest.files)) {
    $rel = [string]$f.path
    $src = Join-Path (Get-Location) ($rel -replace '/', '\')
    $name = Split-Path -Leaf $src
    $sha = ([string]$f.sha256).ToLower()
    $bytes = [int64]$f.bytes
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Output ('[FAIL] missing source: ' + $rel)
        $fail = 1
        continue
    }
    $h = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash.ToLower()
    $len = [int64](Get-Item -LiteralPath $src).Length
    if ($h -ne $sha -or $len -ne $bytes) {
        Write-Output ('[FAIL] source mismatch: ' + $rel + ' sha=' + $h + ' bytes=' + $len)
        $fail = 1
        continue
    }
    try {
        $dst = Get-UniqueDestination -Folder $dl -Name $name -ExpectedSha $sha
        if (Test-Path -LiteralPath $dst) {
            Write-Output ('== already present, not overwritten: ' + (Split-Path -Leaf $dst) + ' sha256=' + $sha)
        } else {
            Copy-Item -LiteralPath $src -Destination $dst -ErrorAction Stop
            Write-Output ('== copied without overwrite: ' + $name + ' -> ' + (Split-Path -Leaf $dst))
        }
        $h2 = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLower()
        $len2 = [int64](Get-Item -LiteralPath $dst).Length
        if ($h2 -ne $sha -or $len2 -ne $bytes) {
            Write-Output ('[FAIL] destination verify failed: ' + $dst)
            $fail = 1
        } else {
            Write-Output ('   verified bytes=' + $len2 + ' sha256=' + $h2)
        }
    } catch {
        Write-Output ('[FAIL] copy failed for ' + $rel + ': ' + $_.Exception.Message)
        $fail = 1
    }
}

if ($fail -ne 0) { exit 1 }
Write-Output '== t191 done: all named PDF copies are present; no existing file was overwritten'
exit 0
