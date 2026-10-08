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
source "$HOME/miniconda3/etc/profile.d/conda.sh" 2>/dev/null
S=$HOME/eyu_repro/stage3
A=$HOME/miniconda3/envs/algenv

echo "=== build algenv (python 3.9 + old sklearn) ==="
if [ ! -x "$A/bin/pip" ] ; then
  conda create -y -n algenv --override-channels -c conda-forge python=3.9 pip \
    > "$HOME/tools/algenv_create.log" 2>&1
  echo "create_exit=$?" ; tail -3 "$HOME/tools/algenv_create.log"
fi
[ -x "$A/bin/pip" ] || { echo "ALGENV_FAILED" ; exit 1 ; }
"$A/bin/python" -V

echo "--- install algpred2 then pin sklearn back ---"
"$A/bin/pip" install -q --no-input algpred2 2>&1 | tail -3
for COMBO in "numpy==1.23.5 scipy==1.9.3 scikit-learn==1.1.3" \
             "numpy==1.21.6 scipy==1.7.3 scikit-learn==1.0.2" \
             "numpy==1.19.5 scipy==1.5.4 scikit-learn==0.24.2" ; do
  echo "== trying $COMBO"
  "$A/bin/pip" install -q --no-input --force-reinstall $COMBO 2>&1 | tail -2
  "$A/bin/python" -c "import numpy,sklearn;print('numpy',numpy.__version__,'sklearn',sklearn.__version__)" 2>&1 | tail -1
  cd "$S" || exit 0
  rm -f "$S/algpred2_raw.csv"
  timeout 900 "$A/bin/algpred2" -i "$S/non_toxin.fa" -o "$S/algpred2_raw.csv" -t 0.3 -m 1 -d 2 \
    > "$S/algpred2.log" 2>&1
  rc=$?
  echo "   algpred2_exit=$rc"
  if [ $rc -eq 0 ] && [ -s "$S/algpred2_raw.csv" ] ; then
    echo "WORKING_COMBO=$COMBO"
    echo "ALG_ROWS=$(wc -l < "$S/algpred2_raw.csv")"
    head -3 "$S/algpred2_raw.csv"
    break
  else
    grep -aE "Error|error|Exception" "$S/algpred2.log" | tail -3
  fi
done

echo
echo "=== parse algpred2 ==="
if [ -s "$S/algpred2_raw.csv" ] ; then
"$A/bin/python" - <<"PY"
import os, csv, collections
S=os.path.expanduser("~/eyu_repro/stage3")
rows=list(csv.DictReader(open(os.path.join(S,"algpred2_raw.csv"))))
print("rows=%d" % len(rows))
print("columns=%s" % list(rows[0].keys()))
lcol=[k for k in rows[0] if "prediction" in k.strip().lower()]
lcol=lcol[0] if lcol else None
print("label_col=%r" % lcol)
if lcol: print(collections.Counter(r[lcol].strip() for r in rows))
idc=list(rows[0])[0]
seqc=[k for k in rows[0] if "sequence" in k.strip().lower()]
seqc=seqc[0] if seqc else None
keep=[r for r in rows if lcol and "non" in r[lcol].strip().lower()]
print("NON_ALLERGEN=%d" % len(keep))
with open(os.path.join(S,"non_allergen.fa"),"w") as fh:
    for r in keep:
        fh.write(">%s\n%s\n" % (r[idc].strip().lstrip(">"), r[seqc].strip() if seqc else ""))
print("wrote non_allergen.fa")
PY
echo "NON_ALLERGEN_SEQS=$(grep -c '^>' "$S/non_allergen.fa" 2>/dev/null)"
fi
'@

$tmp = Join-Path $repo "alg.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("G| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "algpred_env.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "ALGPRED_ENV_DONE=True"
