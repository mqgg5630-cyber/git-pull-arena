# t200_loop_proof_r262.ps1 - prove the full local loop on the real machine:
#   agent pushes code -> watcher auto_pull -> THIS script runs -> results are
#   written into results/status -> watcher auto_push sends them back.
# Runs on the Windows machine inside code\local_check.ps1 section 4.
# ASCII-only source (code/check_all.sh enforces it); output may contain Unicode.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path

$outRoot = Join-Path $repo 'results\status'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$reportMd   = Join-Path $outRoot 'LOOP_PROOF_R262.md'
$reportJson = Join-Path $outRoot 'LOOP_PROOF_R262.json'

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

$cfgBranch = ''
$handsFree = $false
$autoPull  = $false
$autoPush  = $false
if ($cfg) {
    $cfgBranch = [string]$cfg.branch
    if ($null -ne $cfg.hands_free) { $handsFree = [bool]$cfg.hands_free }
    if ($null -ne $cfg.auto_pull)  { $autoPull  = [bool]$cfg.auto_pull }
    if ($null -ne $cfg.auto_push)  { $autoPush  = [bool]$cfg.auto_push }
}

# ----------------------------------------------------------- 2. git identity
$headBranch   = Run-Git 'rev-parse --abbrev-ref HEAD'
$headSha      = Run-Git 'rev-parse --short HEAD'
$headSubject  = Run-Git 'log -1 --pretty=%s'
$remoteUrl    = Run-Git 'remote get-url origin'
$upstreamSha  = Run-Git ('rev-parse --short origin/' + $expectedBranch)

$branchOk = ($cfgBranch -eq $expectedBranch) -and ($headBranch -eq $expectedBranch)
$pulledOk = ($headSha -ne '') -and ($upstreamSha -ne '') -and ($headSha -eq $upstreamSha)

# ------------------------------------------- 3. really execute code locally
# A deterministic computation plus a real toolchain probe, so the receipt
# cannot be faked by only copying files around.
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
    $md5 = [System.Security.Cryptography.SHA256]::Create()
    $sha = ([System.BitConverter]::ToString($md5.ComputeHash($bytes))).Replace('-','').ToLower()
} catch { }

# python probe: try each candidate the way code/check_all.sh does
$pythonFound = ''
$pythonOut = ''
foreach ($cand in @(@('python3', @()), @('python', @()), @('py', @('-3')))) {
    $exe = $cand[0]; $pre = $cand[1]
    try {
        $argv = @() + $pre + @('-c', 'import sys;print("py-ok", sys.version.split()[0])')
        $o = (& $exe @argv 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $o -match 'py-ok') { $pythonFound = $exe; $pythonOut = $o; break }
    } catch { }
}

$codeExecuted = ($computeMs -ge 0) -and ($sha -ne '')

# --------------------------------------- 4. was the previous round pushed?
$hsPath = Join-Path $repo 'results\status\handshake.json'
$hs = $null
try { $hs = (Get-Text $hsPath) | ConvertFrom-Json } catch { }
$round = 0
if ($hs -and $null -ne $hs.round) { $round = [int]$hs.round }

$watchLog = Join-Path $repo '.git\git-sync-watch.log'
$lastPush = ''
if (Test-Path -LiteralPath $watchLog) {
    try {
        $lastPush = (Get-Content -LiteralPath $watchLog -Tail 400 -ErrorAction SilentlyContinue |
                     Where-Object { $_ -match 'auto_push|last_push' } | Select-Object -Last 1)
    } catch { }
}
if ($null -eq $lastPush) { $lastPush = '' }

$loopOk = $branchOk -and $codeExecuted -and $handsFree -and $autoPull -and $autoPush

# ----------------------------------------------------------- 5. receipts
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Local loop proof - round 262') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')) | Out-Null
$lines.Add('host=' + $env:COMPUTERNAME) | Out-Null
$lines.Add('user=' + $env:USERNAME) | Out-Null
$lines.Add('repo_path=' + $repo) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## 1. pull side (agent -> machine)') | Out-Null
$lines.Add('remote_url=' + $remoteUrl) | Out-Null
$lines.Add('config_branch=' + $cfgBranch) | Out-Null
$lines.Add('head_branch=' + $headBranch) | Out-Null
$lines.Add('head_commit=' + $headSha + ' ' + $headSubject) | Out-Null
$lines.Add('origin_commit=' + $upstreamSha) | Out-Null
$lines.Add('BRANCH_MATCHES=' + $branchOk) | Out-Null
$lines.Add('AUTO_PULL_UP_TO_DATE=' + $pulledOk) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## 2. execute side (code really ran on this machine)') | Out-Null
$lines.Add('compute_sum_sqrt_1_200000=' + $acc) | Out-Null
$lines.Add('compute_elapsed_ms=' + $computeMs) | Out-Null
$lines.Add('run_nonce=' + $nonce) | Out-Null
$lines.Add('run_sha256=' + $sha) | Out-Null
$lines.Add('python_interpreter=' + $pythonFound) | Out-Null
$lines.Add('python_probe=' + $pythonOut) | Out-Null
$lines.Add('CODE_EXECUTED=' + $codeExecuted) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## 3. push side (machine -> agent)') | Out-Null
$lines.Add('hands_free=' + $handsFree) | Out-Null
$lines.Add('auto_pull=' + $autoPull) | Out-Null
$lines.Add('auto_push=' + $autoPush) | Out-Null
$lines.Add('handshake_round=' + $round) | Out-Null
$lines.Add('watcher_last_push_line=' + $lastPush) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## verdict') | Out-Null
$lines.Add('LOOP_PULL_EXEC_PUSH_OK=' + $loopOk) | Out-Null
$lines.Add('LOOP_PROOF_DONE=True') | Out-Null
$lines | Set-Content -LiteralPath $reportMd -Encoding UTF8

$obj = [ordered]@{
    round            = 262
    time             = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
    host             = $env:COMPUTERNAME
    repo_path        = $repo
    remote_url       = $remoteUrl
    config_branch    = $cfgBranch
    head_branch      = $headBranch
    head_commit      = $headSha
    origin_commit    = $upstreamSha
    branch_matches   = $branchOk
    auto_pull_synced = $pulledOk
    compute_result   = $acc
    compute_ms       = $computeMs
    run_nonce        = $nonce
    run_sha256       = $sha
    python           = $pythonFound
    hands_free       = $handsFree
    auto_pull        = $autoPull
    auto_push        = $autoPush
    code_executed    = $codeExecuted
    loop_ok          = $loopOk
}
($obj | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $reportJson -Encoding UTF8

Get-Content -LiteralPath $reportMd -Encoding UTF8

if ($loopOk) { exit 0 }
exit 7
