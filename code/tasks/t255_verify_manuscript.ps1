$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$enc  = New-Object Text.UTF8Encoding($false)
$log  = New-Object System.Collections.Generic.List[string]
$desktop = [Environment]::GetFolderPath("Desktop")
$doc = Join-Path $desktop "AMP_Docking_Vina_R255_20261005_1552\AMP_Alligator_Gut_SCI_Manuscript.docx"
$log.Add("DOC exists=" + (Test-Path -LiteralPath $doc))
if (Test-Path -LiteralPath $doc) {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $d = $word.Documents.Open($doc, $false, $true)
  $log.Add("paragraphs=" + $d.Paragraphs.Count + " inlineShapes=" + $d.InlineShapes.Count + " tables=" + $d.Tables.Count)
  $want = 23,24,25,26,27,28,29,30,31,32,33,34,56,57,58,59,60,61,62,63,64,65,66,386,388
  foreach ($i in $want) {
    if ($i -gt $d.Paragraphs.Count) { continue }
    $t = $d.Paragraphs.Item($i).Range.Text -replace "[`r`n`a]",""
    if ($t.Trim().Length -eq 0) { $log.Add("[$i] <empty>"); continue }
    if ($t.Length -gt 150) { $t = $t.Substring(0,150) + " ..." }
    $log.Add("[$i] " + $t)
  }
  $log.Add("--- shapes ---")
  for ($i = 1; $i -le $d.InlineShapes.Count; $i++) {
    $sh = $d.InlineShapes.Item($i)
    $log.Add(("shape {0}: w={1} h={2}" -f $i, [int]$sh.Width, [int]$sh.Height))
  }
  $hits = 0
  $rng = $d.Content
  $rng.Find.Text = "268"
  if ($rng.Find.Execute()) { $hits = 1 }
  $log.Add("still contains '268': " + $hits)
  $d.Close($false); $word.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}
$outDir = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
[IO.File]::WriteAllLines((Join-Path $outDir "manuscript_verify.txt"), $log, $enc)
Write-Output "VERIFY_DONE=True"
