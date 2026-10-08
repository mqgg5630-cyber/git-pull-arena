$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
AF=$HOME/miniconda3/envs/ampfilter
AG=$HOME/miniconda3/envs/algenv
CO=$HOME/miniconda3/bin/conda
W=$HOME/eyu_repro/stage5
mkdir -p "$W"
cd "$W"
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

# 1. build the 153 set (instability < 40 of the 935 non-toxin)
"$AF/bin/python" - <<"PY"
import os
from Bio.SeqUtils.ProtParam import ProteinAnalysis
S=os.path.expanduser("~/eyu_repro/stage3"); W=os.path.expanduser("~/eyu_repro/stage5")
ids=[];seqs=[];cur=None;buf=[]
for line in open(os.path.join(S,"non_toxin.fa")):
    line=line.rstrip("\n")
    if line.startswith(">"):
        if cur is not None: ids.append(cur);seqs.append("".join(buf))
        cur=line[1:].strip();buf=[]
    else: buf.append(line.strip())
if cur is not None: ids.append(cur);seqs.append("".join(buf))
STD=set("ACDEFGHIKLMNPQRSTVWY")
out=[]
for i,s in zip(ids,seqs):
    if not s or set(s)-STD: continue
    if ProteinAnalysis(s).instability_index()<40: out.append((i,s))
with open(os.path.join(W,"inst153.fa"),"w") as f:
    for i,s in out: f.write(">%s\n%s\n"%(i,s))
print("inst153 =", len(out))
K=set(l.strip() for l in open(os.path.join(W,"known46.txt")) if l.strip())
print("known46 inside inst153 =", len(K & {s for _,s in out}))
PY

echo "=== A. algenv (py3.9 sklearn1.1.3) AlgPred2 on the 153 ==="
mkdir -p a && cd a && ln -sfn "$AG/lib/python3.9/site-packages/algpred2/model" ../model 2>/dev/null
"$AG/bin/algpred2" -i ../inst153.fa -o ../alg153_py39.csv -t 0.3 -m 1 -d 2 2>&1 | tail -2
cd "$W"

echo "=== B. build py3.11 env like the user script ==="
if [ ! -x "$HOME/miniconda3/envs/alg311/bin/pip" ]; then
  "$CO" create -y -n alg311 --override-channels -c conda-forge python=3.11 pip 2>&1 | tail -3
fi
P311=$HOME/miniconda3/envs/alg311
"$P311/bin/pip" install -q "pandas==2.2.3" numpy scikit-learn joblib algpred2 2>&1 | tail -3
"$P311/bin/python" -c "import sklearn,pandas,numpy;print('sklearn',sklearn.__version__,'pandas',pandas.__version__,'numpy',numpy.__version__)"
"$P311/bin/python" - <<"PY"
import inspect
from pathlib import Path
import algpred2.python_scripts.algpred2 as m
p=Path(inspect.getsourcefile(m)); t=p.read_text(encoding="utf-8")
old='CM.to_csv("Sequence_1",header=False,index=None,sep="\n")'
new='Path("Sequence_1").write_text("\n".join(map(str, CM.iloc[:,0].tolist())) + "\n", encoding="utf-8")'
if old in t:
    if 'from pathlib import Path\n' not in t:
        t=t.replace('import warnings\n','import warnings\nfrom pathlib import Path\n',1)
    p.write_text(t.replace(old,new),encoding="utf-8"); print("patched",p)
else: print("patch target not found (ok)",p)
PY
mkdir -p b && cd b && ln -sfn "$P311/lib/python3.11/site-packages/algpred2/model" ../model 2>/dev/null
"$P311/bin/algpred2" -i ../inst153.fa -o ../alg153_py311.csv -t 0.3 -m 1 -d 2 2>&1 | tail -5
cd "$W"

echo "=== C. compare ==="
"$AF/bin/python" - <<"PY"
import csv,os,collections
W=os.path.expanduser("~/eyu_repro/stage5")
K=set(l.strip() for l in open(os.path.join(W,"known46.txt")) if l.strip())
for tag in ["alg153_py39.csv","alg153_py311.csv"]:
    p=os.path.join(W,tag)
    if not os.path.exists(p): print(tag,"MISSING"); continue
    r=list(csv.DictReader(open(p)))
    c=collections.Counter(x["Prediction"].strip() for x in r)
    na={x["Sequence"].strip() for x in r if x["Prediction"].strip().lower().startswith("non")}
    print(tag, dict(c), "non_allergen=%d"%len(na), "covers known46: %d/46"%len(K&na))
    # threshold sweep
    for t in [0.2,0.25,0.3,0.35,0.4,0.45,0.5]:
        s={x["Sequence"].strip() for x in r if float(x["ML_Score"])<t}
        print("   t=%.2f -> %d kept, covers %d/46"%(t,len(s),len(K&s)))
PY
'@

$tmp = Join-Path $repo "a311.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o = $o | Where-Object { $_ -notmatch "Predicting:" }
$o | ForEach-Object { Write-Output ("F| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "alg311.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "ALG311_DONE=True"
