$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$enc  = New-Object Text.UTF8Encoding($false)
$log  = New-Object System.Collections.Generic.List[string]
$desktop = [Environment]::GetFolderPath("Desktop")

# 1. re-render the flowchart with a tall enough viewport
$svg = Join-Path $repo "deliverables\AMP_Pipeline_Flowchart_20261012.svg"
$png = Join-Path $repo "deliverables\AMP_Pipeline_Flowchart_20261012_300dpi.png"
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
  $log.Add(("PNG {0} x {1} px, {2} B" -f $img.Width, $img.Height, (Get-Item -LiteralPath $png).Length))
  $img.Dispose()
} else { $log.Add("PNG render FAILED") }

# 2. dump the manuscript docx structure
$doc = Join-Path $desktop "AMP_Docking_Vina_R255_20261005_1552\AMP_Alligator_Gut_SCI_Manuscript.docx"
$log.Add("DOC=" + $doc + " exists=" + (Test-Path -LiteralPath $doc))
if (Test-Path -LiteralPath $doc) {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $d = $word.Documents.Open($doc, $false, $true)
  $log.Add("paragraphs=" + $d.Paragraphs.Count + " tables=" + $d.Tables.Count + " inlineShapes=" + $d.InlineShapes.Count)
  for ($i = 1; $i -le $d.Paragraphs.Count; $i++) {
    $t = $d.Paragraphs.Item($i).Range.Text
    $t = $t -replace "[`r`n`a]", ""
    if ($t.Trim().Length -eq 0) { continue }
    $style = ""
    try { $style = $d.Paragraphs.Item($i).Style.NameLocal } catch { }
    $show = $t
    if ($show.Length -gt 110) { $show = $show.Substring(0,110) }
    $log.Add(("[{0}] <{1}> {2}" -f $i, $style, $show))
  }
  $log.Add("--- inline shapes ---")
  for ($i = 1; $i -le $d.InlineShapes.Count; $i++) {
    $sh = $d.InlineShapes.Item($i)
    $log.Add(("shape {0}: type={1} w={2} h={3}" -f $i, $sh.Type, [int]$sh.Width, [int]$sh.Height))
  }
  $d.Close($false)
  $word.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}

$outDir = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
[IO.File]::WriteAllLines((Join-Path $outDir "docx_structure.txt"), $log, $enc)
Write-Output ("lines=" + $log.Count)
Write-Output "DUMP_DONE=True"
