$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
$data = Join-Path $repo "results\hpc\data"
New-Item -ItemType Directory -Force -Path $out  | Out-Null
New-Item -ItemType Directory -Force -Path $data | Out-Null

$bash = @'
set +e
AF=$HOME/miniconda3/envs/ampfilter
S=$HOME/eyu_repro/stage3
W=$HOME/eyu_repro/stage6
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
import os, csv, collections
from Bio.SeqUtils.ProtParam import ProteinAnalysis
S=os.path.expanduser("~/eyu_repro/stage3"); W=os.path.expanduser("~/eyu_repro/stage6")
KS=set(l.strip() for l in open(os.path.join(W,"known46.txt")) if l.strip())
def read_fasta(p):
    recs=[];h=None;b=[]
    for line in open(p):
        line=line.strip()
        if not line: continue
        if line.startswith(">"):
            if h is not None: recs.append((h,"".join(b)))
            h=line[1:].strip();b=[]
        else: b.append(line)
    if h is not None: recs.append((h,"".join(b)))
    return recs
recs=read_fasta(os.path.join(S,"non_toxin.fa"))
print("records=%d" % len(recs))
raw=open(os.path.join(S,"algpred2_raw.csv")).read()
lines=[x.strip() for x in raw.splitlines() if x.strip()]
rows=[[p.strip() for p in (l.split("\t") if "\t" in l else l.split(","))] for l in lines]
print("csv lines (incl header)=%d" % len(rows))
for shift in (0,1,-1):
    out=[]
    for i,(h,s) in enumerate(recs):
        j=i+shift
        r=rows[j] if 0<=j<len(rows) else []
        low=" | ".join(r).lower()
        pred="non_allergen" if ("non-allergen" in low or "non allergen" in low) else ("allergen" if "allergen" in low else "unknown")
        out.append((h,s,pred))
    na=[x for x in out if x[2]=="non_allergen"]; nas={x[1] for x in na}
    hard=[x for x in na if ProteinAnalysis(x[1]).instability_index()<40]; hs={x[1] for x in hard}
    print("shift=%+d : non_allergen=%d covers46=%d/46 | inst<40 -> %d covers46=%d/46"
          % (shift,len(na),len(KS&nas),len(hard),len(KS&hs)))
r=list(csv.DictReader(open(os.path.join(S,"algpred2_raw.csv"))))
sc=[(x["Sequence"].strip(), float(x["ML_Score"])) for x in r]
print("=== fine threshold scan (target 268) ===")
t=0.250
while t<=0.320001:
    keep={s for s,v in sc if v<t}
    print("  t=%.3f -> %d covers46=%d/46" % (t,len(keep),len(KS&keep)))
    t+=0.002
vals=sorted(v for _,v in sc)
print("268th=%.4f 269th=%.4f" % (vals[267], vals[268]))
print("known46 scores min=%.3f max=%.3f" % (min(v for s,v in sc if s in KS), max(v for s,v in sc if s in KS)))
print("known46 hist:", dict(collections.Counter(round(v,1) for s,v in sc if s in KS)))
PY
'@

$tmp = Join-Path $repo "shift.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o = $o | Where-Object { $_ -notmatch "Predicting:" }
$o | ForEach-Object { Write-Output ("F| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "shift_parse.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))

# copy the small intermediate files into the repo so the agent can iterate offline
$copy = @'
set +e
S=$HOME/eyu_repro/stage3
D="$1"
mkdir -p "$D"
cp -f "$S/non_toxin.fa" "$D/non_toxin_935.fa" 2>/dev/null
cp -f "$S/algpred2_raw.csv" "$D/algpred2_935_raw.csv" 2>/dev/null
cp -f "$S/toxinpred2_raw.csv" "$D/toxinpred2_13294_raw.csv" 2>/dev/null
cp -f "$S/idmap.tsv" "$D/idmap.tsv" 2>/dev/null
ls -l "$D"
'@
$tmp2 = Join-Path $repo "cp.sh"
[IO.File]::WriteAllText($tmp2, ($copy -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$wslPath2 = "/mnt/" + $drive + ($tmp2.Substring(2) -replace '\\','/')
$dataWsl = "/mnt/" + $data.Substring(0,1).ToLower() + ($data.Substring(2) -replace '\\','/')
$o2 = & wsl.exe bash $wslPath2 $dataWsl 2>&1
Remove-Item -LiteralPath $tmp2 -Force -ErrorAction SilentlyContinue
$o2 | ForEach-Object { Write-Output ("C| " + $_) }
Write-Output "SHIFT_DONE=True"
