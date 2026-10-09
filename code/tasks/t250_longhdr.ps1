$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
$data = Join-Path $repo "results\hpc\data"
New-Item -ItemType Directory -Force -Path $out  | Out-Null
New-Item -ItemType Directory -Force -Path $data | Out-Null

$bash = @'
set +e
AF=$HOME/miniconda3/envs/ampfilter
AG=$HOME/miniconda3/envs/algenv
H=$HOME/eyu_repro
W=$H/stage10
mkdir -p "$W/sub"; cd "$W"
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

# rebuild the 935 FASTA with the ORIGINAL long headers from consensus_amp.fa
"$AF/bin/python" - <<"PY"
import os
H=os.path.expanduser("~/eyu_repro"); W=os.path.join(H,"stage10")
def rf(p):
    recs=[];h=None;b=[]
    for line in open(p):
        line=line.rstrip()
        if not line: continue
        if line.startswith(">"):
            if h is not None: recs.append((h,"".join(b)))
            h=line[1:].strip();b=[]
        else: b.append(line.strip())
    if h is not None: recs.append((h,"".join(b)))
    return recs
cons=dict((s,h) for h,s in rf(os.path.join(H,"amp_results_bin1","consensus_amp.fa")))
nt=rf(os.path.join(H,"stage3","non_toxin.fa"))
n=0
with open(os.path.join(W,"non_toxin_longhdr.fa"),"w") as f:
    for h,s in nt:
        hh=cons.get(s,h)
        f.write(">%s\n%s\n"%(hh,s)); n+=1
print("wrote",n,"records with long headers")
PY
head -2 non_toxin_longhdr.fa

ln -sfn "$AG/lib/python3.9/site-packages/algpred2/model" "$W/model" 2>/dev/null
cd "$W/sub"
"$AG/bin/algpred2" -i ../non_toxin_longhdr.fa -o ../alg_longhdr.csv -t 0.3 -m 1 -d 2 2>&1 | tail -3
cd "$W"
wc -l alg_longhdr.csv 2>/dev/null
head -3 alg_longhdr.csv 2>/dev/null

"$AF/bin/python" - <<"PY"
import os, csv, collections
from Bio.SeqUtils.ProtParam import ProteinAnalysis
W=os.path.expanduser("~/eyu_repro/stage10")
KS=set(l.strip() for l in open(os.path.join(W,"known46.txt")) if l.strip())
p=os.path.join(W,"alg_longhdr.csv")
if not os.path.exists(p): print("NO OUTPUT"); raise SystemExit
r=list(csv.DictReader(open(p)))
pk=[k for k in r[0] if "rediction" in k][0]
sk=[k for k in r[0] if "equence" in k]
print("rows=%d" % len(r))
print(collections.Counter(x[pk].strip() for x in r))
if sk:
    sk=sk[0]
    na={x[sk].strip() for x in r if x[pk].strip().lower().startswith("non")}
    hard={s for s in na if set(s)<=set("ACDEFGHIKLMNPQRSTVWY") and ProteinAnalysis(s).instability_index()<40}
    print("non_allergen=%d covers46=%d/46 | inst<40 -> %d covers46=%d/46"
          % (len(na),len(KS&na),len(hard),len(KS&hard)))
# positional join back onto the 935 order
def rf(p):
    recs=[];h=None;b=[]
    for line in open(p):
        line=line.rstrip()
        if not line: continue
        if line.startswith(">"):
            if h is not None: recs.append((h,"".join(b)))
            h=line[1:].strip();b=[]
        else: b.append(line.strip())
    if h is not None: recs.append((h,"".join(b)))
    return recs
seqs=[s for _,s in rf(os.path.join(W,"non_toxin_longhdr.fa"))]
preds=[x[pk].strip().lower() for x in r]
for shift in range(-2,3):
    sel=[s for i,s in enumerate(seqs) if 0<=i+shift<len(preds) and preds[i+shift].startswith("non")]
    hard=[s for s in sel if set(s)<=set("ACDEFGHIKLMNPQRSTVWY") and ProteinAnalysis(s).instability_index()<40]
    print("  posjoin shift=%+d kept=%d covers46=%d/46 | inst<40 -> %d covers46=%d/46"
          % (shift,len(sel),len(KS&set(sel)),len(hard),len(KS&set(hard))))
PY
'@

$tmp = Join-Path $repo "lh.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o = $o | Where-Object { $_ -notmatch "Predicting:" }
$o | ForEach-Object { Write-Output ("F| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "longhdr.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))

$cp = @'
set +e
D="$1"; mkdir -p "$D"
cp -f "$HOME/eyu_repro/stage10/alg_longhdr.csv" "$D/algpred2_935_longhdr.csv" 2>/dev/null
ls -l "$D/algpred2_935_longhdr.csv"
'@
$tmp2 = Join-Path $repo "cp5.sh"
[IO.File]::WriteAllText($tmp2, ($cp -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$wslPath2 = "/mnt/" + $drive + ($tmp2.Substring(2) -replace '\\','/')
$dataWsl = "/mnt/" + $data.Substring(0,1).ToLower() + ($data.Substring(2) -replace '\\','/')
$o2 = & wsl.exe bash $wslPath2 $dataWsl 2>&1
Remove-Item -LiteralPath $tmp2 -Force -ErrorAction SilentlyContinue
$o2 | ForEach-Object { Write-Output ("C| " + $_) }
Write-Output "LONGHDR_DONE=True"
