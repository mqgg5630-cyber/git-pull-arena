# sync.ps1 (skill version) - pull the latest code from the working branch.
#
# Usage (inside the repo folder):
#     .\sync.ps1
#     .\sync.ps1 -Branch arena/01a09d79-zhongqi
#
# The branch defaults to sync.config.json (keys: branch / remote), so the same
# script works in any repo that carries that file.
#
# ASCII-only on purpose: Windows PowerShell 5.1 decodes a .ps1 without BOM as
# ANSI/GBK and Chinese text would break the parser.

param(
    [string]$Branch = '',
    [string]$Remote = '',
    [string]$Config = ''
)

$ErrorActionPreference = 'Stop'

# repo root = walk up from this script until .git appears, so the script also
# works when run straight from skills\git-sync\scripts\
$repo = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
while ($repo -and -not (Test-Path -LiteralPath (Join-Path $repo '.git'))) {
    $up = Split-Path -Parent $repo
    if (-not $up -or $up -eq $repo) { break }
    $repo = $up
}
Set-Location -LiteralPath $repo

if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) {
    Write-Host "[ERROR] Not a git repository: $repo" -ForegroundColor Red
    Write-Host "        Run this from the cloned folder (e.g. E:\0zhongqi\zhongqi)." -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------------- config
# resolution order: -Config <path> > profile file (sync.config.<PROFILE>.json,
# PROFILE from $env:GIT_SYNC_PROFILE) > skills\git-sync\sync.config.json >
# next to this script
if ($Config -and -not (Test-Path -LiteralPath $Config)) {
    Write-Host "[ERROR] config not found: $Config" -ForegroundColor Red
    exit 1
}
$cfgPath = @()
if ($Config) { $cfgPath += $Config }
if ($env:GIT_SYNC_PROFILE) {
    $prof = 'sync.config.' + $env:GIT_SYNC_PROFILE + '.json'
    $cfgPath += @(
        (Join-Path $repo ('skills\git-sync\' + $prof)),
        (Join-Path $repo $prof),
        (Join-Path $PSScriptRoot $prof)
    )
}
$cfgPath += @(
    (Join-Path $repo 'skills\git-sync\sync.config.json'),
    (Join-Path $PSScriptRoot 'sync.config.json')
)
$cfgPath = $cfgPath | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($cfgPath) {
    $cfg = Get-Content -LiteralPath $cfgPath -Encoding UTF8 -Raw | ConvertFrom-Json
    if (-not $Branch -and $cfg.branch) { $Branch = [string]$cfg.branch }
    if (-not $Remote -and $cfg.remote) { $Remote = [string]$cfg.remote }
}
if (-not $Remote) { $Remote = 'origin' }
if (-not $Branch) { $Branch = (git rev-parse --abbrev-ref HEAD).Trim() }

Write-Host "== repo  : $repo" -ForegroundColor Cyan
Write-Host "== branch: $Branch" -ForegroundColor Cyan

# Local changes: the watcher's own artifacts (handshake + check logs) are
# REGENERATED every round, so committing them locally keeps the tree clean.
# Stashing them was a bug: when a push failed, every later sync created another
# stash entry and the pile grew (field report: 6 stale stashes).
$dirty = @(git status --porcelain)
$stashed = $false
$artifactDirty = $false
if ($dirty.Count -gt 0) {
    $watcherOnly = $true
    foreach ($line in $dirty) {
        $p = $line.Substring(3).Trim()
        if ($p -notmatch '^"?results/status/') { $watcherOnly = $false; break }
    }
    if ($watcherOnly) {
        Write-Host "== local changes are watcher artifacts (results/status/) - committing them instead of stashing" -ForegroundColor Cyan
        git add -A -- results/status
        git -c user.name="git-sync watcher" -c user.email="watcher@local" commit -q -m ("watch: local check artifacts " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
        $artifactDirty = $true
    } else {
        Write-Host "!! local changes found, stashing them first ..." -ForegroundColor Yellow
        git stash push -u -m ("auto-stash before sync " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        $stashed = $true
    }
}

git fetch $Remote
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] git fetch failed (network / proxy?)." -ForegroundColor Red; exit 1 }

git checkout $Branch
git pull --ff-only $Remote $Branch
if ($LASTEXITCODE -ne 0) {
    # a failed push from the watcher leaves local verdict commits behind, and
    # the branch then diverges from the remote - which would stall the loop
    # forever. Those commits are regenerable artifacts, so drop them (the
    # files stay in the worktree) and try once more.
    $ahead = @(git log --format=%s "$Remote/$Branch..HEAD" 2>$null)
    $onlyArtifacts = ($ahead.Count -gt 0)
    foreach ($subj in $ahead) {
        if ($subj -notmatch '^(check: round|watch: local check artifacts)') { $onlyArtifacts = $false; break }
    }
    if ($onlyArtifacts) {
        Write-Host "== local commits are only watcher verdicts - realigning with the remote (files are kept)" -ForegroundColor Cyan
        git reset --mixed "$Remote/$Branch" | Out-Null
        git ls-files -d | ForEach-Object { git checkout -- $_ }
        git pull --ff-only $Remote $Branch
    }
}
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] pull failed. Your branch has local commits that conflict." -ForegroundColor Red
    Write-Host "        Diagnose: git status ; git stash list ; git log --oneline -5" -ForegroundColor Yellow
    Write-Host "        Hard reset (loses local commits): git reset --hard $Remote/$Branch" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "== up to date. latest commit:" -ForegroundColor Green
git log -1 --oneline --decorate

if ($stashed) {
    Write-Host ""
    Write-Host "NOTE: your previous local changes are still in the stash. See: git stash list" -ForegroundColor Yellow
}
if ($artifactDirty) {
    Write-Host "NOTE: watcher artifacts were committed locally and will be pushed with the next push." -ForegroundColor DarkGray
}
$stashCount = @(git stash list).Count
if ($stashCount -ge 3) {
    Write-Host ("NOTE: {0} stash entries are piling up - inspect with 'git stash list' and drop the auto-stash ones." -f $stashCount) -ForegroundColor Yellow
}
