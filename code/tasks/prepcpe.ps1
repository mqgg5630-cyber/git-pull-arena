# prepcpe.ps1 (v2) - runs ON THE DESKTOP in the INTERACTIVE session
# (called by the integrun cmd before integration.py). Puts PowerPoint
# into a known clean, DIALOG-FREE, WARM state before each attempt:
#   1. clear Office crash-recovery state (Resiliency key + AutoRecover
#      files) left by the r168/r169 force kills,
#   2. if POWERPNT is running: close its presentations (Saved=true) and
#      Quit GRACEFULLY (force kill only as a last resort, then clean the
#      crash state again),
#   3. prewarm (Prewarm=1): launch PowerPoint VISIBLE - the unactivated
#      Office (ospp: NOTIFICATIONS) shows an activation/first-run
#      NUIDialog on every launch, and the watcher closes it - then LEAVE
#      POWERPOINT RUNNING. integration.py attaches to this warm,
#      dialog-free instance via GetActiveObject, so no new launch and no
#      new activation dialog happens mid-test. PowerPoint survives client
#      exit (r168 proved it), and the final cleanup task quits it.
# Usage: powershell -File prepcpe.ps1 <tag> <prewarm 0|1>
# Output (PREP: lines) is appended to the attempt log by the caller.
# ASCII-only.

param([string]$Tag = 'a1', [int]$Prewarm = 0)

$ErrorActionPreference = 'Continue'

function ResClean {
    try { Remove-Item -Path 'HKCU:\Software\Microsoft\Office\16.0\PowerPoint\Resiliency' -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    try {
        New-Item -Path 'HKCU:\Software\Microsoft\Office\16.0\Common\General' -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Office\16.0\Common\General' -Name 'ShownFirstRunOptin' -Value 1 -Type DWord -ErrorAction SilentlyContinue
    } catch { }
    $ardir = Join-Path $env:APPDATA 'Microsoft\PowerPoint'
    if (Test-Path -LiteralPath $ardir) {
        foreach ($f in @(Get-ChildItem -LiteralPath $ardir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'AutoRecovery*' -or $_.Name -like '~$*' })) {
            try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue } catch { }
            Write-Output ('PREP: removed recovery file ' + $f.Name)
        }
    }
}

function ESan([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }

Write-Output ('PREP[' + $Tag + '] start prewarm=' + $Prewarm)
ResClean
Write-Output 'PREP: resiliency + first-run state cleared'

$running = @(Get-Process -Name POWERPNT -ErrorAction SilentlyContinue)
Write-Output ('PREP: powerpnt running=' + $running.Count)
if ($running.Count -gt 0) {
    $quitOk = $false
    try {
        $app = [System.Runtime.InteropServices.Marshal]::GetActiveObject('PowerPoint.Application')
        $cnt = -1
        try { $cnt = $app.Presentations.Count } catch { }
        Write-Output ('PREP: active object ok, presentations=' + $cnt)
        $guard = 0
        while ($guard -lt 12) {
            $c = -1
            try { $c = $app.Presentations.Count } catch { }
            if ($c -le 0) { break }
            try { $app.Presentations.Item(1).Saved = $true } catch { }
            try { $app.Presentations.Item(1).Close() } catch { }
            $guard++
            Start-Sleep -Milliseconds 500
        }
        try { $app.Quit() } catch { }
        Write-Output 'PREP: graceful quit issued'
        $quitOk = $true
    }
    catch { Write-Output ('PREP: graceful quit failed: ' + (ESan $_.Exception.Message)) }
    Start-Sleep -Seconds 6
    $still = @(Get-Process -Name POWERPNT -ErrorAction SilentlyContinue)
    if ($still.Count -gt 0) {
        Write-Output 'PREP: still running, force kill + clean crash state'
        try { & taskkill /f /im POWERPNT.EXE 2>&1 | Out-Null } catch { }
        Start-Sleep -Seconds 4
        ResClean
    }
    else { if ($quitOk) { Write-Output 'PREP: powerpnt exited cleanly' } }
}

if ($Prewarm -eq 1) {
    try {
        Write-Output 'PREP: prewarm launch VISIBLE (watcher closes activation dialogs; left RUNNING for attach)'
        $app2 = New-Object -ComObject PowerPoint.Application
        try { $app2.Visible = -1 } catch { }
        Start-Sleep -Seconds 15
        $st = @(Get-Process -Name POWERPNT -ErrorAction SilentlyContinue)
        Write-Output ('PREP: prewarm done, powerpnt running=' + $st.Count + ' (left warm)')
    }
    catch { Write-Output ('PREP: prewarm failed: ' + (ESan $_.Exception.Message)) }
}
Write-Output ('PREP[' + $Tag + '] done')
