$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$inv  = Join-Path $repo "results\netops"
New-Item -ItemType Directory -Force -Path $inv | Out-Null
Write-Output "HOST=$env:COMPUTERNAME"

# ============ A. recover the HPC ssh alias from WSL ============
Write-Output "## A. WSL ssh config"
$bash = @'
set +e
echo "--- ~/.ssh/config ---"
cat ~/.ssh/config 2>/dev/null | sed -e 's/^\(\s*IdentityFile\).*/\1 <redacted-path>/'
echo "--- known_hosts host names ---"
cut -d" " -f1 ~/.ssh/known_hosts 2>/dev/null | tr "," "\n" | sort -u | head -40
echo "--- key files present (names only) ---"
ls -1 ~/.ssh 2>/dev/null
echo "--- resolve + reachability ---"
for h in mu01 $(awk "/^Host /{print \$2}" ~/.ssh/config 2>/dev/null); do
  echo "host=$h"
  getent hosts "$h" 2>/dev/null || echo "  no DNS entry"
done
echo "--- ssh dry run (BatchMode, 8s) ---"
timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new mu01 "hostname; pwd" 2>&1 | head -10
'@
$tmp = Join-Path $repo "wslssh.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("W| " + $_) }
[IO.File]::WriteAllLines((Join-Path $inv "wsl_ssh_config.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))

# ============ B. proxy ports actually listening ============
Write-Output ""
Write-Output "## B. local proxy ports"
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -in 1080,1081,7890,7891,10808,10809,10810,18088,18089,20171,20172 } |
  ForEach-Object {
    $pn = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
    Write-Output ("PORT {0} pid={1} proc={2}" -f $_.LocalPort, $_.OwningProcess, $pn)
  }

Write-Output ""
Write-Output "## C. current git proxy config"
git config --global --get http.proxy
git config --global --get https.proxy
git config --global --get http.sslBackend
git config --global --get http.version

# ============ D. probe which proxy actually works for github ============
Write-Output ""
Write-Output "## D. github reachability per proxy"
$cands = @("", "http://127.0.0.1:18088", "socks5h://127.0.0.1:10808", "http://127.0.0.1:10809", "http://127.0.0.1:7890")
$best = $null; $bestSec = 9999
foreach ($p in $cands) {
    $label = if ($p -eq "") { "<direct>" } else { $p }
    $env:ALL_PROXY = ""
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if ($p -eq "") {
        $r = & git -c http.proxy= -c https.proxy= ls-remote --heads https://github.com/mqgg5630-cyber/subs-check-pro.git 2>&1
    } else {
        $r = & git -c http.proxy=$p -c https.proxy=$p ls-remote --heads https://github.com/mqgg5630-cyber/subs-check-pro.git 2>&1
    }
    $sw.Stop()
    $ok = ($LASTEXITCODE -eq 0)
    Write-Output ("PROXY {0,-32} ok={1} sec={2:N1}" -f $label, $ok, $sw.Elapsed.TotalSeconds)
    if ($ok -and $sw.Elapsed.TotalSeconds -lt $bestSec) { $best = $p; $bestSec = $sw.Elapsed.TotalSeconds }
}
Write-Output ("BEST_PROXY={0}" -f $(if ($best -eq $null) { "none" } elseif ($best -eq "") { "<direct>" } else { $best }))
if ($best -eq $null) { Write-Output "NO_WORKING_TRANSPORT"; exit 1 }

# ============ E. apply robust transport settings ============
Write-Output ""
Write-Output "## E. apply settings"
if ($best -eq "") {
    git config --global --unset http.proxy  2>$null
    git config --global --unset https.proxy 2>$null
} else {
    git config --global http.proxy  $best
    git config --global https.proxy $best
}
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999
git config --global core.compression 0
git config --global pull.rebase false
Write-Output "SETTINGS_APPLIED=True"

# ============ F. resilient clone: shallow first, then deepen ============
Write-Output ""
Write-Output "## F. clone subs-check-pro (shallow then deepen)"
$work = "E:\0github\git-sync"
$dir  = Join-Path $work "subs-check-pro-d2a66b2d"
$branch = "arena/d2a66b2d-subs-check-pro"
$url = "https://github.com/mqgg5630-cyber/subs-check-pro.git"
if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }

Push-Location $work
$cloned = $false
for ($try = 1; $try -le 3; $try++) {
    Write-Output ("clone attempt {0} (depth=1, filter=blob:none)" -f $try)
    & git clone --filter=blob:none --no-tags --depth 1 -b $branch $url "subs-check-pro-d2a66b2d" 2>&1 |
        ForEach-Object { Write-Output ("g| " + $_) }
    if ($LASTEXITCODE -eq 0) { $cloned = $true; break }
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}
Pop-Location

if (-not $cloned) { Write-Output "CLONE_FAILED"; exit 1 }
Push-Location $dir
& git log --oneline -1 2>&1 | ForEach-Object { Write-Output ("g| " + $_) }
$files = @(Get-ChildItem -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\\.git\\' }).Count
Write-Output "CLONE_OK=True files=$files"
Pop-Location

Write-Output "HPC_AND_CLONE_FIX_DONE=True"
