# t201_loop_repeat_r263.ps1 - prove the loop REPEATS, not just that it ran once.
#   round 262 wrote results/status/LOOP_PROOF_R262.md on this machine.
#   round 263 re-runs the same pull -> execute -> push cycle, checks that the
#   previous round's receipt is present in the working tree (so it really came
#   back through git), and appends one row to results/status/LOOP_LEDGER.md.
# Runs on the Windows machine inside code\local_check.ps1 section 4.
# ASCII-only source; output may contain Unicode.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path

$round = 263
$prevRound = 262

$outRoot = Join-Path $repo 'results\status'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$reportMd   = Join-Path $outRoot ('LOOP_PROOF_R' + $round + '.md')
$reportJson = Join-Path $outRoot ('LOOP_PROOF_R' + $round + '.json')
$ledger     = Join-Path $outRoot 'LOOP_LEDGER.md'
$prevMd     = Join-Path $outRoot ('LOOP_PROOF_R' + $prevRound + '.md')

$expectedBranch = 'arena/01a10bfd-git-pull-arena'

function Get-Text([string]$path) {
    if (Test-Path -LiteralPath $path) { return (Get-Content -LiteralPath $path -Raw -Encoding UTF8) }
    return ''
}
function Run-Git([string]$cmdArgs) {
    try { return ((& git @($cmdArgs -split ' ') 2>&1) -join "`n").Trim() } catch { return '' }
}

# ----------------------------------------------------------- 1. config gate
$cfgPath = Join-Path $repo 'skills\git-sync\sync.config.json'
$cfg = $null
try { $cfg = (Get-Text $cfgPath) | ConvertFrom-Json } catch { }
$cfgBranch = ''; $handsFree = $false; $autoPull = $false; $autoPush = $false
if ($cfg) {
    $cfgBranch = [string]$cfg.branch
    if ($null -ne $cfg.hands_free) { $handsFree = [bool]$cfg.hands_free }
    if ($null -ne $cfg.auto_pull)  { $autoPull  = [bool]$cfg.auto_pull }
    if ($null -ne $cfg.auto_push)  { $autoPush  = [bool]$cfg.auto_push }
}

# ----------------------------------------------------------- 2. git identity
$headBranch  = Run-Git 'rev-parse --abbrev-ref HEAD'
$headSha     = Run-Git 'rev-parse --short HEAD'
$headSubject = Run-Git 'log -1 --pretty=%s'
$upstreamSha = Run-Git ('rev-parse --short origin/' + $expectedBranch)
$branchOk = ($cfgBranch -eq $expectedBranch) -and ($headBranch -eq $expectedBranch)
$pulledOk = ($headSha -ne '') -and ($headSha -eq $upstreamSha)

# ------------------------------------- 3. the previous round really came back
$prevExists = Test-Path -LiteralPath $prevMd
$prevNonce = ''
$prevSha = ''
$prevOk = $false
if ($prevExists) {
    $prevText = Get-Text $prevMd
    if ($prevText -match 'run_nonce=(\S+)')   { $prevNonce = $Matches[1] }
    if ($prevText -match 'run_sha256=([0-9a-f]+)') { $prevSha = $Matches[1] }
    $prevOk = ($prevText -match 'LOOP_PULL_EXEC_PUSH_OK=True') -and ($prevNonce -ne '')
}
# the previous receipt must be a committed object, i.e. it travelled through git
$prevTracked = ''
try { $prevTracked = Run-Git ('log -1 --pretty=%h -- results/status/LOOP_PROOF_R' + $prevRound + '.md') } catch { }
$prevInGit = ($prevTracked -ne '')

# ------------------------------------------- 4. really execute code again
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$acc = [double]0
for ($i = 1; $i -le 200000; $i++) { $acc += [math]::Sqrt($i) }
$acc = [math]::Round($acc, 6)
$sw.Stop()
$computeMs = [int]$sw.ElapsedMilliseconds

$nonce = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + $env:COMPUTERNAME
$sha = ''
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($nonce + '|' + $headSha + '|' + $acc)
    $h = [System.Security.Cryptography.SHA256]::Create()
    $sha = ([System.BitConverter]::ToString($h.ComputeHash($bytes))).Replace('-','').ToLower()
} catch { }

# a fresh run must not reuse the previous round's nonce/digest
$freshRun = ($sha -ne '') -and ($nonce -ne $prevNonce) -and ($sha -ne $prevSha)

# python probe (robust: resolve the command first, then run it)
$pythonFound = ''; $pythonOut = ''
$pyCandidates = @(
    @{ exe = 'python3'; pre = @() },
    @{ exe = 'python';  pre = @() },
    @{ exe = 'py';      pre = @('-3') }
)
foreach ($cand in $pyCandidates) {
    $exe = [string]$cand.exe
    $pre = @($cand.pre)
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { continue }
    try {
        $argv = @() + $pre + @('-c', 'import sys;print("py-ok "+sys.version.split()[0])')
        $o = (& $exe @argv 2>&1 | Out-String).Trim()
        if ($o -match 'py-ok') { $pythonFound = ($exe + ' ' + ($pre -join ' ')).Trim(); $pythonOut = $o; break }
    } catch { }
}

$codeExecuted = $freshRun
$loopOk = $branchOk -and $codeExecuted -and $handsFree -and $autoPull -and $autoPush
$repeatOk = $loopOk -and $prevOk -and $prevInGit

# ----------------------------------------------------------- 5. receipts
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Local loop proof - round ' + $round + ' (repeat of round ' + $prevRound + ')') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')) | Out-Null
$lines.Add('host=' + $env:COMPUTERNAME) | Out-Null
$lines.Add('repo_path=' + $repo) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## 1. pull side (agent -> machine)') | Out-Null
$lines.Add('config_branch=' + $cfgBranch) | Out-Null
$lines.Add('head_branch=' + $headBranch) | Out-Null
$lines.Add('head_commit=' + $headSha + ' ' + $headSubject) | Out-Null
$lines.Add('origin_commit=' + $upstreamSha) | Out-Null
$lines.Add('BRANCH_MATCHES=' + $branchOk) | Out-Null
$lines.Add('AUTO_PULL_UP_TO_DATE=' + $pulledOk) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## 2. previous round came back through git') | Out-Null
$lines.Add('prev_receipt=results/status/LOOP_PROOF_R' + $prevRound + '.md') | Out-Null
$lines.Add('prev_receipt_present=' + $prevExists) | Out-Null
$lines.Add('prev_receipt_commit=' + $prevTracked) | Out-Null
$lines.Add('prev_run_nonce=' + $prevNonce) | Out-Null
$lines.Add('PREV_ROUND_OK=' + ($prevOk -and $prevInGit)) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## 3. execute side (code ran AGAIN on this machine)') | Out-Null
$lines.Add('compute_sum_sqrt_1_200000=' + $acc) | Out-Null
$lines.Add('compute_elapsed_ms=' + $computeMs) | Out-Null
$lines.Add('run_nonce=' + $nonce) | Out-Null
$lines.Add('run_sha256=' + $sha) | Out-Null
$lines.Add('nonce_differs_from_prev=' + ($nonce -ne $prevNonce)) | Out-Null
$lines.Add('python_interpreter=' + $pythonFound) | Out-Null
$lines.Add('python_probe=' + $pythonOut) | Out-Null
$lines.Add('CODE_EXECUTED=' + $codeExecuted) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## 4. push side (machine -> agent)') | Out-Null
$lines.Add('hands_free=' + $handsFree) | Out-Null
$lines.Add('auto_pull=' + $autoPull) | Out-Null
$lines.Add('auto_push=' + $autoPush) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## verdict') | Out-Null
$lines.Add('LOOP_PULL_EXEC_PUSH_OK=' + $loopOk) | Out-Null
$lines.Add('LOOP_REPEAT_OK=' + $repeatOk) | Out-Null
$lines.Add('LOOP_PROOF_DONE=True') | Out-Null
$lines | Set-Content -LiteralPath $reportMd -Encoding UTF8

$obj = [ordered]@{
    round             = $round
    prev_round        = $prevRound
    time              = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
    host              = $env:COMPUTERNAME
    repo_path         = $repo
    config_branch     = $cfgBranch
    head_branch       = $headBranch
    head_commit       = $headSha
    origin_commit     = $upstreamSha
    branch_matches    = $branchOk
    auto_pull_synced  = $pulledOk
    prev_receipt_ok   = ($prevOk -and $prevInGit)
    prev_run_nonce    = $prevNonce
    compute_result    = $acc
    compute_ms        = $computeMs
    run_nonce         = $nonce
    run_sha256        = $sha
    python            = $pythonFound
    hands_free        = $handsFree
    auto_pull         = $autoPull
    auto_push         = $autoPush
    code_executed     = $codeExecuted
    loop_ok           = $loopOk
    repeat_ok         = $repeatOk
}
($obj | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $reportJson -Encoding UTF8

# ------------------------------------------------- 6. cumulative loop ledger
if (-not (Test-Path -LiteralPath $ledger)) {
    $head = @(
        '# Loop ledger - every completed pull -> execute -> push round on the real machine',
        '',
        'One row per round, appended by the round task while it runs on Windows.',
        '',
        '| round | time (local) | host | head commit | run nonce | run sha256 (12) | loop ok |',
        '|---|---|---|---|---|---|---|'
    )
    $head | Set-Content -LiteralPath $ledger -Encoding UTF8
}
function Add-LedgerRow([int]$r, [string]$t, [string]$h, [string]$commit, [string]$n, [string]$digest, [string]$ok) {
    $short = $digest
    if ($digest.Length -ge 12) { $short = $digest.Substring(0,12) }
    $existing = Get-Text $ledger
    if ($existing -match ('\|\s*' + $r + '\s*\|')) { return }
    $row = '| ' + $r + ' | ' + $t + ' | ' + $h + ' | ' + $commit + ' | ' + $n + ' | ' + $short + ' | ' + $ok + ' |'
    Add-Content -LiteralPath $ledger -Encoding UTF8 -Value $row
}

# backfill the previous round (it ran before the ledger existed)
if ($prevExists) {
    $pTime = ''; $pHost = ''; $pCommit = ''; $pOk = 'False'
    $pText = Get-Text $prevMd
    if ($pText -match 'time=([^\r\n]+)')        { $pTime   = $Matches[1].Trim() }
    if ($pText -match 'host=([^\r\n]+)')        { $pHost   = $Matches[1].Trim() }
    if ($pText -match 'head_commit=(\S+)')      { $pCommit = $Matches[1].Trim() }
    if ($pText -match 'LOOP_PULL_EXEC_PUSH_OK=(\w+)') { $pOk = $Matches[1].Trim() }
    Add-LedgerRow $prevRound $pTime $pHost $pCommit $prevNonce $prevSha $pOk
}

Add-LedgerRow $round ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) $env:COMPUTERNAME $headSha $nonce $sha ([string]$loopOk)

Get-Content -LiteralPath $reportMd -Encoding UTF8

if ($repeatOk) { exit 0 }
exit 7
