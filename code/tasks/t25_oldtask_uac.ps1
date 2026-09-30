# t25_oldtask_uac.ps1 - round 40 task: remove the one stale watcher task
# that needs admin (git-sync-watch-git-pull-arena, no suffix, from an old
# session's clone E:\0github\git-sync\git-pull-arena) via a UAC prompt, and
# verify the pagefile setting that was applied in round 38.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t25: remove old watcher task (UAC) + verify pagefile ---'

$oldTask = 'git-sync-watch-git-pull-arena'
$keepTask = 'git-sync-watch-git-pull-arena-01a0a9f0'
$resultFile = 'E:\oldtask_result.txt'
if (Test-Path -LiteralPath $resultFile) { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue }

# ------------------------------------------------ the elevated helper
$helper = 'E:\oldtask_remove_admin.ps1'
$body = @'
# elevated: removes the stale git-sync watcher task + records the pagefile state
$ErrorActionPreference = 'Continue'
$out = @()
try {
    $t = Get-ScheduledTask -TaskName 'git-sync-watch-git-pull-arena' -ErrorAction SilentlyContinue
    if ($t) {
        if ($t.State -eq 'Running') { Stop-ScheduledTask -TaskName 'git-sync-watch-git-pull-arena' -ErrorAction SilentlyContinue }
        Unregister-ScheduledTask -TaskName 'git-sync-watch-git-pull-arena' -Confirm:$false -ErrorAction Stop
        $out += 'old task unregistered: OK'
    } else {
        $out += 'old task already gone'
    }
} catch { $out += ('old task: ' + $_.Exception.Message) }
try {
    $am = [string](Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile
    $out += ('automatic managed pagefile: ' + $am)
    $pf = @(Get-CimInstance Win32_PageFileSetting)
    foreach ($p in $pf) { $out += ('pagefile setting: ' + $p.Name + ' initial ' + $p.InitialSize + ' MB / max ' + $p.MaximumSize + ' MB') }
} catch { $out += ('pagefile read: ' + $_.Exception.Message) }
[System.IO.File]::WriteAllText('E:\oldtask_result.txt', ($out -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
'@
try {
    [System.IO.File]::WriteAllText($helper, $body, (New-Object System.Text.UTF8Encoding($true)))
    Write-Output ('   helper written: ' + $helper)
} catch {
    Write-Output ('   [FAIL] cannot write helper: ' + (San $_.Exception.Message))
    exit 2
}

# ------------------------------------------------------- pop the UAC
Write-Output '   popping the UAC dialog - CLICK YES on the screen ...'
$ok = $false
try {
    $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Window', 'Hidden', '-File', $helper) -PassThru
    $ok = $true
    Write-Output ('   elevated process started (pid ' + $p.Id + ')')
} catch {
    Write-Output ('   [WARN] elevation declined/failed: ' + (San $_.Exception.Message))
}

if ($ok) {
    # wait for the result file (up to 30s)
    $found = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 2
        if (Test-Path -LiteralPath $resultFile) { $found = $true; break }
    }
    if ($found) {
        Write-Output '   --- elevated result ---'
        foreach ($ln in @(Get-Content -LiteralPath $resultFile -ErrorAction SilentlyContinue)) { Write-Output ('   ' + (San ([string]$ln))) }
        Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Output '   [WARN] no result file - check the admin window for errors'
    }
    Remove-Item -LiteralPath $helper -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------- verify from outside
Write-Output '   --- verify (non-elevated) ---'
try {
    $left = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'git-sync-watch-*' })
    Write-Output ('   remaining git-sync tasks: ' + $left.Count)
    foreach ($t in $left) { Write-Output ('      ' + (San $t.TaskName) + ' [' + $t.State + ']') }
    $ours = @($left | Where-Object { $_.TaskName -eq $keepTask })
    if ($ours.Count -eq 1 -and $left.Count -eq 1) { Write-Output '   == PERFECT: only this session watcher remains' }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }
try {
    $am2 = [string](Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile
    Write-Output ('   automatic managed pagefile: ' + $am2 + ' (False = the 8-16 GB fixed size is set; reboot applies it)')
} catch { }
exit 0
