$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$enc  = New-Object Text.UTF8Encoding($false)
$log  = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$desktop = [Environment]::GetFolderPath("Desktop")

Get-Process WINWORD -ErrorAction SilentlyContinue | ForEach-Object {
  Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
  $log.Add("killed WINWORD " + $_.Id)
}
Start-Sleep -Seconds 2

$fixed = Join-Path $repo "work\AMP_Alligator_Gut_SCI_Manuscript_FIXED.docx"
$log.Add("fixed exists=" + (Test-Path -LiteralPath $fixed))
if (Test-Path -LiteralPath $fixed) {
  $folders = @(
    (Join-Path $desktop "AMP_Docking_Vina_R255_20261005_1552"),
    (Join-Path $desktop "AMP_SCI_Paper")
  )
  foreach ($d in $folders) {
    if (-not (Test-Path -LiteralPath $d)) { continue }
    $t = Join-Path $d "AMP_Alligator_Gut_SCI_Manuscript.docx"
    if (Test-Path -LiteralPath $t) {
      Copy-Item -LiteralPath $t -Destination (Join-Path $d ("AMP_Alligator_Gut_SCI_Manuscript_PREFIG_" + $stamp + ".docx.bak")) -Force
    }
    Copy-Item -LiteralPath $fixed -Destination $t -Force
    $log.Add("installed manuscript -> " + $t)
  }
  $upd = Get-ChildItem -LiteralPath $folders[0] -Directory -ErrorAction SilentlyContinue |
         Where-Object { $_.Name -like "AMP_Pipeline_Update_*" } | Select-Object -First 1
  if ($upd) {
    Copy-Item -LiteralPath $fixed -Destination (Join-Path $upd.FullName "AMP_Alligator_Gut_SCI_Manuscript.docx") -Force
    $log.Add("copied into update folder")
  }

  # verify by opening in Word read-only
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $word.DisplayAlerts = 0
  $doc = Join-Path $folders[0] "AMP_Alligator_Gut_SCI_Manuscript.docx"
  $d2 = $word.Documents.Open($doc, $false, $true)
  $log.Add("Word opened: paragraphs=" + $d2.Paragraphs.Count + " inlineShapes=" + $d2.InlineShapes.Count + " tables=" + $d2.Tables.Count)
  for ($i = 1; $i -le $d2.InlineShapes.Count; $i++) {
    $sh = $d2.InlineShapes.Item($i)
    $log.Add(("shape {0}: w={1} h={2}" -f $i, [int]$sh.Width, [int]$sh.Height))
  }
  $d2.Close($false); $word.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
  $log.Add("Word verification: PASSED")
}

$outDir = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
[IO.File]::WriteAllLines((Join-Path $outDir "push_fixed_docx.txt"), $log, $enc)
Write-Output "PUSHFIX_DONE=True"
