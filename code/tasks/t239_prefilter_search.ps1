$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
AF=$HOME/miniconda3/envs/ampfilter
"$AF/bin/python" - <<"PY"
import os, csv, itertools
from Bio.SeqUtils.ProtParam import ProteinAnalysis
S=os.path.expanduser("~/eyu_repro/stage3")

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
                  ar=a.aromaticity(),
                  cys=s.count("C"), K=s.count("K"), R=s.count("R")))
print("pool=%d" % len(P))
T={"FVNKLNRIIPVKGFSMR":"P1","LISNTKKFGTAIASHR":"P2","ISLAIPLASKISGFTLALVKNAST":"P3"}
targets=set(T)

Lmins=[0,5,8,10,11,12]
Lmaxs=[25,30,35,40,45,50,60,999]
chmins=[-99,0,0.5,1.0,1.5,1.7,2.0]
grmaxs=[99,2.0,1.5,1.2,1.1,1.0]
grmins=[-99,-2.0,-1.5,-1.2,-1.0]
cysopt=[None,0]   # None = no constraint, 0 = must have no cysteine

hits=[]
near=[]
for lmin,lmax,chmin,grmax,grmin,cy in itertools.product(Lmins,Lmaxs,chmins,grmaxs,grmins,cysopt):
    sub=[p for p in P if lmin<=p["L"]<=lmax and p["ch"]>=chmin
         and p["gr"]<=grmax and p["gr"]>=grmin
         and (cy is None or p["cys"]==cy)]
    n=len(sub)
    if not (200 <= n <= 340): continue
    keep=[p for p in sub if p["ii"]<40]
    k=len(keep)
    ks={p["seq"] for p in keep}
    got=sorted(T[s] for s in targets if s in ks)
    rec=(n,k,len(got),lmin,lmax,chmin,grmax,grmin,cy,",".join(got))
    if n==268 and k==49 and len(got)==3: hits.append(rec)
    elif (n==268 and k==49) or (k==49 and len(got)==3) or (n==268 and len(got)==3): near.append(rec)

print()
print("EXACT HITS (seed=268, instability<40 = 49, all three kept): %d" % len(hits))
for r in hits[:20]:
    print("   seed=%d hard=%d kept=%s | len %d..%d charge>=%s gravy %s..%s cys=%s"
          % (r[0],r[1],r[9],r[3],r[4],r[5],r[7],r[6],r[8]))
print()
print("NEAR MISSES: %d (showing 25)" % len(near))
for r in near[:25]:
    print("   seed=%d hard=%d kept=%s | len %d..%d charge>=%s gravy %s..%s cys=%s"
          % (r[0],r[1],r[9],r[3],r[4],r[5],r[7],r[6],r[8]))

print()
print("=== reference: unconstrained ===")
print("  pool instability<40 = %d" % sum(1 for p in P if p["ii"]<40))
for s,n in T.items():
    p=[x for x in P if x["seq"]==s]
    if p:
        p=p[0]
        print("  %s L=%d ii=%.2f gravy=%.3f charge=%.2f cys=%d" % (n,p["L"],p["ii"],p["gr"],p["ch"],p["cys"]))
PY
'@

$tmp = Join-Path $repo "pre.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("F| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "prefilter_search.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "PREFILTER_SEARCH_DONE=True"
