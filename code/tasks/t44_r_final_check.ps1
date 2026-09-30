# t44_r_final_check.ps1 - round 54 task: last R check on the Windows side
# (conda envs in E:\spider + any R/Rscript on PATH). READ-ONLY.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t44: Windows-side R final check ---'
try {
    foreach ($g in @(Get-Command R, Rscript -ErrorAction SilentlyContinue)) { Write-Output ('   PATH: ' + (San ([string]$g.Source))) }
} catch { }
Write-Output '   (no output above = R/Rscript not on PATH)'
try {
    $envs = 'E:\spider\envs'
    if (Test-Path -LiteralPath $envs) {
        foreach ($d in @(Get-ChildItem -LiteralPath $envs -Directory -ErrorAction SilentlyContinue)) { Write-Output ('   conda env: ' + (San ([string]$d.Name))) }
    } else { Write-Output '   E:\spider\envs does not exist' }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }
try {
    $j = Start-Job -ScriptBlock { conda env list 2>&1 | Out-String }
    if (Wait-Job $j -Timeout 40) {
        foreach ($l in @((Receive-Job $j | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
    } else { Write-Output '   conda env list: timeout' }
    Remove-Job $j -Force -ErrorAction SilentlyContinue
} catch { }
try {
    foreach ($root in @('E:\', 'D:\')) {
        foreach ($d in @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'rstudio|^r$|^R-' })) { Write-Output ('   dir hit: ' + (San ([string]$d.FullName))) }
    }
    Write-Output '   (no dir hits = no R/RStudio folders)'
} catch { }
exit 0
