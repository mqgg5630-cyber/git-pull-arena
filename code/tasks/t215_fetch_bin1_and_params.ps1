$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\params"
New-Item -ItemType Directory -Force -Path $out | Out-Null
Write-Output "HOST=$env:COMPUTERNAME"

$bash = @'
set +e
if ! timeout 20 ssh -o BatchMode=yes -o ConnectTimeout=10 mu01 "echo SSH_OK" 2>/dev/null | grep -q SSH_OK; then
  echo "SSH_KEYAUTH_FAILED"; exit 1
fi
echo "SSH_OK"

E=/mnt/hpc/home/25menglei/25wenshaohua/wsh-eyu/easy_98
WORK=$HOME/eyu_repro
mkdir -p "$WORK/input" "$WORK/evidence"

echo "=== 1. fetch bin.1 sORF catalog (the exact 131816 input) ==="
scp -o BatchMode=yes "mu01:$E/result/bin.1_getorf_sorf/03_filter/all_orf.nr.no_known_amp.fa" "$WORK/input/bin1_sorf_131816.fa" 2>&1 | tail -2
if [ -f "$WORK/input/bin1_sorf_131816.fa" ] ; then
  echo "LOCAL_FASTA=$WORK/input/bin1_sorf_131816.fa"
  echo "LOCAL_BYTES=$(stat -c%s "$WORK/input/bin1_sorf_131816.fa")"
  echo "LOCAL_SEQS=$(grep -c '^>' "$WORK/input/bin1_sorf_131816.fa")"
  echo "LOCAL_SHA256=$(sha256sum "$WORK/input/bin1_sorf_131816.fa" | cut -d' ' -f1)"
else
  echo "FETCH_FAILED"
fi

echo
echo "=== 2. also fetch the HQ MAG and small evidence files ==="
for p in \
  "result/bin/HQ_MAGs/bin.1.fa" \
  "result/bin/metawrap_50_10_bins.stats" \
  "result/bin/tax.bac120.summary.tsv" \
  "result/metadata.txt" ; do
  n=$(basename "$p")
  scp -q -o BatchMode=yes "mu01:$E/$p" "$WORK/evidence/$n" 2>/dev/null && echo "got $n ($(stat -c%s "$WORK/evidence/$n") B)" || echo "miss $p"
done

echo
echo "=== 3. harvest real parameters from logs on the cluster ==="
cat > /tmp/params.sh <<"REMOTE"
E=/mnt/hpc/home/25menglei/25wenshaohua/wsh-eyu/easy_98
echo "### metadata.txt"
cat "$E/result/metadata.txt" 2>/dev/null
echo
echo "### metawrap_50_10_bins.stats"
cat "$E/result/bin/metawrap_50_10_bins.stats" 2>/dev/null
echo
echo "### tax.bac120.summary.tsv (first 2 cols)"
cut -f1,2 "$E/result/bin/tax.bac120.summary.tsv" 2>/dev/null | head -10
echo
echo "### log dir listing"
ls -la "$E/log" 2>/dev/null | head -40
echo
echo "### megahit opts"
for f in "$E/temp/megahit/options.json" "$E/temp/megahit/opts.txt" "$E/temp/megahit/log" ; do
  if [ -f "$f" ] ; then echo "--- $f" ; head -40 "$f" | cut -c1-300 ; fi
done
echo
echo "### megahit assembly stats"
if [ -f "$E/temp/megahit/final.contigs.fa" ] ; then
  echo "contigs=$(grep -c '^>' "$E/temp/megahit/final.contigs.fa")"
  echo "bytes=$(stat -c%s "$E/temp/megahit/final.contigs.fa")"
  grep -m3 '^>' "$E/temp/megahit/final.contigs.fa"
fi
echo
echo "### kneaddata / qc logs"
ls -la "$E/temp/qc" 2>/dev/null | head -20
ls -la "$E/result/qc" 2>/dev/null | head -20
for f in $(find "$E/result/qc" "$E/temp/qc" -maxdepth 1 -name "*.txt" -o -maxdepth 1 -name "*.log" -o -maxdepth 1 -name "*.tsv" 2>/dev/null | head -4) ; do
  echo "--- $f" ; head -15 "$f" | cut -c1-250
done
echo
echo "### checkm full table"
if [ -f "$E/temp/checkm/storage/bin_stats_ext.tsv" ] ; then cat "$E/temp/checkm/storage/bin_stats_ext.tsv" ; fi
echo
echo "### all log files, any slurm scripts nearby"
find "$E" -maxdepth 2 -name "*.log" -o -maxdepth 2 -name "*.out" -o -maxdepth 2 -name "*.err" 2>/dev/null | head -30
echo
echo "### getorf / sorf step logs (bin.1 only)"
ls -la "$E/result/bin.1_getorf_sorf/log" 2>/dev/null | head -12
ls -la "$E/result/bin.1_getorf_sorf/04_stats" 2>/dev/null
for f in $(find "$E/result/bin.1_getorf_sorf/04_stats" -type f 2>/dev/null | head -5) ; do
  echo "--- $f" ; head -30 "$f" | cut -c1-250
done
for f in $(find "$E/result/bin.1_getorf_sorf/log" -type f 2>/dev/null | head -3) ; do
  echo "--- $f" ; head -25 "$f" | cut -c1-250
done
echo
echo "### history: how easy_98 was driven"
H=/mnt/hpc/home/25menglei/25wenshaohua/.bash_history
grep -aiE "easy_98|eyu|getorf|SRR1811" "$H" 2>/dev/null | tail -60
REMOTE
timeout 300 ssh -o BatchMode=yes mu01 "bash -s" < /tmp/params.sh 2>&1
rm -f /tmp/params.sh
'@

$tmp = Join-Path $repo "fetch1.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("H| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "bin1_fetch_and_params.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))

$txt = ($o | Out-String)
if ($txt -match "LOCAL_SEQS=131816") { Write-Output "BIN1_FASTA_OK=True" } else { Write-Output "BIN1_FASTA_OK=False" }
Write-Output "FETCH_AND_PARAMS_DONE=True"
