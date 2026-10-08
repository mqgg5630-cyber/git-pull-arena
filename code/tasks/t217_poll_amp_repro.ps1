$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
W=$HOME/eyu_repro
OUTD=$W/amp_results_bin1
if pgrep -f "run_pipeline_one.sh" >/dev/null 2>&1 ; then
  echo "PIPELINE_RUNNING=True pid=$(pgrep -f run_pipeline_one.sh | head -1)"
else
  echo "PIPELINE_RUNNING=False"
fi
echo "ELAPSED_LOG_MTIME=$(stat -c%y "$W/pipeline.log" 2>/dev/null)"
echo "LOG_BYTES=$(stat -c%s "$W/pipeline.log" 2>/dev/null)"
echo "--- last 25 log lines ---"
tail -25 "$W/pipeline.log" 2>/dev/null | tr -d "\000"
echo "--- outputs ---"
find "$OUTD" -type f -printf "%10s  %TH:%TM  %p\n" 2>/dev/null | sort -k3 | head -30
echo "--- row counts of any csv/tsv ---"
for f in $(find "$OUTD" -name "*.csv" -o -name "*.tsv" 2>/dev/null | head -10) ; do
  echo "$(wc -l < "$f") lines  $f"
done
echo "--- gpu ---"
nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader 2>/dev/null
'@

$tmp = Join-Path $repo "poll.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("P| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "poll_amp_repro.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "AMP_REPRO_POLL_DONE=True"
