$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
D=/mnt/e/huifu/e-yu
T() { timeout "$1" bash -c "$2" 2>/dev/null || echo "  [timeout]" ; }

echo "=== 1. tree ==="
T 120 "find '$D' -maxdepth 3 -type d | head -60"

echo
echo "=== 2. all files with size and date ==="
T 180 "find '$D' -maxdepth 3 -type f -printf '%12s  %TY-%Tm-%Td %TH:%TM  %p\n' | sort -k2 | head -120"

echo
echo "=== 3. fasta sequence counts ==="
for f in $(timeout 120 find "$D" -maxdepth 3 \( -name "*.fa" -o -name "*.fasta" -o -name "*.txt" \) -size -20M 2>/dev/null | head -40) ; do
  n=$(grep -c "^>" "$f" 2>/dev/null)
  if [ "$n" -gt 0 ] 2>/dev/null ; then echo "$n seqs   $f" ; fi
done

echo
echo "=== 4. csv/tsv row counts ==="
for f in $(timeout 120 find "$D" -maxdepth 3 \( -name "*.csv" -o -name "*.tsv" \) -size -50M 2>/dev/null | head -40) ; do
  echo "$(wc -l < "$f") rows   $f"
done

echo
echo "=== 5. the pipeline scripts ==="
for f in "$D/yuce/run_amp_novelty_hemo_pepfun_pipeline.sh" "$D/algpred2_onefile_py311.sh" "$D/yuce/batch_pepfun2_properties.py" ; do
  if [ -f "$f" ] ; then echo "########## $f" ; sed -n "1,120p" "$f" ; echo "########## end" ; fi
done

echo
echo "=== 6. algpred2_result ==="
T 60 "ls -la '$D/algpred2_result' | head -20"

echo
echo "=== 7. BiToxNet project ==="
T 60 "ls -la $HOME/projects/BiToxNet | head -25"
T 60 "find $HOME/projects/BiToxNet -maxdepth 2 -name '*.py' -o -maxdepth 2 -name '*.md' -o -maxdepth 2 -name '*.sh' | head -20"
'@

$tmp = Join-Path $repo "eyuws.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("E| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "eyu_workspace.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "EYU_WORKSPACE_DONE=True"
