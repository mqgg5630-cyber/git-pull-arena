$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$inv  = Join-Path $repo "results\hpc"
New-Item -ItemType Directory -Force -Path $inv | Out-Null
Write-Output "HOST=$env:COMPUTERNAME"

$bash = @'
set +e
if ! timeout 20 ssh -o BatchMode=yes -o ConnectTimeout=10 mu01 "echo SSH_OK" 2>/dev/null | grep -q SSH_OK; then
  echo "SSH_KEYAUTH_FAILED"; exit 0
fi
echo "SSH_OK"

cat > /tmp/hpc_inv2.sh <<"REMOTE"
R=/mnt/hpc/home/25menglei/25wenshaohua
T() { timeout "$1" bash -c "$2" 2>/dev/null || echo "  [timed out after $1 s]" ; }

echo "=== 1. full top-level listing ==="
ls -la "$R" | grep -v "^total" | awk '{ printf "%s %10s %s %s %s %s\n", $1, $5, $6, $7, $8, $9 }'

echo
echo "=== 2. wsh-eyu: dirs 3 levels ==="
T 90 "find '$R/wsh-eyu' -maxdepth 3 -type d | head -100"

echo
echo "=== 3. wsh-eyu: biggest 40 files ==="
T 120 "find '$R/wsh-eyu' -type f -printf '%10s  %TY-%Tm-%Td  %p\n' | sort -rn | head -40"

echo
echo "=== 4. wsh-eyu: file count + total size ==="
T 120 "find '$R/wsh-eyu' -type f | wc -l"
T 120 "du -sh --exclude=.git '$R/wsh-eyu'"

echo
echo "=== 5. 0amp-src (recently modified!) ==="
T 60 "ls -la '$R/0amp-src'"
T 90 "find '$R/0amp-src' -maxdepth 2 -type d | head -40"
T 120 "find '$R/0amp-src' -type f -printf '%10s  %TY-%Tm-%Td  %p\n' | sort -rn | head -25"

echo
echo "=== 6. named artifacts, targeted dirs only ==="
for target in final_sORF_Catalog.unique.fa MAG_Sample_Mapping.tsv Sample_Group_Mapping.tsv ; do
  hits=$(timeout 150 find "$R/wsh-eyu" "$R/0amp-src" "$R/amp" "$R/wsh" -maxdepth 7 -name "$target" 2>/dev/null)
  if [ -n "$hits" ] ; then
    echo "FOUND $target"
    echo "$hits" | while read -r h ; do echo "    $(stat -c%s "$h") bytes  $h" ; done
  else
    echo "MISSING $target"
  fi
done

echo
echo "=== 7. any large fasta in those dirs ==="
T 180 "find '$R/wsh-eyu' '$R/0amp-src' '$R/amp' '$R/wsh' -maxdepth 7 \( -name '*.fa' -o -name '*.fasta' -o -name '*.faa' -o -name '*.fna' \) -size +1M -printf '%10s  %TY-%Tm-%Td  %p\n' | sort -rn | head -30"

echo
echo "=== 8. mapping-ish tsv/csv ==="
T 150 "find '$R/wsh-eyu' '$R/0amp-src' '$R/amp' '$R/wsh' -maxdepth 7 \( -name '*apping*' -o -name '*roup*' \) -type f -printf '%10s  %p\n' | sort -rn | head -30"

echo
echo "=== 9. old sorf_pipeline ==="
P="$R/wsh/ad/codenew/sorf_pipeline"
if [ -d "$P" ] ; then echo "exists=yes" ; ls -la "$P" | head -30 ; else echo "exists=no" ; fi
if [ -d "$R/wsh" ] ; then echo "-- wsh tree --" ; T 90 "find '$R/wsh' -maxdepth 4 -type d | head -50" ; fi

echo
echo "=== 10. quota ==="
df -h "$R" 2>/dev/null | tail -2

echo
echo "=== 11. history grep: sorf / amp / assembly commands ==="
grep -aiE "sorf|prodigal|megahit|metabat|checkm|final_sORF|Mapping" "$R/.bash_history" 2>/dev/null | tail -45
REMOTE

timeout 900 ssh -o BatchMode=yes -o ServerAliveInterval=20 mu01 "bash -s" < /tmp/hpc_inv2.sh 2>&1
rm -f /tmp/hpc_inv2.sh
'@

$tmp = Join-Path $repo "hpcinv2.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("H| " + $_) }
[IO.File]::WriteAllLines((Join-Path $inv "hpc_inventory2.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output ("INV2_LINES=" + $o.Count)
Write-Output "HPC_INVENTORY2_DONE=True"
