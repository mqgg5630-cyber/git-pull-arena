$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$dst  = Join-Path $repo "results\user_amp\eyu_downstream"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Write-Output "DST=$dst"

$srcRoots = @(
  "E:\huifu\e-yu\bin.1_getorf_sorf\03_filter\c_AMP_prediction_3models\liucheng2_mmseqs_pepfun_toxinpred2_algpred2_top12",
  "E:\huifu\e-yu\bin.1_getorf_sorf\03_filter\c_AMP_prediction_3models\liucheng2_mmseqs_pepfun_toxinpred2_top12",
  "E:\huifu\e-yu\algpred2_result",
  "E:\huifu\e-yu\final_screen_non_allergen"
)
$n = 0
foreach ($r in $srcRoots) {
  if (-not (Test-Path -LiteralPath $r)) { Write-Output "MISS $r"; continue }
  $leaf = Split-Path $r -Leaf
  $o = Join-Path $dst $leaf
  New-Item -ItemType Directory -Force -Path $o | Out-Null
  Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -lt 2000000 } | ForEach-Object {
      $rel = $_.FullName.Substring($r.Length).TrimStart('\')
      $t = Join-Path $o ($rel -replace '\\','__')
      Copy-Item -LiteralPath $_.FullName -Destination $t -Force
      Write-Output ("COPIED {0}\{1} ({2} B)" -f $leaf, ($rel -replace '\\','__'), $_.Length)
      $script:n++
    }
}
foreach ($f in @(
  "E:\huifu\e-yu\bin.1_getorf_sorf\03_filter\c_AMP_prediction_3models\summary_counts.tsv",
  "E:\huifu\e-yu\bin3_getorf_sorf\eyu-method.txt",
  "E:\huifu\e-yu\bin.1_getorf_sorf\eyu.txt",
  "E:\huifu\e-yu\AMP_positive_3of3.exact_novelty.summary.txt",
  "E:\huifu\e-yu\pepfun.fa",
  "E:\huifu\e-yu\non_allergen.fasta",
  "E:\huifu\e-yu\yuce\run_amp_novelty_hemo_pepfun_pipeline.sh",
  "E:\huifu\e-yu\yuce\batch_pepfun2_properties.py",
  "E:\huifu\e-yu\algpred2_onefile_py311.sh"
)) {
  if (Test-Path -LiteralPath $f) {
    $t = Join-Path $dst ((Split-Path $f -Parent | Split-Path -Leaf) + "__" + (Split-Path $f -Leaf))
    Copy-Item -LiteralPath $f -Destination $t -Force
    Write-Output ("COPIED {0} ({1} B)" -f (Split-Path $t -Leaf), (Get-Item -LiteralPath $t).Length)
    $n++
  } else { Write-Output "MISS $f" }
}
Write-Output "COPIED_COUNT=$n"
if ($n -lt 5) { Write-Output "TOO_FEW"; exit 1 }
Write-Output "EYU_SMALL_COPY_DONE=True"
