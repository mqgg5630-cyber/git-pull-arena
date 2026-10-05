# t221_run_dynamic_video_wallpaper_r269.ps1 - round 269 wrapper.
$ErrorActionPreference='Continue'
$py=''
foreach($n in @('python.exe','python','py.exe')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1; if($c -and $c.Source){ $py=$c.Source; break } }catch{} }
if(-not $py){ Write-Output 'python not found'; exit 7 }
$script=Join-Path $PSScriptRoot 't221_dynamic_video_wallpaper_r269.py'
if($py -like '*py.exe'){ & $py -3 $script } else { & $py $script }
exit $LASTEXITCODE
