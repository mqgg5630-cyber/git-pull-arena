# Run in Administrator PowerShell.
# Stops Git auth popups, fixes duplicate fetch refspec, speeds up fetch.
param(
  [string]$Repo   = "E:\0github\git-sync\git-pull-arena-01a0ff69",
  [string]$Branch = "arena/01a0ff69-git-pull-arena",
  [string]$Proxy  = ""            # e.g. "http://127.0.0.1:10809"; empty = no proxy change
)
$ErrorActionPreference = "Continue"
Set-Location -LiteralPath $Repo

Write-Host "== 1) never show an auth dialog again ==" -ForegroundColor Cyan
git config --global core.askPass ""
git config --global credential.interactive never
git config --global credential.modalPrompt false
[Environment]::SetEnvironmentVariable("GIT_TERMINAL_PROMPT","0","Machine")
[Environment]::SetEnvironmentVariable("GCM_INTERACTIVE","never","Machine")
$env:GIT_TERMINAL_PROMPT = "0"
$env:GCM_INTERACTIVE     = "never"

Write-Host "== 2) silent credential store ==" -ForegroundColor Cyan
git config --global credential.helper manager
git config --global "credential.https://github.com.provider" github

Write-Host "== 3) one fetch refspec only ==" -ForegroundColor Cyan
git config --unset-all remote.origin.fetch
git config --add remote.origin.fetch ("+refs/heads/{0}:refs/remotes/origin/{0}" -f $Branch)
git config --get-all remote.origin.fetch

Write-Host "== 4) transport tuning ==" -ForegroundColor Cyan
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 1000
git config --global http.lowSpeedTime 30
git config --global core.fscache true
git config --global "gc.auto" 0
git config --global fetch.prune true

if ($Proxy -ne "") {
  Write-Host "== 5) proxy: $Proxy ==" -ForegroundColor Cyan
  git config --global http.proxy  $Proxy
  git config --global https.proxy $Proxy
  [Environment]::SetEnvironmentVariable("HTTPS_PROXY",$Proxy,"Machine")
  [Environment]::SetEnvironmentVariable("HTTP_PROXY",$Proxy,"Machine")
  $env:HTTPS_PROXY = $Proxy
  $env:HTTP_PROXY  = $Proxy
} else {
  Write-Host "== 5) proxy unchanged (pass -Proxy to set one) ==" -ForegroundColor Yellow
}

Write-Host "== 6) timing test ==" -ForegroundColor Cyan
$t1 = Measure-Command { git ls-remote origin -h 2>&1 | Out-Null }
Write-Host ("ls-remote seconds = {0:N1}" -f $t1.TotalSeconds)
$t2 = Measure-Command { git fetch origin $Branch 2>&1 | Out-Null }
Write-Host ("fetch seconds     = {0:N1}" -f $t2.TotalSeconds)

git reset --hard ("origin/{0}" -f $Branch)
git log --oneline -1
Write-Host "FIX_OK=True" -ForegroundColor Green
