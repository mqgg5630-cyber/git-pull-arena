$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
HOSTIP=$(ip route | awk "/^default/ {print \$3}" | head -1)
for P in "http://${HOSTIP}:10808" "http://${HOSTIP}:18088" "http://${HOSTIP}:4067" ; do
  if timeout 8 curl -sSI -x "$P" https://github.com >/dev/null 2>&1 ; then
    export http_proxy="$P" https_proxy="$P" ; echo "PROXY=$P" ; break
  fi
done

T=$HOME/tools
mkdir -p "$T"
source "$HOME/miniconda3/etc/profile.d/conda.sh" 2>/dev/null

echo "=== 1. create a filter venv (no conda) ==="
V=$HOME/tools/ampfilter
if [ ! -x "$V/bin/python" ] ; then
  python3 -m venv "$V" 2>&1 | tail -3
  echo "venv_exit=$?"
fi
PY="$V/bin/python"
PIP="$V/bin/pip"
if [ ! -x "$PY" ] ; then echo "VENV_FAILED" ; exit 1 ; fi
"$PY" -V
"$PIP" install -q --upgrade pip 2>&1 | tail -2

echo "=== 2. core deps ==="
"$PIP" install -q --no-input biopython pandas numpy scikit-learn 2>&1 | tail -3
"$PY" -c "import Bio, pandas, sklearn; print('deps ok', Bio.__version__, pandas.__version__, sklearn.__version__)"

echo
echo "=== 3. toxinpred2 ==="
"$PIP" install -q --no-input toxinpred2 2>&1 | tail -5
"$V/bin/toxinpred2" -h 2>&1 | head -15
echo "toxinpred2_exit=$?"

echo
echo "=== 4. algpred2 ==="
"$PIP" install -q --no-input algpred2 2>&1 | tail -5
"$V/bin/algpred2" -h 2>&1 | head -15
echo "algpred2_exit=$?"

echo
echo "=== 5. what landed in bin ==="
ls "$V/bin" | grep -iE "tox|alg|pep" | head

echo
echo "=== 6. biopython instability index smoke test ==="
"$PY" - <<"PY"
from Bio.SeqUtils.ProtParam import ProteinAnalysis
for s in ("FVNKLNRIIPVKGFSMR","LISNTKKFGTAIASHR","ISLAIPLASKISGFTLALVKNAST"):
    a=ProteinAnalysis(s)
    print(s, "len=%d" % len(s), "II=%.2f" % a.instability_index(),
          "GRAVY=%.3f" % a.gravy(), "pI=%.2f" % a.isoelectric_point())
PY
'@

$tmp = Join-Path $repo "inst.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("I| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "install_filters.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "INSTALL_FILTERS_DONE=True"
