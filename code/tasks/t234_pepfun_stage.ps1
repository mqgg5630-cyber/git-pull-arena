$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
S=$HOME/eyu_repro/stage3
V=$HOME/miniconda3/envs/ampfilter
echo "NON_ALLERGEN=$(grep -c '^>' "$S/non_allergen.fa")"

"$V/bin/python" - <<"PY"
import os, csv
from Bio.SeqUtils.ProtParam import ProteinAnalysis
S=os.path.expanduser("~/eyu_repro/stage3")

idmap={}
with open(os.path.join(S,"idmap.tsv")) as fh:
    r=csv.DictReader(fh,delimiter="\t")
    for row in r: idmap[row["short"]]=row["original"]

ids=[];seqs=[];cur=None;buf=[]
for line in open(os.path.join(S,"non_allergen.fa")):
    line=line.rstrip("\n")
    if line.startswith(">"):
        if cur is not None: ids.append(cur);seqs.append("".join(buf))
        cur=line[1:].strip();buf=[]
    else: buf.append(line.strip())
if cur is not None: ids.append(cur);seqs.append("".join(buf))
print("loaded=%d" % len(ids))

STD=set("ACDEFGHIKLMNPQRSTVWY")
rows=[]
for i,s in zip(ids,seqs):
    if not s or set(s)-STD: continue
    a=ProteinAnalysis(s)
    try:
        rows.append(dict(id=i, seq=s, length=len(s),
            instability=a.instability_index(),
            gravy=a.gravy(),
            pI=a.isoelectric_point(),
            charge=a.charge_at_pH(7.0),
            aromaticity=a.aromaticity(),
            mw=a.molecular_weight(),
            original=idmap.get(i,"")))
    except Exception as e:
        pass
print("scored=%d" % len(rows))

with open(os.path.join(S,"pepfun_metrics.tsv"),"w",newline="") as fh:
    w=csv.DictWriter(fh,fieldnames=list(rows[0].keys()),delimiter="\t")
    w.writeheader()
    for r in rows: w.writerow(r)

for t in (30,35,40,45,50):
    print("  instability < %d : %d" % (t, sum(1 for r in rows if r["instability"] < t)))

keep=[r for r in rows if r["instability"] < 40]
print("HARD_FILTER_INSTABILITY_LT_40=%d" % len(keep))

with open(os.path.join(S,"hard_filter_49.fa"),"w") as fh:
    for r in keep:
        fh.write(">%s\n%s\n" % (r["original"] or r["id"], r["seq"]))
with open(os.path.join(S,"hard_filter_49.tsv"),"w",newline="") as fh:
    w=csv.DictWriter(fh,fieldnames=list(rows[0].keys()),delimiter="\t")
    w.writeheader()
    for r in sorted(keep,key=lambda x:x["instability"]): w.writerow(r)
print("wrote hard_filter_49.*")

# are the three published peptides in here?
targets={"FVNKLNRIIPVKGFSMR":"P1","LISNTKKFGTAIASHR":"P2","ISLAIPLASKISGFTLALVKNAST":"P3"}
bystage={"non_allergen":set(seqs)}
allseq={r["seq"] for r in rows}
keepseq={r["seq"] for r in keep}
for t,n in targets.items():
    print("  %s %-26s in_non_allergen=%s in_hard_filter=%s" % (n,t,t in allseq,t in keepseq))
PY

echo
echo "=== top of the hard filter table ==="
head -12 "$S/hard_filter_49.tsv" | cut -c1-200
echo "HARD_FILTER_SEQS=$(grep -c '^>' "$S/hard_filter_49.fa")"
'@

$tmp = Join-Path $repo "pf.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("P| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "pepfun_stage.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "PEPFUN_STAGE_DONE=True"
