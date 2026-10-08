$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$inv  = Join-Path $repo "results\netops"
New-Item -ItemType Directory -Force -Path $inv | Out-Null
Write-Output "HOST=$env:COMPUTERNAME"

$bash = @'
set +e
HOSTIP=10.10.5.210
USERN=25wenshaohua

echo "=== 0. network layer: can we even reach the host ==="
ip -4 addr show | grep -E "inet " | sed "s/^/  /"
echo "--- ping ---"
ping -c 2 -W 3 $HOSTIP 2>&1 | tail -4
echo "--- tcp 22 ---"
timeout 6 bash -c "cat < /dev/null > /dev/tcp/$HOSTIP/22" 2>&1 && echo "TCP22=open" || echo "TCP22=closed_or_filtered"

echo ""
echo "=== 1. write ~/.ssh/config ==="
mkdir -p ~/.ssh && chmod 700 ~/.ssh
if [ -f ~/.ssh/config ]; then cp ~/.ssh/config ~/.ssh/config.bak.$(date +%Y%m%d%H%M%S); fi
# drop any pre-existing mu01 block, then append a fresh one
if [ -f ~/.ssh/config ]; then
  awk "BEGIN{skip=0} /^[Hh]ost /{skip=(\$2==\"mu01\")} skip==0{print}" ~/.ssh/config > ~/.ssh/config.new
else
  : > ~/.ssh/config.new
fi
cat >> ~/.ssh/config.new <<CFG

Host mu01
    HostName $HOSTIP
    User $USERN
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 6
    StrictHostKeyChecking accept-new
CFG
mv ~/.ssh/config.new ~/.ssh/config
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_ed25519 2>/dev/null
echo "--- resulting config (IdentityFile redacted) ---"
sed -e "s#^\(\s*IdentityFile\).*#\1 <redacted>#" ~/.ssh/config

echo ""
echo "=== 2. ssh verbose dry run ==="
timeout 25 ssh -o BatchMode=yes -o ConnectTimeout=10 -v mu01 "echo SSH_OK; hostname; whoami; pwd" 2>&1 \
  | grep -viE "debug1: (Reading|Offering|Will attempt|Trying|identity file|Local version|Remote protocol|compat|SSH2_MSG|kex|cipher|compression|umac|peer |Authenticating|rekey)" \
  | head -40

echo ""
echo "=== 3. if logged in: inspect the sorf pipeline dir ==="
timeout 40 ssh -o BatchMode=yes -o ConnectTimeout=10 mu01 '
  P=/mnt/hpc/home/25menglei/25wenshaohua/wsh/ad/codenew/sorf_pipeline
  echo "EXISTS=$([ -d "$P" ] && echo yes || echo no)"
  [ -d "$P" ] && du -sh "$P" 2>/dev/null
  [ -d "$P" ] && ls -la "$P" | head -30
  echo "--- key artifacts ---"
  for f in sorf_output/final_sORF_Catalog.unique.fa MAG_Sample_Mapping.tsv Sample_Group_Mapping.tsv; do
    if [ -f "$P/$f" ]; then echo "FOUND $f $(stat -c%s "$P/$f") bytes"; else echo "MISSING $f"; fi
  done
  echo "--- quota / home usage ---"
  df -h "$P" 2>/dev/null | tail -2
' 2>&1 | head -50
'@

$tmp = Join-Path $repo "hpcssh.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("W| " + $_) }
[IO.File]::WriteAllLines((Join-Path $inv "hpc_ssh_restore.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))

$txt = ($o | Out-String)
if ($txt -match "SSH_OK") { Write-Output "HPC_SSH_REACHABLE=True" } else { Write-Output "HPC_SSH_REACHABLE=False" }
Write-Output "HPC_SSH_RESTORE_DONE=True"
