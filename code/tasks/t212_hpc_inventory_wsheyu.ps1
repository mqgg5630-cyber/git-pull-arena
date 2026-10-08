$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$inv  = Join-Path $repo "results\hpc"
New-Item -ItemType Directory -Force -Path $inv | Out-Null
Write-Output "HOST=$env:COMPUTERNAME"

$bash = @'
set +e
if ! timeout 20 ssh -o BatchMode=yes -o ConnectTimeout=10 mu01 "echo SSH_OK" 2>/dev/null | grep -q SSH_OK; then
  echo "SSH_KEYAUTH_FAILED"
  exit 0
fi
echo "SSH_OK"

cat > /tmp/hpc_inv_remote.sh <<"REMOTE"
R=/mnt/hpc/home/25menglei/25wenshaohua
echo "=== 1. top of home ==="
ls -la "$R" | head -40
echo
echo "=== 2. disk usage per top-level dir ==="
du -sh "$R"/* 2>/dev/null | sort -h | tail -30
echo
echo "=== 3. wsh-eyu tree (dirs, 3 levels) ==="
find "$R/wsh-eyu" -maxdepth 3 -type d 2>/dev/null | head -80
echo
echo "=== 4. wsh-eyu biggest files ==="
find "$R/wsh-eyu" -type f -printf "%10s  %p\n" 2>/dev/null | sort -rn | head -40
echo
echo "=== 5. sequence/result artifacts anywhere in home ==="
find "$R" -maxdepth 6 \( -name "*.fa" -o -name "*.fasta" -o -name "*.faa" -o -name "*.fna" -o -name "*.tsv" -o -name "*.csv" \) -printf "%10s  %TY-%Tm-%Td  %p\n" 2>/dev/null | sort -rn | head -60
echo
echo "=== 6. the three artifacts we care about ==="
for target in final_sORF_Catalog.unique.fa MAG_Sample_Mapping.tsv Sample_Group_Mapping.tsv ; do
  hits=$(find "$R" -maxdepth 8 -name "$target" 2>/dev/null)
  if [ -n "$hits" ] ; then
    echo "FOUND $target"
    echo "$hits" | sed "s/^/    /"
  else
    echo "MISSING $target"
  fi
done
echo
echo "=== 7. old pipeline dir still there? ==="
P="$R/wsh/ad/codenew/sorf_pipeline"
if [ -d "$P" ] ; then echo "sorf_pipeline exists=yes" ; ls -la "$P" | head -25 ; else echo "sorf_pipeline exists=no" ; fi
echo
echo "=== 8. quota ==="
df -h "$R" 2>/dev/null | tail -2
lfs quota -u $(whoami) "$R" 2>/dev/null | head -5
echo
echo "=== 9. recent shell history (job clues) ==="
tail -60 "$R/.bash_history" 2>/dev/null
REMOTE

timeout 300 ssh -o BatchMode=yes mu01 "bash -s" < /tmp/hpc_inv_remote.sh 2>&1
rm -f /tmp/hpc_inv_remote.sh
'@

$tmp = Join-Path $repo "hpcinv.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("H| " + $_) }
[IO.File]::WriteAllLines((Join-Path $inv "hpc_inventory_wsheyu.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))

$txt = ($o | Out-String)
if ($txt -match "SSH_KEYAUTH_FAILED") { Write-Output "HPC_KEYAUTH=False" } else { Write-Output "HPC_KEYAUTH=True" }
Write-Output "HPC_INVENTORY_DONE=True"
