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

cat > /tmp/eyu_detail.sh <<"REMOTE"
# SCOPE: wsh-eyu only
D=/mnt/hpc/home/25menglei/25wenshaohua/wsh-eyu
R="$D/easy_98/result"
T() { timeout "$1" bash -c "$2" 2>/dev/null || echo "  [timeout ${1}s]" ; }
NSEQ() { if [ -f "$1" ] ; then echo "$(grep -c '^>' "$1" 2>/dev/null) seqs  $(stat -c%s "$1") B  $1" ; fi ; }

echo "=== A. raw reads in wsh-eyu root ==="
ls -la "$D"/*.fastq.gz 2>/dev/null | awk '{print $5, $9}'

echo
echo "=== B. easy_98/result full listing ==="
T 60 "ls -laR '$R' | head -200"

echo
echo "=== C. refined bins ==="
T 90 "ls -la '$D/easy_98/result/bin' 2>/dev/null | head -40"
T 90 "find '$D/easy_98' -name 'bin.*.fa' -path '*bin_refine*' -printf '%10s %p\n' | sort -rn | head -30"

echo
echo "=== D. checkm quality table ==="
T 60 "find '$D/easy_98' -name '*.tsv' -path '*checkm*' -o -name 'checkm.txt' -o -name '*quality*' | head -10"
for f in $(timeout 60 find "$D/easy_98" -name "*.tsv" -path "*checkm*" 2>/dev/null | head -3) ; do
  echo "--- $f"
  head -20 "$f" | cut -c1-200
done

echo
echo "=== E. gtdbtk taxonomy ==="
T 60 "find '$D/easy_98' -name 'gtdbtk.*.summary.tsv' | head -5"
for f in $(timeout 60 find "$D/easy_98" -name "gtdbtk.*.summary.tsv" 2>/dev/null | head -2) ; do
  echo "--- $f"
  cut -f1,2 "$f" | head -15
done

echo
echo "=== F. bin.1_getorf_sorf contents ==="
T 60 "find '$R/bin.1_getorf_sorf' -type f -printf '%12s  %p\n' | sort -rn | head -40"
echo "--- seq counts ---"
for f in $(timeout 90 find "$R/bin.1_getorf_sorf" -name "*.fa" -o -name "*.fasta" 2>/dev/null | head -12) ; do NSEQ "$f" ; done

echo
echo "=== G. bin.3_getorf_sorf contents ==="
T 60 "find '$R/bin.3_getorf_sorf' -type f -printf '%12s  %p\n' | sort -rn | head -40"
echo "--- seq counts ---"
for f in $(timeout 90 find "$R/bin.3_getorf_sorf" -name "*.fa" -o -name "*.fasta" 2>/dev/null | head -12) ; do NSEQ "$f" ; done

echo
echo "=== H. any other getorf_sorf dirs ==="
T 60 "find '$D' -maxdepth 4 -type d -name '*getorf*'"

echo
echo "=== I. scripts in wsh-eyu ==="
T 90 "find '$D' \( -name '*.sh' -o -name '*.py' -o -name '*.sbatch' \) -printf '%10s  %TY-%Tm-%Td  %p\n' | sort -k2 -r | head -40"

echo
echo "=== J. logs ==="
T 60 "ls -la '$D/easy_98/log' 2>/dev/null | head -30"

echo
echo "=== K. first 4 headers of each sorf fasta ==="
for f in "$R/bin.1_getorf_sorf/02_merge/all_orf.fa" "$R/bin.1_getorf_sorf/03_filter/all_orf.nr.no_known_amp.fa" "$R/bin.3_getorf_sorf/02_merge/all_orf.fa" "$R/bin.3_getorf_sorf/03_filter/all_orf.nr.no_known_amp.fa" ; do
  if [ -f "$f" ] ; then echo "--- $f" ; grep -m4 '^>' "$f" ; fi
done
REMOTE

timeout 1200 ssh -o BatchMode=yes -o ServerAliveInterval=20 mu01 "bash -s" < /tmp/eyu_detail.sh 2>&1
rm -f /tmp/eyu_detail.sh
'@

$tmp = Join-Path $repo "eyudetail.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("H| " + $_) }
[IO.File]::WriteAllLines((Join-Path $inv "wsh_eyu_detail.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "EYU_DETAIL_DONE=True"
