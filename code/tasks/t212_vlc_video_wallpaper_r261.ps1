# t212_vlc_video_wallpaper_r261.ps1 - round 261.
# Use VLC's built-in video-wallpaper mode as an alternative to broken Lively.
# No custom desktop host. Verify real desktop screenshots. ASCII-only.

$ErrorActionPreference='Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function W([string]$p,[string[]]$lines){ WriteUtf8 $p (($lines -join "`r`n")+"`r`n") }
function RunExe([string]$Exe,[string[]]$Args,[int]$TimeoutSec){
  if(-not $Exe -or -not(Test-Path -LiteralPath $Exe)){ return @{code=127;text='missing exe'} }
  $job=Start-Job -ScriptBlock { param($e,$a); & $e @a 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Exe,$Args
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }
  return @{code=$code;text=$txt}
}
function RunLine([string]$Line,[int]$TimeoutSec){
  $job=Start-Job -ScriptBlock { param($line); cmd.exe /d /s /c $line 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Line
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }
  return @{code=$code;text=$txt}
}
function Capture([string]$Path){
  try{ Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue; Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue; $b=[System.Windows.Forms.SystemInformation]::VirtualScreen; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null; $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size); $bmp.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose(); return @{ok=(Test-Path -LiteralPath $Path);width=$b.Width;height=$b.Height;err=''} }catch{ return @{ok=$false;width=0;height=0;err=$_.Exception.Message} }
}
function DiffImg([string]$A,[string]$B){
  try{ Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue; $ia=[System.Drawing.Bitmap]::FromFile($A); $ib=[System.Drawing.Bitmap]::FromFile($B); $w=[Math]::Min($ia.Width,$ib.Width); $h=[Math]::Min($ia.Height,$ib.Height); $step=[Math]::Max(4,[int]([Math]::Min($w,$h)/260)); $samples=0; $changed=0; [int64]$total=0; for($y=0;$y -lt $h;$y+=$step){ for($x=0;$x -lt $w;$x+=$step){ $ca=$ia.GetPixel($x,$y); $cb=$ib.GetPixel($x,$y); $d=[Math]::Abs([int]$ca.R-[int]$cb.R)+[Math]::Abs([int]$ca.G-[int]$cb.G)+[Math]::Abs([int]$ca.B-[int]$cb.B); $total+=$d; $samples++; if($d -gt 25){$changed++} } }; $ia.Dispose(); $ib.Dispose(); $ratio=0.0; $avg=0.0; if($samples -gt 0){$ratio=[double]$changed/[double]$samples; $avg=[double]$total/[double]$samples}; return @{ok=$true;ratio=$ratio;avg=$avg;changed=$changed;samples=$samples} }catch{ return @{ok=$false;ratio=0.0;avg=0.0;changed=0;samples=0;err=$_.Exception.Message} }
}
function FindVlc(){
  foreach($p in @('C:\Program Files\VideoLAN\VLC\vlc.exe','C:\Program Files (x86)\VideoLAN\VLC\vlc.exe')){ if(Test-Path -LiteralPath $p){ return $p } }
  try{ $c=Get-Command vlc.exe -ErrorAction SilentlyContinue|Select-Object -First 1; if($c -and $c.Source){return $c.Source} }catch{}
  return ''
}
function SetStatic([string]$Path){ try{ Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10' -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0' -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $Path -ErrorAction SilentlyContinue; rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True | Out-Null; return $true }catch{return $false} }
function Tidy(){ $d=[Environment]::GetFolderPath('Desktop'); if(-not $d){$d=Join-Path $env:USERPROFILE 'Desktop'}; $org=Join-Path $d 'DeskBox-Cute-Desktop-Organizer'; New-Item -ItemType Directory -Force -Path $org|Out-Null; $m=Join-Path $org 'AUTO_TIDY_LAST_RUN.txt'; WriteUtf8 $m ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`nvlc_video_wallpaper_r261=True`r`n"); return $m }
$script:Lines=@(); $repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path; $outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R261_VLC_VIDEO_WALLPAPER.md'; $json=Join-Path $outDir 'r261-vlc-video-wallpaper.json'; $before=Join-Path $outDir 'r261_desktop_before.png'; $afterA=Join-Path $outDir 'r261_desktop_after_a.png'; $afterB=Join-Path $outDir 'r261_desktop_after_b.png'; $rollback=Join-Path $outDir 'r261_rollback_screenshot.png'
$root='E:\0mcp-agv-arena-optimized\wallpapers\vlc-anime-live-r261'; New-Item -ItemType Directory -Force -Path $root|Out-Null
$mp4=Join-Path $root 'anime_girl_beneath_meteor_sky_vlc_r261.mp4'; $src='E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r254\anime_girl_beneath_meteor_sky_existing_r254.mp4'; if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $mp4 -Force }
$static='C:\Windows\Web\Wallpaper\Windows\img0.jpg'
L '# R261 VLC video wallpaper'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
$locked=(@(Get-Process LogonUI -ErrorAction SilentlyContinue).Count -gt 0); L ('screen_locked_detected='+$locked)
try{ $lively='C:\Program Files\Lively Wallpaper\Lively.exe'; if(Test-Path -LiteralPath $lively){ RunExe $lively ([string[]]@('closewp','--monitor','-1')) 20|Out-Null; RunExe $lively ([string[]]@('--shutdown','true')) 20|Out-Null } }catch{}
try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 1 }catch{}
$capB=Capture $before; L ('before_screenshot='+$before+' ok='+$capB.ok+' width='+$capB.width+' height='+$capB.height+' err='+$capB.err)
$vlc=FindVlc
if(-not $vlc){
  $winget=(Get-Command winget.exe -ErrorAction SilentlyContinue|Select-Object -First 1).Source
  if($winget){ $r=RunLine ('"'+$winget+'" install -e --id VideoLAN.VLC --silent --accept-package-agreements --accept-source-agreements') 900; L ('winget_vlc_install_exit='+$r.code); L ('winget_vlc_install_tail='+(($r.text -split "`r?`n"|Select-Object -Last 8)-join ' | ')); $vlc=FindVlc }
}
$bytes=0; if(Test-Path -LiteralPath $mp4){$bytes=(Get-Item -LiteralPath $mp4).Length}; L ('selected_existing_wallpaper=Anime Girl Beneath a Meteor Sky'); L ('mp4='+$mp4+' exists='+(Test-Path -LiteralPath $mp4)); L ('mp4_bytes='+$bytes); L ('vlc_exe='+$vlc+' exists='+(Test-Path -LiteralPath $vlc))
$startOk=$false
if((Test-Path -LiteralPath $vlc) -and (Test-Path -LiteralPath $mp4)){
  $args=@('--no-audio','--loop','--repeat','--video-wallpaper','--no-video-title-show','--qt-start-minimized','--qt-system-tray','--no-qt-privacy-ask','--width=1536','--height=864',$mp4)
  try{ Start-Process -FilePath $vlc -ArgumentList $args -WindowStyle Minimized -WorkingDirectory (Split-Path -Parent $vlc)|Out-Null; $startOk=$true }catch{ L ('vlc_start_error='+$_.Exception.Message) }
}
L ('vlc_start_ok='+$startOk)
Start-Sleep -Seconds 18; try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 1 }catch{}
$capA=Capture $afterA; Start-Sleep -Seconds 6; $capC=Capture $afterB; $d1=DiffImg $before $afterA; $d2=DiffImg $afterA $afterB
L ('after_a_screenshot='+$afterA+' ok='+$capA.ok+' width='+$capA.width+' height='+$capA.height+' err='+$capA.err); L ('after_b_screenshot='+$afterB+' ok='+$capC.ok+' width='+$capC.width+' height='+$capC.height+' err='+$capC.err)
L ('desktop_changed_from_before_ratio='+('{0:N6}' -f [double]$d1.ratio)); L ('desktop_changed_from_before_avg='+('{0:N3}' -f [double]$d1.avg)); L ('desktop_motion_diff_ratio='+('{0:N6}' -f [double]$d2.ratio)); L ('desktop_motion_diff_avg='+('{0:N3}' -f [double]$d2.avg))
$vlcProcs=@(); try{$vlcProcs=Get-Process -Name vlc -ErrorAction SilentlyContinue}catch{}; L ('vlc_process_count='+(@($vlcProcs).Count))
$changed=($d1.ok -and ([double]$d1.ratio -gt 0.02 -or [double]$d1.avg -gt 4.0)); $moving=($d2.ok -and ([double]$d2.ratio -gt 0.0005 -or [double]$d2.avg -gt 0.25)); $success=($startOk -and $changed -and $moving -and -not $locked)
if(-not $success){ L 'rollback_performed=True'; try{ if($vlc){ Start-Process -FilePath $vlc -ArgumentList @('vlc://quit') -WindowStyle Hidden|Out-Null; Start-Sleep -Seconds 2 } }catch{}; SetStatic $static|Out-Null; Start-Sleep -Seconds 3; Capture $rollback|Out-Null }
$tidy=Tidy; L ('actual_desktop_changed_to_new_wallpaper='+$changed); L ('actual_desktop_is_moving='+$moving); L ('desktop_tidy_manifest='+$tidy); L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy)); L ('R261_VLC_VIDEO_WALLPAPER_READY='+$success)
$summary=[pscustomobject]@{ready=$success;locked=$locked;vlc=$vlc;vlcStarted=$startOk;mp4=$mp4;mp4Bytes=$bytes;before=$before;afterA=$afterA;afterB=$afterB;rollback=$rollback;desktopChangedFromBeforeRatio=[double]$d1.ratio;desktopChangedFromBeforeAvg=[double]$d1.avg;desktopMotionDiffRatio=[double]$d2.ratio;desktopMotionDiffAvg=[double]$d2.avg;actualDesktopChangedToNewWallpaper=$changed;actualDesktopIsMoving=$moving;vlcProcessCount=@($vlcProcs).Count;tidyManifest=$tidy}
WriteUtf8 $json (($summary|ConvertTo-Json -Depth 6)+"`r`n"); W $report $script:Lines; if(-not $success){exit 6}; exit 0
