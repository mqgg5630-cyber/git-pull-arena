# t220_loop_smoke_r268.ps1 - round 268: hands-free loop smoke test.
#
# The user asked for: connect with the local machine, then auto pull ->
# execute code -> push the local results back, polling until it succeeds.
# This task runs ON THE REAL MACHINE only because the watcher auto-pulled
# the round-268 request, and its receipt rides the watcher auto_push back:
#
#   1. auto pull  : verify the worktree is on the session branch and HEAD
#                   equals origin/<branch> (the pull that carried this task)
#   2. execute    : run real code here - arithmetic with a known answer,
#                   a SHA256 over code/tasks/manifest.json, and a manifest
#                   self-mapping check
#   3. push back  : write results/mcp_agv_lab/R268_LOOP_POLL_SMOKE.md and
#                   r268-loop-poll-smoke.json; the watcher commits them with
#                   the round verdict right after this script exits
#
# ASCII only (Windows PowerShell 5.1 reads .ps1 as ANSI/GBK).
# Exit 0 = smoke passed, anything else fails the round.

$ErrorActionPreference = 'Continue'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

$round  = 268
$branch = 'arena/01a10bf3-git-pull-arena'
$fail   = 0
$startUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')

Write-Output ('== t220 loop smoke r' + $round + ' on ' + $env:COMPUTERNAME + ' (user ' + $env:USERNAME + '), start ' + $startUtc + ' UTC')

# ---- 1. auto pull -----------------------------------------------------------
$headBranch = ((& git rev-parse --abbrev-ref HEAD 2>$null) | Out-String).Trim()
$headSha    = ((& git rev-parse HEAD 2>$null) | Out-String).Trim()
$originSha  = ((& git rev-parse ('origin/' + $branch) 2>$null) | Out-String).Trim()
$branchOk = ($headBranch -eq $branch)
$headOk   = ($headSha -ne '' -and $originSha -ne '' -and $headSha -eq $originSha)
Write-Output ('   auto_pull_branch_ok=' + $branchOk + ' (HEAD on ' + $headBranch + ')')
Write-Output ('   auto_pull_head_ok=' + $headOk + ' (HEAD ' + $headSha + ' = origin ' + $originSha + ')')
if (-not $branchOk) { Write-Output '   [FAIL] worktree is not on the session branch'; $fail = 1 }
if (-not $headOk)   { Write-Output '   [FAIL] HEAD does not match origin/<branch> - the auto pull did not align'; $fail = 1 }

# ---- 2. execute -------------------------------------------------------------
$calc = (2 + 3) * 17
$calcOk = ($calc -eq 85)
$manifestRel = 'code\tasks\manifest.json'
$manSha = ''
$manBytes = 0
$selfMapped = $false
if (Test-Path -LiteralPath $manifestRel) {
    $manBytes = [int64](Get-Item -LiteralPath $manifestRel).Length
    $manSha = (Get-FileHash -LiteralPath $manifestRel -Algorithm SHA256).Hash.ToLowerInvariant()
    try {
        $tman = Get-Content -LiteralPath $manifestRel -Raw -Encoding UTF8 | ConvertFrom-Json
        $mapped = @($tman.rounds."$round")
        $selfMapped = ($mapped -contains 't220_loop_smoke_r268.ps1')
    } catch { $selfMapped = $false }
}
$codeOk = ($calcOk -and ($manSha -ne '') -and ($manBytes -gt 0) -and $selfMapped)
Write-Output ('   code_exec_ok=' + $codeOk + ' ((2+3)*17=' + $calc + '; manifest ' + $manBytes + ' B, sha256 ' + $manSha + ')')
Write-Output ('   self_mapped_ok=' + $selfMapped + ' (manifest maps r' + $round + ' to this task)')
if (-not $codeOk) { Write-Output '   [FAIL] code execution checks did not all hold'; $fail = 1 }

# ---- 3. receipt -------------------------------------------------------------
$endUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
$smokeOk = ($fail -eq 0)
$dirRel = 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $dirRel | Out-Null
$mdRel = Join-Path $dirRel 'R268_LOOP_POLL_SMOKE.md'
$jsonRel = Join-Path $dirRel 'r268-loop-poll-smoke.json'

$md = @(
    '# R268 - hands-free loop smoke test (auto pull -> execute -> push back)',
    '',
    ('- round: ' + $round),
    ('- branch: ' + $branch),
    ('- host: ' + $env:COMPUTERNAME + ' (user ' + $env:USERNAME + ')'),
    ('- started_utc: ' + $startUtc),
    ('- finished_utc: ' + $endUtc),
    '',
    '## 1. auto pull (the watcher pulled the round-268 request before this code ran)',
    ('- auto_pull_branch_ok=' + $branchOk),
    ('- auto_pull_head_ok=' + $headOk),
    ('- head_sha=' + $headSha),
    ('- origin_sha=' + $originSha),
    '',
    '## 2. execute (real code ran on the real machine)',
    ('- code_exec_ok=' + $codeOk),
    ('- calc_result=' + $calc),
    ('- manifest_sha256=' + $manSha),
    ('- manifest_bytes=' + $manBytes),
    ('- self_mapped_ok=' + $selfMapped),
    '',
    '## 3. push back (this receipt rides the watcher auto_push with the verdict)',
    '- receipt_written=True',
    '- receipt_md=R268_LOOP_POLL_SMOKE.md',
    '- receipt_json=r268-loop-poll-smoke.json',
    '',
    '## verdict',
    ('- loop_smoke_ok=' + $smokeOk)
)
$md | Set-Content -LiteralPath $mdRel -Encoding Ascii

$j = [ordered]@{
    round = $round
    branch = $branch
    host = $env:COMPUTERNAME
    user = $env:USERNAME
    started_utc = $startUtc
    finished_utc = $endUtc
    auto_pull_branch_ok = $branchOk
    auto_pull_head_ok = $headOk
    head_sha = $headSha
    origin_sha = $originSha
    code_exec_ok = $codeOk
    calc_result = $calc
    manifest_sha256 = $manSha
    manifest_bytes = $manBytes
    self_mapped_ok = $selfMapped
    receipt_written = $true
    loop_smoke_ok = $smokeOk
}
($j | ConvertTo-Json) | Set-Content -LiteralPath $jsonRel -Encoding Ascii

Write-Output ('   receipt_written=True (' + $mdRel + ' + ' + $jsonRel + ')')

if ($smokeOk) {
    Write-Output ('== t220 loop smoke r' + $round + ' ok - auto pull proven, code executed, receipt ready for auto_push')
    exit 0
}
Write-Output ('== t220 loop smoke r' + $round + ' FAILED - see the False markers above')
exit 1
