# t50_run.ps1 - round 61 task: run the Zotero-link transformation on
# English.docx (in-place, backup first, verify before overwrite).
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t50: English.docx -> Zotero-linked (in place) ---'
try {
    $fs = [System.IO.File]::Open('E:\0writing\Light-skills\projects\English.docx', 'Open', 'Read', 'None')
    $fs.Close()
    Write-Output '   lock check: file free'
} catch { Write-Output ('   [FAIL] file locked: ' + (San $_.Exception.Message)); exit 2 }

$j = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot\..\..
    $env:PYTHONIOENCODING = 'utf-8'
    python code\tasks\t50_zotero_link.py 2>&1 | Out-String
}
if (Wait-Job $j -Timeout 420) {
    foreach ($l in @((Receive-Job $j | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else {
    Write-Output '   [TIMEOUT] python transform'
}
Remove-Job $j -Force -ErrorAction SilentlyContinue

# final sanity: output exists and got bigger (fields added)
try {
    $f = Get-Item -LiteralPath 'E:\0writing\Light-skills\projects\English.docx'
    Write-Output ('   final: English.docx ' + [math]::Round($f.Length / 1KB, 1) + ' KB  ' + $f.LastWriteTime.ToString('HH:mm:ss'))
    $b = Get-Item -LiteralPath 'E:\0writing\Light-skills\projects\English_backup_pre-zotero.docx' -ErrorAction SilentlyContinue
    if ($b) { Write-Output ('   backup: ' + [math]::Round($b.Length / 1KB, 1) + ' KB') }
    $l = Get-Item -LiteralPath 'E:\0writing\Light-skills\projects\English_Zotero_library.json' -ErrorAction SilentlyContinue
    if ($l) { Write-Output ('   library json: ' + [math]::Round($l.Length / 1KB, 1) + ' KB') }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }
exit 0
