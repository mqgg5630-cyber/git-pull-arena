$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
$data = Join-Path $repo "results\hpc\data"
New-Item -ItemType Directory -Force -Path $out  | Out-Null
New-Item -ItemType Directory -Force -Path $data | Out-Null

$bash = @'
set +e
AF=$HOME/miniconda3/envs/ampfilter
W=$HOME/eyu_repro/stage9
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
import os, re, csv, collections
from Bio.SeqUtils.ProtParam import ProteinAnalysis
H=os.path.expanduser("~/eyu_repro")
W=os.path.join(H,"stage9")
KS=set(l.strip() for l in open(os.path.join(W,"known46.txt")) if l.strip())
def read_fasta(p):
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
cons=read_fasta(os.path.join(H,"amp_results_bin1","consensus_amp.fa"))
print("consensus records:",len(cons))
print("example header:",cons[0][0][:160])
sc={}
for h,s in cons:
    m=dict(re.findall(r"(lstm|attn|bert)=([0-9.eE+-]+)",h))
    if m: sc[s]=(float(m.get("lstm",0)),float(m.get("attn",0)),float(m.get("bert",0)))
print("with scores:",len(sc))
nt=read_fasta(os.path.join(H,"stage3","non_toxin.fa"))
rows=[]
for h,s in nt:
    if set(s)-set("ACDEFGHIKLMNPQRSTVWY"): continue
    a=ProteinAnalysis(s)
    l,at,b=sc.get(s,(float("nan"),)*3)
    rows.append((h,s,len(s),round(a.instability_index(),3),l,at,b))
print("935 rows with scores:", sum(1 for r in rows if r[4]==r[4]))
with open(os.path.join(W,"scores935.tsv"),"w") as f:
    f.write("id\tseq\tlen\tinstability\tlstm\tattn\tbert\tknown46\n")
    for h,s,L,ii,l,at,b in rows:
        f.write("%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\n"%(h,s,L,ii,l,at,b,int(s in KS)))
i153=[r for r in rows if r[3]<40]
kn=[r for r in i153 if r[1] in KS]
print("inst153=%d known=%d"%(len(i153),len(kn)))
for idx,name in ((4,"lstm"),(5,"attn"),(6,"bert")):
    ok=[r for r in i153 if r[idx]==r[idx]]
    ok.sort(key=lambda r:-r[idx])
    top=ok[:46]
    print("  top46 by %s -> known in top46 = %d/46"%(name,sum(1 for r in top if r[1] in KS)))
ok=[r for r in i153 if r[4]==r[4]]
ok.sort(key=lambda r:-(r[4]+r[5]+r[6]))
print("  top46 by mean(3) -> known = %d/46"%sum(1 for r in ok[:46] if r[1] in KS))
ok.sort(key=lambda r:-min(r[4],r[5],r[6]))
print("  top46 by min(3)  -> known = %d/46"%sum(1 for r in ok[:46] if r[1] in KS))
PY
'@

$tmp = Join-Path $repo "rank.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o = $o | Where-Object { $_ -notmatch "Predicting:" }
$o | ForEach-Object { Write-Output ("F| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "rank_scores.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))

$cp = @'
set +e
D="$1"; mkdir -p "$D"
cp -f "$HOME/eyu_repro/stage9/scores935.tsv" "$D/scores935.tsv" 2>/dev/null
ls -l "$D/scores935.tsv"
'@
$tmp2 = Join-Path $repo "cp4.sh"
[IO.File]::WriteAllText($tmp2, ($cp -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$wslPath2 = "/mnt/" + $drive + ($tmp2.Substring(2) -replace '\\','/')
$dataWsl = "/mnt/" + $data.Substring(0,1).ToLower() + ($data.Substring(2) -replace '\\','/')
$o2 = & wsl.exe bash $wslPath2 $dataWsl 2>&1
Remove-Item -LiteralPath $tmp2 -Force -ErrorAction SilentlyContinue
$o2 | ForEach-Object { Write-Output ("C| " + $_) }
Write-Output "RANK_DONE=True"
