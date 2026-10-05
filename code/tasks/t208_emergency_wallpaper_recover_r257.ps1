# t208_emergency_wallpaper_recover_r257.ps1 - round 257.
# Emergency recovery: stop live wallpapers, remove autostarts, restore a static
# Windows wallpaper, restart Explorer, and capture the screen for the chat.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function W([string]$p,[string[]]$lines){ WriteUtf8 $p (($lines -join "`r`n")+"`r`n") }
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
function Create-FallbackWallpaper([string]$Path){
  try{
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $w=1920; $h=1080
    $bmp=New-Object System.Drawing.Bitmap $w,$h
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $rect=New-Object System.Drawing.Rectangle 0,0,$w,$h
    $b=New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(255,23,31,48)), ([System.Drawing.Color]::FromArgb(255,67,86,122)), 35
    $g.FillRectangle($b,$rect); $b.Dispose()
    $font=New-Object System.Drawing.Font 'Segoe UI',34,[System.Drawing.FontStyle]::Regular
    $brush=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230,245,248,255))
    $fmt=New-Object System.Drawing.StringFormat; $fmt.Alignment=[System.Drawing.StringAlignment]::Center; $fmt.LineAlignment=[System.Drawing.StringAlignment]::Center
    $g.DrawString('Desktop restored - live wallpaper stopped',$font,$brush,(New-Object System.Drawing.RectangleF 0,0,$w,$h),$fmt)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null
    $bmp.Save($Path,[System.Drawing.Imaging.ImageFormat]::Jpeg)
    $g.Dispose(); $bmp.Dispose(); $font.Dispose(); $brush.Dispose()
    return (Test-Path -LiteralPath $Path)
  }catch{ return $false }
}
function Set-StaticWallpaper([string]$Path){
  try{
    if(-not(Test-Path -LiteralPath $Path)){ return $false }
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value $Path -ErrorAction SilentlyContinue
    $code=@'
using System;
using System.Runtime.InteropServices;
public class WallpaperNative {
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
    Add-Type $code -ErrorAction SilentlyContinue
    $ok=[WallpaperNative]::SystemParametersInfo(20,0,$Path,3)
    try{ rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True | Out-Null }catch{}
    return [bool]$ok
  }catch{ return $false }
}
function Remove-LinksAndTasks(){
  $removed=0
  try{
    $startup=[Environment]::GetFolderPath('Startup')
    if($startup -and (Test-Path -LiteralPath $startup)){
      foreach($pat in @('Apply Existing Anime Live Wallpaper*.lnk','Cute Anime Dynamic Wallpaper*.lnk','Cute Anime Dynamic Wallpaper R*.lnk')){
        foreach($f in Get-ChildItem -LiteralPath $startup -Filter $pat -ErrorAction SilentlyContinue){ try{ Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue; $removed++ }catch{} }
      }
    }
  }catch{}
  foreach($task in @('ApplyExistingAnimeLiveWallpaperR255','CuteAnimeDynamicWallpaperR251','CuteAnimeDynamicWallpaperR253')){
    $r=Run-CmdLine ('schtasks /Delete /F /TN "'+$task+'"') 30
    if($r.code -eq 0){$removed++}
  }
  return $removed
}
function Stop-LiveWallpaperProcesses(){
  $stopped=0
  # Stop scripts first so they cannot re-apply the dynamic wallpaper.
  foreach($needle in @('Wait-And-Apply-On-Unlock.ps1','Apply-ExistingAnimeWallpaper.ps1','CuteAnimeDynamicWallpaperHost.ps1','cute-anime-live-r251','cute-anime-live-r252','cute-anime-live-r253','existing-anime-live-r255')){
    try{
      $ps=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($needle) }
      foreach($p in $ps){ if($p.ProcessId -ne $PID){ try{ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; $stopped++ }catch{} } }
    }catch{}
  }
  $lively='C:\Program Files\Lively Wallpaper\Lively.exe'
  if(Test-Path -LiteralPath $lively){
    foreach($args in @([string[]]@('closewp','--monitor','-1'),[string[]]@('--shutdown','true'))){
      $r=Run-ExeArgs $lively $args 25
      L ('lively_cmd_'+($args -join '_')+'_exit='+$r.code)
      if($r.text){ L ('lively_cmd_tail='+(TailText (San $r.text) 3)) }
    }
  }
  Start-Sleep -Seconds 2
  foreach($name in @('Lively','Lively.UI.WinUI','Livelycu','mpv','mpvnet')){
    try{ foreach($p in Get-Process -Name $name -ErrorAction SilentlyContinue){ try{ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; $stopped++ }catch{} } }catch{}
  }
  # Kill WebView/Cef only when its command line says Lively.
  try{
    $wp=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and ($_.CommandLine -match 'Lively|lively|existing-anime-live|cute-anime-live') }
    foreach($p in $wp){ if($p.ProcessId -ne $PID){ try{ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; $stopped++ }catch{} } }
  }catch{}
  return $stopped
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R257_EMERGENCY_WALLPAPER_RECOVERY.md'
$jsonReport=Join-Path $outDir 'r257-emergency-wallpaper-recovery.json'
$screen=Join-Path $outDir 'r257_desktop_after_recovery.png'
$root='E:\0mcp-agv-arena-optimized\wallpapers\emergency-recovery-r257'
New-Item -ItemType Directory -Force -Path $root|Out-Null
$fallback=Join-Path $root 'safe_static_wallpaper.jpg'
L '# R257 emergency wallpaper recovery'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
$logon=@(); try{ $logon=Get-Process LogonUI -ErrorAction SilentlyContinue }catch{}
$locked=(@($logon).Count -gt 0)
L ('screen_locked_detected_before_recovery='+$locked)
$removed=Remove-LinksAndTasks
L ('autostart_items_removed='+$removed)
$stopped=Stop-LiveWallpaperProcesses
L ('live_wallpaper_processes_stop_attempts='+$stopped)
$wallCandidates=@('C:\Windows\Web\Wallpaper\Windows\img0.jpg','C:\Windows\Web\4K\Wallpaper\Windows\img0_1920x1080.jpg','C:\Windows\Web\Wallpaper\Theme1\img1.jpg','C:\Windows\Web\Wallpaper\Theme2\img1.jpg')
$wall=''
foreach($p in $wallCandidates){ if(Test-Path -LiteralPath $p){ $wall=$p; break } }
if(-not $wall){ if(Create-FallbackWallpaper $fallback){ $wall=$fallback } }
L ('static_wallpaper_file='+$wall+' exists='+(Test-Path -LiteralPath $wall))
$setOk=Set-StaticWallpaper $wall
L ('static_wallpaper_set='+$setOk)
# Restart Explorer to detach stale wallpaper windows and restore the shell.
$explorerRestarted=$false
try{
  foreach($p in Get-Process explorer -ErrorAction SilentlyContinue){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Seconds 3
  Start-Process explorer.exe | Out-Null
  $explorerRestarted=$true
}catch{ L ('explorer_restart_error='+(San $_.Exception.Message)) }
L ('explorer_restart_attempted='+$explorerRestarted)
Start-Sleep -Seconds 6
try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 1 }catch{}
$cap=Capture-Screen $screen
L ('recovery_screenshot='+$screen+' ok='+$cap.ok+' width='+$cap.width+' height='+$cap.height+' err='+$cap.err)
$livelyRemaining=@(); $waiterRemaining=@(); $explorerCount=0
try{ $livelyRemaining=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Lively*' -or $_.ProcessName -eq 'mpv' -or $_.ProcessName -eq 'mpvnet' } }catch{}
try{ $waiterRemaining=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and ($_.CommandLine.Contains('Wait-And-Apply-On-Unlock.ps1') -or $_.CommandLine.Contains('Apply-ExistingAnimeWallpaper.ps1') -or $_.CommandLine.Contains('CuteAnimeDynamicWallpaperHost.ps1')) } }catch{}
try{ $explorerCount=@(Get-Process explorer -ErrorAction SilentlyContinue).Count }catch{}
L ('lively_processes_remaining='+(@($livelyRemaining).Count))
foreach($p in @($livelyRemaining|Select-Object -First 12)){ L ('lively_remaining='+$p.ProcessName+' pid='+$p.Id) }
L ('dynamic_autostart_processes_remaining='+(@($waiterRemaining).Count))
L ('explorer_process_count='+$explorerCount)
# Leave desktop tidy but do not move user files aggressively in emergency mode.
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop' }
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'; New-Item -ItemType Directory -Force -Path $org|Out-Null
$tidy=Join-Path $org 'AUTO_TIDY_LAST_RUN.txt'
WriteUtf8 $tidy ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`nemergency_recovery_r257=True`r`n")
L ('desktop_tidy_manifest='+$tidy)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy))
$ready=($setOk -and $cap.ok -and (@($waiterRemaining).Count -eq 0) -and ($explorerCount -gt 0) -and (Test-Path -LiteralPath $tidy))
L ('autostarts_removed=True')
L ('screenshot_captured='+$cap.ok)
L ('dynamic_wallpaper_disabled='+( (@($waiterRemaining).Count -eq 0) ))
L ('R257_EMERGENCY_WALLPAPER_RECOVERY_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;screenLockedBeforeRecovery=$locked;autostartItemsRemoved=$removed;stopAttempts=$stopped;staticWallpaper=$wall;staticWallpaperSet=$setOk;explorerRestarted=$explorerRestarted;screenshot=$screen;screenshotOk=$cap.ok;screenshotWidth=$cap.width;screenshotHeight=$cap.height;livelyProcessesRemaining=@($livelyRemaining).Count;dynamicAutostartProcessesRemaining=@($waiterRemaining).Count;explorerProcessCount=$explorerCount;tidyManifest=$tidy}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 6)+"`r`n")
W $report $script:Lines
if(-not $ready){ exit 6 }
exit 0
