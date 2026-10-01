# t91_desk_fig1b.ps1 - round 124 task: run the FIXTURE test job for BOTH
# skills on the desktop (fig1desk scheduled task -> desktop_worker.ps1 in
# the interactive session): write JOB.marker via F$, schtasks /run, poll
# DONE/FAILED markers, dump log + probe result. Quote-free ssh commands.
# ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t91: desktop fig1 full demo (cell_su7) ---'

$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$deskRoot = $fshare + '\fig1_rebuild'

function Invoke-SshCapped([string]$remoteCmd, [int]$capSec) {
    $job = Start-Job -ScriptBlock {
        param($o, $t, $c)
        $x = (& ssh @o ($t + '@' + $c[0]) $c[1] 2>&1 | Out-String).Trim()
        $x + "`nREMOTE_EXIT=$LASTEXITCODE"
    } -ArgumentList $sshBase, $duser, @($desktop, $remoteCmd)
    if (Wait-Job $job -Timeout $capSec) {
        $out = (Receive-Job $job | Out-String).Trim()
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return $out
    }
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return '__TIMEOUT__'
}
function Show([string]$tag, [string]$out) {
    if ($out -eq '__TIMEOUT__') { L ('   ' + $tag + ': __TIMEOUT__'); return }
    foreach ($ln in ($out -split "`r?`n")) { $x = San $ln; if ($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +') { L ('   ' + $tag + '| ' + $x) } }
}

$failCount = 0
foreach ($skill in @('cell_su7')) {
    L ('=== fixture job: ' + $skill + ' ===')
    # 1. reset markers + write JOB.marker via share
    $netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
    foreach ($m in @('DONE.marker', 'FAILED.marker', 'probe.result')) { Remove-Item -LiteralPath (Join-Path $deskRoot $m) -Force -ErrorAction SilentlyContinue }
    [IO.File]::WriteAllText((Join-Path $deskRoot 'JOB.marker'), ('fig1|' + $skill), (New-Object System.Text.UTF8Encoding($false)))
    & net use $fshare /delete 2>&1 | Out-Null
    L '   JOB.marker written (fig1)'
    # 2. run the task
    $out = Invoke-SshCapped 'schtasks /run /tn fig1desk' 60
    if ($out -notmatch 'REMOTE_EXIT=0') { L ('   [FAIL] schtasks run: ' + (San $out)); $failCount++; continue }
    L '   fig1desk task started'
    # 3. poll markers (6 min)
    $verdict = $null
    $deadline = [DateTime]::UtcNow.AddMinutes(16)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Seconds 20
        $o = Invoke-SshCapped 'type F:\fig1_rebuild\DONE.marker' 30
        if ($o -match 'DESKTOP_DONE') { $verdict = 'DONE'; break }
        $o = Invoke-SshCapped 'type F:\fig1_rebuild\FAILED.marker' 30
        if ($o -match 'DESKTOP_FAILED') { $verdict = 'FAILED'; break }
    }
    if ($verdict -eq 'DONE') { L ('   JOB DONE (' + $skill + ')') }
    elseif ($verdict -eq 'FAILED') { L ('   JOB FAILED (' + $skill + ')'); $failCount++ }
    else { L ('   JOB TIMEOUT (' + $skill + ')'); $failCount++ }
    # 4. dump log tail + probe
    $out = Invoke-SshCapped 'powershell -NoProfile -Command Get-Content F:\fig1_rebuild\rebuild.log -Tail 14' 45
    Show 'log' $out
    $out = Invoke-SshCapped 'type F:\fig1_rebuild\probe.result' 30
    Show 'probe' $out
    $out = Invoke-SshCapped 'powershell -NoProfile -Command Get-ChildItem F:\fig1_rebuild -Recurse -Filter *.png -Name' 45
    Show 'pngs' $out
}
L ('--- task t91 done (failures=' + $failCount + ') ---')
exit 0
