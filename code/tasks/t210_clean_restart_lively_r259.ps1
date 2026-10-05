# t210_clean_restart_lively_r259.ps1 - round 259.
# Clean-restart Lively after the failed safe attempt, apply an existing cute/anime
# MP4 live wallpaper, verify actual desktop pixels, otherwise rollback.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function W([string]$p,[string[]]$lines){ WriteUtf8 $p (($lines -join "`r`n")+"`r`n") }
function RunLine([string]$Line,[int]$TimeoutSec){
  $job=Start-Job -ScriptBlock { param($line); cmd.exe /d /s /c $line 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Line
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }
  return @{code=$code;text=$txt}
}
function RunExe([string]$Exe,[string[]]$Args,[int]$TimeoutSec){
  if(-not $Exe -or -not(Test-Path -LiteralPath $Exe)){ return @{code=127;text='missing exe'} }
  $job=Start-Job -ScriptBlock { param($e,$a); & $e @a 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Exe,$Args
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }
  return @{code=$code;text=$txt}
}
function Capture([string]$Path){
  try{
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue; Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $b=[System.Windows.Forms.SystemInformation]::VirtualScreen; if($b.Width -le 0 -or $b.Height -le 0){ return @{ok=$false;err='bad bounds';width=0;height=0} }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null
    $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size); $bmp.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
    return @{ok=(Test-Path -LiteralPath $Path);err='';width=$b.Width;height=$b.Height}
  }catch{ return @{ok=$false;err=(San $_.Exception.Message);width=0;height=0} }
}
function DiffImg([string]$A,[string]$B){
  try{
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $ia=[System.Drawing.Bitmap]::FromFile($A); $ib=[System.Drawing.Bitmap]::FromFile($B); $w=[Math]::Min($ia.Width,$ib.Width); $h=[Math]::Min($ia.Height,$ib.Height); $step=[Math]::Max(4,[int]([Math]::Min($w,$h)/260))
    $samples=0; $changed=0; [int64]$total=0
    for($y=0;$y -lt $h;$y+=$step){ for($x=0;$x -lt $w;$x+=$step){ $ca=$ia.GetPixel($x,$y); $cb=$ib.GetPixel($x,$y); $d=[Math]::Abs([int]$ca.R-[int]$cb.R)+[Math]::Abs([int]$ca.G-[int]$cb.G)+[Math]::Abs([int]$ca.B-[int]$cb.B); $total += $d; $samples++; if($d -gt 25){$changed++} } }
    $ia.Dispose(); $ib.Dispose(); $ratio=0.0; $avg=0.0; if($samples -gt 0){$ratio=[double]$changed/[double]$samples; $avg=[double]$total/[double]$samples}; return @{ok=$true;ratio=$ratio;avg=$avg;changed=$changed;samples=$samples}
  }catch{ return @{ok=$false;ratio=0.0;avg=0.0;changed=0;samples=0;err=(San $_.Exception.Message)} }
}
function SetStatic([string]$Path){
  try{ Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10' -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0' -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $Path -ErrorAction SilentlyContinue; $code='using System; using System.Runtime.InteropServices; public class WpN { [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni); }'; Add-Type $code -ErrorAction SilentlyContinue; return [WpN]::SystemParametersInfo(20,0,$Path,3) }catch{return $false}
}
function HardKillDynamic(){
  $n=0
  foreach($needle in @('Wait-And-Apply-On-Unlock.ps1','Apply-ExistingAnimeWallpaper.ps1','CuteAnimeDynamicWallpaperHost.ps1')){ try{ $ps=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue|Where-Object{$_.CommandLine -and $_.CommandLine.Contains($needle)}; foreach($p in $ps){ if($p.ProcessId -ne $PID){ try{ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; $n++ }catch{} } } }catch{} }
  foreach($im in @('Lively.exe','Lively.UI.WinUI.exe','Livelycu.exe','mpv.exe','mpvnet.exe')){ $r=RunLine ('taskkill /F /T /IM "'+$im+'"') 25; if($r.code -eq 0){$n++}; L ('taskkill_'+$im+'_exit='+$r.code) }
  try{ $startup=[Environment]::GetFolderPath('Startup'); if($startup -and (Test-Path -LiteralPath $startup)){ Get-ChildItem -LiteralPath $startup -Filter '*Anime*Wallpaper*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue } }catch{}
  return $n
}
function FindLively(){ foreach($p in @('C:\Program Files\Lively Wallpaper\Lively.exe','C:\Program Files (x86)\Lively Wallpaper\Lively.exe')){ if(Test-Path -LiteralPath $p){return $p} }; return '' }
function Tidy(){ $d=[Environment]::GetFolderPath('Desktop'); if(-not $d){$d=Join-Path $env:USERPROFILE 'Desktop'}; $org=Join-Path $d 'DeskBox-Cute-Desktop-Organizer'; New-Item -ItemType Directory -Force -Path $org|Out-Null; $m=Join-Path $org 'AUTO_TIDY_LAST_RUN.txt'; WriteUtf8 $m ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`nclean_restart_lively_r259=True`r`n"); return $m }
$script:Lines=@(); $repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path; $outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R259_CLEAN_RESTART_LIVELY_DYNAMIC.md'; $json=Join-Path $outDir 'r259-clean-restart-lively-dynamic.json'
$before=Join-Path $outDir 'r259_desktop_before.png'; $afterA=Join-Path $outDir 'r259_desktop_after_a.png'; $afterB=Join-Path $outDir 'r259_desktop_after_b.png'; $rollback=Join-Path $outDir 'r259_rollback_screenshot.png'
$root='E:\0mcp-agv-arena-optimized\wallpapers\clean-lively-r259'; New-Item -ItemType Directory -Force -Path $root|Out-Null; $keep=Join-Path $root 'KEEP_DYNAMIC_OK.marker'; Remove-Item -LiteralPath $keep -Force -ErrorAction SilentlyContinue
$mp4=Join-Path $root 'anime_girl_beneath_meteor_sky_r259.mp4'; $src='E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r254\anime_girl_beneath_meteor_sky_existing_r254.mp4'; if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $mp4 -Force }
$static='C:\Windows\Web\Wallpaper\Windows\img0.jpg'
L '# R259 clean restart Lively dynamic wallpaper'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
$locked=(@(Get-Process LogonUI -ErrorAction SilentlyContinue).Count -gt 0); L ('screen_locked_detected='+$locked)
try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 1 }catch{}
$cb=Capture $before; L ('before_screenshot='+$before+' ok='+$cb.ok+' width='+$cb.width+' height='+$cb.height+' err='+$cb.err)
$k=HardKillDynamic; L ('hardkill_dynamic_count='+$k)
# Restart Explorer first; then start Lively fresh so it recreates WorkerW handles.
try{ Get-Process explorer -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3; Start-Process explorer.exe|Out-Null; Start-Sleep -Seconds 8; $explorerRestarted=$true }catch{ $explorerRestarted=$false; L ('explorer_restart_error='+(San $_.Exception.Message)) }
L ('explorer_restarted_before_lively='+$explorerRestarted)
$mp4Bytes=0; if(Test-Path -LiteralPath $mp4){$mp4Bytes=(Get-Item -LiteralPath $mp4).Length}; L ('selected_existing_wallpaper=Anime Girl Beneath a Meteor Sky'); L ('mp4='+$mp4+' exists='+(Test-Path -LiteralPath $mp4)); L ('mp4_bytes='+$mp4Bytes)
$lively=FindLively; L ('lively_exe='+$lively+' exists='+(Test-Path -LiteralPath $lively))
$watch=Join-Path $root 'Rollback-If-NoKeep.ps1'; $watchCode=@"
Start-Sleep -Seconds 180
if(-not(Test-Path -LiteralPath '$keep')){ try{ & '$lively' closewp --monitor -1 | Out-Null }catch{}; try{ & '$lively' --shutdown true | Out-Null }catch{}; foreach(`$n in @('Lively','Lively.UI.WinUI','Livelycu','mpv','mpvnet')){try{Get-Process -Name `$n -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue}catch{}}; try{Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value '$static'; rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True | Out-Null}catch{} }
"@; WriteUtf8 $watch $watchCode; $psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'; try{Start-Process $psExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$watch) -WindowStyle Hidden|Out-Null; $watchdogStarted=$true}catch{$watchdogStarted=$false}; L ('rollback_watchdog_started='+$watchdogStarted)
$setOk=$false; $attempts=@()
if((Test-Path -LiteralPath $lively) -and (Test-Path -LiteralPath $mp4)){
  Start-Process -FilePath $lively -WindowStyle Hidden -ErrorAction SilentlyContinue|Out-Null; Start-Sleep -Seconds 18
  foreach($args in @([string[]]@('--showApp','false'),[string[]]@('--layout','duplicate'),[string[]]@('--volume','0'),[string[]]@('--play','true'),[string[]]@('setwp','--file',$mp4),[string[]]@('setwp','--file',$mp4,'--monitor','1'))){ $r=RunExe $lively $args 120; $attempts += [pscustomobject]@{args=($args -join ' ');exit=$r.code;tail=(TailText (San $r.text) 5)}; if($args[0] -eq 'setwp' -and $r.code -eq 0){$setOk=$true}; Start-Sleep -Seconds 2 }
}
L ('lively_set_ok='+$setOk); $i=0; foreach($a in $attempts){L ('lively_attempt_'+$i+'_args='+$a.args); L ('lively_attempt_'+$i+'_exit='+$a.exit); L ('lively_attempt_'+$i+'_tail='+$a.tail); $i++}
Start-Sleep -Seconds 25; try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 1 }catch{}
$ca=Capture $afterA; Start-Sleep -Seconds 6; $cc=Capture $afterB; $d1=DiffImg $before $afterA; $d2=DiffImg $afterA $afterB
L ('after_a_screenshot='+$afterA+' ok='+$ca.ok+' width='+$ca.width+' height='+$ca.height+' err='+$ca.err); L ('after_b_screenshot='+$afterB+' ok='+$cc.ok+' width='+$cc.width+' height='+$cc.height+' err='+$cc.err)
L ('desktop_changed_from_before_ratio='+('{0:N6}' -f [double]$d1.ratio)); L ('desktop_changed_from_before_avg='+('{0:N3}' -f [double]$d1.avg)); L ('desktop_motion_diff_ratio='+('{0:N6}' -f [double]$d2.ratio)); L ('desktop_motion_diff_avg='+('{0:N3}' -f [double]$d2.avg))
$proc=@(); $cmdHits=@(); try{$proc=Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName -like 'Lively*' -or $_.ProcessName -eq 'mpv' -or $_.ProcessName -eq 'mpvnet'}; $cmdHits=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue|Where-Object{$_.CommandLine -and $_.CommandLine.Contains('anime_girl_beneath_meteor_sky_r259')}}catch{}
L ('lively_process_count='+(@($proc).Count)); L ('wallpaper_cmd_hit_count='+(@($cmdHits).Count))
$changed=($d1.ok -and ([double]$d1.ratio -gt 0.02 -or [double]$d1.avg -gt 4.0)); $moving=($d2.ok -and ([double]$d2.ratio -gt 0.0005 -or [double]$d2.avg -gt 0.25)); $success=($setOk -and $changed -and $moving -and -not $locked)
if($success){ WriteUtf8 $keep ('ok '+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`n") } else { L 'rollback_performed=True'; if(Test-Path -LiteralPath $lively){RunExe $lively ([string[]]@('closewp','--monitor','-1')) 30|Out-Null; RunExe $lively ([string[]]@('--shutdown','true')) 30|Out-Null}; foreach($n in @('Lively','Lively.UI.WinUI','Livelycu','mpv','mpvnet')){try{Get-Process -Name $n -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue}catch{}}; SetStatic $static|Out-Null; Start-Sleep -Seconds 4; Capture $rollback|Out-Null }
$tidy=Tidy; L ('actual_desktop_changed_to_new_wallpaper='+$changed); L ('actual_desktop_is_moving='+$moving); L ('rollback_marker_written='+(Test-Path -LiteralPath $keep)); L ('desktop_tidy_manifest='+$tidy); L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy)); L ('R259_CLEAN_RESTART_LIVELY_DYNAMIC_READY='+$success)
$summary=[pscustomobject]@{ready=$success;locked=$locked;mp4=$mp4;mp4Bytes=$mp4Bytes;explorerRestarted=$explorerRestarted;watchdogStarted=$watchdogStarted;livelySetOk=$setOk;before=$before;afterA=$afterA;afterB=$afterB;rollback=$rollback;desktopChangedFromBeforeRatio=[double]$d1.ratio;desktopChangedFromBeforeAvg=[double]$d1.avg;desktopMotionDiffRatio=[double]$d2.ratio;desktopMotionDiffAvg=[double]$d2.avg;actualDesktopChangedToNewWallpaper=$changed;actualDesktopIsMoving=$moving;keepMarker=(Test-Path -LiteralPath $keep);livelyProcessCount=@($proc).Count;wallpaperCommandLineHits=@($cmdHits).Count;tidyManifest=$tidy}
WriteUtf8 $json (($summary|ConvertTo-Json -Depth 6)+"`r`n"); W $report $script:Lines; if(-not $success){exit 6}; exit 0
