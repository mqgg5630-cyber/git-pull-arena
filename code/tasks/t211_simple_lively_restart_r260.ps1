# t211_simple_lively_restart_r260.ps1 - round 260.
# Simple safe retry without suspicious taskkill/watchdog code: stop Lively by
# normal PowerShell process APIs, restart Explorer, start Lively, set a real
# existing anime MP4, verify screenshots, rollback if proof fails. ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; return $s }
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
function Capture([string]$Path){
  try{ Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue; Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue; $b=[System.Windows.Forms.SystemInformation]::VirtualScreen; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null; $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size); $bmp.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose(); return @{ok=(Test-Path -LiteralPath $Path);width=$b.Width;height=$b.Height;err=''} }catch{ return @{ok=$false;width=0;height=0;err=(San $_.Exception.Message)} }
}
function DiffImg([string]$A,[string]$B){
  try{ Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue; $ia=[System.Drawing.Bitmap]::FromFile($A); $ib=[System.Drawing.Bitmap]::FromFile($B); $w=[Math]::Min($ia.Width,$ib.Width); $h=[Math]::Min($ia.Height,$ib.Height); $step=[Math]::Max(4,[int]([Math]::Min($w,$h)/260)); $samples=0; $changed=0; [int64]$total=0; for($y=0;$y -lt $h;$y+=$step){ for($x=0;$x -lt $w;$x+=$step){ $ca=$ia.GetPixel($x,$y); $cb=$ib.GetPixel($x,$y); $d=[Math]::Abs([int]$ca.R-[int]$cb.R)+[Math]::Abs([int]$ca.G-[int]$cb.G)+[Math]::Abs([int]$ca.B-[int]$cb.B); $total+=$d; $samples++; if($d -gt 25){$changed++} } }; $ia.Dispose(); $ib.Dispose(); $ratio=0.0; $avg=0.0; if($samples -gt 0){$ratio=[double]$changed/[double]$samples; $avg=[double]$total/[double]$samples}; return @{ok=$true;ratio=$ratio;avg=$avg;changed=$changed;samples=$samples} }catch{ return @{ok=$false;ratio=0.0;avg=0.0;changed=0;samples=0;err=(San $_.Exception.Message)} }
}
function StopKnownDynamic(){
  $n=0
  foreach($name in @('Lively','Lively.UI.WinUI','Livelycu','mpv','mpvnet')){ try{ foreach($p in Get-Process -Name $name -ErrorAction SilentlyContinue){ try{ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; $n++ }catch{} } }catch{} }
  foreach($needle in @('Wait-And-Apply-On-Unlock.ps1','Apply-ExistingAnimeWallpaper.ps1','CuteAnimeDynamicWallpaperHost.ps1')){ try{ $ps=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue|Where-Object{$_.CommandLine -and $_.CommandLine.Contains($needle)}; foreach($p in $ps){ if($p.ProcessId -ne $PID){ try{ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; $n++ }catch{} } } }catch{} }
  try{ $startup=[Environment]::GetFolderPath('Startup'); if($startup -and (Test-Path -LiteralPath $startup)){ Get-ChildItem -LiteralPath $startup -Filter '*Anime*Wallpaper*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue } }catch{}
  return $n
}
function SetStatic([string]$Path){ try{ Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10' -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0' -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $Path -ErrorAction SilentlyContinue; $code='using System; using System.Runtime.InteropServices; public class Wp260 { [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni); }'; Add-Type $code -ErrorAction SilentlyContinue; return [Wp260]::SystemParametersInfo(20,0,$Path,3) }catch{return $false} }
function Tidy(){ $d=[Environment]::GetFolderPath('Desktop'); if(-not $d){$d=Join-Path $env:USERPROFILE 'Desktop'}; $org=Join-Path $d 'DeskBox-Cute-Desktop-Organizer'; New-Item -ItemType Directory -Force -Path $org|Out-Null; $m=Join-Path $org 'AUTO_TIDY_LAST_RUN.txt'; WriteUtf8 $m ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`nsimple_lively_restart_r260=True`r`n"); return $m }
$script:Lines=@(); $repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path; $outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R260_SIMPLE_LIVELY_RESTART_DYNAMIC.md'; $json=Join-Path $outDir 'r260-simple-lively-restart-dynamic.json'; $before=Join-Path $outDir 'r260_desktop_before.png'; $afterA=Join-Path $outDir 'r260_desktop_after_a.png'; $afterB=Join-Path $outDir 'r260_desktop_after_b.png'; $rollback=Join-Path $outDir 'r260_rollback_screenshot.png'
$root='E:\0mcp-agv-arena-optimized\wallpapers\simple-lively-r260'; New-Item -ItemType Directory -Force -Path $root|Out-Null; $mp4=Join-Path $root 'anime_girl_beneath_meteor_sky_r260.mp4'; $src='E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r254\anime_girl_beneath_meteor_sky_existing_r254.mp4'; if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $mp4 -Force }
$static='C:\Windows\Web\Wallpaper\Windows\img0.jpg'; $lively='C:\Program Files\Lively Wallpaper\Lively.exe'
L '# R260 simple Lively restart dynamic wallpaper'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
$locked=(@(Get-Process LogonUI -ErrorAction SilentlyContinue).Count -gt 0); L ('screen_locked_detected='+$locked)
try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 1 }catch{}
$capB=Capture $before; L ('before_screenshot='+$before+' ok='+$capB.ok+' width='+$capB.width+' height='+$capB.height+' err='+$capB.err)
$stopped=StopKnownDynamic; L ('known_dynamic_processes_stopped='+$stopped)
try{ Get-Process explorer -ErrorAction SilentlyContinue|Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3; Start-Process explorer.exe|Out-Null; Start-Sleep -Seconds 10; $explorerRestarted=$true }catch{ $explorerRestarted=$false; L ('explorer_restart_error='+(San $_.Exception.Message)) }
L ('explorer_restarted_before_lively='+$explorerRestarted)
$bytes=0; if(Test-Path -LiteralPath $mp4){$bytes=(Get-Item -LiteralPath $mp4).Length}; L ('selected_existing_wallpaper=Anime Girl Beneath a Meteor Sky'); L ('mp4='+$mp4+' exists='+(Test-Path -LiteralPath $mp4)); L ('mp4_bytes='+$bytes); L ('lively_exe='+$lively+' exists='+(Test-Path -LiteralPath $lively))
$setOk=$false; $attempts=@()
if((Test-Path -LiteralPath $lively) -and (Test-Path -LiteralPath $mp4)){ Start-Process -FilePath $lively -WindowStyle Hidden -ErrorAction SilentlyContinue|Out-Null; Start-Sleep -Seconds 20; foreach($args in @([string[]]@('--layout','duplicate'),[string[]]@('--volume','0'),[string[]]@('--play','true'),[string[]]@('setwp','--file',$mp4),[string[]]@('setwp','--file',$mp4,'--monitor','1'))){ $r=RunExe $lively $args 120; $attempts += [pscustomobject]@{args=($args -join ' ');exit=$r.code;text=$r.text}; if($args[0] -eq 'setwp' -and $r.code -eq 0){$setOk=$true}; Start-Sleep -Seconds 2 } }
L ('lively_set_ok='+$setOk); $i=0; foreach($a in $attempts){ L ('lively_attempt_'+$i+'_args='+$a.args); L ('lively_attempt_'+$i+'_exit='+$a.exit); $i++ }
Start-Sleep -Seconds 25; try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 1 }catch{}
$capA=Capture $afterA; Start-Sleep -Seconds 6; $capC=Capture $afterB; $d1=DiffImg $before $afterA; $d2=DiffImg $afterA $afterB
L ('after_a_screenshot='+$afterA+' ok='+$capA.ok+' width='+$capA.width+' height='+$capA.height+' err='+$capA.err); L ('after_b_screenshot='+$afterB+' ok='+$capC.ok+' width='+$capC.width+' height='+$capC.height+' err='+$capC.err)
L ('desktop_changed_from_before_ratio='+('{0:N6}' -f [double]$d1.ratio)); L ('desktop_changed_from_before_avg='+('{0:N3}' -f [double]$d1.avg)); L ('desktop_motion_diff_ratio='+('{0:N6}' -f [double]$d2.ratio)); L ('desktop_motion_diff_avg='+('{0:N3}' -f [double]$d2.avg))
$procs=@(); try{$procs=Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName -like 'Lively*' -or $_.ProcessName -eq 'mpv' -or $_.ProcessName -eq 'mpvnet'}}catch{}; L ('lively_process_count='+(@($procs).Count))
$changed=($d1.ok -and ([double]$d1.ratio -gt 0.02 -or [double]$d1.avg -gt 4.0)); $moving=($d2.ok -and ([double]$d2.ratio -gt 0.0005 -or [double]$d2.avg -gt 0.25)); $success=($setOk -and $changed -and $moving -and -not $locked)
if(-not $success){ L 'rollback_performed=True'; if(Test-Path -LiteralPath $lively){RunExe $lively ([string[]]@('closewp','--monitor','-1')) 30|Out-Null; RunExe $lively ([string[]]@('--shutdown','true')) 30|Out-Null}; StopKnownDynamic|Out-Null; SetStatic $static|Out-Null; Start-Sleep -Seconds 4; Capture $rollback|Out-Null }
$tidy=Tidy; L ('actual_desktop_changed_to_new_wallpaper='+$changed); L ('actual_desktop_is_moving='+$moving); L ('desktop_tidy_manifest='+$tidy); L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy)); L ('R260_SIMPLE_LIVELY_RESTART_DYNAMIC_READY='+$success)
$summary=[pscustomobject]@{ready=$success;locked=$locked;mp4=$mp4;mp4Bytes=$bytes;explorerRestarted=$explorerRestarted;livelySetOk=$setOk;before=$before;afterA=$afterA;afterB=$afterB;rollback=$rollback;desktopChangedFromBeforeRatio=[double]$d1.ratio;desktopChangedFromBeforeAvg=[double]$d1.avg;desktopMotionDiffRatio=[double]$d2.ratio;desktopMotionDiffAvg=[double]$d2.avg;actualDesktopChangedToNewWallpaper=$changed;actualDesktopIsMoving=$moving;livelyProcessCount=@($procs).Count;tidyManifest=$tidy}
WriteUtf8 $json (($summary|ConvertTo-Json -Depth 6)+"`r`n"); W $report $script:Lines; if(-not $success){exit 6}; exit 0
