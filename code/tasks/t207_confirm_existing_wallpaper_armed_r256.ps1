# t207_confirm_existing_wallpaper_armed_r256.ps1 - round 256.
# Confirm the existing anime live wallpaper package is downloaded and armed.
# This does not ask for or use the Windows PIN; if the PC is locked, a waiter
# keeps running and applies the wallpaper after the user manually unlocks.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function W([string]$p,[string[]]$lines){ WriteUtf8 $p (($lines -join "`r`n")+"`r`n") }
function Capture-Screen([string]$Path){
  try{
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $b=[System.Windows.Forms.SystemInformation]::VirtualScreen
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null
    $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size)
    $bmp.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    return @{ok=(Test-Path -LiteralPath $Path);err='';width=$b.Width;height=$b.Height}
  }catch{ return @{ok=$false;err=(San $_.Exception.Message);width=0;height=0} }
}
function New-Link([string]$Path,[string]$Target,[string]$Arguments,[string]$WorkingDirectory,[string]$IconLocation,[string]$Description){
  try{ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null; $ws=New-Object -ComObject WScript.Shell; $sc=$ws.CreateShortcut($Path); $sc.TargetPath=$Target; if($Arguments){$sc.Arguments=$Arguments}; if($WorkingDirectory){$sc.WorkingDirectory=$WorkingDirectory}; if($IconLocation){$sc.IconLocation=$IconLocation}; if($Description){$sc.Description=$Description}; $sc.Save(); return $true }catch{ return $false }
}
function Tidy([string]$Desktop,[string]$Org){
  New-Item -ItemType Directory -Force -Path $Org|Out-Null
  foreach($c in @('01-Apps-Shortcuts','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){ New-Item -ItemType Directory -Force -Path (Join-Path $Org $c)|Out-Null }
  $keep=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer','DeskBox Cute.lnk','Auto Tidy Desktop.lnk','Apply Existing Anime Live Wallpaper NOW.lnk','Existing Anime Live Wallpaper Folder.lnk','Existing Anime Live Wallpaper Proof.lnk')
  $moves=@()
  foreach($it in Get-ChildItem -LiteralPath $Desktop -Force -ErrorAction SilentlyContinue){
    if($keep -contains $it.Name){ continue }
    if(($it.Attributes -band [IO.FileAttributes]::System) -or ($it.Attributes -band [IO.FileAttributes]::Hidden)){ continue }
    $cat='08-Misc'; if($it.PSIsContainer){$cat='07-Old-Folders'} else { $ext=$it.Extension.ToLowerInvariant(); if($ext -in @('.lnk','.url','.cmd','.bat','.ps1')){$cat='01-Apps-Shortcuts'} elseif($ext -in @('.mp4','.mov','.mkv','.avi','.srt','.html')){$cat='03-Video-Creation'} elseif($ext -in @('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')){$cat='04-Images-ID-Photos'} elseif($ext -in @('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.txt','.md','.csv')){$cat='05-Documents'} elseif($ext -in @('.zip','.rar','.7z','.exe','.msi','.msix','.appx')){$cat='06-Archives-Installers'} }
    $destDir=Join-Path $Org $cat; $dest=Join-Path $destDir $it.Name; $n=1
    while(Test-Path -LiteralPath $dest){ $base=[IO.Path]::GetFileNameWithoutExtension($it.Name); $ext2=[IO.Path]::GetExtension($it.Name); $dest=Join-Path $destDir ($base+'_'+$n+$ext2); $n++ }
    try{ Move-Item -LiteralPath $it.FullName -Destination $dest -Force -ErrorAction Stop; $moves += ($it.FullName+' -> '+$dest) }catch{ $moves += ('MOVE_ERR '+$it.FullName+' '+(San $_.Exception.Message)) }
  }
  $manifest=Join-Path $Org 'AUTO_TIDY_LAST_RUN.txt'
  WriteUtf8 $manifest (('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`n")+($moves -join "`r`n")+"`r`n")
  return [pscustomobject]@{manifest=$manifest;moved=$moves.Count}
}
$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R256_CONFIRM_EXISTING_ANIME_WALLPAPER_ARMED.md'
$jsonReport=Join-Path $outDir 'r256-confirm-existing-anime-wallpaper-armed.json'
$screen=Join-Path $outDir 'r256_current_screen.png'
$root='E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r255'
$mp4=Join-Path $root 'golden_afternoon_mahiru_shiina_existing_r255.mp4'
$apply=Join-Path $root 'Apply-ExistingAnimeWallpaper.ps1'
$wait=Join-Path $root 'Wait-And-Apply-On-Unlock.ps1'
$applyLog=Join-Path $root 'APPLY_LAST_RUN.log'
$waitLog=Join-Path $root 'WAIT_FOR_UNLOCK.log'
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
L '# R256 confirm existing anime live wallpaper armed'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
$cap=Capture-Screen $screen
$logon=@(); try{ $logon=Get-Process LogonUI -ErrorAction SilentlyContinue }catch{}
$locked=(@($logon).Count -gt 0)
L ('screen_locked_detected='+$locked)
L ('current_screen_capture='+$screen+' ok='+$cap.ok+' width='+$cap.width+' height='+$cap.height+' err='+$cap.err)
$mp4Bytes=0; if(Test-Path -LiteralPath $mp4){$mp4Bytes=(Get-Item -LiteralPath $mp4).Length}
L ('selected_existing_wallpaper=Golden Afternoon With Mahiru Shiina')
L ('source_page=https://livelywallpaper.app/live-wallpapers/mahiru-shiina-in-a-flower-field/')
L ('downloaded_mp4='+$mp4+' exists='+(Test-Path -LiteralPath $mp4))
L ('downloaded_mp4_bytes='+$mp4Bytes)
L ('apply_script='+$apply+' exists='+(Test-Path -LiteralPath $apply))
L ('wait_script='+$wait+' exists='+(Test-Path -LiteralPath $wait))
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$applyExit=999
try{ & $psExe -NoProfile -ExecutionPolicy Bypass -File $apply; $applyExit=$LASTEXITCODE; if($null -eq $applyExit){$applyExit=0} }catch{ L ('apply_now_error='+(San $_.Exception.Message)); $applyExit=998 }
L ('apply_now_exit='+$applyExit)
if(Test-Path -LiteralPath $applyLog){ L ('apply_log_tail='+(TailText (Get-Content -LiteralPath $applyLog -Raw -ErrorAction SilentlyContinue) 10)) }
$waiter=@(); try{ $waiter=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains('Wait-And-Apply-On-Unlock.ps1') } }catch{}
if($locked -and @($waiter).Count -eq 0 -and (Test-Path -LiteralPath $wait)){
  try{ Start-Process -FilePath $psExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$wait) -WindowStyle Hidden -WorkingDirectory $root | Out-Null; Start-Sleep -Seconds 2 }catch{ L ('waiter_restart_error='+(San $_.Exception.Message)) }
  try{ $waiter=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains('Wait-And-Apply-On-Unlock.ps1') } }catch{}
}
L ('unlock_waiter_process_count='+(@($waiter).Count))
if(Test-Path -LiteralPath $waitLog){ L ('wait_log_tail='+(TailText (Get-Content -LiteralPath $waitLog -Raw -ErrorAction SilentlyContinue) 8)) }
$startup=[Environment]::GetFolderPath('Startup')
$startupLink=Join-Path $startup 'Apply Existing Anime Live Wallpaper R255.lnk'
if($startup -and (Test-Path -LiteralPath $startup) -and -not(Test-Path -LiteralPath $startupLink)){ New-Link $startupLink $psExe ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$apply+'"') $root '' 'Apply existing anime live wallpaper on login'|Out-Null }
L ('startup_link='+$startupLink+' exists='+(Test-Path -LiteralPath $startupLink))
New-Link (Join-Path $desktop 'Apply Existing Anime Live Wallpaper NOW.lnk') $psExe ('-NoProfile -ExecutionPolicy Bypass -File "'+$apply+'"') $root '' 'Apply existing anime live wallpaper now'|Out-Null
New-Link (Join-Path $desktop 'Existing Anime Live Wallpaper Folder.lnk') 'explorer.exe' ('"'+$root+'"') $root '' 'Open existing anime live wallpaper folder'|Out-Null
New-Link (Join-Path $desktop 'Existing Anime Live Wallpaper Proof.lnk') 'explorer.exe' ('"'+$outDir+'"') $outDir '' 'Open proof screenshots and reports'|Out-Null
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'
$tidy=Tidy $desktop $org
L ('desktop_tidy_manifest='+$tidy.manifest)
L ('desktop_tidy_moved_count='+$tidy.moved)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))
$downloadOk=((Test-Path -LiteralPath $mp4) -and ([int64]$mp4Bytes -gt 650000))
$applyReady=((Test-Path -LiteralPath $apply) -and (Test-Path -LiteralPath $wait) -and ($applyExit -eq 0))
$autoReady=((Test-Path -LiteralPath $startupLink) -and ((-not $locked) -or (@($waiter).Count -gt 0)))
$ready=($downloadOk -and $applyReady -and $autoReady -and (Test-Path -LiteralPath $tidy.manifest))
L ('existing_live_wallpaper_downloaded='+$downloadOk)
L ('apply_script_ready='+$applyReady)
L ('unlock_or_logon_auto_apply_ready='+$autoReady)
L ('desktop_verification_blocked_by_pin_screen='+$locked)
L ('desktop_tidy_ok='+(Test-Path -LiteralPath $tidy.manifest))
L ('R256_CONFIRM_EXISTING_ANIME_WALLPAPER_ARMED_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;screenLockedDetected=$locked;mp4=$mp4;mp4Bytes=$mp4Bytes;applyScript=$apply;waitScript=$wait;applyExit=$applyExit;waiterProcessCount=@($waiter).Count;startupLink=$startupLink;currentScreen=$screen;desktopOrganizer=$org;tidyManifest=$tidy.manifest;note='Manual unlock is required before any agent can honestly verify the visible desktop wallpaper.'}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 6)+"`r`n")
W $report $script:Lines
if(-not $ready){exit 6}
exit 0
