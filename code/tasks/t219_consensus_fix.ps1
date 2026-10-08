$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
W=$HOME/eyu_repro
O=$W/amp_results_bin1
python3 - <<"PY"
import os, re
O=os.path.expanduser("~/eyu_repro/amp_results_bin1")

ids=[]; seqs=[]
cur=None; buf=[]
with open(os.path.join(O,"input.fa")) as fh:
    for line in fh:
        line=line.rstrip("\n")
        if line.startswith(">"):
            if cur is not None: ids.append(cur); seqs.append("".join(buf))
            cur=line[1:].strip(); buf=[]
        else: buf.append(line.strip())
if cur is not None: ids.append(cur); seqs.append("".join(buf))
print("input_seqs=%d" % len(ids))

def col(n):
    v=[]
    with open(os.path.join(O,n)) as fh:
        for line in fh:
            line=line.strip()
            if not line: continue
            try: v.append(float(line.split()[-1]))
            except ValueError: pass
    return v
L=col("lstm_proba.tsv"); A=col("attention_proba.tsv"); B=col("bert_proba.tsv")
print("lstm=%d attention=%d bert=%d" % (len(L),len(A),len(B)))
n=min(len(ids),len(L),len(A),len(B))
print("aligned=%d" % n)

cons=[i for i in range(n) if L[i]>=0.5 and A[i]>=0.5 and B[i]>=0.5]
print("CONSENSUS_ALL3_0.5=%d" % len(cons))
for t in (0.5,):
    print("  lstm>=%.1f  : %d" % (t,sum(1 for x in L[:n] if x>=t)))
    print("  attn>=%.1f  : %d" % (t,sum(1 for x in A[:n] if x>=t)))
    print("  bert>=%.1f  : %d" % (t,sum(1 for x in B[:n] if x>=t)))
maj=[i for i in range(n) if (L[i]>=0.5)+(A[i]>=0.5)+(B[i]>=0.5)>=2]
print("MAJORITY_2of3=%d" % len(maj))

# what result.pl itself decided
pos=0; tot=0
with open(os.path.join(O,"final_prediction.txt")) as fh:
    for line in fh:
        if line.startswith(">"):
            tot+=1
            if re.search(r"_1;\s*$", line): pos+=1
print("FINAL_PRED_RECORDS=%d  FINAL_PRED_POSITIVE=%d" % (tot,pos))

out=os.path.join(O,"consensus_amp.fa")
with open(out,"w") as fh:
    for i in cons:
        fh.write(">%s|lstm=%.4f|attn=%.4f|bert=%.4f\n%s\n" % (ids[i],L[i],A[i],B[i],seqs[i]))
print("WROTE %s (%d seqs)" % (out,len(cons)))

ln=[len(seqs[i]) for i in cons]
if ln:
    print("consensus length min/median/max = %d / %d / %d" % (min(ln), sorted(ln)[len(ln)//2], max(ln)))
PY
echo "--- files now ---"
ls -la "$O"
'@

$tmp = Join-Path $repo "cons2.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("C| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "consensus_fix.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "CONSENSUS_FIX_DONE=True"
