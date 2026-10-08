$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
W=$HOME/eyu_repro
O=$W/amp_results_bin1
S=$W/stage2
mkdir -p "$S"
source "$HOME/miniconda3/etc/profile.d/conda.sh" 2>/dev/null

echo "=== tool availability ==="
for t in mmseqs cd-hit seqkit ; do
  p=$(command -v $t 2>/dev/null)
  if [ -n "$p" ] ; then echo "OK   $t -> $p" ; else echo "MISS $t" ; fi
done
echo "--- conda envs that may hold them ---"
conda env list 2>/dev/null
for e in $(conda env list 2>/dev/null | awk '!/^#/ && NF>1 {print $NF}') ; do
  if [ -x "$e/bin/mmseqs" ] ; then echo "FOUND mmseqs in $e" ; fi
done

echo
echo "=== input ==="
IN=$O/consensus_amp.fa
echo "seqs=$(grep -c '^>' "$IN")"

echo
echo "=== exact duplicate sequences (pure dedup baseline) ==="
python3 - <<"PY"
import os
p=os.path.expanduser("~/eyu_repro/amp_results_bin1/consensus_amp.fa")
ids=[];seqs=[];cur=None;buf=[]
for line in open(p):
    line=line.rstrip("\n")
    if line.startswith(">"):
        if cur is not None: ids.append(cur);seqs.append("".join(buf))
        cur=line[1:];buf=[]
    else: buf.append(line.strip())
if cur is not None: ids.append(cur);seqs.append("".join(buf))
print("total=%d" % len(seqs))
seen={}; keep=[]
for i,s in enumerate(seqs):
    if s not in seen:
        seen[s]=i; keep.append(i)
print("unique_sequences=%d" % len(keep))
print("exact_duplicates_removed=%d" % (len(seqs)-len(keep)))
out=os.path.expanduser("~/eyu_repro/stage2/consensus_nr.fa")
with open(out,"w") as fh:
    for i in keep:
        fh.write(">%s\n%s\n" % (ids[i],seqs[i]))
print("wrote",out)
PY

echo
echo "=== mmseqs easy-cluster at 100 percent identity if available ==="
MM=$(command -v mmseqs 2>/dev/null)
if [ -z "$MM" ] ; then
  for e in $(conda env list 2>/dev/null | awk '!/^#/ && NF>1 {print $NF}') ; do
    [ -x "$e/bin/mmseqs" ] && MM="$e/bin/mmseqs" && break
  done
fi
if [ -n "$MM" ] ; then
  echo "using $MM"
  cd "$S" || exit 0
  "$MM" easy-cluster "$O/consensus_amp.fa" "$S/clu100" "$S/tmp_mm" \
      --min-seq-id 1.0 -c 1.0 --cov-mode 1 > "$S/mmseqs.log" 2>&1
  echo "exit=$?"
  tail -5 "$S/mmseqs.log"
  [ -f "$S/clu100_rep_seq.fasta" ] && echo "MMSEQS_REPS=$(grep -c '^>' "$S/clu100_rep_seq.fasta")"
else
  echo "MMSEQS_NOT_AVAILABLE"
fi

echo
echo "=== files ==="
ls -la "$S" 2>/dev/null | head -20
'@

$tmp = Join-Path $repo "mm.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("M| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "mmseqs_dedup.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "MMSEQS_DEDUP_DONE=True"
