$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
S=$HOME/eyu_repro/stage3
V=$HOME/miniconda3/envs/ampfilter
A=$HOME/miniconda3/envs/algenv

echo "=== A. instability filter applied to the 935 non-toxin set ==="
"$V/bin/python" - <<"PY"
import os, csv
from Bio.SeqUtils.ProtParam import ProteinAnalysis
S=os.path.expanduser("~/eyu_repro/stage3")
idmap={}
for row in csv.DictReader(open(os.path.join(S,"idmap.tsv")),delimiter="\t"):
    idmap[row["short"]]=row["original"]
ids=[];seqs=[];cur=None;buf=[]
for line in open(os.path.join(S,"non_toxin.fa")):
    line=line.rstrip("\n")
    if line.startswith(">"):
        if cur is not None: ids.append(cur);seqs.append("".join(buf))
        cur=line[1:].strip();buf=[]
    else: buf.append(line.strip())
if cur is not None: ids.append(cur);seqs.append("".join(buf))
print("non_toxin=%d" % len(ids))
STD=set("ACDEFGHIKLMNPQRSTVWY")
rows=[]
for i,s in zip(ids,seqs):
    if not s or set(s)-STD: continue
    a=ProteinAnalysis(s)
    rows.append(dict(id=i,seq=s,length=len(s),instability=a.instability_index(),
        gravy=a.gravy(),pI=a.isoelectric_point(),charge=a.charge_at_pH(7.0),
        aromaticity=a.aromaticity(),mw=a.molecular_weight(),original=idmap.get(i,"")))
print("scored=%d" % len(rows))
for t in (30,35,38,39,40,41,42,45,50):
    print("  instability < %-3d : %d" % (t,sum(1 for r in rows if r["instability"]<t)))
keep=[r for r in rows if r["instability"]<40]
print("INSTABILITY_LT40_ON_935=%d" % len(keep))
T={"FVNKLNRIIPVKGFSMR":"P1","LISNTKKFGTAIASHR":"P2","ISLAIPLASKISGFTLALVKNAST":"P3"}
ks={r["seq"] for r in keep}
for s,n in T.items(): print("   %s present=%s" % (n, s in ks))
with open(os.path.join(S,"route_B_instability49.fa"),"w") as fh:
    for r in sorted(keep,key=lambda x:x["instability"]):
        fh.write(">%s\n%s\n" % (r["id"],r["seq"]))
with open(os.path.join(S,"route_B_instability49.tsv"),"w",newline="") as fh:
    w=csv.DictWriter(fh,fieldnames=list(rows[0].keys()),delimiter="\t"); w.writeheader()
    for r in sorted(keep,key=lambda x:x["instability"]): w.writerow(r)
print("wrote route_B_instability49.*")
PY

echo
echo "=== B. then AlgPred2 on that set ==="
if [ -s "$S/route_B_instability49.fa" ] ; then
  cd "$S" || exit 0
  timeout 900 "$A/bin/algpred2" -i "$S/route_B_instability49.fa" -o "$S/route_B_alg.csv" -t 0.3 -m 1 -d 2 > "$S/route_B_alg.log" 2>&1
  echo "exit=$?"
  "$A/bin/python" - <<"PY"
import os, csv, collections
S=os.path.expanduser("~/eyu_repro/stage3")
p=os.path.join(S,"route_B_alg.csv")
if os.path.exists(p):
    rows=list(csv.DictReader(open(p)))
    print("rows=%d" % len(rows), collections.Counter(r["Prediction"].strip() for r in rows))
    T={"FVNKLNRIIPVKGFSMR":"P1","LISNTKKFGTAIASHR":"P2","ISLAIPLASKISGFTLALVKNAST":"P3"}
    for r in rows:
        if r["Sequence"].strip() in T:
            print("   %s score=%s -> %s" % (T[r["Sequence"].strip()], r["ML_Score"], r["Prediction"]))
PY
fi

echo
echo "=== C. the 43-vs-49 gap: instability thresholds on the 388 ==="
echo "(already printed above for the 935 route)"
'@

$tmp = Join-Path $repo "ord.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("O| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "order_fix.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "ORDER_FIX_DONE=True"
