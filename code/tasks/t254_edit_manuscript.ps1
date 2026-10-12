$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$enc  = New-Object Text.UTF8Encoding($false)
$log  = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$desktop = [Environment]::GetFolderPath("Desktop")
$src = Join-Path $repo "deliverables"

$cfgPath = Join-Path $src "manuscript_edits.json"
$cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$log.Add("edits=" + $cfg.edits.Count)

$folders = @(
  (Join-Path $desktop "AMP_Docking_Vina_R255_20261005_1552"),
  (Join-Path $desktop "AMP_SCI_Paper")
)
$updateDir = Get-ChildItem -LiteralPath $folders[0] -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -like "AMP_Pipeline_Update_*" } |
             Sort-Object Name -Descending | Select-Object -First 1

# 1. ship the standalone MD protocol docx and the fixed flowchart PNG
$ship = @("AMP_MD_Simulation_Protocol.docx", "AMP_MD_Simulation_Protocol.md",
          "AMP_Pipeline_Flowchart_20261012_300dpi.png", "AMP_Pipeline_Flowchart_20261012.svg",
          "AMP_Pipeline_Reproduction_Method.md")
$dests = @() + $folders
if ($updateDir) { $dests += $updateDir.FullName }
foreach ($d in $dests) {
  if (-not (Test-Path -LiteralPath $d)) { continue }
  foreach ($f in $ship) {
    $p = Join-Path $src $f
    if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $d $f) -Force }
  }
  $log.Add("shipped files to " + $d)
}

# 2. edit the manuscript in place (with backup)
$doc = Join-Path $folders[0] "AMP_Alligator_Gut_SCI_Manuscript.docx"
if (-not (Test-Path -LiteralPath $doc)) { $log.Add("MANUSCRIPT MISSING"); }
else {
  $bak = Join-Path $folders[0] ("AMP_Alligator_Gut_SCI_Manuscript_OLD_" + $stamp + ".docx.bak")
  Copy-Item -LiteralPath $doc -Destination $bak -Force
  $log.Add("backup -> " + $bak)

  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $d = $word.Documents.Open($doc)
  $log.Add("opened: paragraphs=" + $d.Paragraphs.Count)

  $sorted = $cfg.edits | Sort-Object -Property index -Descending
  foreach ($e in $sorted) {
    $i = [int]$e.index
    if ($i -lt 1 -or $i -gt $d.Paragraphs.Count) { $log.Add("SKIP index " + $i); continue }
    $r = $d.Paragraphs.Item($i).Range
    $before = $r.Text
    if ($before.Length -gt 40) { $before = $before.Substring(0,40) }
    $r.MoveEnd(1, -1) | Out-Null
    $r.Text = [string]$e.text
    $log.Add(("replaced [{0}] old='{1}'" -f $i, ($before -replace "[`r`n]","")))
  }

  $fig = $cfg.figure
  $pngPath = Join-Path $src ([string]$fig.file)
  if (Test-Path -LiteralPath $pngPath) {
    $ai = [int]$fig.after_index
    $anchor = $d.Paragraphs.Item($ai).Range
    $anchor.InsertParagraphAfter()
    $capPara = $d.Paragraphs.Item($ai + 1)
    $capRange = $capPara.Range
    $capRange.MoveEnd(1, -1) | Out-Null
    $capRange.Text = [string]$fig.caption
    $capPara.Alignment = 1
    $capPara.Range.InsertParagraphBefore()
    $imgPara = $d.Paragraphs.Item($ai + 1)
    $imgPara.Alignment = 1
    $shape = $d.InlineShapes.AddPicture($pngPath, $false, $true, $imgPara.Range)
    $ratio = $shape.Height / $shape.Width
    $shape.Width = [float]([double]$fig.width_inches * 72.0)
    $shape.Height = $shape.Width * $ratio
    $log.Add(("inserted flowchart after paragraph {0}, w={1} h={2}" -f $ai, [int]$shape.Width, [int]$shape.Height))
  } else { $log.Add("flowchart PNG missing: " + $pngPath) }

  $d.Save()
  $log.Add("saved: paragraphs=" + $d.Paragraphs.Count + " inlineShapes=" + $d.InlineShapes.Count)
  $d.Close($true)
  $word.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
  Start-Sleep -Seconds 2
  Copy-Item -LiteralPath $doc -Destination (Join-Path $folders[1] "AMP_Alligator_Gut_SCI_Manuscript.docx") -Force
  $log.Add("mirrored manuscript to AMP_SCI_Paper")
}

foreach ($d in $dests) {
  if (Test-Path -LiteralPath $d) {
    $log.Add("=== " + $d)
    Get-ChildItem -LiteralPath $d -File | Sort-Object Name | ForEach-Object { $log.Add(("   {0}  {1} B" -f $_.Name, $_.Length)) }
  }
}

$outDir = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
[IO.File]::WriteAllLines((Join-Path $outDir "manuscript_edit.txt"), $log, $enc)
Write-Output "EDIT_DONE=True"
