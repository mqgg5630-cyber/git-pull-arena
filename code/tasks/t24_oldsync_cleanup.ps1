# t24_oldsync_cleanup.ps1 - round 39 task: remove STALE git-sync watcher
# scheduled tasks left over from earlier sessions. The round-38 review
# found 9 of them besides ours (git-sync-watch-git-pull-arena-01a0a9f0):
# 8 disabled ones and one still-RUNNING old task (git-sync-watch-git-pull-
# arena, no suffix) that can steal handshake rounds. This task keeps ONLY
# ours; each removal is reported (and the old running task's process is
# stopped). The clones' folders on disk are NOT touched.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t24: stale git-sync watcher cleanup ---'
$keep = 'git-sync-watch-git-pull-arena-01a0a9f0'

$tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'git-sync-watch-*' })
Write-Output ('   git-sync tasks found: ' + $tasks.Count + ' (keeping: ' + $keep + ')')

foreach ($t in $tasks) {
    if ($t.TaskName -eq $keep) {
        Write-Output ('   KEEP  ' + (San $t.TaskName) + ' [' + $t.State + '] - this session')
        continue
    }
    # capture what the old task pointed at (audit trail) before removing
    $exe = ''
    $arg = ''
    try { $exe = [string]$t.Actions[0].Execute; $arg = [string]$t.Actions[0].Arguments } catch { }
    Write-Output ('   REMOVE ' + (San $t.TaskName) + ' [' + $t.State + ']')
    Write-Output ('      was: ' + (San $exe) + ' ' + (San $arg))
    try {
        # stop a still-running instance first (it may hold a lock on its clone)
        if ($t.State -eq 'Running') {
            try { Stop-ScheduledTask -TaskName $t.TaskName -ErrorAction Stop; Write-Output '      stopped the running instance' } catch { Write-Output ('      [WARN] stop: ' + (San $_.Exception.Message)) }
        }
        Unregister-ScheduledTask -TaskName $t.TaskName -Confirm:$false -ErrorAction Stop
        Write-Output '      unregistered OK'
    } catch {
        Write-Output ('      [WARN] ' + (San $_.Exception.Message))
        Write-Output '      (admin may be needed for this one - it will be listed for manual removal)'
    }
}

# final state
$left = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'git-sync-watch-*' })
Write-Output ('   remaining git-sync tasks: ' + $left.Count)
foreach ($t in $left) { Write-Output ('      ' + (San $t.TaskName) + ' [' + $t.State + ']') }
exit 0
