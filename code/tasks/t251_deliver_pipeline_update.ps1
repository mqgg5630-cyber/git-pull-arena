$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$enc  = New-Object Text.UTF8Encoding($false)
$log  = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

$desktop = [Environment]::GetFolderPath("Desktop")
$log.Add("DESKTOP=" + $desktop)

$src = Join-Path $repo "deliverables"
$files = @(
  "AMP_Pipeline_Reproduction_Method.md",
  "AMP_Pipeline_Flowchart_20261012.svg",
  "AMP_MD_Simulation_Protocol.md"
)
foreach ($f in $files) {
  $p = Join-Path $src $f
  $sz = 0
  if (Test-Path -LiteralPath $p) { $sz = (Get-Item -LiteralPath $p).Length }
  $log.Add(("SRC {0} exists={1} size={2}" -f $f, (Test-Path -LiteralPath $p), $sz))
}

$mainFolders = @(
  (Join-Path $desktop "AMP_Docking_Vina_R255_20261005_1552"),
  (Join-Path $desktop "AMP_SCI_Paper")
)

$newDir = Join-Path $mainFolders[0] ("AMP_Pipeline_Update_" + $stamp)
New-Item -ItemType Directory -Force -Path $newDir | Out-Null
$log.Add("NEW_DIR=" + $newDir)

foreach ($f in $files) {
  $p = Join-Path $src $f
  if (Test-Path -LiteralPath $p) {
    Copy-Item -LiteralPath $p -Destination (Join-Path $newDir $f) -Force
    $log.Add("COPIED_TO_NEW_DIR " + $f)
  }
}

foreach ($d in $mainFolders) {
  if (-not (Test-Path -LiteralPath $d)) { $log.Add("SKIP missing folder " + $d); continue }
  $log.Add("=== folder " + $d + " ===")
  $old = Join-Path $d "AMP_Pipeline_Reproduction_Method.md"
  if (Test-Path -LiteralPath $old) {
    Copy-Item -LiteralPath $old -Destination (Join-Path $d ("AMP_Pipeline_Reproduction_Method_OLD_" + $stamp + ".md.bak")) -Force
    $log.Add("   backed up old method md")
  }
  Copy-Item -LiteralPath (Join-Path $src "AMP_Pipeline_Reproduction_Method.md") -Destination $old -Force
  $log.Add("   REPLACED AMP_Pipeline_Reproduction_Method.md")
  Copy-Item -LiteralPath (Join-Path $src "AMP_MD_Simulation_Protocol.md") -Destination (Join-Path $d "AMP_MD_Simulation_Protocol.md") -Force
  $log.Add("   WROTE AMP_MD_Simulation_Protocol.md")
  Copy-Item -LiteralPath (Join-Path $src "AMP_Pipeline_Flowchart_20261012.svg") -Destination (Join-Path $d "AMP_Pipeline_Flowchart_20261012.svg") -Force
  $log.Add("   WROTE AMP_Pipeline_Flowchart_20261012.svg")

  Get-ChildItem -LiteralPath $d -Filter "*.svg" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "AMP_Pipeline_Flowchart_20261012.svg" -and ($_.Name -match "workflow" -or $_.Name -match "flow") } |
    ForEach-Object {
      Rename-Item -LiteralPath $_.FullName -NewName ($_.BaseName + "_SUPERSEDED_" + $stamp + ".svg") -ErrorAction SilentlyContinue
      $log.Add("   superseded old flowchart: " + $_.Name)
    }
}

$log.Add("")
$log.Add("=== final listing: " + $newDir)
Get-ChildItem -LiteralPath $newDir -File | ForEach-Object { $log.Add(("   {0}  {1} B" -f $_.Name, $_.Length)) }
foreach ($d in $mainFolders) {
  if (Test-Path -LiteralPath $d) {
    $log.Add("=== listing: " + $d)
    Get-ChildItem -LiteralPath $d -File | Sort-Object Name | ForEach-Object { $log.Add(("   {0}  {1} B" -f $_.Name, $_.Length)) }
  }
}

$outDir = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
[IO.File]::WriteAllLines((Join-Path $outDir "deliver_pipeline_update.txt"), $log, $enc)
$log | ForEach-Object { Write-Output $_ }
Write-Output "DELIVER_DONE=True"
