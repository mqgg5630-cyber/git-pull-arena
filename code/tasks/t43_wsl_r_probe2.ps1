# t43_wsl_r_probe2.ps1 - round 53 task: run code/tasks/r_probe.sh INSIDE
# WSL Ubuntu-24.04; the script writes its own output file into the repo
# (all Linux-side, avoids the PowerShell wsl.exe output mojibake).
# READ-ONLY. Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t43: WSL R probe (linux-side output) ---'
$repo = (Get-Location).Path
if ($repo -notmatch '^[A-Z]:\\') { Write-Output ('   [FAIL] unexpected cwd: ' + (San $repo)); exit 2 }
$drive = $repo.Substring(0, 1).ToLowerInvariant()
$rest = $repo.Substring(2).Replace('\', '/')
$linuxRepo = '/mnt/' + $drive + $rest
$probe = $linuxRepo + '/code/tasks/r_probe.sh'
$outLinux = $linuxRepo + '/results/status/r_detail_wsl24.txt'

$j = Start-Job -ScriptBlock {
    param($d, $p, $o)
    & wsl.exe -d $d -- bash $p $o 2>&1 | Out-String
} -ArgumentList 'Ubuntu-24.04', $probe, $outLinux
$done = $false
if (Wait-Job $j -Timeout 150) { $done = $true }
$null = Receive-Job $j
Remove-Job $j -Force -ErrorAction SilentlyContinue

$outWin = Join-Path $repo 'results\status\r_detail_wsl24.txt'
if (Test-Path -LiteralPath $outWin) {
    Write-Output '   probe output written: results/status/r_detail_wsl24.txt'
    try {
        $txt = [System.IO.File]::ReadAllText($outWin, [System.Text.Encoding]::UTF8)
        foreach ($l in @($txt -split "`n" | Where-Object { $_ -match '\S' } | Select-Object -First 30)) { Write-Output ('   ' + (San ([string]$l.Trim()))) }
    } catch { Write-Output ('   [WARN] read: ' + (San $_.Exception.Message)) }
} else {
    Write-Output ('   [FAIL] no output file (job finished: ' + $done + ')')
}
exit 0
