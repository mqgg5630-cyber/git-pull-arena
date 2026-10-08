$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
HOSTIP=$(ip route | awk "/^default/ {print \$3}" | head -1)
for P in "http://${HOSTIP}:10808" "http://${HOSTIP}:18088" ; do
  if timeout 8 curl -sSI -x "$P" https://pypi.org >/dev/null 2>&1 ; then
    export http_proxy="$P" https_proxy="$P" ; echo "PROXY=$P" ; break
  fi
done
S=$HOME/eyu_repro/stage3
A=$HOME/miniconda3/envs/algenv
AF=$HOME/miniconda3/envs/ampfilter
R=$HOME/eyu_repro/algsearch
mkdir -p "$R"
SP="$A/lib/python3.9/site-packages"

evaluate () {
  TAG="$1" ; CSV="$2"
  [ -s "$CSV" ] || { echo "   [$TAG] no output" ; return ; }
  cp "$CSV" "$R/${TAG}.csv"
  "$AF/bin/python" - "$R/${TAG}.csv" "$TAG" <<"PY"
import sys, csv
from Bio.SeqUtils.ProtParam import ProteinAnalysis
p,tag=sys.argv[1],sys.argv[2]
rows=list(csv.DictReader(open(p)))
if not rows: print("   [%s] empty" % tag); raise SystemExit
seqc=[k for k in rows[0] if "sequence" in k.lower()]
lc=[k for k in rows[0] if "prediction" in k.lower()]
if not (seqc and lc):
    print("   [%s] cols=%s" % (tag,list(rows[0]))); raise SystemExit
na=[r for r in rows if "non" in r[lc[0]].lower()]
STD=set("ACDEFGHIKLMNPQRSTVWY")
keep=[r[seqc[0]].strip() for r in na
      if r[seqc[0]].strip() and not (set(r[seqc[0]].strip())-STD)
      and ProteinAnalysis(r[seqc[0]].strip()).instability_index() < 40]
T={"FVNKLNRIIPVKGFSMR":"P1","LISNTKKFGTAIASHR":"P2","ISLAIPLASKISGFTLALVKNAST":"P3"}
ks=set(keep); hits=sorted(n for s,n in T.items() if s in ks)
ok = (len(keep)==49 and len(hits)==3)
print("   [%s] rows=%d non_allergen=%d instability_lt40=%d kept=%s%s"
      % (tag,len(rows),len(na),len(keep),",".join(hits) or "none",
         "   <<<<<< TARGET HIT" if ok else ""))
PY
}

echo "=== 1. older pypi versions with their own model dir ==="
for V in 1.2 1.1 1.0 ; do
  echo "-- algpred2==$V"
  "$A/bin/pip" install -q --no-input --force-reinstall --no-deps "algpred2==$V" 2>&1 | tail -1
  PKG=$(find "$SP" -maxdepth 1 -iname "algpred2*" -type d | head -1)
  echo "   pkg=$PKG"
  [ -n "$PKG" ] && find "$PKG" -maxdepth 2 -type d | head -10
  MODEL=$(find "$SP" -maxdepth 3 -type d -name "model" 2>/dev/null | head -1)
  if [ -z "$MODEL" ] ; then MODEL=$(find "$SP" -maxdepth 4 -name "rf_model" 2>/dev/null | head -1 | xargs -r dirname) ; fi
  echo "   model_dir=$MODEL"
  if [ -n "$MODEL" ] ; then
    WD="$R/wd_$V/sub" ; rm -rf "$R/wd_$V" ; mkdir -p "$WD"
    ln -sfn "$MODEL" "$R/wd_$V/model"
    for extra in merci blast_binaries Database database ; do
      E=$(find "$SP" -maxdepth 3 -type d -name "$extra" 2>/dev/null | head -1)
      [ -n "$E" ] && ln -sfn "$E" "$R/wd_$V/$extra"
    done
    cd "$WD" || continue
    rm -f out.csv
    timeout 900 "$A/bin/algpred2" -i "$S/non_toxin.fa" -o "$WD/out.csv" -t 0.3 -m 1 -d 2 > "$R/v$V.log" 2>&1
    echo "   exit=$?"
    grep -aE "Error|No such file" "$R/v$V.log" | tail -2
    evaluate "pypi_${V}_modeldir" "$WD/out.csv"
  fi
done

echo
echo "=== 2. GitHub source via curl tarball ==="
cd "$R" || exit 0
for U in "https://codeload.github.com/raghavagps/algpred2/tar.gz/refs/heads/main" \
         "https://codeload.github.com/raghavagps/algpred2/tar.gz/refs/heads/master" ; do
  echo "try $U"
  timeout 420 curl -fsSL -o algpred2_src.tar.gz "$U" && break
done
if [ -s algpred2_src.tar.gz ] ; then
  rm -rf algpred2_src && mkdir -p algpred2_src
  tar xzf algpred2_src.tar.gz -C algpred2_src --strip-components=1 2>&1 | tail -2
  echo "--- tree ---"
  find algpred2_src -maxdepth 2 | head -40
  echo "--- python entry points ---"
  find algpred2_src -maxdepth 2 -name "*.py" | head -10
  echo "--- model artifacts ---"
  find algpred2_src -maxdepth 3 \( -name "*model*" -o -name "*.zip" -o -name "*.pkl" \) | head -15
else
  echo "GITHUB_TARBALL_FAILED"
fi
'@

$tmp = Join-Path $repo "ao.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("W| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "algpred_oldmodels.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "ALGPRED_OLDMODELS_DONE=True"
