# t189_upload_pdfs_r238.ps1 - round 238.
# Copy two source PDFs from the user's Downloads folder into the repo
# (sources/) and commit them, so the sandbox agent can convert them to docx.
# The user folder name is non-ASCII, so Downloads is located via wildcards
# and the environment - never a literal non-ASCII path. ASCII-only on purpose.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')   # repo root (this file lives in code\tasks\)

$names = @('plag_English.pdf', 'AI_English.pdf')

# candidate Downloads folders, most specific first
$dirs = @()
if ($env:USERPROFILE) { $dirs += (Join-Path $env:USERPROFILE 'Downloads') }
$dirs += 'E:\Users\*\Downloads'
$dirs += 'C:\Users\*\Downloads'
$dirs += 'D:\Users\*\Downloads'

New-Item -ItemType Directory -Force -Path '.\sources' | Out-Null

$fail = 0
$copied = @()
foreach ($n in $names) {
    $found = $null
    foreach ($d in $dirs) {
        try {
            $hit = Get-ChildItem -Path (Join-Path $d $n) -File -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($hit) { $found = $hit; break }
        } catch {}
    }
    if (-not $found) {
        Write-Output ('[FAIL] not found in any Downloads folder: ' + $n)
        Write-Output ('       searched: ' + ($dirs -join ' ; '))
        $fail = 1
        continue
    }
    $dstPath = Join-Path '.\sources' $n
    Copy-Item -LiteralPath $found.FullName -Destination $dstPath -Force
    $dst = Get-Item -LiteralPath $dstPath
    $h = (Get-FileHash -LiteralPath $dst.FullName -Algorithm SHA256).Hash.ToLower()
    Write-Output ('== uploaded ' + $n + ' bytes=' + $dst.Length + ' sha256=' + $h)
    $copied += ('sources/' + $n)
}

if ($copied.Count -gt 0) {
    # commit right here so the watcher's verdict push carries the PDFs even
    # when auto_push would skip them; push itself is left to the watcher
    try {
        git add -- $copied 2>&1 | Out-String | Write-Output
        $st = (git status --porcelain -- $copied | Out-String).Trim()
        if ($st) {
            git commit -m ('local: upload source PDFs for docx conversion (r238)') -- $copied 2>&1 |
                Out-String | Write-Output
        } else {
            Write-Output '== sources already committed (no change)'
        }
    } catch {
        Write-Output ('[WARN] git add/commit failed: ' + $_.Exception.Message)
    }
}

if ($fail -ne 0) { exit 1 }
Write-Output ('== t189 done: ' + $copied.Count + ' PDF(s) staged for the agent')
exit 0
