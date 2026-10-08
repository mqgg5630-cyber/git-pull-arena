$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null
Write-Output "HOST=$env:COMPUTERNAME"

$bash = @'
set +e
W=$HOME/eyu_repro
IN=$W/input/bin1_sorf_131816.fa
echo "INPUT_SEQS=$(grep -c '^>' "$IN" 2>/dev/null)"

echo "=== 1. locate the c_AMPs-prediction project ==="
PROJ=""
for c in "$HOME/c_AMPs-prediction-master/c_AMPs-prediction-master" "$HOME/c_AMPs-prediction-master" "$HOME/c_AMPs-prediction" ; do
  if [ -d "$c/amp_pipeline" ] || [ -d "$c/script" ] ; then PROJ="$c" ; break ; fi
done
if [ -z "$PROJ" ] ; then
  PROJ=$(find "$HOME" -maxdepth 4 -type d -name "amp_pipeline" 2>/dev/null | head -1 | xargs -r dirname)
fi
echo "PROJ=$PROJ"
if [ -z "$PROJ" ] ; then echo "PROJECT_NOT_FOUND" ; exit 0 ; fi
ls -la "$PROJ" | head -25

echo
echo "=== 2. models present? ==="
for m in Models/att.h5 Models/lstm.h5 Models/bert.bin ; do
  if [ -f "$PROJ/$m" ] ; then echo "OK   $m $(stat -c%s "$PROJ/$m") B" ; else echo "MISS $m" ; fi
done

echo
echo "=== 3. conda envs ==="
source "$HOME/miniconda3/etc/profile.d/conda.sh" 2>/dev/null || source "$HOME/anaconda3/etc/profile.d/conda.sh" 2>/dev/null
conda env list 2>/dev/null | grep -E "camps-tf114|py36"

echo
echo "=== 4. pipeline entrypoint ==="
ls -la "$PROJ/amp_pipeline" 2>/dev/null | head -20

echo
echo "=== 5. launch (background, nohup) ==="
OUTD=$W/amp_results_bin1
mkdir -p "$OUTD"
if [ -f "$OUTD/.done" ] ; then echo "ALREADY_DONE" ; fi
if pgrep -f "run_pipeline_one.sh" >/dev/null 2>&1 ; then
  echo "ALREADY_RUNNING pid=$(pgrep -f run_pipeline_one.sh | tr '\n' ' ')"
else
  if [ -f "$PROJ/amp_pipeline/run_pipeline_one.sh" ] ; then
    cd "$PROJ" || exit 0
    export BERT_NUM_WORKERS=0
    export BERT_USE_CUDA=auto
    export BERT_EVAL_BATCH_SIZE=64
    nohup bash "$PROJ/amp_pipeline/run_pipeline_one.sh" "$IN" "$OUTD" "$PROJ" camps-tf114 py36 \
      > "$W/pipeline.log" 2>&1 &
    echo "LAUNCHED pid=$!"
    sleep 25
  else
    echo "ENTRYPOINT_MISSING"
  fi
fi

echo
echo "=== 6. first log lines ==="
tail -40 "$W/pipeline.log" 2>/dev/null

echo
echo "=== 7. current outputs ==="
ls -la "$OUTD" 2>/dev/null | head -20
'@

$tmp = Join-Path $repo "launch.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("H| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "launch_amp_repro.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "AMP_REPRO_LAUNCH_DONE=True"
