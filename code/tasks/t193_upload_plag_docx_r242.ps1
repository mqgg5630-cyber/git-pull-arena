# t193_upload_plag_docx_r242.ps1 - round 242.
# Copy plag_English.docx (possibly edited by the user) from Downloads into the
# repo as sources/plag_English_as_edited.docx and commit it, so the agent can
# diff it against the docx it delivered and port the edits onto the original
# PDF. ASCII-only; the non-ASCII user folder is located via wildcards.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')   # repo root

$src = $null
$pats = @()
if ($env:USERPROFILE) { $pats += (Join-Path $env:USERPROFILE 'Downloads') }
$pats += 'E:\Users\*\Downloads'
$pats += 'C:\Users\*\Downloads'
$pats += 'D:\Users\*\Downloads'
foreach ($pat in $pats) {
    try {
        $hit = Get-ChildItem -Path (Join-Path $pat 'plag_English.docx') -File -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($hit) { $src = $hit.FullName; break }
    } catch {}
}
if (-not $src) {
    Write-Output '[FAIL] plag_English.docx not found in any Downloads folder'
    exit 1
}
Write-Output ('== source: ' + ($src -replace '[^\x20-\x7E]', '?'))
$dst = '.\sources\plag_English_as_edited.docx'
Copy-Item -LiteralPath $src -Destination $dst -Force
$it = Get-Item -LiteralPath $dst
$h = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLower()
Write-Output ('== uploaded plag_English_as_edited.docx bytes=' + $it.Length + ' sha256=' + $h)

try {
    git add -- 'sources/plag_English_as_edited.docx' 2>&1 | Out-String | Write-Output
    $st = (git status --porcelain -- 'sources/plag_English_as_edited.docx' | Out-String).Trim()
    if ($st) {
        git commit -m 'local: upload edited plag_English.docx (r242)' -- 'sources/plag_English_as_edited.docx' 2>&1 | Out-String | Write-Output
    } else {
        Write-Output '== already committed (no change)'
    }
} catch {
    Write-Output ('[WARN] git add/commit failed: ' + $_.Exception.Message)
}
Write-Output '== t193 done'
exit 0
