# t228_run_lively_one_click_repair_r276.ps1 - round 276 wrapper.
$ErrorActionPreference='Continue'
$py=''
foreach($n in @('python.exe','python','py.exe')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1; if($c -and $c.Source){ $py=$c.Source; break } }catch{} }
if(-not $py){ Write-Output 'python not found'; exit 7 }
$script=Join-Path $PSScriptRoot 't228_lively_one_click_repair_r276.py'
if($py -like '*py.exe'){ & $py -3 $script } else { & $py $script }
exit $LASTEXITCODE
