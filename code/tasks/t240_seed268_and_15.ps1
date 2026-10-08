$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
AF=$HOME/miniconda3/envs/ampfilter
AG=$HOME/miniconda3/envs/algenv
S=$HOME/eyu_repro/stage3
W=$HOME/eyu_repro/stage4
mkdir -p "$W"

"$AF/bin/python" - <<"PY"
import os, itertools, json
from Bio.SeqUtils.ProtParam import ProteinAnalysis
S=os.path.expanduser("~/eyu_repro/stage3"); W=os.path.expanduser("~/eyu_repro/stage4")
ids=[];seqs=[];cur=None;buf=[]
for line in open(os.path.join(S,"non_toxin.fa")):
    line=line.rstrip("\n")
    if line.startswith(">"):
        if cur is not None: ids.append(cur);seqs.append("".join(buf))
        cur=line[1:].strip();buf=[]
    else: buf.append(line.strip())
if cur is not None: ids.append(cur);seqs.append("".join(buf))
STD=set("ACDEFGHIKLMNPQRSTVWY")
P=[]
for i,s in zip(ids,seqs):
    if not s or set(s)-STD: continue
    a=ProteinAnalysis(s)
    P.append(dict(id=i,seq=s,L=len(s),ii=a.instability_index(),gr=a.gravy(),
                  pI=a.isoelectric_point(),ch=a.charge_at_pH(7.0),
                  ar=a.aromaticity(),cys=s.count("C"),
                  kr=(s.count("K")+s.count("R"))/len(s)))
print("pool=%d" % len(P))
T={"FVNKLNRIIPVKGFSMR":"P1","LISNTKKFGTAIASHR":"P2","ISLAIPLASKISGFTLALVKNAST":"P3"}

Lmins=[0,5,10,11,12]; Lmaxs=[25,30,40,50,999]
chmins=[-99,0,1.0,1.5,1.7]
grmaxs=[99,1.5,1.2,1.1]; grmins=[-99,-1.5,-1.0]
cysopt=[None,0]; armaxs=[99,0.4,0.3,0.2]
pImins=[-99,8.0,9.0]; krmins=[-99,0.1,0.15,0.2]

exact=[];k49=[];seed268=[]
for lmin,lmax,chmin,grmax,grmin,cy,arm,pim,krm in itertools.product(
        Lmins,Lmaxs,chmins,grmaxs,grmins,cysopt,armaxs,pImins,krmins):
    sub=[p for p in P if lmin<=p["L"]<=lmax and p["ch"]>=chmin
         and grmin<=p["gr"]<=grmax and (cy is None or p["cys"]==cy)
         and p["ar"]<=arm and p["pI"]>=pim and p["kr"]>=krm]
    n=len(sub)
    if not (180 <= n <= 360): continue
    keep=[p for p in sub if p["ii"]<40]; k=len(keep)
    ks={p["seq"] for p in keep}
    got=sorted(T[s] for s in T if s in ks)
    desc="len %s..%s ch>=%s gravy %s..%s cys=%s arom<=%s pI>=%s KR>=%s"%(lmin,lmax,chmin,grmin,grmax,cy,arm,pim,krm)
    rec=dict(seed=n,hard=k,kept=",".join(got),desc=desc,
             ids=[p["id"] for p in keep], seqs=[p["seq"] for p in keep])
    if n==268 and k==49 and len(got)==3: exact.append(rec)
    elif n==268: seed268.append(rec)
    elif k==49 and len(got)==3: k49.append(rec)

print("EXACT(seed268+49+3):%d  seed268-only:%d  k49+3-only:%d"%(len(exact),len(seed268),len(k49)))
for r in (exact[:10] or []): print("  EXACT:",r["desc"])
for r in seed268[:10]: print("  seed268: hard=%d kept=%s | %s"%(r["hard"],r["kept"],r["desc"]))
for r in k49[:5]: print("  k49: seed=%d | %s"%(r["seed"],r["desc"]))

chosen = (exact or k49 or seed268)
json.dump(chosen[:1], open(os.path.join(W,"chosen.json"),"w"))
if chosen:
    c=chosen[0]
    print("CHOSEN:",c["desc"],"seed=",c["seed"],"hard=",c["hard"],"kept=",c["kept"])
    with open(os.path.join(W,"hard49.fa"),"w") as f:
        for i,s in zip(c["ids"],c["seqs"]): f.write(">%s\n%s\n"%(i,s))
PY

echo "=== hard49 count ==="
grep -c "^>" "$W/hard49.fa"

cd "$W"
"$AG/bin/algpred2" -i hard49.fa -o alg49.csv -t 0.3 -m 1 -d 2 2>&1 | tail -3
"$AF/bin/python" - <<"PY"
import csv,os,collections
W=os.path.expanduser("~/eyu_repro/stage4")
r=list(csv.DictReader(open(os.path.join(W,"alg49.csv"))))
c=collections.Counter(x["Prediction"].strip() for x in r)
print("ALGPRED on 49:",dict(c))
T={"FVNKLNRIIPVKGFSMR":"P1","LISNTKKFGTAIASHR":"P2","ISLAIPLASKISGFTLALVKNAST":"P3"}
na=[x for x in r if x["Prediction"].strip().lower().startswith("non")]
print("non_allergen=%d"%len(na))
print("kept:",sorted(T[x["Sequence"].strip()] for x in na if x["Sequence"].strip() in T))
for x in r:
    s=x["Sequence"].strip()
    if s in T: print(" ",T[s],x["ML_Score"],x["Prediction"])
with open(os.path.join(W,"alg49_nonallergen.fa"),"w") as f:
    for x in na: f.write(">%s\n%s\n"%(x["ID"].strip(),x["Sequence"].strip()))
PY
'@

$bash = $bash -replace "`r`n", "`n"
$tmp = "$env:TEMP\t240.sh"
[IO.File]::WriteAllText($tmp, $bash, (New-Object Text.UTF8Encoding($false)))
$wtmp = "/mnt/c" + ($tmp.Substring(2) -replace '\\','/')
$log = wsl.exe -d Ubuntu -- bash -lc "bash '$wtmp' 2>&1"
$log = ($log | Where-Object { $_ -notmatch "Predicting:" }) -join "`n"
[IO.File]::WriteAllText((Join-Path $out "seed268_and_15.txt"), $log, (New-Object Text.UTF8Encoding($false)))
Write-Output "DONE"
