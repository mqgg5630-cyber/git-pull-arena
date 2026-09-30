# t42_fix_desktop_and_rdetail.ps1 - round 52 task: (1) patch the n8n
# section of the report copy on the user's Desktop (round 51 report had a
# misleading "engine RUNNING" line from a detection bug), (2) probe R
# inside WSL Ubuntu-24.04 in detail (versions/paths/conda envs) so the
# user can decide which old R versions to remove (WSL itself untouched).
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t42: patch desktop report n8n section + WSL R detail ---'

# -------------------------------------------- 1. desktop report patch
$desk = [Environment]::GetFolderPath('Desktop')
$name = [string]([char]0x4EFB + [char]0x52A1 + [char]0x573A + [char]0x666F + [char]0x4E0E + [char]0x5927 + [char]0x6587 + [char]0x4EF6 + [char]0x6E05 + [char]0x5355 + '_2026-09-30.md')
$deskFile = Join-Path $desk $name
if (Test-Path -LiteralPath $deskFile) {
    try {
        $raw = [System.IO.File]::ReadAllText($deskFile, [System.Text.Encoding]::UTF8)
        $startMark = '- Docker engine RUNNING. Containers:'
        $endMark = '- No n8n container currently running.'
        $i0 = $raw.IndexOf($startMark)
        $i1 = $raw.IndexOf($endMark)
        if ($i0 -ge 0 -and $i1 -gt $i0) {
            $endLen = $endMark.Length
            $replacement = '- Docker engine OFF (Docker Desktop not running) - n8n unreachable right now.' + "`r`n" + '- With the engine on: browser UI http://localhost:5678; the agent manages n8n via docker CLI (start/backup/API triggers).'
            $new = $raw.Substring(0, $i0) + $replacement + $raw.Substring($i1 + $endLen)
            [System.IO.File]::WriteAllText($deskFile, $new, (New-Object System.Text.UTF8Encoding($true)))
            Write-Output '   desktop report: n8n section CORRECTED'
        } elseif ($i0 -lt 0) {
            Write-Output '   desktop report: no misleading line found (already correct?)'
        } else {
            Write-Output '   [WARN] desktop report: end marker not found, left unchanged'
        }
    } catch { Write-Output ('   [WARN] desktop patch: ' + (San $_.Exception.Message)) }
} else {
    Write-Output ('   [WARN] desktop report not found: ' + (San $deskFile))
}

# -------------------------------------------- 2. WSL R detail probe
Write-Output '--- WSL Ubuntu-24.04 R detail ---'
$j = Start-Job -ScriptBlock {
    & wsl.exe -d Ubuntu-24.04 -- sh -c 'echo ==WHICH==; which R Rscript 2>/dev/null; echo ==VER==; R --version 2>/dev/null | head -2; echo ==DIRS==; ls -d /opt/R* /usr/lib/R /usr/local/lib/R $HOME/R 2>/dev/null; echo ==CONDA==; ls $HOME/miniconda3/envs $HOME/anaconda3/envs 2>/dev/null; conda env list 2>/dev/null; echo ==DPKG==; dpkg -l 2>/dev/null | grep -E "r-base-core|r-cran" | head -5; echo ==DONE==' 2>&1 | Out-String
}
$o = '__TIMEOUT__'
if (Wait-Job $j -Timeout 90) { $o = (Receive-Job $j | Out-String) }
Remove-Job $j -Force -ErrorAction SilentlyContinue
if ($o -eq '__TIMEOUT__') {
    Write-Output '   [WARN] WSL probe timed out'
} else {
    try {
        [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'results\status\r51_r_detail.md'), $o, (New-Object System.Text.UTF8Encoding($false)))
        Write-Output '   detail written: results/status/r51_r_detail.md'
    } catch { Write-Output ('   [WARN] detail file: ' + (San $_.Exception.Message)) }
    $lines = @($o -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 25)
    foreach ($l in $lines) { Write-Output ('   R?  ' + (San ([string]$l))) }
}
exit 0
