# t233_run_wallpaper_rebuild_safe_r281.ps1 - round 281 wrapper.
$ErrorActionPreference='Continue'
$py=''
foreach($n in @('python.exe','python','py.exe')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1; if($c -and $c.Source){ $py=$c.Source; break } }catch{} }
if(-not $py){ Write-Output 'python not found'; exit 7 }
$script=Join-Path $PSScriptRoot 't233_wallpaper_rebuild_safe_r281.py'
if($py -like '*py.exe'){ & $py -3 $script } else { & $py $script }
exit $LASTEXITCODE
