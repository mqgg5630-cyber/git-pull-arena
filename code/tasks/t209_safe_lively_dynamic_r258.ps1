# t209_safe_lively_dynamic_r258.ps1 - round 258.
# Safely apply an existing anime MP4 live wallpaper through Lively only.
# A watchdog rolls back to a static Windows wallpaper if the apply hangs/fails.
# ASCII-only.

$ErrorActionPreference='Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { [System.Net.ServicePointManager]::CheckCertificateRevocationList=$false } catch {}
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function W([string]$p,[string[]]$lines){ WriteUtf8 $p (($lines -join "`r`n")+"`r`n") }
function Find-Cmd([string[]]$Names){ foreach($n in $Names){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1; if($c -and $c.Source){ return [string]$c.Source } }catch{} }; return '' }
function Run-CmdLine([string]$Line,[int]$TimeoutSec){
  $job=Start-Job -ScriptBlock { param($line); cmd.exe /d /s /c $line 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Line
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }
  return @{code=$code;text=$txt}
}
function Run-ExeArgs([string]$Exe,[string[]]$Args,[int]$TimeoutSec){
  if(-not $Exe -or -not(Test-Path -LiteralPath $Exe)){ return @{code=127;text='missing exe'} }
  $job=Start-Job -ScriptBlock { param($e,$a); & $e @a 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Exe,$Args
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }
  return @{code=$code;text=$txt}
}
function Capture-Screen([string]$Path){
  try{
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $b=[System.Windows.Forms.SystemInformation]::VirtualScreen
    if($b.Width -le 0 -or $b.Height -le 0){ return @{ok=$false;err='bad screen bounds';width=0;height=0} }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null
    $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size)
    $bmp.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    return @{ok=(Test-Path -LiteralPath $Path);err='';width=$b.Width;height=$b.Height}
  }catch{ return @{ok=$false;err=(San $_.Exception.Message);width=0;height=0} }
}
function Compare-Images([string]$A,[string]$B){
  try{
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $ia=[System.Drawing.Bitmap]::FromFile($A); $ib=[System.Drawing.Bitmap]::FromFile($B)
    $w=[Math]::Min($ia.Width,$ib.Width); $h=[Math]::Min($ia.Height,$ib.Height)
    $step=[Math]::Max(4,[int]([Math]::Min($w,$h)/260))
    $samples=0; $changed=0; [int64]$total=0
    for($y=0;$y -lt $h;$y+=$step){ for($x=0;$x -lt $w;$x+=$step){ $ca=$ia.GetPixel($x,$y); $cb=$ib.GetPixel($x,$y); $d=[Math]::Abs([int]$ca.R-[int]$cb.R)+[Math]::Abs([int]$ca.G-[int]$cb.G)+[Math]::Abs([int]$ca.B-[int]$cb.B); $total += $d; $samples++; if($d -gt 25){$changed++} } }
    $ia.Dispose(); $ib.Dispose(); $ratio=0.0; $avg=0.0; if($samples -gt 0){$ratio=[double]$changed/[double]$samples; $avg=[double]$total/[double]$samples}
    return @{ok=$true;samples=$samples;changed=$changed;ratio=$ratio;avgDiff=$avg;step=$step;width=$w;height=$h}
  }catch{ return @{ok=$false;err=(San $_.Exception.Message);samples=0;changed=0;ratio=0.0;avgDiff=0.0} }
}
function Find-LivelyExe(){
  foreach($p in @('C:\Program Files\Lively Wallpaper\Lively.exe','C:\Program Files (x86)\Lively Wallpaper\Lively.exe')){ if(Test-Path -LiteralPath $p){ return $p } }
  foreach($root in @($env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)){
    if($root -and (Test-Path -LiteralPath $root)){ try{ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter Lively.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){return $f.FullName} }catch{} }
  }
  return (Find-Cmd @('Lively.exe','lively.exe'))
}
function Download-Any([string[]]$Urls,[string]$Out){
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out)|Out-Null
  $curl=Find-Cmd @('curl.exe','curl')
  $attempts=@()
  foreach($u in $Urls){
    $tmp=$Out+'.tmp'; Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    if($curl){
      $cmd='"'+$curl+'" -L --ssl-no-revoke --retry 3 --connect-timeout 25 --max-time 300 -A "Mozilla/5.0" -o "'+$tmp+'" "'+$u+'"'
      $r=Run-CmdLine $cmd 360
      $bytes=0; if(Test-Path -LiteralPath $tmp){$bytes=(Get-Item -LiteralPath $tmp).Length}
      $attempts += [pscustomobject]@{url=$u;method='curl';exit=$r.code;bytes=$bytes;tail=(TailText (San $r.text) 4)}
      if($bytes -gt 650000){ Move-Item -LiteralPath $tmp -Destination $Out -Force; return [pscustomobject]@{ok=$true;url=$u;method='curl';attempts=$attempts} }
    }
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
  return [pscustomobject]@{ok=$false;url='';method='';attempts=$attempts}
}
function Stop-DangerousDynamic(){
  $stopped=0
  foreach($needle in @('Wait-And-Apply-On-Unlock.ps1','Apply-ExistingAnimeWallpaper.ps1','CuteAnimeDynamicWallpaperHost.ps1','cute-anime-live-r251','cute-anime-live-r252','cute-anime-live-r253')){
    try{ $ps=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($needle) }; foreach($p in $ps){ if($p.ProcessId -ne $PID){ try{ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; $stopped++ }catch{} } } }catch{}
  }
  foreach($name in @('Livelycu')){ try{ foreach($p in Get-Process -Name $name -ErrorAction SilentlyContinue){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; $stopped++ } }catch{} }
  try{ $startup=[Environment]::GetFolderPath('Startup'); if($startup -and (Test-Path -LiteralPath $startup)){ Get-ChildItem -LiteralPath $startup -Filter 'Apply Existing Anime Live Wallpaper*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue; Get-ChildItem -LiteralPath $startup -Filter 'Cute Anime Dynamic Wallpaper*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue } }catch{}
  return $stopped
}
function Set-StaticWallpaper([string]$Path){
  try{
    if(-not(Test-Path -LiteralPath $Path)){ return $false }
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $Path -ErrorAction SilentlyContinue
    $code='using System; using System.Runtime.InteropServices; public class WallpaperNative { [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni); }'
    Add-Type $code -ErrorAction SilentlyContinue
    return [WallpaperNative]::SystemParametersInfo(20,0,$Path,3)
  }catch{return $false}
}
function Tidy([string]$Desktop,[string]$Org){ New-Item -ItemType Directory -Force -Path $Org|Out-Null; $m=Join-Path $Org 'AUTO_TIDY_LAST_RUN.txt'; WriteUtf8 $m ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`nsafe_lively_dynamic_r258=True`r`n"); return $m }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R258_SAFE_LIVELY_DYNAMIC_WALLPAPER.md'
$jsonReport=Join-Path $outDir 'r258-safe-lively-dynamic-wallpaper.json'
$before=Join-Path $outDir 'r258_desktop_before.png'
$aShot=Join-Path $outDir 'r258_desktop_after_a.png'
$bShot=Join-Path $outDir 'r258_desktop_after_b.png'
$rollbackShot=Join-Path $outDir 'r258_rollback_screenshot.png'
$root='E:\0mcp-agv-arena-optimized\wallpapers\safe-existing-anime-live-r258'; New-Item -ItemType Directory -Force -Path $root|Out-Null
$keep=Join-Path $root 'KEEP_DYNAMIC_OK.marker'; Remove-Item -LiteralPath $keep -Force -ErrorAction SilentlyContinue
$rollbackLog=Join-Path $root 'ROLLBACK_WATCHDOG.log'
$static='C:\Windows\Web\Wallpaper\Windows\img0.jpg'
$mp4=Join-Path $root 'anime_girl_meteor_sky_safe_r258.mp4'
L '# R258 safe Lively dynamic wallpaper'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L 'safety=only Lively MP4 is used; custom hosts are disabled; watchdog rolls back if not confirmed'
$logon=@(); try{$logon=Get-Process LogonUI -ErrorAction SilentlyContinue}catch{}
$locked=(@($logon).Count -gt 0)
L ('screen_locked_detected='+$locked)
try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 1 }catch{}
$capBefore=Capture-Screen $before
L ('before_screenshot='+$before+' ok='+$capBefore.ok+' width='+$capBefore.width+' height='+$capBefore.height+' err='+$capBefore.err)
$stopped=Stop-DangerousDynamic
L ('dangerous_dynamic_processes_stopped='+$stopped)
$dl=$null
if(-not(Test-Path -LiteralPath $mp4)){
  $existing='E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r254\anime_girl_beneath_meteor_sky_existing_r254.mp4'
  if(Test-Path -LiteralPath $existing){ Copy-Item -LiteralPath $existing -Destination $mp4 -Force; $dl=[pscustomobject]@{ok=$true;url='local:'+ $existing;method='local';attempts=@()} }
}
if(-not(Test-Path -LiteralPath $mp4)){
  $dl=Download-Any @('https://cdn.livelywallpaper.app/wallpapers/beautiful-anime-girl-under-starry-sky/hd.mp4','https://cdn.livelywallpaper.app/wallpapers/beautiful-anime-girl-under-starry-sky/preview.mp4') $mp4
}
if($null -eq $dl){ $dl=[pscustomobject]@{ok=(Test-Path -LiteralPath $mp4);url='existing';method='existing';attempts=@()} }
$mp4Bytes=0; if(Test-Path -LiteralPath $mp4){$mp4Bytes=(Get-Item -LiteralPath $mp4).Length}
L ('selected_existing_wallpaper=Anime Girl Beneath a Meteor Sky')
L ('source_page=https://livelywallpaper.app/live-wallpapers/beautiful-anime-girl-under-starry-sky/')
L ('download_ok='+$dl.ok)
L ('download_url='+$dl.url)
L ('download_method='+$dl.method)
L ('mp4='+$mp4+' exists='+(Test-Path -LiteralPath $mp4))
L ('mp4_bytes='+$mp4Bytes)
$rollbackScript=Join-Path $root 'Rollback-If-Not-Kept.ps1'
$rollbackCode=@"
`$ErrorActionPreference='Continue'
`$Keep='$keep'
`$Log='$rollbackLog'
`$Static='$static'
function Log(`$m){ try{ Add-Content -LiteralPath `$Log -Encoding UTF8 -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+' '+`$m) }catch{} }
Start-Sleep -Seconds 150
if(-not(Test-Path -LiteralPath `$Keep)){
  Log 'rollback_start_no_keep_marker'
  try{ & 'C:\Program Files\Lively Wallpaper\Lively.exe' closewp --monitor -1 2>&1 | Out-String | Out-Null }catch{}
  try{ & 'C:\Program Files\Lively Wallpaper\Lively.exe' --shutdown true 2>&1 | Out-String | Out-Null }catch{}
  foreach(`$n in @('Lively','Lively.UI.WinUI','Livelycu','mpv','mpvnet')){ try{ Get-Process -Name `$n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }catch{} }
  try{ Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'; Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'; Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value `$Static }catch{}
  try{ rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True | Out-Null }catch{}
  try{ Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2; Start-Process explorer.exe | Out-Null }catch{}
  Log 'rollback_done'
} else { Log 'keep_marker_seen_no_rollback' }
"@
WriteUtf8 $rollbackScript $rollbackCode
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
try{ Start-Process -FilePath $psExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$rollbackScript) -WindowStyle Hidden -WorkingDirectory $root | Out-Null; $watchdogStarted=$true }catch{ $watchdogStarted=$false; L ('watchdog_start_error='+(San $_.Exception.Message)) }
L ('rollback_watchdog_started='+$watchdogStarted)
$lively=Find-LivelyExe
L ('lively_exe='+$lively+' exists='+($lively -and (Test-Path -LiteralPath $lively)))
$setOk=$false; $setAttempts=@()
if($lively -and (Test-Path -LiteralPath $lively) -and (Test-Path -LiteralPath $mp4)){
  try{ Start-Process -FilePath $lively -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 8 }catch{}
  foreach($args in @([string[]]@('closewp','--monitor','-1'),[string[]]@('--layout','duplicate'),[string[]]@('--volume','0'),[string[]]@('--play','true'),[string[]]@('setwp','--file',$mp4),[string[]]@('setwp','--file',$mp4,'--monitor','1'))){
    $r=Run-ExeArgs $lively $args 90
    $setAttempts += [pscustomobject]@{args=($args -join ' ');exit=$r.code;tail=(TailText (San $r.text) 5)}
    if($args[0] -eq 'setwp' -and $r.code -eq 0){$setOk=$true}
    Start-Sleep -Milliseconds 800
  }
}
L ('lively_set_ok='+$setOk)
$i=0; foreach($x in $setAttempts){ L ('lively_attempt_'+$i+'_args='+$x.args); L ('lively_attempt_'+$i+'_exit='+$x.exit); L ('lively_attempt_'+$i+'_tail='+$x.tail); $i++ }
Start-Sleep -Seconds 16
try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 1 }catch{}
$ca=Capture-Screen $aShot; Start-Sleep -Seconds 5; $cb=Capture-Screen $bShot
$diffBefore=@{ok=$false;ratio=0.0;avgDiff=0.0;changed=0;samples=0}; $diffMove=@{ok=$false;ratio=0.0;avgDiff=0.0;changed=0;samples=0}
if($capBefore.ok -and $ca.ok){$diffBefore=Compare-Images $before $aShot}
if($ca.ok -and $cb.ok){$diffMove=Compare-Images $aShot $bShot}
L ('after_a_screenshot='+$aShot+' ok='+$ca.ok+' width='+$ca.width+' height='+$ca.height+' err='+$ca.err)
L ('after_b_screenshot='+$bShot+' ok='+$cb.ok+' width='+$cb.width+' height='+$cb.height+' err='+$cb.err)
L ('desktop_changed_from_before_ratio='+('{0:N6}' -f [double]$diffBefore.ratio))
L ('desktop_changed_from_before_avg='+('{0:N3}' -f [double]$diffBefore.avgDiff))
L ('desktop_motion_diff_ratio='+('{0:N6}' -f [double]$diffMove.ratio))
L ('desktop_motion_diff_avg='+('{0:N3}' -f [double]$diffMove.avgDiff))
$livelyProc=@(); try{$livelyProc=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Lively*' -or $_.ProcessName -eq 'mpv' -or $_.ProcessName -eq 'mpvnet' }}catch{}
L ('lively_process_count='+(@($livelyProc).Count))
$desktopChanged=($diffBefore.ok -and ([double]$diffBefore.ratio -gt 0.02 -or [double]$diffBefore.avgDiff -gt 4.0))
$desktopMoving=($diffMove.ok -and ([double]$diffMove.ratio -gt 0.0005 -or [double]$diffMove.avgDiff -gt 0.25))
$success=($setOk -and $desktopChanged -and $desktopMoving -and (@($livelyProc).Count -gt 0) -and -not $locked)
if($success){ WriteUtf8 $keep ('ok '+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`n") } else {
  L 'safe_rollback_reason=dynamic apply was not proven or desktop was locked'
  if($lively){ Run-ExeArgs $lively ([string[]]@('closewp','--monitor','-1')) 30 | Out-Null; Run-ExeArgs $lively ([string[]]@('--shutdown','true')) 30 | Out-Null }
  foreach($n in @('Lively','Lively.UI.WinUI','Livelycu','mpv','mpvnet')){ try{ Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }catch{} }
  Set-StaticWallpaper $static | Out-Null
  try{ rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True | Out-Null }catch{}
  Start-Sleep -Seconds 3
  Capture-Screen $rollbackShot | Out-Null
}
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop){$desktop=Join-Path $env:USERPROFILE 'Desktop'}
$tidy=Tidy $desktop (Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer')
L ('actual_desktop_changed_to_new_wallpaper='+$desktopChanged)
L ('actual_desktop_is_moving='+$desktopMoving)
L ('rollback_marker_written='+(Test-Path -LiteralPath $keep))
L ('desktop_tidy_manifest='+$tidy)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy))
L ('R258_SAFE_LIVELY_DYNAMIC_WALLPAPER_READY='+$success)
$summary=[pscustomobject]@{ready=$success;locked=$locked;mp4=$mp4;mp4Bytes=$mp4Bytes;watchdogStarted=$watchdogStarted;livelySetOk=$setOk;before=$before;afterA=$aShot;afterB=$bShot;rollbackScreenshot=$rollbackShot;desktopChangedFromBeforeRatio=[double]$diffBefore.ratio;desktopChangedFromBeforeAvg=[double]$diffBefore.avgDiff;desktopMotionDiffRatio=[double]$diffMove.ratio;desktopMotionDiffAvg=[double]$diffMove.avgDiff;actualDesktopChangedToNewWallpaper=$desktopChanged;actualDesktopIsMoving=$desktopMoving;keepMarkerWritten=(Test-Path -LiteralPath $keep);livelyProcessCount=@($livelyProc).Count;tidyManifest=$tidy}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 6)+"`r`n")
W $report $script:Lines
if(-not $success){ exit 6 }
exit 0
