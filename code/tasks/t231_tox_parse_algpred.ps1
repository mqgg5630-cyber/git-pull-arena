$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
S=$HOME/eyu_repro/stage3
V=$HOME/miniconda3/envs/ampfilter

echo "=== toxinpred2 output header + 3 rows ==="
head -4 "$S/toxinpred2_raw.csv"

echo
echo "=== counts at several thresholds ==="
"$V/bin/python" - <<"PY"
import os, csv
S=os.path.expanduser("~/eyu_repro/stage3")
rows=list(csv.DictReader(open(os.path.join(S,"toxinpred2_raw.csv"))))
print("rows=%d" % len(rows))
print("columns=%s" % list(rows[0].keys()))
import collections
# find score and label columns
scol=None; lcol=None
for k in rows[0]:
    kl=k.strip().lower()
    if "score" in kl or "ml score" in kl: scol=k
    if "prediction" in kl: lcol=k
print("score_col=%r label_col=%r" % (scol,lcol))
if lcol:
    print(collections.Counter(r[lcol].strip() for r in rows))
if scol:
    vals=[]
    for r in rows:
        try: vals.append(float(r[scol]))
        except Exception: pass
    for t in (0.5,0.6,0.7,0.8):
        print("  non-toxin (score < %.1f): %d" % (t, sum(1 for v in vals if v < t)))

# write non-toxin set at default threshold using the label
keep=[r for r in rows if lcol and r[lcol].strip().lower().startswith("non")]
print("NON_TOXIN_BY_LABEL=%d" % len(keep))
idc=[k for k in rows[0] if k.strip().lower() in ("id","seq_id","sequence id","#")] or [list(rows[0])[0]]
seqc=[k for k in rows[0] if "sequence" in k.strip().lower()]
print("id_col=%r seq_col=%r" % (idc[0], seqc[0] if seqc else None))
with open(os.path.join(S,"non_toxin.fa"),"w") as fh:
    for r in keep:
        sid=r[idc[0]].strip().lstrip(">")
        sq=(r[seqc[0]].strip() if seqc else "")
        fh.write(">%s\n%s\n" % (sid,sq))
print("wrote non_toxin.fa")
PY
echo "NON_TOXIN_SEQS=$(grep -c '^>' "$S/non_toxin.fa" 2>/dev/null)"

echo
echo "=== run algpred2 on the non-toxin set, exactly as the user did (-t 0.3 -m 1 -d 2) ==="
if [ -s "$S/non_toxin.fa" ] ; then
  cd "$S" || exit 0
  timeout 1200 "$V/bin/algpred2" -i "$S/non_toxin.fa" -o "$S/algpred2_raw.csv" -t 0.3 -m 1 -d 2 \
    > "$S/algpred2.log" 2>&1
  echo "algpred2_exit=$?"
  tail -12 "$S/algpred2.log"
  [ -f "$S/algpred2_raw.csv" ] && echo "ALG_ROWS=$(wc -l < "$S/algpred2_raw.csv")" && head -3 "$S/algpred2_raw.csv"
fi

echo
echo "=== files ==="
ls -la "$S" | head -20
'@

$tmp = Join-Path $repo "tox2.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("A| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "tox_parse_algpred.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "TOX_PARSE_ALGPRED_DONE=True"
