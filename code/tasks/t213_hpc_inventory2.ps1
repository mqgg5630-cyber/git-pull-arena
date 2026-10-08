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

cat > /tmp/hpc_eyu.sh <<"REMOTE"
# SCOPE: only wsh-eyu. Nothing else in the home is touched.
D=/mnt/hpc/home/25menglei/25wenshaohua/wsh-eyu
T() { timeout "$1" bash -c "$2" 2>/dev/null || echo "  [timed out after $1 s]" ; }

echo "SCOPE=$D"
if [ ! -d "$D" ] ; then echo "SCOPE_MISSING" ; exit 0 ; fi

echo
echo "=== 1. top level ==="
ls -la "$D" | grep -v "^total"

echo
echo "=== 2. size + file count ==="
T 180 "du -sh '$D'"
T 180 "find '$D' -type f | wc -l"

echo
echo "=== 3. directory tree, 4 levels ==="
T 120 "find '$D' -maxdepth 4 -type d -printf '%p\n' | sort | head -150"

echo
echo "=== 4. per-subdir size ==="
T 240 "du -sh '$D'/*/ 2>/dev/null | sort -h | tail -40"

echo
echo "=== 5. biggest 60 files ==="
T 240 "find '$D' -type f -printf '%12s  %TY-%Tm-%Td  %p\n' | sort -rn | head -60"

echo
echo "=== 6. file extension census ==="
T 180 "find '$D' -type f -printf '%f\n' | sed -n 's/.*\.\([A-Za-z0-9]\{1,8\}\)$/\1/p' | sort | tr 'A-Z' 'a-z' | uniq -c | sort -rn | head -30"

echo
echo "=== 7. sequence files ==="
T 240 "find '$D' \( -name '*.fa' -o -name '*.fasta' -o -name '*.faa' -o -name '*.fna' -o -name '*.fa.gz' -o -name '*.fasta.gz' -o -name '*.fq*' -o -name '*.fastq*' \) -printf '%12s  %TY-%Tm-%Td  %p\n' | sort -rn | head -50"

echo
echo "=== 8. tables (tsv/csv/txt > 1k) ==="
T 240 "find '$D' \( -name '*.tsv' -o -name '*.csv' \) -size +1k -printf '%12s  %p\n' | sort -rn | head -50"

echo
echo "=== 9. scripts and notebooks ==="
T 180 "find '$D' \( -name '*.sh' -o -name '*.py' -o -name '*.R' -o -name '*.ipynb' -o -name '*.smk' -o -name 'Snakefile' -o -name '*.yaml' -o -name '*.yml' \) -printf '%12s  %TY-%Tm-%Td  %p\n' | sort -k2 -r | head -60"

echo
echo "=== 10. readme / notes ==="
T 120 "find '$D' -iname '*readme*' -o -iname '*note*' -o -iname '*.md' | head -25"

echo
echo "=== 11. newest 30 files overall (what was last worked on) ==="
T 240 "find '$D' -type f -printf '%TY-%Tm-%Td %TH:%TM  %12s  %p\n' | sort -r | head -30"

echo
echo "=== 12. head of every top-level tsv/csv (first 2 lines) ==="
T 120 "find '$D' -maxdepth 2 \( -name '*.tsv' -o -name '*.csv' \) | head -12 | while read -r f ; do echo \"--- \$f\" ; head -2 \"\$f\" | cut -c1-240 ; done"
REMOTE

timeout 1500 ssh -o BatchMode=yes -o ServerAliveInterval=20 mu01 "bash -s" < /tmp/hpc_eyu.sh 2>&1
rm -f /tmp/hpc_eyu.sh
'@

$tmp = Join-Path $repo "hpceyu.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("H| " + $_) }
[IO.File]::WriteAllLines((Join-Path $inv "wsh_eyu_inventory.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output ("EYU_LINES=" + $o.Count)
Write-Output "WSH_EYU_INVENTORY_DONE=True"
