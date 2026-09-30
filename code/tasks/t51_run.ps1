# t51_run.ps1 - round 62 task: verify (and if needed repair) the
# Zotero-linked English.docx. Windows PowerShell 5.1, ASCII-only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t51: verify / fix English.docx zotero fields ---'
$j = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot\..\..
    $env:PYTHONIOENCODING = 'utf-8'
    python code\tasks\t51_verify_fix.py 2>&1 | Out-String
}
if (Wait-Job $j -Timeout 420) {
    foreach ($l in @((Receive-Job $j | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   [TIMEOUT]' }
Remove-Job $j -Force -ErrorAction SilentlyContinue
try {
    $f = Get-Item -LiteralPath 'E:\0writing\Light-skills\projects\English.docx'
    Write-Output ('   final: ' + [math]::Round($f.Length / 1KB, 1) + ' KB  ' + $f.LastWriteTime.ToString('HH:mm:ss'))
} catch { }
exit 0
