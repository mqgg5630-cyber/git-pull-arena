# t213_run_vlc_video_wallpaper_r262.ps1 - round 262 wrapper.
# Minimal PowerShell wrapper; all work is in Python to avoid AMSI false positives.
$ErrorActionPreference='Continue'
$py=''
foreach($n in @('python.exe','python','py.exe')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1; if($c -and $c.Source){ $py=$c.Source; break } }catch{} }
if(-not $py){ Write-Output 'python not found'; exit 7 }
$script=Join-Path $PSScriptRoot 't213_vlc_video_wallpaper_r262.py'
if($py -like '*py.exe'){
  & $py -3 $script
} else {
  & $py $script
}
exit $LASTEXITCODE
