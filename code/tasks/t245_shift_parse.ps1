$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

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
import os, csv
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

# replicate the Downloads script parser EXACTLY (header counted as a data row)
raw=open(os.path.join(S,"algpred2_raw.csv")).read()
lines=[x.strip() for x in raw.splitlines() if x.strip()]
rows=[[p.strip() for p in (l.split("\t") if "\t" in l else l.split(","))] for l in lines]
print("csv lines (incl header)=%d" % len(rows))

def summarize(shift):
    out=[]
    for i,(h,s) in enumerate(recs):
        j=i+shift
        r=rows[j] if 0<=j<len(rows) else []
        low=" | ".join(r).lower()
        if "non-allergen" in low or "non allergen" in low: pred="non_allergen"
        elif "allergen" in low: pred="allergen"
        else: pred="unknown"
        out.append((h,s,pred))
    return out

for shift in (0,1,-1):
    sm=summarize(shift)
    na=[x for x in sm if x[2]=="non_allergen"]
    nas={x[1] for x in na}
    hard=[x for x in na if ProteinAnalysis(x[1]).instability_index()<40]
    hs={x[1] for x in hard}
    print()
    print("shift=%+d : non_allergen=%d  covers46=%d/46 | instability<40 -> %d  covers46=%d/46"
          % (shift,len(na),len(KS&nas),len(hard),len(KS&hs)))
    if len(na) in range(255,285) or len(hard) in range(44,56):
        with open(os.path.join(W,"shift%+d_nonallergen.fa"%shift),"w") as f:
            for h,s,_ in na: f.write(">%s\n%s\n"%(h,s))
        with open(os.path.join(W,"shift%+d_hard.fa"%shift),"w") as f:
            for h,s,_ in hard: f.write(">%s\n%s\n"%(h,s))

# fine threshold scan for exactly 268
r=list(csv.DictReader(open(os.path.join(S,"algpred2_raw.csv"))))
sc=[(x["Sequence"].strip(), float(x["ML_Score"])) for x in r]
print()
print("=== fine threshold scan (target 268) ===")
t=0.250
while t<=0.320001:
    keep={s for s,v in sc if v<t}
    print("  t=%.3f -> %d  covers46=%d/46" % (t,len(keep),len(KS&keep)))
    t+=0.002
vals=sorted(v for _,v in sc)
print("268th smallest score = %.4f ; 269th = %.4f" % (vals[267], vals[268]))
print("scores of the known 46: min=%.3f max=%.3f" % (
    min(v for s,v in sc if s in KS), max(v for s,v in sc if s in KS)))
import collections
print("known46 score histogram:", collections.Counter(round(v,1) for s,v in sc if s in KS))
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
Write-Output "SHIFT_DONE=True"
