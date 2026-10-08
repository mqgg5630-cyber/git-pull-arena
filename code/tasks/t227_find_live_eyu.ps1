$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$out  = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$desk = ("D:\" + [char]0x684C + [char]0x9762)
$cands = @(
  (Join-Path $desk "AI\e-yu"),
  (Join-Path $desk "AI"),
  "E:\huifu\e-yu"
)
foreach ($c in $cands) {
  Write-Output ("CAND {0} exists={1}" -f $c, (Test-Path -LiteralPath $c))
}

$live = Join-Path $desk "AI\e-yu"
if (Test-Path -LiteralPath $live) {
  Write-Output "LIVE_FOUND=$live"
  $files = Get-ChildItem -LiteralPath $live -Recurse -File -ErrorAction SilentlyContinue
  Write-Output ("LIVE_FILE_COUNT={0}" -f $files.Count)
  Write-Output ("LIVE_TOTAL_MB={0:N1}" -f (($files | Measure-Object Length -Sum).Sum / 1MB))
  Write-Output "--- non-empty files under the two liucheng2 dirs and key roots ---"
  $files | Where-Object {
      $_.Length -gt 0 -and (
        $_.FullName -match 'liucheng2' -or $_.FullName -match 'algpred2' -or
        $_.Name -match 'ranking|top12|hard_filter|pepfun|toxin|AMP_positive|summary|method|seed' )
    } | Sort-Object Length -Descending | Select-Object -First 60 | ForEach-Object {
      $nz = 0
      try {
        $b = [IO.File]::ReadAllBytes($_.FullName)
        foreach ($x in $b) { if ($x -ne 0) { $nz++ } }
      } catch {}
      Write-Output ("{0,10} B  nonzero={1,10}  {2}" -f $_.Length, $nz, $_.FullName.Substring($live.Length+1))
    }
} else {
  Write-Output "LIVE_MISSING"
  Write-Output "--- search the whole Desktop and D root for e-yu ---"
  foreach ($root in @($desk, "D:\", "E:\")) {
    Get-ChildItem -LiteralPath $root -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match 'e-yu|eyu' } |
      Select-Object -First 15 | ForEach-Object { Write-Output ("HIT " + $_.FullName) }
  }
}
Write-Output "FIND_LIVE_EYU_DONE=True"
