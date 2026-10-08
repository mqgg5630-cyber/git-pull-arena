$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
W=$HOME/eyu_repro
S=$W/stage3
mkdir -p "$S"
V=$HOME/miniconda3/envs/ampfilter
REP=$W/stage2/clu100_rep_seq.fasta

echo "REPS=$(grep -c '^>' "$REP")"

echo "=== make a clean fasta with short ids (tools choke on long headers) ==="
"$V/bin/python" - <<"PY"
import os
rep=os.path.expanduser("~/eyu_repro/stage2/clu100_rep_seq.fasta")
S=os.path.expanduser("~/eyu_repro/stage3")
os.makedirs(S,exist_ok=True)
ids=[];seqs=[];cur=None;buf=[]
for line in open(rep):
    line=line.rstrip("\n")
    if line.startswith(">"):
        if cur is not None: ids.append(cur);seqs.append("".join(buf))
        cur=line[1:];buf=[]
    else: buf.append(line.strip())
if cur is not None: ids.append(cur);seqs.append("".join(buf))
print("loaded",len(ids))
with open(os.path.join(S,"in.fa"),"w") as fh, open(os.path.join(S,"idmap.tsv"),"w") as mp:
    mp.write("short\tsequence\toriginal\n")
    for i,(h,s) in enumerate(zip(ids,seqs),1):
        sid="p%06d"%i
        fh.write(">%s\n%s\n"%(sid,s))
        mp.write("%s\t%s\t%s\n"%(sid,s,h))
print("wrote in.fa")
PY
echo "IN_SEQS=$(grep -c '^>' "$S/in.fa")"

echo
echo "=== launch toxinpred2 (background) ==="
if pgrep -f "toxinpred2" >/dev/null 2>&1 ; then
  echo "ALREADY_RUNNING"
else
  cd "$S" || exit 0
  nohup "$V/bin/toxinpred2" -i "$S/in.fa" -o "$S/toxinpred2_raw.csv" -t 0.6 -m 1 -d 2 \
      > "$S/toxinpred2.log" 2>&1 &
  echo "LAUNCHED pid=$!"
  sleep 60
fi
echo "--- log ---"
tail -20 "$S/toxinpred2.log" 2>/dev/null
echo "--- out so far ---"
ls -la "$S" | head -15
[ -f "$S/toxinpred2_raw.csv" ] && echo "ROWS=$(wc -l < "$S/toxinpred2_raw.csv")"
'@

$tmp = Join-Path $repo "tox.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("T| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "toxinpred2_run.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "TOXINPRED2_RUN_DONE=True"
