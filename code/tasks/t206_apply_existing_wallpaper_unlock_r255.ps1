# t206_apply_existing_wallpaper_unlock_r255.ps1 - round 255.
# User reported the wallpaper is still static. The previous screenshot proof showed
# the PIN lock screen, not the desktop. This round downloads an existing anime
# MP4 live wallpaper, prepares an unlock/logon auto-apply script, and starts a
# waiter so it applies as soon as the user manually unlocks the PC.
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
    if($b.Width -le 0 -or $b.Height -le 0){ return @{ok=$false;err='bad screen bounds';path=$Path;width=0;height=0} }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null
    $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size)
    $bmp.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    return @{ok=(Test-Path -LiteralPath $Path);err='';path=$Path;width=$b.Width;height=$b.Height;left=$b.Left;top=$b.Top}
  }catch{ return @{ok=$false;err=(San $_.Exception.Message);path=$Path;width=0;height=0} }
}
function Compare-Images([string]$A,[string]$B){
  try{
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $ia=[System.Drawing.Bitmap]::FromFile($A); $ib=[System.Drawing.Bitmap]::FromFile($B)
    $w=[Math]::Min($ia.Width,$ib.Width); $h=[Math]::Min($ia.Height,$ib.Height)
    $step=[Math]::Max(4,[int]([Math]::Min($w,$h)/240))
    $samples=0; $changed=0; [int64]$total=0
    for($y=0;$y -lt $h;$y+=$step){ for($x=0;$x -lt $w;$x+=$step){ $ca=$ia.GetPixel($x,$y); $cb=$ib.GetPixel($x,$y); $d=[Math]::Abs([int]$ca.R-[int]$cb.R)+[Math]::Abs([int]$ca.G-[int]$cb.G)+[Math]::Abs([int]$ca.B-[int]$cb.B); $total += $d; $samples++; if($d -gt 30){$changed++} } }
    $ia.Dispose(); $ib.Dispose(); $ratio=0.0; $avg=0.0; if($samples -gt 0){$ratio=[double]$changed/[double]$samples; $avg=[double]$total/[double]$samples}
    return @{ok=$true;samples=$samples;changed=$changed;ratio=$ratio;avgDiff=$avg;step=$step;width=$w;height=$h}
  }catch{ return @{ok=$false;err=(San $_.Exception.Message);samples=0;changed=0;ratio=0.0;avgDiff=0.0} }
}
function New-Link([string]$Path,[string]$Target,[string]$Arguments,[string]$WorkingDirectory,[string]$IconLocation,[string]$Description){
  try{
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null
    $ws=New-Object -ComObject WScript.Shell
    $sc=$ws.CreateShortcut($Path); $sc.TargetPath=$Target
    if($Arguments){$sc.Arguments=$Arguments}; if($WorkingDirectory){$sc.WorkingDirectory=$WorkingDirectory}; if($IconLocation){$sc.IconLocation=$IconLocation}; if($Description){$sc.Description=$Description}
    $sc.Save(); return $true
  }catch{ return $false }
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
    try{
      Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='Mozilla/5.0'} -Uri $u -OutFile $tmp -TimeoutSec 300
      $bytes=0; if(Test-Path -LiteralPath $tmp){$bytes=(Get-Item -LiteralPath $tmp).Length}
      $attempts += [pscustomobject]@{url=$u;method='Invoke-WebRequest';exit=0;bytes=$bytes;tail=''}
      if($bytes -gt 650000){ Move-Item -LiteralPath $tmp -Destination $Out -Force; return [pscustomobject]@{ok=$true;url=$u;method='Invoke-WebRequest';attempts=$attempts} }
    }catch{ $attempts += [pscustomobject]@{url=$u;method='Invoke-WebRequest';exit=1;bytes=0;tail=(San $_.Exception.Message)} }
  }
  return [pscustomobject]@{ok=$false;url='';method='';attempts=$attempts}
}
function Tidy-Desktop([string]$Desktop,[string]$OrgRoot){
  New-Item -ItemType Directory -Force -Path $OrgRoot|Out-Null
  foreach($c in @('01-Apps-Shortcuts','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){ New-Item -ItemType Directory -Force -Path (Join-Path $OrgRoot $c)|Out-Null }
  $keep=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer','DeskBox Cute.lnk','Auto Tidy Desktop.lnk','Apply Existing Anime Live Wallpaper NOW.lnk','Existing Anime Live Wallpaper Folder.lnk','Existing Anime Live Wallpaper Proof.lnk')
  $moves=@()
  foreach($it in Get-ChildItem -LiteralPath $Desktop -Force -ErrorAction SilentlyContinue){
    if($keep -contains $it.Name){ continue }
    if(($it.Attributes -band [IO.FileAttributes]::System) -or ($it.Attributes -band [IO.FileAttributes]::Hidden)){ continue }
    $cat='08-Misc'; if($it.PSIsContainer){$cat='07-Old-Folders'} else { $ext=$it.Extension.ToLowerInvariant(); if($ext -in @('.lnk','.url','.cmd','.bat','.ps1')){$cat='01-Apps-Shortcuts'} elseif($ext -in @('.mp4','.mov','.mkv','.avi','.srt','.html')){$cat='03-Video-Creation'} elseif($ext -in @('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')){$cat='04-Images-ID-Photos'} elseif($ext -in @('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.txt','.md','.csv')){$cat='05-Documents'} elseif($ext -in @('.zip','.rar','.7z','.exe','.msi','.msix','.appx')){$cat='06-Archives-Installers'} }
    $destDir=Join-Path $OrgRoot $cat; $dest=Join-Path $destDir $it.Name; $n=1
    while(Test-Path -LiteralPath $dest){ $base=[IO.Path]::GetFileNameWithoutExtension($it.Name); $ext2=[IO.Path]::GetExtension($it.Name); $dest=Join-Path $destDir ($base+'_'+$n+$ext2); $n++ }
    try{ Move-Item -LiteralPath $it.FullName -Destination $dest -Force -ErrorAction Stop; $moves += ($it.FullName+' -> '+$dest) }catch{ $moves += ('MOVE_ERR '+$it.FullName+' '+(San $_.Exception.Message)) }
  }
  $manifest=Join-Path $OrgRoot 'AUTO_TIDY_LAST_RUN.txt'
  WriteUtf8 $manifest (('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`n")+($moves -join "`r`n")+"`r`n")
  return [pscustomobject]@{manifest=$manifest;moved=$moves.Count}
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R255_EXISTING_ANIME_WALLPAPER_ARMED.md'
$jsonReport=Join-Path $outDir 'r255-existing-anime-wallpaper-armed.json'
$screenNow=Join-Path $outDir 'r255_current_screen.png'
$screenA=Join-Path $outDir 'r255_after_apply_a.png'
$screenB=Join-Path $outDir 'r255_after_apply_b.png'
$lab='E:\0mcp-agv-arena-optimized'
$root=Join-Path $lab 'wallpapers\existing-anime-live-r255'
$proof=Join-Path $root 'proof'
foreach($d in @($root,$proof)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
L '# R255 existing anime live wallpaper armed for unlock'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L 'important=the previous real screenshot showed the Windows PIN lock screen, so desktop verification cannot be trusted until the user manually unlocks the PC'
$logonUi=@(); try{ $logonUi=Get-Process LogonUI -ErrorAction SilentlyContinue }catch{}
$locked=(@($logonUi).Count -gt 0)
$cap=Capture-Screen $screenNow
L ('screen_locked_detected='+$locked)
L ('logonui_process_count='+(@($logonUi).Count))
L ('current_screen_capture='+$screenNow+' ok='+$cap.ok+' width='+$cap.width+' height='+$cap.height+' err='+$cap.err)
$sourceName='Golden Afternoon With Mahiru Shiina'
$sourcePage='https://livelywallpaper.app/live-wallpapers/mahiru-shiina-in-a-flower-field/'
$urls=@(
 'https://cdn.livelywallpaper.app/wallpapers/mahiru-shiina-in-a-flower-field/hd.mp4',
 'https://cdn.livelywallpaper.app/wallpapers/mahiru-shiina-in-a-flower-field/preview.mp4',
 'https://cdn.livelywallpaper.app/wallpapers/mahiru-shiina-in-a-flower-field/4k.mp4',
 'https://cdn.livelywallpaper.app/wallpapers/beautiful-anime-girl-under-starry-sky/hd.mp4'
)
$mp4=Join-Path $root 'golden_afternoon_mahiru_shiina_existing_r255.mp4'
$dl=Download-Any $urls $mp4
if(-not $dl.ok){
  $fallback='E:\0mcp-agv-arena-optimized\wallpapers\existing-anime-live-r254\anime_girl_beneath_meteor_sky_existing_r254.mp4'
  if(Test-Path -LiteralPath $fallback){ Copy-Item -LiteralPath $fallback -Destination $mp4 -Force; $dl=[pscustomobject]@{ok=$true;url='fallback:'+ $fallback;method='local-fallback';attempts=$dl.attempts}; $sourceName='Anime Girl Beneath a Meteor Sky'; $sourcePage='https://livelywallpaper.app/live-wallpapers/beautiful-anime-girl-under-starry-sky/' }
}
$mp4Bytes=0; if(Test-Path -LiteralPath $mp4){ $mp4Bytes=(Get-Item -LiteralPath $mp4).Length }
L ('selected_existing_wallpaper='+$sourceName)
L ('source_page='+$sourcePage)
L ('download_ok='+$dl.ok)
L ('download_url='+$dl.url)
L ('download_method='+$dl.method)
L ('downloaded_mp4='+$mp4+' exists='+(Test-Path -LiteralPath $mp4))
L ('downloaded_mp4_bytes='+$mp4Bytes)
$i=0; foreach($a in @($dl.attempts)){ L ('download_attempt_'+$i+'_method='+$a.method); L ('download_attempt_'+$i+'_url='+$a.url); L ('download_attempt_'+$i+'_exit='+$a.exit); L ('download_attempt_'+$i+'_bytes='+$a.bytes); L ('download_attempt_'+$i+'_tail='+(TailText (San $a.tail) 2)); $i++ }
$lively=Find-LivelyExe
L ('lively_exe='+$lively+' exists='+($lively -and (Test-Path -LiteralPath $lively)))
$applyScript=Join-Path $root 'Apply-ExistingAnimeWallpaper.ps1'
$waitScript=Join-Path $root 'Wait-And-Apply-On-Unlock.ps1'
$applyLog=Join-Path $root 'APPLY_LAST_RUN.log'
$waitLog=Join-Path $root 'WAIT_FOR_UNLOCK.log'
$applyCode=@'
param([switch]$FromWaiter)
$ErrorActionPreference='Continue'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$Mp4=Join-Path $Root 'golden_afternoon_mahiru_shiina_existing_r255.mp4'
if(-not(Test-Path -LiteralPath $Mp4)){ $Mp4=Join-Path $Root 'anime_girl_beneath_meteor_sky_existing_r254.mp4' }
$Log=Join-Path $Root 'APPLY_LAST_RUN.log'
function Log($m){ try{ Add-Content -LiteralPath $Log -Encoding UTF8 -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+' '+$m) }catch{} }
function RunLively($exe,[string[]]$args){ try{ & $exe @args 2>&1 | Out-String | ForEach-Object { if($_){Log $_.Trim()} }; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Log ('exit='+$c+' args='+($args -join ' ')); return $c }catch{ Log ('error='+$_.Exception.Message+' args='+($args -join ' ')); return 999 } }
try{
  foreach($needle in @('CuteAnimeDynamicWallpaperHost.ps1','cute-anime-live-r251','cute-anime-live-r252','cute-anime-live-r253')){
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($needle) } | ForEach-Object { try{ Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; Log ('stopped_old_host_pid='+$_.ProcessId) }catch{} }
  }
}catch{}
$Lively='C:\Program Files\Lively Wallpaper\Lively.exe'
if(-not(Test-Path -LiteralPath $Lively)){ $Lively=(Get-Command Lively.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source }
Log ('start from_waiter='+$FromWaiter+' mp4='+$Mp4+' exists='+(Test-Path -LiteralPath $Mp4)+' lively='+$Lively+' exists='+(Test-Path -LiteralPath $Lively))
if(Test-Path -LiteralPath $Lively){
  try{ Start-Process -FilePath $Lively -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 8 }catch{ Log ('start_lively_error='+$_.Exception.Message) }
  RunLively $Lively ([string[]]@('--layout','duplicate')) | Out-Null
  RunLively $Lively ([string[]]@('--volume','0')) | Out-Null
  RunLively $Lively ([string[]]@('--play','true')) | Out-Null
  RunLively $Lively ([string[]]@('closewp','--monitor','-1')) | Out-Null
  Start-Sleep -Seconds 2
  foreach($args in @(
    [string[]]@('setwp','--file',$Mp4),
    [string[]]@('setwp','--file',$Mp4,'--monitor','1'),
    [string[]]@('setwp','--file',$Mp4,'--monitor','0'),
    [string[]]@('setwp','--file',$Mp4,'--monitor','2'),
    [string[]]@('setwp','--file',$Mp4,'--monitor','3'),
    [string[]]@('setwp','--file='+$Mp4),
    [string[]]@('setwp','--file='+$Mp4,'--monitor=1')
  )){ RunLively $Lively $args | Out-Null; Start-Sleep -Seconds 1 }
}
Log 'done'
'@
WriteUtf8 $applyScript $applyCode
$waitCode=@'
$ErrorActionPreference='Continue'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$Apply=Join-Path $Root 'Apply-ExistingAnimeWallpaper.ps1'
$Log=Join-Path $Root 'WAIT_FOR_UNLOCK.log'
function Log($m){ try{ Add-Content -LiteralPath $Log -Encoding UTF8 -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+' '+$m) }catch{} }
Log 'waiter_start'
for($i=0;$i -lt 2160;$i++){
  $locked=$false
  try{ $locked=@(Get-Process LogonUI -ErrorAction SilentlyContinue).Count -gt 0 }catch{ $locked=$false }
  if(-not $locked){
    Log ('unlocked_detected iteration='+$i)
    try{ & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Apply -FromWaiter | Out-Null; Log 'apply_called' }catch{ Log ('apply_error='+$_.Exception.Message) }
    exit 0
  }
  if(($i % 30) -eq 0){ Log ('still_locked iteration='+$i) }
  Start-Sleep -Seconds 10
}
Log 'timeout_waiting_for_unlock'
exit 2
'@
WriteUtf8 $waitScript $waitCode
L ('apply_script='+$applyScript+' exists='+(Test-Path -LiteralPath $applyScript))
L ('wait_script='+$waitScript+' exists='+(Test-Path -LiteralPath $waitScript))
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$applyNowCode=999
try{
  & $psExe -NoProfile -ExecutionPolicy Bypass -File $applyScript
  $applyNowCode=$LASTEXITCODE; if($null -eq $applyNowCode){$applyNowCode=0}
}catch{ L ('apply_now_throw='+(San $_.Exception.Message)); $applyNowCode=998 }
Start-Sleep -Seconds 4
L ('apply_now_exit='+$applyNowCode)
if(Test-Path -LiteralPath $applyLog){ L ('apply_log_tail='+(TailText (Get-Content -LiteralPath $applyLog -Raw -ErrorAction SilentlyContinue) 14)) }
# Start a persistent waiter only if the screen is locked. It will apply immediately after manual unlock.
$waiterStarted=$false
if($locked){
  try{ Start-Process -FilePath $psExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$waitScript) -WindowStyle Hidden -WorkingDirectory $root | Out-Null; $waiterStarted=$true }catch{ L ('waiter_start_error='+(San $_.Exception.Message)) }
}
Start-Sleep -Seconds 2
$waiterProcs=@(); try{ $waiterProcs=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains('Wait-And-Apply-On-Unlock.ps1') } }catch{}
L ('unlock_waiter_started='+$waiterStarted)
L ('unlock_waiter_process_count='+(@($waiterProcs).Count))
if(Test-Path -LiteralPath $waitLog){ L ('wait_log_tail='+(TailText (Get-Content -LiteralPath $waitLog -Raw -ErrorAction SilentlyContinue) 8)) }
# Startup shortcut and a user scheduled ONLOGON task make the setting persistent without needing the PIN from chat.
$startup=[Environment]::GetFolderPath('Startup')
$startupLink=''
if($startup -and (Test-Path -LiteralPath $startup)){
  $startupLink=Join-Path $startup 'Apply Existing Anime Live Wallpaper R255.lnk'
  New-Link $startupLink $psExe ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$applyScript+'"') $root '' 'Apply existing anime live wallpaper on login'|Out-Null
}
$taskOk=$false; $taskName='ApplyExistingAnimeLiveWallpaperR255'
$taskCmd='schtasks /Create /F /TN "'+$taskName+'" /SC ONLOGON /TR "'+$psExe+' -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"'+$applyScript+'\""'
$taskRes=Run-CmdLine $taskCmd 90
$taskOk=($taskRes.code -eq 0)
L ('startup_link='+$startupLink+' exists='+($startupLink -and (Test-Path -LiteralPath $startupLink)))
L ('scheduled_task_name='+$taskName)
L ('scheduled_task_create_exit='+$taskRes.code)
L ('scheduled_task_create_tail='+(TailText (San $taskRes.text) 5))
# If not locked, make a real after-vs-after desktop motion check. If locked, record that verification is blocked by the PIN screen.
$actualMotionChecked=$false; $actualMoving=$false; $diff=@{ok=$false;ratio=0.0;avgDiff=0.0;changed=0;samples=0;err='locked'}
if(-not $locked){
  try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 3 }catch{}
  $ca=Capture-Screen $screenA; Start-Sleep -Seconds 4; $cb=Capture-Screen $screenB
  if($ca.ok -and $cb.ok){ $diff=Compare-Images $screenA $screenB; $actualMotionChecked=$true; $actualMoving=($diff.ok -and ([double]$diff.ratio -gt 0.0007 -or [double]$diff.avgDiff -gt 0.4)) }
  L ('unlocked_after_capture_a_ok='+$ca.ok+' path='+$screenA)
  L ('unlocked_after_capture_b_ok='+$cb.ok+' path='+$screenB)
}
L ('actual_desktop_motion_checked='+$actualMotionChecked)
L ('actual_desktop_is_moving='+$actualMoving)
L ('actual_desktop_motion_diff_ratio='+('{0:N6}' -f [double]$diff.ratio))
L ('actual_desktop_motion_diff_avg='+('{0:N3}' -f [double]$diff.avgDiff))
$paths=Join-Path $root 'PATHS.txt'
WriteUtf8 $paths ((@('Existing anime live wallpaper: '+$sourceName,'Source page: '+$sourcePage,'Downloaded MP4: '+$mp4,'Apply script: '+$applyScript,'Wait/unlock script: '+$waitScript,'Apply log: '+$applyLog,'Wait log: '+$waitLog,'Current screen proof: '+$screenNow,'Report: '+$report) -join "`r`n")+"`r`n")
New-Link (Join-Path $desktop 'Apply Existing Anime Live Wallpaper NOW.lnk') $psExe ('-NoProfile -ExecutionPolicy Bypass -File "'+$applyScript+'"') $root '' 'Apply existing anime live wallpaper now'|Out-Null
New-Link (Join-Path $desktop 'Existing Anime Live Wallpaper Folder.lnk') 'explorer.exe' ('"'+$root+'"') $root '' 'Open existing anime live wallpaper folder'|Out-Null
New-Link (Join-Path $desktop 'Existing Anime Live Wallpaper Proof.lnk') 'explorer.exe' ('"'+$outDir+'"') $outDir '' 'Open proof screenshots and reports'|Out-Null
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'; $wallFolder=Join-Path $org '09-Anime-Wallpapers'; New-Item -ItemType Directory -Force -Path $wallFolder|Out-Null
Copy-Item -LiteralPath $mp4 -Destination (Join-Path $wallFolder ([IO.Path]::GetFileName($mp4))) -Force -ErrorAction SilentlyContinue
$tidy=Tidy-Desktop $desktop $org
L ('paths_summary='+$paths+' exists='+(Test-Path -LiteralPath $paths))
L ('desktop_tidy_manifest='+$tidy.manifest)
L ('desktop_tidy_moved_count='+$tidy.moved)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))
$downloadOk=((Test-Path -LiteralPath $mp4) -and ([int64]$mp4Bytes -gt 650000))
$applyReady=((Test-Path -LiteralPath $applyScript) -and (Test-Path -LiteralPath $waitScript) -and ($applyNowCode -eq 0))
$armedOk=($downloadOk -and $applyReady -and (($locked -and (@($waiterProcs).Count -gt 0)) -or (-not $locked)) -and (($startupLink -and (Test-Path -LiteralPath $startupLink)) -or $taskOk) -and (Test-Path -LiteralPath $tidy.manifest))
L ('existing_live_wallpaper_downloaded='+$downloadOk)
L ('apply_script_ready='+$applyReady)
L ('unlock_or_logon_auto_apply_ready='+$armedOk)
L ('desktop_verification_blocked_by_pin_screen='+$locked)
L ('desktop_tidy_ok='+(Test-Path -LiteralPath $tidy.manifest))
L ('R255_EXISTING_ANIME_WALLPAPER_ARMED='+$armedOk)
$summary=[pscustomobject]@{ready=$armedOk;screenLockedDetected=$locked;note='If screenLockedDetected is true, no agent should claim visual desktop success until the user unlocks the PC. The unlock waiter applies the live wallpaper after manual unlock.';sourceName=$sourceName;sourcePage=$sourcePage;downloadUrl=$dl.url;mp4=$mp4;mp4Bytes=$mp4Bytes;livelyExe=$lively;applyScript=$applyScript;waitScript=$waitScript;applyNowExit=$applyNowCode;waiterProcessCount=@($waiterProcs).Count;startupLink=$startupLink;scheduledTask=$taskName;scheduledTaskCreateExit=$taskRes.code;currentScreen=$screenNow;actualDesktopMotionChecked=$actualMotionChecked;actualDesktopIsMoving=$actualMoving;actualDesktopMotionDiffRatio=[double]$diff.ratio;actualDesktopMotionDiffAvg=[double]$diff.avgDiff;desktopOrganizer=$org;tidyManifest=$tidy.manifest;pathsSummary=$paths}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $armedOk){ exit 6 }
exit 0
