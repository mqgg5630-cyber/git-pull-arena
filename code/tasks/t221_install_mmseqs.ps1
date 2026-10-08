$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
W=$HOME/eyu_repro
O=$W/amp_results_bin1
S=$W/stage2
mkdir -p "$S" "$HOME/tools"

echo "=== 0. proxy for downloads ==="
HOSTIP=$(ip route | awk "/^default/ {print \$3}" | head -1)
echo "HOSTIP=$HOSTIP"
for P in "http://${HOSTIP}:4067" "http://${HOSTIP}:18088" "http://${HOSTIP}:10808" ; do
  if timeout 8 curl -sSI -x "$P" https://github.com >/dev/null 2>&1 ; then
    export http_proxy="$P" https_proxy="$P"
    echo "PROXY_OK=$P" ; break
  fi
done
if [ -z "$http_proxy" ] ; then
  timeout 8 curl -sSI https://github.com >/dev/null 2>&1 && echo "DIRECT_OK" || echo "NO_NET"
fi

echo
echo "=== 1. get mmseqs static binary ==="
if [ ! -x "$HOME/tools/mmseqs/bin/mmseqs" ] ; then
  cd "$HOME/tools" || exit 0
  for U in "https://mmseqs.com/latest/mmseqs-linux-avx2.tar.gz" \
           "https://github.com/soedinglab/MMseqs2/releases/latest/download/mmseqs-linux-avx2.tar.gz" ; do
    echo "try $U"
    timeout 300 curl -fL --retry 2 -o mmseqs.tar.gz "$U" 2>&1 | tail -2
    if [ -s mmseqs.tar.gz ] ; then
      tar xzf mmseqs.tar.gz && break
    fi
  done
fi
MM="$HOME/tools/mmseqs/bin/mmseqs"
if [ -x "$MM" ] ; then
  echo "MMSEQS_INSTALLED=$MM"
  "$MM" version 2>&1 | head -2
else
  echo "MMSEQS_INSTALL_FAILED"
fi

echo
echo "=== 2. substring containment check in python (independent) ==="
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
order=sorted(range(len(seqs)), key=lambda i: -len(seqs[i]))
kept=[]; keptseq=[]
contained=0
big="\x00".join(sorted(set(seqs), key=len, reverse=True))
for i in order:
    s=seqs[i]
    hit=False
    for t in keptseq:
        if len(t)>len(s) and s in t:
            hit=True; break
    if hit: contained+=1
    else:
        kept.append(i); keptseq.append(s)
print("total=%d kept=%d contained_removed=%d" % (len(seqs),len(kept),contained))
PY

echo
echo "=== 3. run mmseqs easy-cluster if we have it ==="
if [ -x "$MM" ] ; then
  cd "$S" || exit 0
  rm -rf tmp_mm clu100*
  "$MM" easy-cluster "$O/consensus_amp.fa" "$S/clu100" "$S/tmp_mm" \
      --min-seq-id 1.0 -c 1.0 --cov-mode 1 -v 1 > "$S/mmseqs.log" 2>&1
  echo "exit=$?"
  tail -8 "$S/mmseqs.log"
  if [ -f "$S/clu100_rep_seq.fasta" ] ; then
    echo "MMSEQS_REPS=$(grep -c '^>' "$S/clu100_rep_seq.fasta")"
  fi
fi

echo
echo "=== files ==="
ls -la "$S" | head -20
'@

$tmp = Join-Path $repo "mm2.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("M| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "mmseqs_install.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "MMSEQS_INSTALL_DONE=True"
