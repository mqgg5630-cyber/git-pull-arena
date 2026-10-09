$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
$data = Join-Path $repo "results\hpc\data"
New-Item -ItemType Directory -Force -Path $out  | Out-Null
New-Item -ItemType Directory -Force -Path $data | Out-Null

$bash = @'
set +e
HOSTIP=$(ip route | awk "/^default/ {print \$3}" | head -1)
for P in "http://${HOSTIP}:10808" "http://${HOSTIP}:18088" ; do
  if timeout 8 curl -sSI -x "$P" https://pypi.org >/dev/null 2>&1 ; then
    export http_proxy="$P" https_proxy="$P" ; echo "PROXY=$P" ; break
  fi
done
source "$HOME/miniconda3/etc/profile.d/conda.sh" 2>/dev/null
V=$HOME/miniconda3/envs/alg311
if [ ! -x "$V/bin/pip" ] ; then
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main > /dev/null 2>&1
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r    > /dev/null 2>&1
  conda create -y -n alg311 --override-channels -c conda-forge python=3.11 pip \
    > "$HOME/tools/alg311_create.log" 2>&1
  echo "create_exit=$?"
  tail -5 "$HOME/tools/alg311_create.log"
fi
PY311="$V/bin/python"
PIP311="$V/bin/pip"
if [ ! -x "$PY311" ] ; then echo "NO_PY311"; exit 0; fi
"$PIP311" install -q -U pip setuptools wheel > /dev/null 2>&1
"$PIP311" install -q "pandas==2.2.3" numpy scikit-learn joblib algpred2 2>&1 | tail -5
"$PY311" -c "import sklearn,pandas,numpy;print('sklearn',sklearn.__version__,'pandas',pandas.__version__,'numpy',numpy.__version__)"

"$PY311" - <<"PY"
import inspect
from pathlib import Path
import algpred2.python_scripts.algpred2 as m
p=Path(inspect.getsourcefile(m)); t=p.read_text(encoding="utf-8")
old='CM.to_csv("Sequence_1",header=False,index=None,sep="\n")'
new='Path("Sequence_1").write_text("\n".join(map(str, CM.iloc[:,0].tolist())) + "\n", encoding="utf-8")'
if old in t:
    if 'from pathlib import Path\n' not in t:
        t=t.replace('import warnings\n','import warnings\nfrom pathlib import Path\n',1)
    p.write_text(t.replace(old,new),encoding="utf-8"); print("patched")
else:
    print("patch target absent (already fine)")
PY

S=$HOME/eyu_repro/stage3
W=$HOME/eyu_repro/stage7
mkdir -p "$W/sub"
ln -sfn "$V/lib/python3.11/site-packages/algpred2/model" "$W/model" 2>/dev/null
cd "$W/sub"
"$V/bin/algpred2" -i "$S/non_toxin.fa" -o "$W/alg935_py311.csv" -t 0.3 -m 1 -d 2 2>&1 | tail -4
cd "$W"
ls -l alg935_py311.csv 2>/dev/null
head -3 alg935_py311.csv 2>/dev/null
"$HOME/miniconda3/envs/ampfilter/bin/python" - <<"PY"
import csv, os, collections
W=os.path.expanduser("~/eyu_repro/stage7")
p=os.path.join(W,"alg935_py311.csv")
if not os.path.exists(p):
    print("NO OUTPUT"); raise SystemExit
r=list(csv.DictReader(open(p)))
print("rows",len(r))
print(collections.Counter(x[[k for k in x if "rediction" in k][0]].strip() for x in r))
PY
'@

$tmp = Join-Path $repo "p311.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o = $o | Where-Object { $_ -notmatch "Predicting:" }
$o | ForEach-Object { Write-Output ("F| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "py311_scores.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))

$cp = @'
set +e
D="$1"; mkdir -p "$D"
cp -f "$HOME/eyu_repro/stage7/alg935_py311.csv" "$D/algpred2_935_py311.csv" 2>/dev/null
ls -l "$D"
'@
$tmp2 = Join-Path $repo "cp2.sh"
[IO.File]::WriteAllText($tmp2, ($cp -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$wslPath2 = "/mnt/" + $drive + ($tmp2.Substring(2) -replace '\\','/')
$dataWsl = "/mnt/" + $data.Substring(0,1).ToLower() + ($data.Substring(2) -replace '\\','/')
$o2 = & wsl.exe bash $wslPath2 $dataWsl 2>&1
Remove-Item -LiteralPath $tmp2 -Force -ErrorAction SilentlyContinue
$o2 | ForEach-Object { Write-Output ("C| " + $_) }
Write-Output "PY311_DONE=True"
