$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
D=/mnt/e/huifu/e-yu
R="$D/bin.1_getorf_sorf/03_filter/c_AMP_prediction_3models"
L="$R/liucheng2_mmseqs_pepfun_toxinpred2_algpred2_top12"

show() {
  f="$1" ; n="$2"
  [ -f "$f" ] || { echo "MISSING $f" ; return ; }
  echo "########## $f  ($(stat -c%s "$f") B)  type: $(file -b "$f")"
  python3 - "$f" "$n" <<"PY"
import sys
p,n=sys.argv[1],int(sys.argv[2])
raw=open(p,"rb").read()
for enc in ("utf-8","utf-16","utf-16le","gbk","latin-1"):
    try:
        t=raw.decode(enc)
        if "\x00" in t: continue
        break
    except Exception: continue
t=t.replace("\r\n","\n").replace("\r","\n")
lines=[x for x in t.split("\n")]
print("ENC=%s TOTAL_LINES=%d" % (enc,len(lines)))
print("FASTA_HEADERS=%d" % sum(1 for x in lines if x.startswith(">")))
for x in lines[:n]:
    print("  "+x[:220])
PY
  echo "########## end"
}

echo "=== funnel tables ==="
show "$R/summary_counts.tsv" 20
show "$L/selection_summary.txt" 20
show "$R/../c_AMP_prediction_3models/liucheng2_mmseqs_pepfun_toxinpred2_top12/step_counts.tsv" 30
show "$L/hard_filter_all.summary.txt" 30

echo
echo "=== sequence sets, counted properly ==="
for f in "$L/05_seed_for_pepfun.fa" "$L/hard_filter_all.fa" "$L/hard_filter_all.simple.fa" "$L/top12_for_synthesis.fa" \
         "$D/algpred2_result/non_allergen.fa" "$D/algpred2_result/allergen.fa" "$D/pepfun.fa" "$D/non_allergen.fasta" ; do
  if [ -f "$f" ] ; then
    c=$(tr -d "\000" < "$f" | tr "\r" "\n" | grep -c "^>")
    echo "$c seqs   $(stat -c%s "$f") B   $f"
  fi
done

echo
echo "=== top12_for_synthesis.fa full ==="
tr -d "\000" < "$L/top12_for_synthesis.fa" 2>/dev/null | tr "\r" "\n" | head -40

echo
echo "=== 05_seed_for_pepfun.tsv header + 3 rows ==="
show "$L/05_seed_for_pepfun.tsv" 4

echo
echo "=== 06_pepfun_metrics.tsv header + 3 rows ==="
show "$L/06_pepfun_metrics.tsv" 4

echo
echo "=== hard_filter_all.tsv header + 5 rows ==="
show "$L/hard_filter_all.tsv" 6

echo
echo "=== the method note the user wrote ==="
show "$D/bin3_getorf_sorf/eyu-method.txt" 80
'@

$tmp = Join-Path $repo "eyuc.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("N| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "eyu_counts.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "EYU_COUNTS_DONE=True"
