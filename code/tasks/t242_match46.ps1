$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
AF=$HOME/miniconda3/envs/ampfilter
AG=$HOME/miniconda3/envs/algenv
W=$HOME/eyu_repro/stage4
mkdir -p "$W"
cat > "$W/known46.txt" <<"EOS"
AYGKPFSFKKGL
VSTLKAMSLKL
WRPTVLRKVSA
THWKSAA
QPWRPPGHFADRYG
YRPGPIHKTVWRPGTGAKVRFRT
DTPHWVPTKAAG
WPRTSATSHPYTPPGWRP
KWSHFSRI
KIYKQYKSI
WGTWQKAPK
SAIPNKSKPLPM
TYWKPIRATS
WSGHRPRPLRTHTW
KPLHPVSTWK
GPPGWTDHPAF
KWPAQLHT
FVNKLNRIIPVKGFSMR
AIKSKNKITKRVQLE
NGAGLHFRYGAATGWHHKNMS
IPGRAQHAGTANHAG
RHGRAVYQIQRHAGKGVPYL
WRGPSAGYPHP
YRLKDLGKPLLSTLQKIKKQGNLKYLMKA
GWFLGHPTGSSGRHPGYR
GDHVRHIFKPVFKIITYAFQRIKLKKRD
PPGFFGT
YWIASKVR
LISNTKKFGTAIASHR
HWPTVSISIHL
SHAGKGPWQAVPTGWRSGPR
WGKPGPAHQVIPSVVSLK
RGYHRPR
KPWLTAWPTAS
YWPSWVR
SAFFAHKITARQWRAVLIGVSRGSARCGHRSV
ISLAIPLASKISGFTLALVKNAST
NSMGPKAIFWASLMASSAL
KWISTVISVQYSGIWCQMQ
FHRGPGAHLPFRGGAGAGTGIGAAARYAQRRFRAQPV
CPRSHSVGPRCRGRYGARLSGRAVTAAGRARHRGGAFQLSLHEQAGPGW
FSLVRTWPRWIVQPSSWPTPPRGAMC
SLTAQGRAPAISASGTAGLSIWTC
EATSSDWGFLAGAGGSWGSGGSR
SIGAIVRLWCPVLRGPGWRGGGSAATISCCNHSHLQTITMQTGHHANTSQ
SATFFGPIPPVGQNFTWGRGAAMAASALVPPFASAGKNLRWS
EOS

"$AF/bin/python" - <<"PY"
import os, itertools
from Bio.SeqUtils.ProtParam import ProteinAnalysis
S=os.path.expanduser("~/eyu_repro/stage3"); W=os.path.expanduser("~/eyu_repro/stage4")
K=[l.strip() for l in open(os.path.join(W,"known46.txt")) if l.strip()]
KS=set(K); print("known46=%d" % len(KS))
ids=[];seqs=[];cur=None;buf=[]
for line in open(os.path.join(S,"non_toxin.fa")):
    line=line.rstrip("\n")
    if line.startswith(">"):
        if cur is not None: ids.append(cur);seqs.append("".join(buf))
        cur=line[1:].strip();buf=[]
    else: buf.append(line.strip())
if cur is not None: ids.append(cur);seqs.append("".join(buf))
pool=set(seqs)
print("pool=%d  known46 in non_toxin pool=%d" % (len(seqs), len(KS&pool)))
miss=sorted(KS-pool)
print("missing from 935:", len(miss))
for m in miss[:50]: print("   MISS", len(m), m)

STD=set("ACDEFGHIKLMNPQRSTVWY")
P=[]
for i,s in zip(ids,seqs):
    if not s or set(s)-STD: continue
    a=ProteinAnalysis(s)
    P.append(dict(id=i,seq=s,L=len(s),ii=a.instability_index(),gr=a.gravy(),
                  pI=a.isoelectric_point(),ch=a.charge_at_pH(7.0),
                  ar=a.aromaticity(),cys=s.count("C"),
                  kr=(s.count("K")+s.count("R"))/len(s)))
inpool=[p for p in P if p["seq"] in KS]
print("known46 with clean AA alphabet: %d" % len(inpool))
if inpool:
    print("  L  min=%d max=%d" % (min(p["L"] for p in inpool), max(p["L"] for p in inpool)))
    print("  ii min=%.2f max=%.2f" % (min(p["ii"] for p in inpool), max(p["ii"] for p in inpool)))
    print("  ch min=%.2f max=%.2f" % (min(p["ch"] for p in inpool), max(p["ch"] for p in inpool)))
    print("  gr min=%.3f max=%.3f" % (min(p["gr"] for p in inpool), max(p["gr"] for p in inpool)))
    print("  pI min=%.2f max=%.2f" % (min(p["pI"] for p in inpool), max(p["pI"] for p in inpool)))
    print("  ar min=%.3f max=%.3f" % (min(p["ar"] for p in inpool), max(p["ar"] for p in inpool)))
    print("  cys values:", sorted(set(p["cys"] for p in inpool)))
    over40=[p for p in inpool if p["ii"]>=40]
    print("  known46 with instability>=40: %d" % len(over40))
    for p in over40[:10]: print("    ", p["seq"], "ii=%.2f" % p["ii"])

Lmins=[0,5,10,11,12]; Lmaxs=[25,30,40,50,60,999]
chmins=[-99,0,0.5,1.0,1.5,1.7]
grmaxs=[99,1.5,1.2,1.1]; grmins=[-99,-1.5,-1.0]
cysopt=[None,0]; armaxs=[99,0.4,0.3,0.2]
best=[]
for lmin,lmax,chmin,grmax,grmin,cy,arm in itertools.product(Lmins,Lmaxs,chmins,grmaxs,grmins,cysopt,armaxs):
    sub=[p for p in P if lmin<=p["L"]<=lmax and p["ch"]>=chmin
         and grmin<=p["gr"]<=grmax and (cy is None or p["cys"]==cy) and p["ar"]<=arm]
    keep=[p for p in sub if p["ii"]<40]
    ks={p["seq"] for p in keep}
    cov=len(KS&ks)
    best.append((cov,-abs(len(keep)-49),len(sub),len(keep),
        "len %s..%s ch>=%s gravy %s..%s cys=%s arom<=%s"%(lmin,lmax,chmin,grmin,grmax,cy,arm)))
best.sort(reverse=True)
print()
print("TOP combos by coverage of the known 46:")
for b in best[:15]: print("  cov=%d/46 seed=%d hard=%d | %s" % (b[0],b[2],b[3],b[4]))
PY
'@

$tmp = Join-Path $repo "m46.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o = $o | Where-Object { $_ -notmatch "Predicting:" }
$o | ForEach-Object { Write-Output ("F| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "match46.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "MATCH46_DONE=True"
