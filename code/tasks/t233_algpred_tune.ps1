$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
S=$HOME/eyu_repro/stage3
A=$HOME/miniconda3/envs/algenv

echo "=== 1. threshold scan on the existing m=1 scores (target non-allergen = 268) ==="
"$A/bin/python" - <<"PY"
import os, csv
S=os.path.expanduser("~/eyu_repro/stage3")
rows=list(csv.DictReader(open(os.path.join(S,"algpred2_raw.csv"))))
sc=[float(r["ML_Score"]) for r in rows]
print("n=%d" % len(sc))
best=None
t=0.05
while t <= 0.95001:
    n=sum(1 for v in sc if v < t)
    flag=""
    if n==268: flag="   <<< MATCHES 268"
    if best is None or abs(n-268) < abs(best[1]-268): best=(t,n)
    print("  t=%.2f -> non-allergen=%d%s" % (t,n,flag))
    t+=0.05
print("closest: t=%.2f n=%d" % best)
PY

echo
echo "=== 2. try the hybrid model (-m 2) at the user threshold ==="
cd "$S" || exit 0
timeout 1500 "$A/bin/algpred2" -i "$S/non_toxin.fa" -o "$S/algpred2_m2.csv" -t 0.3 -m 2 -d 2 \
  > "$S/algpred2_m2.log" 2>&1
echo "m2_exit=$?"
tail -6 "$S/algpred2_m2.log"
if [ -s "$S/algpred2_m2.csv" ] ; then
  echo "M2_ROWS=$(wc -l < "$S/algpred2_m2.csv")"
  head -3 "$S/algpred2_m2.csv"
  "$A/bin/python" - <<"PY"
import os, csv, collections
S=os.path.expanduser("~/eyu_repro/stage3")
rows=list(csv.DictReader(open(os.path.join(S,"algpred2_m2.csv"))))
print("columns=%s" % list(rows[0].keys()))
lc=[k for k in rows[0] if "prediction" in k.lower()]
if lc:
    c=collections.Counter(r[lc[0]].strip() for r in rows)
    print(c)
    print("M2_NON_ALLERGEN=%d" % sum(v for k,v in c.items() if "non" in k.lower()))
PY
fi

echo
echo "=== 3. also try m=1 on the full 13294 (in case algpred2 came before toxinpred2) ==="
timeout 1700 "$A/bin/algpred2" -i "$S/in.fa" -o "$S/algpred2_full.csv" -t 0.3 -m 1 -d 2 \
  > "$S/algpred2_full.log" 2>&1
echo "full_exit=$?"
if [ -s "$S/algpred2_full.csv" ] ; then
  "$A/bin/python" - <<"PY"
import os, csv, collections
S=os.path.expanduser("~/eyu_repro/stage3")
rows=list(csv.DictReader(open(os.path.join(S,"algpred2_full.csv"))))
c=collections.Counter(r["Prediction"].strip() for r in rows)
print("full rows=%d" % len(rows), c)
na=set(r["ID"] for r in rows if "non" in r["Prediction"].lower())
print("FULL_NON_ALLERGEN=%d" % len(na))
tox=list(csv.DictReader(open(os.path.join(S,"toxinpred2_raw.csv"))))
nt=set(r["ID"] for r in tox if "non" in r["Prediction"].lower())
print("NON_TOXIN=%d" % len(nt))
print("INTERSECT_nonAllergen_AND_nonToxin=%d" % len(na & nt))
PY
fi
'@

$tmp = Join-Path $repo "algt.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("U| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "algpred_tune.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "ALGPRED_TUNE_DONE=True"
