# local_check.ps1 (git-pull-arena) - this repo's checks, run on the real
# machine when the agent requests one. watch.ps1 executes this whenever the agent requests a check
# (config key check_cmd), captures all output to
# results\status\check_rN_<stamp>.log and pushes the verdict back.
#
# Exit 0 = passed, anything else = failed. Edit freely - this file belongs to
# the repo, the installer only creates it when it is missing.
#
# Ideas for real checks (pick what fits the repo):
#   - deliverable files exist and have sane sizes
#   - open an Office file via COM to prove it is not corrupt
#   - python -c "import torch; assert torch.cuda.is_available()"  (GPU smoke test)
#   - run a script from code\ and compare its output
#
# ASCII-only on purpose (Windows PowerShell 5.1 decodes .ps1 as ANSI/GBK).

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')   # repo root (this file lives in code\)

$fail = 0

# 1. the standard gate (.ps1 ASCII + branch guard + script consistency)
#    (forward slashes on purpose: this also runs under the scheduled task,
#     where bash may eat backslashes; Write-Output on purpose: the watcher
#     captures stdout, and PS 5.1 Write-Host bypasses it)
if (Test-Path -LiteralPath '.\code\check_all.sh') {
    if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-Output '[FAIL] bash is not on PATH - the gate cannot run (install Git for Windows)'
        $fail = 1
    } else {
        $gateOut = bash code/check_all.sh 2>&1
        $gateCode = $LASTEXITCODE
        if ($gateOut) { Write-Output $gateOut }
        if ($gateCode -ne 0) {
            Write-Output ('[FAIL] gate failed (exit ' + $gateCode + ')')
            $fail = 1
        } elseif (-not $gateOut) {
            # a command that produces NOTHING must not be trusted as a pass
            Write-Output '[FAIL] gate produced no output - not trusting that pass'
            $fail = 1
        }
    }
}

# 1b. the two hard requirements are asserted strictly in section 2 (2a/2b) -
#     they fail the round on purpose, because "push needs a click" and
#     "watcher flashes a window" are exactly what v2.5.0 had to fix.

# 2. v2.5.0 acceptance: the two hard requirements, asserted ON THIS MACHINE.
#    (Write-Output, not Write-Host: the watcher captures stdout only.)
#    2a. silent push - git must get a credential with ALL prompts disabled
if (Test-Path -LiteralPath '.\auth.ps1') {
    try {
        $auth = ((& .\auth.ps1 -Json -Verify) | Out-String) | ConvertFrom-Json
        if ($auth.push_dry_run -eq 'passed' -and $auth.lsremote -eq 'passed') {
            Write-Output '== accept 2a: silent push PROVEN (ls-remote + push --dry-run, prompts disabled)'
        } else {
            Write-Output ("[FAIL] accept 2a: silent push NOT proven (lsremote=" + $auth.lsremote + " push_dry_run=" + $auth.push_dry_run + ")")
            Write-Output ("       detail: " + $auth.push_dry_run_detail)
            Write-Output '       fix once with:  .\auth.ps1 -Setup  then  .\auth.ps1 -Verify'
            $fail = 1
        }
    } catch {
        Write-Output '[FAIL] accept 2a: auth.ps1 probe failed (run .\auth.ps1 by hand to see why)'
        $fail = 1
    }
} else {
    Write-Output '[FAIL] accept 2a: auth.ps1 is missing (upgrade the skill)'
    $fail = 1
}

#    2b. zero-window watcher - the scheduled task must start the launcher exe,
#        not powershell.exe (which always flashes a console window first)
$taskName = 'git-sync-watch-' + (Split-Path -Leaf (Get-Location).Path)
try {
    $t = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $exec = [string]$t.Actions[0].Execute
    $logon = [string]$t.Principal.LogonType
    if ($exec -match 'watchhost' -or $logon -eq 'S4U' -or $logon -eq 'Password') {
        Write-Output ("== accept 2b: watcher is windowless (action: " + $exec + ")")
    } else {
        Write-Output ("[FAIL] accept 2b: watcher action is not the zero-window launcher: " + $exec)
        Write-Output '       fix with:  .\watch.ps1 -Unregister  then  .\watch.ps1 -Register'
        $fail = 1
    }
} catch {
    Write-Output ("[FAIL] accept 2b: scheduled task '" + $taskName + "' not found - run .\watch.ps1 -Register")
    $fail = 1
}

# 3. example: the deliverable must exist and not be empty
# if (-not (Test-Path '.\deliverable\final.pptx')) {
#     Write-Host '[FAIL] deliverable\final.pptx missing' -ForegroundColor Red; $fail = 1
# }

# 4. add your own checks here ...

if ($fail -eq 0) { Write-Output '== local checks passed' }
exit $fail
