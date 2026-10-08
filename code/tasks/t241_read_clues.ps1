$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
$clue = Join-Path $repo "results\hpc\clues"
New-Item -ItemType Directory -Force -Path $out  | Out-Null
New-Item -ItemType Directory -Force -Path $clue | Out-Null

$enc = New-Object Text.UTF8Encoding($false)
$lines = New-Object System.Collections.Generic.List[string]

$dl = "E:\Users\" + [char]0x6587 + [char]0x5C11 + "\Downloads"
$lines.Add("downloads dir: " + $dl)
$lines.Add("exists: " + (Test-Path $dl))

$files = @(
  "algpred2_onefile_py311.sh",
  "run_algpred2_allergen.sh",
  "Prediction_Result(1).csv",
  "jieguo.csv"
)

foreach ($f in $files) {
  $p = Join-Path $dl $f
  $lines.Add("")
  $lines.Add("=== " + $f + " ===")
  if (-not (Test-Path -LiteralPath $p)) { $lines.Add("MISSING"); continue }
  $fi = Get-Item -LiteralPath $p
  $lines.Add(("size={0} B  mtime={1}" -f $fi.Length, $fi.LastWriteTime))
  $safe = ($f -replace '[^A-Za-z0-9._-]','_')
  Copy-Item -LiteralPath $p -Destination (Join-Path $clue $safe) -Force
  $txt = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
  if ($null -eq $txt) { $lines.Add("UNREADABLE"); continue }
  $all = $txt -split "`r?`n"
  $lines.Add(("lines={0}" -f $all.Count))
  if ($f -like "*.csv") {
    $lines.Add("--- header + first 12 rows ---")
    foreach ($l in ($all | Select-Object -First 13)) { $lines.Add($l) }
    $lines.Add("--- last 3 rows ---")
    foreach ($l in ($all | Select-Object -Last 3)) { $lines.Add($l) }
    try {
      $rows = Import-Csv -LiteralPath $p
      $lines.Add(("csv rows={0}" -f $rows.Count))
      $cols = ($rows | Select-Object -First 1).psobject.Properties.Name
      $lines.Add("csv cols: " + ($cols -join " | "))
      foreach ($c in $cols) {
        $vals = $rows | ForEach-Object { $_.$c }
        $uniq = ($vals | Sort-Object -Unique)
        if ($uniq.Count -le 8) {
          $parts = foreach ($u in $uniq) { "{0}={1}" -f $u, (@($vals | Where-Object { $_ -eq $u }).Count) }
          $lines.Add(("  counts[{0}]: {1}" -f $c, ($parts -join ", ")))
        }
      }
    } catch { $lines.Add("Import-Csv failed: " + $_.Exception.Message) }
  } else {
    $lines.Add("--- full text ---")
    foreach ($l in $all) { $lines.Add($l) }
  }
}

$lines.Add("")
$lines.Add("=== other algpred/pepfun/toxin files in Downloads ===")
Get-ChildItem -LiteralPath $dl -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match "algpred|pepfun|toxin|jieguo|Prediction|amp|hard|top12|seed" } |
  Sort-Object LastWriteTime -Descending | Select-Object -First 40 |
  ForEach-Object { $lines.Add(("{0}  {1} B  {2}" -f $_.Name, $_.Length, $_.LastWriteTime)) }

[IO.File]::WriteAllLines((Join-Path $out "clue_files.txt"), $lines, $enc)
Write-Output "DONE"
