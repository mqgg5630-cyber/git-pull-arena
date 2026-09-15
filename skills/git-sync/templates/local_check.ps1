# local_check.ps1 (template) - the repo-specific checks that run on YOUR
# machine. watch.ps1 executes this whenever the agent requests a check
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
    bash code/check_all.sh
    if ($LASTEXITCODE -ne 0) { Write-Output '[FAIL] gate failed'; $fail = 1 }
}

# 1b. informational: can a push leave this machine with no window and no click?
#     This is what the watcher needs to push the verdict back (soft check - it
#     never fails the round, it just tells you to run .\auth.ps1 -Setup once).
if (Test-Path -LiteralPath '.\auth.ps1') {
    try {
        $authJson = (& .\auth.ps1 -Json | Out-String)
        $authObj = $authJson | ConvertFrom-Json
        if ($authObj.ready) {
            Write-Output '== auth: silent push ready (no prompt, no window)'
        } else {
            Write-Output '== auth: NOT ready - run .\auth.ps1 -Setup once, then .\auth.ps1 -Verify'
            Write-Output ('   probe said: ' + $authObj.credential_detail)
        }
    } catch {
        Write-Output '== auth: probe failed (soft warning only)'
    }
}

# 2. example: the deliverable must exist and not be empty
# if (-not (Test-Path '.\deliverable\final.pptx')) {
#     Write-Host '[FAIL] deliverable\final.pptx missing' -ForegroundColor Red; $fail = 1
# }

# 3. add your own checks here ...

if ($fail -eq 0) { Write-Output '== local checks passed' }
exit $fail
