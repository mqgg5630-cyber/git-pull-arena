$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$dst  = Join-Path $repo "results\user_amp\eyu_live"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
$live = "D:\DeskBoxLibrary\07-Old-Folders\AI\e-yu"
Write-Output ("LIVE={0} exists={1}" -f $live, (Test-Path -LiteralPath $live))
if (-not (Test-Path -LiteralPath $live)) { Write-Output "LIVE_MISSING"; exit 1 }

$all = Get-ChildItem -LiteralPath $live -Recurse -File -ErrorAction SilentlyContinue
Write-Output ("FILE_COUNT={0}" -f $all.Count)
Write-Output ("TOTAL_MB={0:N1}" -f (($all | Measure-Object Length -Sum).Sum / 1MB))

Write-Output "--- top-level ---"
Get-ChildItem -LiteralPath $live | ForEach-Object { Write-Output ("  {0}  {1}" -f $(if($_.PSIsContainer){"<DIR>"}else{$_.Length}), $_.Name) }

$want = $all | Where-Object {
  $_.Length -gt 0 -and $_.Length -lt 3000000 -and (
    $_.FullName -match 'liucheng2|algpred2|toxinpred|pepfun|flow3|final_screen' -or
    $_.Name -match 'ranking|top12|hard_filter|AMP_positive|summary|method|seed|step_counts|novelty' )
}
Write-Output ("CANDIDATES={0}" -f $want.Count)

$n = 0
foreach ($f in $want) {
  $rel = $f.FullName.Substring($live.Length).TrimStart('\')
  $flat = ($rel -replace '\\','__')
  if ($flat.Length -gt 150) { $flat = $flat.Substring($flat.Length-150) }
  $t = Join-Path $dst $flat
  Copy-Item -LiteralPath $f.FullName -Destination $t -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $t) {
    $b = [IO.File]::ReadAllBytes($t)
    $nz = 0; foreach ($x in $b) { if ($x -ne 0) { $nz++ } }
    Write-Output ("COPIED {0,9} B nonzero={1,9}  {2}" -f $f.Length, $nz, $rel)
    if ($nz -eq 0) { Remove-Item -LiteralPath $t -Force }
    else { $n++ }
  }
}
Write-Output "KEPT_NONEMPTY=$n"
if ($n -lt 3) { Write-Output "TOO_FEW_LIVE"; exit 1 }
Write-Output "GRAB_LIVE_EYU_DONE=True"
