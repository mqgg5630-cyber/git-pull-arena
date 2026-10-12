$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$enc  = New-Object Text.UTF8Encoding($false)
$log  = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$desktop = [Environment]::GetFolderPath("Desktop")

$svg = Join-Path $repo "deliverables\AMP_Pipeline_Flowchart_20261012.svg"
$png = Join-Path $repo "deliverables\AMP_Pipeline_Flowchart_20261012_300dpi.png"
$log.Add("SVG exists=" + (Test-Path -LiteralPath $svg))

$rendered = $false
$inkscape = Get-Command inkscape.exe -ErrorAction SilentlyContinue
if ($inkscape) {
  & $inkscape.Source --export-type=png --export-dpi=300 --export-filename="$png" "$svg" 2>&1 | Out-Null
  if (Test-Path -LiteralPath $png) { $rendered = $true; $log.Add("rendered with Inkscape") }
}
if (-not $rendered) {
  $edge = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
  ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if ($edge) {
    $uri = "file:///" + ($svg -replace '\\','/')
    & $edge --headless=new --disable-gpu --force-device-scale-factor=3 --window-size=1080,1180 --screenshot="$png" "$uri" 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    if (Test-Path -LiteralPath $png) { $rendered = $true; $log.Add("rendered with Edge headless: " + $edge) }
  } else { $log.Add("no Edge found") }
}
$log.Add("PNG rendered=" + $rendered)
if (Test-Path -LiteralPath $png) { $log.Add("PNG size=" + (Get-Item -LiteralPath $png).Length) }

$targets = @(
  (Join-Path $desktop "AMP_Docking_Vina_R255_20261005_1552"),
  (Join-Path $desktop "AMP_SCI_Paper")
)
$newDirs = Get-ChildItem -LiteralPath $targets[0] -Directory -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -like "AMP_Pipeline_Update_*" }
foreach ($nd in $newDirs) { $targets += $nd.FullName }

foreach ($d in $targets) {
  if (-not (Test-Path -LiteralPath $d)) { continue }
  $log.Add("=== " + $d)
  if (Test-Path -LiteralPath $png) {
    Copy-Item -LiteralPath $png -Destination (Join-Path $d "AMP_Pipeline_Flowchart_20261012_300dpi.png") -Force
    $log.Add("   wrote 300dpi PNG")
  }
  Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "screening_cascade" -or ($_.Name -match "workflow" -and $_.Extension -eq ".svg") } |
    ForEach-Object {
      $nn = $_.BaseName + "_SUPERSEDED_" + $stamp + $_.Extension
      Rename-Item -LiteralPath $_.FullName -NewName $nn -ErrorAction SilentlyContinue
      $log.Add("   superseded: " + $_.Name)
    }
  Get-ChildItem -LiteralPath $d -File | Sort-Object Name | ForEach-Object { $log.Add(("     {0}  {1} B" -f $_.Name, $_.Length)) }
}

$outDir = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
[IO.File]::WriteAllLines((Join-Path $outDir "render_supersede.txt"), $log, $enc)
$log | ForEach-Object { Write-Output $_ }
Write-Output "RENDER_DONE=True"
