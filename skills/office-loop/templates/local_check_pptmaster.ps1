# office-loop section: PPT Master installed ON THIS MACHINE + a deck built BY it.
# Installed by skills/office-loop/agent-install.sh; byte-for-byte the code the
# user machine validated (rounds 29-32): real child process with a readable exit
# code, receipt needles 4b, real PowerPoint open 4c.
# --- office-loop: ppt-master section (sentinel) ---
# 4. PPT Master installed ON THIS MACHINE, and a deck produced BY this machine.
#    code\pptmaster_local.ps1 clones/creates the toolchain outside the repo
#    (default <parent>\ppt-master), runs the full pipeline here (author the 12
#    SVG pages from this repo -> svg_quality_checker -> svg_to_pptx), verifies
#    the pptx it produced and opens it read-only in the real PowerPoint, then
#    writes results\status\pptmaster_local.json / .txt - which the watcher
#    pushes back, so the agent can see what this machine actually did.
#    Run in a child process so its exit code is unambiguous and no console
#    window can flash.
$pptScript = Join-Path (Get-Location).Path 'code\pptmaster_local.ps1'
if (Test-Path -LiteralPath $pptScript) {
    Write-Output '== ppt-master: local install + local deck generation'
    $pptOut = Join-Path $env:TEMP ('pptmaster_out_' + (Get-Date -Format 'HHmmss') + '.log')
    $pptErr = Join-Path $env:TEMP ('pptmaster_err_' + (Get-Date -Format 'HHmmss') + '.log')
    # resolve a REAL powershell.exe: the bare name can hit a Store app-execution
    # alias ("%1 is not a valid Win32 application", round 25) - the same lesson
    # watch.ps1 learned, so the same preference order (pwsh > SysNative >
    # System32 > this process).
    $psExe = ''
    $me = ''
    try { $me = [string](Get-Process -Id $PID).Path } catch { $me = '' }
    if ($me -match 'pwsh\.exe$') {
        $psExe = $me
    } else {
        $is32 = $false
        try { $is32 = -not [Environment]::Is64BitProcess } catch { }
        if ($is32 -and $env:WINDIR) {
            $native = Join-Path $env:WINDIR 'SysNative\WindowsPowerShell\v1.0\powershell.exe'
            if (Test-Path -LiteralPath $native) { $psExe = $native }
        }
        if (-not $psExe -and $env:WINDIR) {
            $sys = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
            if (Test-Path -LiteralPath $sys) { $psExe = $sys }
        }
        if (-not $psExe -and $me -match 'powershell\.exe$') { $psExe = $me }
    }
    if (-not $psExe) { $psExe = 'powershell.exe' }
    Write-Output ('   .. 4a launcher: ' + $psExe)
    $pptCode = 124
    try {
        # The child is launched through the .NET Process class, not
        # Start-Process: on this machine Start-Process -PassThru combined with
        # -RedirectStandardOutput handed back a process object whose ExitCode
        # was $null, so round 29 reported "failed (exit )" for a child that had
        # verified the whole install (checker 0 blocking, 12 slides, PowerPoint
        # opened it, receipt clean). Never read an exit code through that path.
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $psExe
        $psi.Arguments = ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $pptScript + '"')
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WorkingDirectory = (Get-Location).Path
        $child = New-Object System.Diagnostics.Process
        $child.StartInfo = $psi
        $null = $child.Start()
        # drain both pipes as raw bytes while the child runs - reading them one
        # after the other would deadlock once the second buffer fills, and
        # decoding here would have to guess between the GBK console text and
        # the UTF-8 file text the child mixes
        $outBuf = New-Object System.IO.MemoryStream
        $errBuf = New-Object System.IO.MemoryStream
        $outCopy = $child.StandardOutput.BaseStream.CopyToAsync($outBuf)
        $errCopy = $child.StandardError.BaseStream.CopyToAsync($errBuf)
        # 20 minutes: below the watcher's 30 minute hard cap, so a stall here
        # still produces a verdict instead of a TIMEOUT with no detail
        if (-not $child.WaitForExit(1200000)) {
            try { $child.Kill() } catch { }
            Write-Output '   FAIL 4a pptmaster_local.ps1 did not finish in 20 minutes'
            $fail = 1
        } else {
            $child.WaitForExit()
            $null = $outCopy.Wait(60000)
            $null = $errCopy.Wait(60000)
            [System.IO.File]::WriteAllBytes($pptOut, $outBuf.ToArray())
            [System.IO.File]::WriteAllBytes($pptErr, $errBuf.ToArray())
            $pptCode = [int]$child.ExitCode
        }
    } catch {
        # last resort: run it in this process (no exit code, so 4b/4c carry the
        # verdict from the receipt instead)
        Write-Output ('   WARN 4a could not start a child powershell (' + $_.Exception.Message + ') - running it in-process')
        try {
            & $pptScript *> $pptOut
            $pptCode = 0
        } catch {
            Write-Output ('   FAIL 4a pptmaster_local.ps1 threw: ' + $_.Exception.Message)
            $fail = 1
        }
    }
    foreach ($f in @($pptOut, $pptErr)) {
        if (Test-Path -LiteralPath $f) {
            $body = ([System.IO.File]::ReadAllText($f)).TrimEnd()
            if ($body) { Write-Output $body }
        }
    }
    if ($pptCode -eq 0) {
        Write-Output '   OK   4a ppt-master installed + verified on this machine (exit 0)'
    } elseif ($pptCode -eq 126) {
        Write-Output '   WARN 4a child exit code could not be read - 4b/4c judged the receipt'
    } elseif ($pptCode -ne 124) {
        Write-Output ('   FAIL 4a ppt-master local install/verification failed (exit ' + $pptCode + ')')
        $fail = 1
    }

    # 4b/4c read the receipt, so the verdict names exactly which claim failed
    $recTxt = '.\results\status\pptmaster_local.txt'
    if (Test-Path -LiteralPath $recTxt) {
        $rec = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $recTxt).Path)
        # environment=windows matters: without it a receipt committed by the
        # agent's sandbox would be read as if THIS machine had verified it
        foreach ($needle in @('environment=windows', 'deck_slides=12', 'checker_blocking=0', 'markers=ok')) {
            if ($rec.Contains($needle)) {
                Write-Output ('   OK   4b receipt: ' + $needle)
            } else {
                Write-Output ('   FAIL 4b receipt is missing ' + $needle)
                $fail = 1
            }
        }
        if ($rec.Contains('powerpoint=yes')) {
            Write-Output '   OK   4c real PowerPoint opened the deck this machine generated'
        } elseif ($rec.Contains('powerpoint=na')) {
            Write-Output '   WARN 4c PowerPoint COM unavailable - counted as SKIP (structural checks stand)'
        } else {
            Write-Output '   FAIL 4c PowerPoint refused the deck this machine generated'
            $fail = 1
        }
    } else {
        Write-Output '[FAIL] 4b results\status\pptmaster_local.txt was never written'
        $fail = 1
    }
} else {
    Write-Output '[WARN] 4. code\pptmaster_local.ps1 is missing - local ppt-master install not verified'
}


#    2d. v2.7.0 hands-free helpers must be in watch.ps1 (on disk after sync;
#        the running loop still needs a re-register to USE them).
$watchSrc = '.\watch.ps1'
if (Test-Path -LiteralPath $watchSrc) {
    $wt = Get-Content -LiteralPath $watchSrc -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($wt -and $wt.Contains('function Invoke-AutoPull') -and $wt.Contains('function Invoke-AutoPush')) {
        Write-Output '== accept 2d: hands-free auto_pull/auto_push present in watch.ps1'
    } else {
        Write-Output '[FAIL] accept 2d: watch.ps1 is missing Invoke-AutoPull / Invoke-AutoPush (upgrade the skill)'
        $fail = 1
    }
} else {
    Write-Output '[FAIL] accept 2d: watch.ps1 missing'
    $fail = 1
}
