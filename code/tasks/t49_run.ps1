# t49_run.ps1 - round 60 task: dump English.docx reference-list format and
# reverse-match entries against the Zotero library. READ-ONLY.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t49: refs format dump + reverse zotero match (READ-ONLY) ---'
$j = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot\..\..
    $env:PYTHONIOENCODING = 'utf-8'
    python code\tasks\t49_dump_refs.py 2>&1 | Out-String
}
if (Wait-Job $j -Timeout 150) {
    foreach ($l in @((Receive-Job $j | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   [TIMEOUT]' }
Remove-Job $j -Force -ErrorAction SilentlyContinue
exit 0
