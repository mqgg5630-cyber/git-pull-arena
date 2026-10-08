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
R=$HOME/eyu_repro/algsearch
mkdir -p "$R"

echo "=== 0. available algpred2 versions on PyPI ==="
"$A/bin/python" - <<"PY"
import json, urllib.request
try:
    d=json.load(urllib.request.urlopen("https://pypi.org/pypi/algpred2/json", timeout=30))
    vs=sorted(d["releases"].keys())
    print("VERSIONS=" + ",".join(vs))
except Exception as e:
    print("PYPI_QUERY_FAILED", e)
PY

evaluate () {
  TAG="$1"
  rm -f "$S/vtest.csv"
  timeout 900 "$A/bin/algpred2" -i "$S/non_toxin.fa" -o "$S/vtest.csv" -t 0.3 -m 1 -d 2 > "$R/${TAG}.log" 2>&1
  rc=$?
  if [ $rc -ne 0 ] || [ ! -s "$S/vtest.csv" ] ; then
    echo "   [$TAG] run failed rc=$rc" ; grep -aE "Error|error" "$R/${TAG}.log" | tail -2 ; return
  fi
  cp "$S/vtest.csv" "$R/${TAG}.csv"
  "$HOME/miniconda3/envs/ampfilter/bin/python" - "$R/${TAG}.csv" "$TAG" <<"PY"
import sys, csv, collections
from Bio.SeqUtils.ProtParam import ProteinAnalysis
p,tag=sys.argv[1],sys.argv[2]
rows=list(csv.DictReader(open(p)))
sc=[k for k in rows[0] if "score" in k.lower() and "ml" in k.lower()] or [k for k in rows[0] if "score" in k.lower()]
seqc=[k for k in rows[0] if "sequence" in k.lower()]
lc=[k for k in rows[0] if "prediction" in k.lower()]
if not (seqc and lc): print("   [%s] unexpected columns %s" % (tag,list(rows[0]))); raise SystemExit
na=[r for r in rows if "non" in r[lc[0]].lower()]
STD=set("ACDEFGHIKLMNPQRSTVWY")
keep=[]
for r in na:
    s=r[seqc[0]].strip()
    if not s or set(s)-STD: continue
    if ProteinAnalysis(s).instability_index() < 40: keep.append(s)
T={"FVNKLNRIIPVKGFSMR":"P1","LISNTKKFGTAIASHR":"P2","ISLAIPLASKISGFTLALVKNAST":"P3"}
ks=set(keep)
hits=[n for s,n in T.items() if s in ks]
print("   [%s] non_allergen=%d  instability_lt40=%d  peptides_kept=%s%s"
      % (tag,len(na),len(keep),",".join(sorted(hits)) or "none",
         "   <<<< TARGET 49 + ALL THREE" if (len(keep)==49 and len(hits)==3) else ""))
PY
}

echo
echo "=== 1. try each PyPI version ==="
for V in $("$A/bin/python" -c "
import json,urllib.request
try:
    d=json.load(urllib.request.urlopen('https://pypi.org/pypi/algpred2/json',timeout=30))
    print(' '.join(sorted(d['releases'].keys(), reverse=True)))
except Exception: print('')
") ; do
  echo "-- algpred2==$V"
  "$A/bin/pip" install -q --no-input --force-reinstall --no-deps "algpred2==$V" 2>&1 | tail -1
  evaluate "pypi_$V"
done

echo
echo "=== 2. GitHub repo version ==="
cd "$R" || exit 0
if [ ! -d algpred2_repo ] ; then
  timeout 600 git clone --depth 1 https://github.com/raghavagps/algpred2.git algpred2_repo > clone.log 2>&1
  echo "clone_exit=$? "; tail -3 clone.log
fi
if [ -d algpred2_repo ] ; then
  echo "--- repo tree ---"
  find algpred2_repo -maxdepth 2 | head -30
  echo "--- any model archive to unpack ---"
  find algpred2_repo -name "*.zip" -o -name "*.tar*" -o -name "*.pkl" -o -name "*.sav" | head -10
fi
'@

$tmp = Join-Path $repo "av.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("V| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "algpred_versions.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "ALGPRED_VERSIONS_DONE=True"
