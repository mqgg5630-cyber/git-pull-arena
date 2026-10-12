$ErrorActionPreference = "Continue"
$repo = (Get-Location).Path
$enc  = New-Object Text.UTF8Encoding($false)
$log  = New-Object System.Collections.Generic.List[string]
$desktop = [Environment]::GetFolderPath("Desktop")

Get-Process WINWORD -ErrorAction SilentlyContinue | ForEach-Object {
  $log.Add("killing WINWORD pid " + $_.Id)
  Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

$folder = Join-Path $desktop "AMP_Docking_Vina_R255_20261005_1552"
$doc = Join-Path $folder "AMP_Alligator_Gut_SCI_Manuscript.docx"
$dst = Join-Path $repo "work\AMP_Alligator_Gut_SCI_Manuscript.docx"
New-Item -ItemType Directory -Force -Path (Join-Path $repo "work") | Out-Null
if (Test-Path -LiteralPath $doc) {
  Copy-Item -LiteralPath $doc -Destination $dst -Force
  $log.Add("pulled manuscript: " + (Get-Item -LiteralPath $dst).Length + " B")
} else { $log.Add("manuscript missing") }

Get-ChildItem -LiteralPath $folder -Filter "~`$*" -Force -ErrorAction SilentlyContinue |
  ForEach-Object { $log.Add("lock file present: " + $_.Name) }

$outDir = Join-Path $repo "results\hpc\repro"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
[IO.File]::WriteAllLines((Join-Path $outDir "pull_docx.txt"), $log, $enc)
Write-Output "PULL_DONE=True"
