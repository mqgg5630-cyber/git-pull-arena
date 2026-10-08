$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
AF=$HOME/miniconda3/envs/ampfilter
W=$HOME/eyu_repro/stage5
mkdir -p "$W"; cd "$W"
cat > known46.txt <<"EOS"
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
import os
from Bio.SeqUtils.ProtParam import ProteinAnalysis
S=os.path.expanduser("~/eyu_repro/stage3"); W=os.path.expanduser("~/eyu_repro/stage5")
K=[l.strip() for l in open(os.path.join(W,"known46.txt")) if l.strip()]
KS=set(K)
ids=[];seqs=[];cur=None;buf=[]
for line in open(os.path.join(S,"non_toxin.fa")):
    line=line.rstrip("\n")
    if line.startswith(">"):
        if cur is not None: ids.append(cur);seqs.append("".join(buf))
        cur=line[1:].strip();buf=[]
    else: buf.append(line.strip())
if cur is not None: ids.append(cur);seqs.append("".join(buf))
# toxin scores
tox={}
import csv as _csv
for row in _csv.DictReader(open(os.path.join(S,"toxinpred2_raw.csv"))):
    tox[row["Sequence"].strip()]=row["ML_Score"]
# algpred scores on the 935
alg={}
p=os.path.join(S,"algpred2_raw.csv")
if os.path.exists(p):
    for row in _csv.DictReader(open(p)):
        alg[row["Sequence"].strip()]=row["ML_Score"]
STD=set("ACDEFGHIKLMNPQRSTVWY")
cols=["id","seq","known46","L","instability","gravy","charge7","pI","aromaticity","cys","trp","KR_frac","helix","turn","sheet","mw","ext","tox_ml","alg_ml"]
rows=[]
for i,s in zip(ids,seqs):
    if not s or set(s)-STD: continue
    a=ProteinAnalysis(s)
    ii=a.instability_index()
    if ii>=40: continue
    h,t,sh=a.secondary_structure_fraction()
    rows.append([i,s,int(s in KS),len(s),round(ii,3),round(a.gravy(),4),
        round(a.charge_at_pH(7.0),3),round(a.isoelectric_point(),3),
        round(a.aromaticity(),4),s.count("C"),s.count("W"),
        round((s.count("K")+s.count("R"))/len(s),4),
        round(h,4),round(t,4),round(sh,4),round(a.molecular_weight(),2),
        a.molar_extinction_coefficient()[0],
        tox.get(s,""),alg.get(s,"")])
with open(os.path.join(W,"inst153_features.tsv"),"w") as f:
    f.write("\t".join(cols)+"\n")
    for r in rows: f.write("\t".join(map(str,r))+"\n")
print("rows=%d known=%d" % (len(rows), sum(r[2] for r in rows)))
PY
cat "$W/inst153_features.tsv"
'@

$tmp = Join-Path $repo "feat.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o = $o | Where-Object { $_ -notmatch "Predicting:" }
[IO.File]::WriteAllLines((Join-Path $out "inst153_features.tsv"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "FEAT_DONE=True"
