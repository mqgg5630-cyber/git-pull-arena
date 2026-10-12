$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$enc  = New-Object Text.UTF8Encoding($false)
$log  = New-Object System.Collections.Generic.List[string]
$desktop = [Environment]::GetFolderPath("Desktop")
$src = Join-Path $repo "deliverables"
$clue = Join-Path $repo "results\hpc\clues"
New-Item -ItemType Directory -Force -Path $clue | Out-Null

# 0. bring the user's ORIGINAL cascade SVG back into the repo
$paper = Join-Path $desktop "AMP_SCI_Paper"
Get-ChildItem -LiteralPath $paper -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like "fig_screening_cascade*" } |
  ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $clue $_.Name) -Force
    $log.Add("pulled original: " + $_.Name + "  " + $_.Length + " B")
  }

# 1. re-render the corrected SVG
$svg = Join-Path $src "AMP_Pipeline_Flowchart_20261012.svg"
$png = Join-Path $src "AMP_Pipeline_Flowchart_20261012_300dpi.png"
if (Test-Path -LiteralPath $png) { Remove-Item -LiteralPath $png -Force }
$edge = @(
  "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($edge) {
  $uri = "file:///" + ($svg -replace '\\','/')
  & $edge --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=3 --window-size=1100,1340 --screenshot="$png" "$uri" 2>&1 | Out-Null
  Start-Sleep -Seconds 4
}
if (Test-Path -LiteralPath $png) {
  Add-Type -AssemblyName System.Drawing
  $img = [System.Drawing.Image]::FromFile($png)
  $log.Add(("PNG {0} x {1}, {2} B" -f $img.Width, $img.Height, (Get-Item -LiteralPath $png).Length))
  $img.Dispose()
} else { $log.Add("PNG RENDER FAILED") }

# 2. swap the figure inside the manuscript (inline shape 1 = our cascade)
$folders = @((Join-Path $desktop "AMP_Docking_Vina_R255_20261005_1552"), $paper)
foreach ($d in $folders) {
  foreach ($f in @("AMP_Pipeline_Flowchart_20261012.svg","AMP_Pipeline_Flowchart_20261012_300dpi.png")) {
    $p = Join-Path $src $f
    if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $d $f) -Force }
  }
}
$upd = Get-ChildItem -LiteralPath $folders[0] -Directory -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -like "AMP_Pipeline_Update_*" } | Select-Object -First 1
if ($upd) {
  foreach ($f in @("AMP_Pipeline_Flowchart_20261012.svg","AMP_Pipeline_Flowchart_20261012_300dpi.png")) {
    Copy-Item -LiteralPath (Join-Path $src $f) -Destination (Join-Path $upd.FullName $f) -Force
  }
}

$doc = Join-Path $folders[0] "AMP_Alligator_Gut_SCI_Manuscript.docx"
if ((Test-Path -LiteralPath $doc) -and (Test-Path -LiteralPath $png)) {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $d = $word.Documents.Open($doc)
  $log.Add("before: inlineShapes=" + $d.InlineShapes.Count)
  $sh = $d.InlineShapes.Item(1)
  $log.Add(("shape1 before: w={0} h={1}" -f [int]$sh.Width, [int]$sh.Height))
  $rng = $sh.Range
  $sh.Delete()
  $new = $d.InlineShapes.AddPicture($png, $false, $true, $rng)
  $ratio = $new.Height / $new.Width
  $new.Width = 432
  $new.Height = 432 * $ratio
  $log.Add(("shape1 after: w={0} h={1}" -f [int]$new.Width, [int]$new.Height))
  $d.Save()
  $log.Add("saved: paragraphs=" + $d.Paragraphs.Count + " inlineShapes=" + $d.InlineShapes.Count)
  $d.Close($true); $word.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
  Start-Sleep -Seconds 2
  Copy-Item -LiteralPath $doc -Destination (Join-Path $paper "AMP_Alligator_Gut_SCI_Manuscript.docx") -Force
  $log.Add("mirrored manuscript")
}

$outDir = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
[IO.File]::WriteAllLines((Join-Path $outDir "fix_figure.txt"), $log, $enc)
Write-Output "FIXFIG_DONE=True"
