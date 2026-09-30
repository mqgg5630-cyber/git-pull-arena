# t48_run.ps1 - round 59 task: deep recon of English.docx citations + Zotero
# library matching + 0mcp-agv verifier peek. Runs the two python helpers
# (code/tasks/t48_*.py, shipped via git) READ-ONLY.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t48: English.docx citations + Zotero match (READ-ONLY) ---'

$envPYTHONIOENCODING = 'utf-8'

# 1. citation-run analysis
Write-Output '--- 1. python: english_citations ---'
$j = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot\..\..
    $env:PYTHONIOENCODING = 'utf-8'
    python code\tasks\t48_english_citations.py 2>&1 | Out-String
}
if (Wait-Job $j -Timeout 120) {
    foreach ($l in @((Receive-Job $j | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   [TIMEOUT] english_citations' }
Remove-Job $j -Force -ErrorAction SilentlyContinue

# 2. Zotero library match
Write-Output '--- 2. python: zotero match ---'
$j2 = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot\..\..
    $env:PYTHONIOENCODING = 'utf-8'
    python code\tasks\t48_zotero_match.py 2>&1 | Out-String
}
if (Wait-Job $j2 -Timeout 120) {
    foreach ($l in @((Receive-Job $j2 | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   [TIMEOUT] zotero match' }
Remove-Job $j2 -Force -ErrorAction SilentlyContinue

# 3. zotero styles dir
Write-Output '--- 3. installed zotero styles ---'
try {
    foreach ($s in @(Get-ChildItem -LiteralPath 'E:\ozotero\styles' -Filter '*.csl' -ErrorAction Stop | Select-Object -First 20)) { Write-Output ('   STYLE ' + (San ([string]$s.Name))) }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# 4. peek at the 0mcp-agv verifier
Write-Output '--- 4. head of verify_english_review_docx.py ---'
try {
    $ln = 0
    foreach ($l in @(Get-Content -LiteralPath 'E:\0mcp-agv\scripts\verify_english_review_docx.py' -TotalCount 40 -ErrorAction Stop)) {
        $ln++
        Write-Output ('     ' + (San ([string]$l)))
        if ($ln -ge 25) { break }
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# 5. is Word holding the file open?
Write-Output '--- 5. file locks ---'
try {
    $fs = [System.IO.File]::Open('E:\0writing\Light-skills\projects\English.docx', 'Open', 'Read', 'None')
    $fs.Close()
    Write-Output '   English.docx: not locked (safe to modify)'
} catch { Write-Output ('   [WARN] English.docx locked: ' + (San $_.Exception.Message)) }
exit 0
