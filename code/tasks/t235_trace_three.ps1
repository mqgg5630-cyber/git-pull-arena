$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
W=$HOME/eyu_repro
V=$HOME/miniconda3/envs/ampfilter
"$V/bin/python" - <<"PY"
import os, csv
from Bio.SeqUtils.ProtParam import ProteinAnalysis
W=os.path.expanduser("~/eyu_repro")
S=os.path.join(W,"stage3")

T={"FVNKLNRIIPVKGFSMR":"P1","LISNTKKFGTAIASHR":"P2","ISLAIPLASKISGFTLALVKNAST":"P3"}

def fa(p):
    out={}
    cur=None;buf=[]
    if not os.path.exists(p): return out
    for line in open(p):
        line=line.rstrip("\n")
        if line.startswith(">"):
            if cur is not None: out["".join(buf)]=cur
            cur=line[1:].strip();buf=[]
        else: buf.append(line.strip())
    if cur is not None: out["".join(buf)]=cur
    return out

stages=[
 ("1 input bin.1 sORF      ", os.path.join(W,"amp_results_bin1","input.fa")),
 ("2 consensus 3of3        ", os.path.join(W,"amp_results_bin1","consensus_amp.fa")),
 ("3 mmseqs reps           ", os.path.join(W,"stage2","clu100_rep_seq.fasta")),
 ("4 short-id in.fa        ", os.path.join(S,"in.fa")),
 ("5 non-toxin             ", os.path.join(S,"non_toxin.fa")),
 ("6 non-allergen          ", os.path.join(S,"non_allergen.fa")),
 ("7 instability<40        ", os.path.join(S,"hard_filter_49.fa")),
]
maps={n:fa(p) for n,p in stages}
for n,_ in stages:
    print("%s  n=%d" % (n, len(maps[n])))
print()
for seq,label in T.items():
    print("== %s  %s  (len %d)" % (label, seq, len(seq)))
    for n,_ in stages:
        m=maps[n]
        print("   %s : %s" % (n, "PRESENT" if seq in m else "absent"))
    a=ProteinAnalysis(seq)
    print("   instability=%.2f  gravy=%.3f  pI=%.2f  charge7=%.2f" %
          (a.instability_index(), a.gravy(), a.isoelectric_point(), a.charge_at_pH(7.0)))

print()
print("=== scores for the three, from each prediction table ===")
def table(p,key="ID"):
    if not os.path.exists(p): return {}
    return {r.get("Sequence","").strip(): r for r in csv.DictReader(open(p))}
tox=table(os.path.join(S,"toxinpred2_raw.csv"))
alg=table(os.path.join(S,"algpred2_raw.csv"))
for seq,label in T.items():
    t=tox.get(seq); g=alg.get(seq)
    print("  %s tox=%s %s | alg=%s %s" % (
        label,
        t.get("ML_Score") if t else "-", t.get("Prediction") if t else "-",
        g.get("ML_Score") if g else "-", g.get("Prediction") if g else "-"))
PY
'@

$tmp = Join-Path $repo "tr.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("R| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "trace_three.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "TRACE_THREE_DONE=True"
