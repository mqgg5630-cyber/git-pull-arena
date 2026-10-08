$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$bash = @'
set +e
D=/mnt/e/huifu/e-yu

echo "=== 1. key dirs listed in full ==="
for sub in yuce algpred2_result algpred2_result/raw final_screen_non_allergen final_screen_non_allergen/ampsphere_exact final_screen_non_allergen/ampsphere_mmseqs final_screen_non_allergen/macrel_peptides "bin.1_getorf_sorf/03_filter" "bin.1_getorf_sorf/03_filter/c_AMP_prediction_3models" "bin.1_getorf_sorf/04_stats" ; do
  echo "---------- $sub"
  ls -la "$D/$sub" 2>/dev/null | head -40
done

echo
echo "=== 2. top-level files ==="
ls -la "$D" | head -40

echo
echo "=== 3. seq counts of every fasta outside 00_split/01_orf ==="
find "$D" -type f \( -name "*.fa" -o -name "*.fasta" -o -name "*.faa" \) 2>/dev/null \
  | grep -v "/00_split/\|/01_orf/" | while read -r f ; do
    echo "$(grep -c '^>' "$f" 2>/dev/null) seqs   $(stat -c%s "$f") B   $f"
  done

echo
echo "=== 4. row counts of every csv/tsv/xlsx-ish ==="
find "$D" -type f \( -name "*.csv" -o -name "*.tsv" -o -name "*.txt" \) 2>/dev/null \
  | grep -v "/00_split/\|/01_orf/\|/log/" | while read -r f ; do
    echo "$(wc -l < "$f" 2>/dev/null) rows   $(stat -c%s "$f") B   $f"
  done

echo
echo "=== 5. summary.tsv contents ==="
cat "$D/bin.1_getorf_sorf/04_stats/summary.tsv" 2>/dev/null

echo
echo "=== 6. scripts, dumped ==="
for f in "$D/yuce/run_amp_novelty_hemo_pepfun_pipeline.sh" "$D/algpred2_onefile_py311.sh" "$D/yuce/batch_pepfun2_properties.py" ; do
  echo "########## $f  ($(stat -c%s "$f" 2>/dev/null) B)"
  head -c 6000 "$f" 2>/dev/null
  echo ""
  echo "########## end"
done
'@

$tmp = Join-Path $repo "eyukey.sh"
[IO.File]::WriteAllText($tmp, ($bash -replace "`r`n","`n"), (New-Object Text.UTF8Encoding($false)))
$drive = $tmp.Substring(0,1).ToLower()
$wslPath = "/mnt/" + $drive + ($tmp.Substring(2) -replace '\\','/')
$o = & wsl.exe bash $wslPath 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$o | ForEach-Object { Write-Output ("K| " + $_) }
[IO.File]::WriteAllLines((Join-Path $out "eyu_key.txt"), [string[]]$o, (New-Object Text.UTF8Encoding($false)))
Write-Output "EYU_KEY_DONE=True"
