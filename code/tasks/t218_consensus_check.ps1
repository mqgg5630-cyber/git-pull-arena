$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
W=$HOME/eyu_repro
O=$W/amp_results_bin1
echo "PIPELINE_RUNNING=$(pgrep -f run_pipeline_one.sh >/dev/null && echo True || echo False)"
echo "--- tail of pipeline log (non-progress) ---"
grep -av "Predicting:" "$W/pipeline.log" 2>/dev/null | tr -d "\000" | tail -30
echo
echo "--- files ---"
ls -la "$O"
echo
echo "--- final_prediction.txt head ---"
head -5 "$O/final_prediction.txt"
echo "LINES=$(wc -l < "$O/final_prediction.txt")"
echo
echo "--- proba file heads ---"
for f in lstm attention bert ; do echo "== $f" ; head -3 "$O/${f}_proba.tsv" ; done
echo
echo "--- consensus count (all three >= 0.5) ---"
python3 - <<"PY"
import os
O=os.path.expanduser("~/eyu_repro/amp_results_bin1")
def load(n):
    d={}
    with open(os.path.join(O,n)) as fh:
        for line in fh:
            p=line.rstrip("\n").split("\t")
            if len(p)<2: continue
            try: d[p[0]]=float(p[-1])
            except ValueError: continue
    return d
L=load("lstm_proba.tsv"); A=load("attention_proba.tsv"); B=load("bert_proba.tsv")
print("sizes", len(L), len(A), len(B))
keys=set(L)&set(A)&set(B)
print("shared keys", len(keys))
for t in (0.5,):
    c=[k for k in keys if L[k]>=t and A[k]>=t and B[k]>=t]
    print("consensus@%.2f = %d" % (t,len(c)))
    with open(os.path.join(O,"consensus_ids.txt"),"w") as fh:
        for k in sorted(c): fh.write(k+"\n")
PY
echo
echo "--- any aggregate script output ---"
find "$O" -name "*.csv" -o -name "*summary*" | head
'@

$tmp = Join-Path $repo "cons.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("C| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "consensus_check.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "CONSENSUS_CHECK_DONE=True"
