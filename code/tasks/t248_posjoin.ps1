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
W=$HOME/eyu_repro/stage8
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
echo "=== candidate algpred/toxin csv files in stage3 ==="
ls -l "$S"/*.csv
"$AF/bin/python" - <<"PY"
import os, csv, glob, collections
from Bio.SeqUtils.ProtParam import ProteinAnalysis
S=os.path.expanduser("~/eyu_repro/stage3"); W=os.path.expanduser("~/eyu_repro/stage8")
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
seqs=[s for _,s in recs]
ii={s:ProteinAnalysis(s).instability_index() for s in set(seqs) if set(s)<=set("ACDEFGHIKLMNPQRSTVWY")}
print("935 records, known46 present:", sum(1 for s in seqs if s in KS))
for path in sorted(glob.glob(os.path.join(S,"*.csv"))):
    try: rows=list(csv.DictReader(open(path)))
    except Exception as e: print(path,"ERR",e); continue
    pk=[k for k in rows[0] if "rediction" in k]
    if not pk: continue
    pk=pk[0]
    preds=[str(r[pk]).strip().lower() for r in rows]
    na_total=sum(1 for p in preds if p.startswith("non"))
    print()
    print("FILE %s rows=%d non_allergen_total=%d" % (os.path.basename(path), len(rows), na_total))
    for shift in range(-3,4):
        sel=[]
        for i,s in enumerate(seqs):
            j=i+shift
            if 0<=j<len(preds) and preds[j].startswith("non"): sel.append(s)
        hard=[s for s in sel if ii.get(s,99)<40]
        print("   shift=%+d -> kept=%d covers46=%d/46 | inst<40 -> %d covers46=%d/46"
              % (shift,len(sel),len(KS&set(sel)),len(hard),len(KS&set(hard))))
PY
'@

$tmp = Join-Path $repo "pos.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o = $o | Where-Object { $_ -notmatch "Predicting:" }
$o | ForEach-Object { Write-Output ("F| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "posjoin.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))

$cp = @'
set +e
D="$1"; mkdir -p "$D"
for f in $HOME/eyu_repro/stage3/*.csv ; do
  b=$(basename "$f")
  sz=$(stat -c%s "$f")
  if [ "$sz" -lt 3000000 ]; then cp -f "$f" "$D/stage3_$b"; fi
done
ls -l "$D"
'@
$tmp2 = Join-Path $repo "cp3.sh"
[IO.File]::WriteAllText($tmp2, ($cp -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$wslPath2 = "/mnt/" + $drive + ($tmp2.Substring(2) -replace '\\','/')
$dataWsl = "/mnt/" + $data.Substring(0,1).ToLower() + ($data.Substring(2) -replace '\\','/')
$o2 = & wsl.exe bash $wslPath2 $dataWsl 2>&1
Remove-Item -LiteralPath $tmp2 -Force -ErrorAction SilentlyContinue
$o2 | ForEach-Object { Write-Output ("C| " + $_) }
Write-Output "POSJOIN_DONE=True"
