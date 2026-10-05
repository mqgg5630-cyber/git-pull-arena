# t205_existing_anime_lively_wallpaper_r254.ps1 - round 254.
# Download an existing anime live wallpaper MP4 from the web, set it through Lively,
# stop earlier custom hosts, and prove the real desktop changed and is moving.
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
function Run-ExeArgs([string]$Exe,[string[]]$Args,[int]$TimeoutSec){
  if(-not $Exe -or -not(Test-Path -LiteralPath $Exe)){ return @{code=127;text='missing exe'} }
  $job=Start-Job -ScriptBlock { param($e,$a); & $e @a 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Exe,$Args
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }
  return @{code=$code;text=$txt}
}
function Run-CmdLine([string]$Line,[int]$TimeoutSec){
  $job=Start-Job -ScriptBlock { param($line); cmd.exe /d /s /c $line 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Line
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
    $step=[Math]::Max(4,[int]([Math]::Min($w,$h)/260))
    $samples=0; $changed=0; [int64]$total=0
    for($y=0;$y -lt $h;$y+=$step){ for($x=0;$x -lt $w;$x+=$step){ $ca=$ia.GetPixel($x,$y); $cb=$ib.GetPixel($x,$y); $d=[Math]::Abs([int]$ca.R-[int]$cb.R)+[Math]::Abs([int]$ca.G-[int]$cb.G)+[Math]::Abs([int]$ca.B-[int]$cb.B); $total += $d; $samples++; if($d -gt 30){$changed++} } }
    $ia.Dispose(); $ib.Dispose()
    $ratio=0.0; $avg=0.0; if($samples -gt 0){$ratio=[double]$changed/[double]$samples; $avg=[double]$total/[double]$samples}
    return @{ok=$true;samples=$samples;changed=$changed;ratio=$ratio;avgDiff=$avg;step=$step;width=$w;height=$h}
  }catch{ return @{ok=$false;err=(San $_.Exception.Message);samples=0;changed=0;ratio=0.0;avgDiff=0.0} }
}
function New-Link([string]$Path,[string]$Target,[string]$Arguments,[string]$WorkingDirectory,[string]$IconLocation,[string]$Description){
  try{
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null
    $ws=New-Object -ComObject WScript.Shell
    $sc=$ws.CreateShortcut($Path)
    $sc.TargetPath=$Target
    if($Arguments){$sc.Arguments=$Arguments}
    if($WorkingDirectory){$sc.WorkingDirectory=$WorkingDirectory}
    if($IconLocation){$sc.IconLocation=$IconLocation}
    if($Description){$sc.Description=$Description}
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
function Stop-OldHosts(){
  $stopped=0
  foreach($needle in @('CuteAnimeDynamicWallpaperHost.ps1','cute-anime-live-r251','cute-anime-live-r252','cute-anime-live-r253')){
    try{
      $ps=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($needle) }
      foreach($p in $ps){ try{ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; $stopped++ }catch{} }
    }catch{}
  }
  try{
    $startup=[Environment]::GetFolderPath('Startup')
    if($startup -and (Test-Path -LiteralPath $startup)){
      Get-ChildItem -LiteralPath $startup -Filter 'Cute Anime Dynamic Wallpaper R25*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
  }catch{}
  return $stopped
}
function Download-Wallpaper([string[]]$Urls,[string]$Out){
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out)|Out-Null
  $curl=Find-Cmd @('curl.exe','curl')
  $attempts=@()
  foreach($u in $Urls){
    $tmp=$Out+'.tmp'
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    if($curl){
      $cmd='"'+$curl+'" -L --ssl-no-revoke --retry 3 --connect-timeout 25 --max-time 300 -A "Mozilla/5.0" -o "'+$tmp+'" "'+$u+'"'
      $r=Run-CmdLine $cmd 360
      $bytes=0; if(Test-Path -LiteralPath $tmp){$bytes=(Get-Item -LiteralPath $tmp).Length}
      $attempts += [pscustomobject]@{url=$u;method='curl';exit=$r.code;bytes=$bytes;tail=(TailText (San $r.text) 4)}
      if($bytes -gt 800000){ Move-Item -LiteralPath $tmp -Destination $Out -Force; return [pscustomobject]@{ok=$true;url=$u;method='curl';attempts=$attempts} }
    }
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    try{
      Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='Mozilla/5.0'} -Uri $u -OutFile $tmp -TimeoutSec 300
      $bytes=0; if(Test-Path -LiteralPath $tmp){$bytes=(Get-Item -LiteralPath $tmp).Length}
      $attempts += [pscustomobject]@{url=$u;method='Invoke-WebRequest';exit=0;bytes=$bytes;tail=''}
      if($bytes -gt 800000){ Move-Item -LiteralPath $tmp -Destination $Out -Force; return [pscustomobject]@{ok=$true;url=$u;method='Invoke-WebRequest';attempts=$attempts} }
    }catch{ $attempts += [pscustomobject]@{url=$u;method='Invoke-WebRequest';exit=1;bytes=0;tail=(San $_.Exception.Message)} }
  }
  return [pscustomobject]@{ok=$false;url='';method='';attempts=$attempts}
}
function Tidy-Desktop([string]$Desktop,[string]$OrgRoot){
  New-Item -ItemType Directory -Force -Path $OrgRoot|Out-Null
  foreach($c in @('01-Apps-Shortcuts','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){ New-Item -ItemType Directory -Force -Path (Join-Path $OrgRoot $c)|Out-Null }
  $keep=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer','DeskBox Cute.lnk','Auto Tidy Desktop.lnk','Existing Anime Live Wallpaper R254.lnk','Existing Anime Live Wallpaper Folder R254.lnk','Existing Anime Live Wallpaper Proof R254.lnk')
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
$report=Join-Path $outDir 'R254_EXISTING_ANIME_LIVELY_WALLPAPER.md'
$jsonReport=Join-Path $outDir 'r254-existing-anime-lively-wallpaper.json'
$repoBefore=Join-Path $outDir 'r254_desktop_before.png'
$repoAfterA=Join-Path $outDir 'r254_desktop_after_a.png'
$repoAfterB=Join-Path $outDir 'r254_desktop_after_b.png'
$repoLivelyShot=Join-Path $outDir 'r254_lively_screenshot.jpg'
$lab='E:\0mcp-agv-arena-optimized'
$root=Join-Path $lab 'wallpapers\existing-anime-live-r254'
$proof=Join-Path $root 'proof'
foreach($d in @($root,$proof)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
L '# R254 existing anime Lively wallpaper'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L 'user_report=desktop still looked static, so this round uses an existing web MP4 and verifies the real desktop screenshots'
L ('desktop_dir='+$desktop)
$sourcePage='https://livelywallpaper.app/live-wallpapers/beautiful-anime-girl-under-starry-sky/'
$sourceName='Anime Girl Beneath a Meteor Sky'
$urls=@(
 'https://cdn.livelywallpaper.app/wallpapers/beautiful-anime-girl-under-starry-sky/preview.mp4',
 'https://cdn.livelywallpaper.app/wallpapers/beautiful-anime-girl-under-starry-sky/4k.mp4',
 'https://cdn.livelywallpaper.app/wallpapers/beautiful-anime-girl-under-starry-sky/wallpaper.mp4',
 'https://cdn.livelywallpaper.app/wallpapers/beautiful-anime-girl-under-starry-sky/hd.mp4',
 'https://cdn.livelywallpaper.app/wallpapers/beautiful-anime-girl-under-starry-sky/1080p.mp4'
)
$mp4=Join-Path $root 'anime_girl_beneath_meteor_sky_existing_r254.mp4'
L ('source_page='+$sourcePage)
L ('selected_existing_wallpaper='+$sourceName)
try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 2 }catch{}
$before=Capture-Screen $repoBefore
L ('before_desktop_capture_ok='+$before.ok+' path='+$repoBefore+' width='+$before.width+' height='+$before.height+' err='+$before.err)
$stopped=Stop-OldHosts
L ('old_custom_hosts_stopped='+$stopped)
$dl=Download-Wallpaper $urls $mp4
$mp4Bytes=0; if(Test-Path -LiteralPath $mp4){ $mp4Bytes=(Get-Item -LiteralPath $mp4).Length }
L ('download_ok='+$dl.ok)
L ('download_method='+$dl.method)
L ('download_url='+$dl.url)
L ('downloaded_mp4='+$mp4+' exists='+(Test-Path -LiteralPath $mp4))
L ('downloaded_mp4_bytes='+$mp4Bytes)
$i=0; foreach($a in $dl.attempts){ L ('download_attempt_'+$i+'_method='+$a.method); L ('download_attempt_'+$i+'_url='+$a.url); L ('download_attempt_'+$i+'_exit='+$a.exit); L ('download_attempt_'+$i+'_bytes='+$a.bytes); L ('download_attempt_'+$i+'_tail='+(TailText (San $a.tail) 2)); $i++ }
$lively=Find-LivelyExe
L ('lively_exe='+$lively+' exists='+($lively -and (Test-Path -LiteralPath $lively)))
$setAttempts=@(); $setOk=$false
if($lively -and (Test-Path -LiteralPath $lively) -and (Test-Path -LiteralPath $mp4)){
  try{ Start-Process -FilePath $lively -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 8 }catch{}
  foreach($args in @(
    [string[]]@('--layout','duplicate'),
    [string[]]@('closewp','--monitor','-1'),
    [string[]]@('--volume','0'),
    [string[]]@('--play','true'),
    [string[]]@('setwp','--file',$mp4),
    [string[]]@('setwp','--file',$mp4,'--monitor','0'),
    [string[]]@('setwp','--file',$mp4,'--monitor','1'),
    [string[]]@('setwp','--file',$mp4,'--monitor','2'),
    [string[]]@('setwp','--file',$mp4,'--monitor','3'),
    [string[]]@('setwp','--file='+$mp4,'--monitor=1'),
    [string[]]@('setwp','--file='+$mp4)
  )){
    $r=Run-ExeArgs $lively $args 240
    $argText=($args -join ' ')
    $setAttempts += [pscustomobject]@{args=$argText;exit=$r.code;tail=(TailText (San $r.text) 5)}
    if(($args[0] -eq 'setwp') -and $r.code -eq 0){ $setOk=$true }
    Start-Sleep -Milliseconds 500
  }
  Start-Sleep -Seconds 18
  $shotLocal=Join-Path $proof 'lively_screenshot_monitor1.jpg'
  $sr=Run-ExeArgs $lively ([string[]]@('screenshot','--file',$shotLocal,'--monitor','1')) 120
  L ('lively_screenshot_exit='+$sr.code)
  L ('lively_screenshot_path='+$shotLocal+' exists='+(Test-Path -LiteralPath $shotLocal))
  if(Test-Path -LiteralPath $shotLocal){ Copy-Item -LiteralPath $shotLocal -Destination $repoLivelyShot -Force -ErrorAction SilentlyContinue }
}
L ('lively_set_any_ok='+$setOk)
$i=0; foreach($a in $setAttempts){ L ('lively_attempt_'+$i+'_args='+$a.args); L ('lively_attempt_'+$i+'_exit='+$a.exit); L ('lively_attempt_'+$i+'_tail='+$a.tail); $i++ }
try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 2 }catch{}
$afterA=Capture-Screen $repoAfterA
Start-Sleep -Seconds 4
$afterB=Capture-Screen $repoAfterB
$diffAB=@{ok=$false;ratio=0.0;avgDiff=0.0;changed=0;samples=0;err='not compared'}
$diffBefore=@{ok=$false;ratio=0.0;avgDiff=0.0;changed=0;samples=0;err='not compared'}
if($afterA.ok -and $afterB.ok){ $diffAB=Compare-Images $repoAfterA $repoAfterB }
if($before.ok -and $afterA.ok){ $diffBefore=Compare-Images $repoBefore $repoAfterA }
L ('after_a_capture_ok='+$afterA.ok+' path='+$repoAfterA+' width='+$afterA.width+' height='+$afterA.height+' err='+$afterA.err)
L ('after_b_capture_ok='+$afterB.ok+' path='+$repoAfterB+' width='+$afterB.width+' height='+$afterB.height+' err='+$afterB.err)
L ('desktop_changed_from_before_ok='+$diffBefore.ok)
L ('desktop_changed_from_before_ratio='+('{0:N6}' -f [double]$diffBefore.ratio))
L ('desktop_changed_from_before_avg='+('{0:N3}' -f [double]$diffBefore.avgDiff))
L ('dynamic_screen_diff_ok='+$diffAB.ok)
L ('dynamic_screen_diff_changed='+$diffAB.changed)
L ('dynamic_screen_diff_samples='+$diffAB.samples)
L ('dynamic_screen_diff_ratio='+('{0:N6}' -f [double]$diffAB.ratio))
L ('dynamic_screen_diff_avg='+('{0:N3}' -f [double]$diffAB.avgDiff))
$procs=@(); $cmdHits=@()
try{
  $procs=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Lively*' -or $_.ProcessName -like '*mpv*' -or $_.ProcessName -like '*WebView*' -or $_.ProcessName -like '*CefSharp*' }
  $needle1='existing-anime-live-r254'; $needle2='beautiful-anime-girl-under-starry-sky'; $needle3='anime_girl_beneath_meteor_sky_existing_r254'
  $cmdHits=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and ($_.CommandLine.Contains($needle1) -or $_.CommandLine.Contains($needle2) -or $_.CommandLine.Contains($needle3)) }
}catch{}
L ('lively_related_process_count='+(@($procs).Count))
foreach($p in @($procs|Select-Object -First 20)){ L ('lively_related_process='+$p.ProcessName+' pid='+$p.Id) }
L ('wallpaper_process_commandline_hit_count='+(@($cmdHits).Count))
foreach($p in @($cmdHits|Select-Object -First 8)){ L ('wallpaper_cmd_hit='+$p.Name+' pid='+$p.ProcessId) }
$paths=Join-Path $root 'PATHS.txt'
$pathsText=@('Existing anime live wallpaper: '+$sourceName,'Source page: '+$sourcePage,'Downloaded MP4: '+$mp4,'Proof before screenshot: '+$repoBefore,'Proof after A screenshot: '+$repoAfterA,'Proof after B screenshot: '+$repoAfterB,'Lively screenshot copy: '+$repoLivelyShot,'Lively executable: '+$lively) -join "`r`n"
WriteUtf8 $paths ($pathsText+"`r`n")
New-Link (Join-Path $desktop 'Existing Anime Live Wallpaper R254.lnk') $mp4 '' $root $mp4 'Open existing anime live wallpaper MP4'|Out-Null
New-Link (Join-Path $desktop 'Existing Anime Live Wallpaper Folder R254.lnk') 'explorer.exe' ('"'+$root+'"') $root '' 'Open existing anime wallpaper folder'|Out-Null
New-Link (Join-Path $desktop 'Existing Anime Live Wallpaper Proof R254.lnk') 'explorer.exe' ('"'+$outDir+'"') $outDir '' 'Open proof screenshots and report'|Out-Null
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'; $wallFolder=Join-Path $org '09-Anime-Wallpapers'; New-Item -ItemType Directory -Force -Path $wallFolder|Out-Null
Copy-Item -LiteralPath $mp4 -Destination (Join-Path $wallFolder 'anime_girl_beneath_meteor_sky_existing_r254.mp4') -Force -ErrorAction SilentlyContinue
$tidy=Tidy-Desktop $desktop $org
L ('paths_summary='+$paths+' exists='+(Test-Path -LiteralPath $paths))
L ('desktop_tidy_manifest='+$tidy.manifest)
L ('desktop_tidy_moved_count='+$tidy.moved)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))
$downloadOk=((Test-Path -LiteralPath $mp4) -and ([int64]$mp4Bytes -gt 800000))
$desktopChanged=($diffBefore.ok -and ([double]$diffBefore.ratio -gt 0.03 -or [double]$diffBefore.avgDiff -gt 5.0))
$dynamicMoving=($diffAB.ok -and ([double]$diffAB.ratio -gt 0.0007 -or [double]$diffAB.avgDiff -gt 0.4))
$livelyProcOk=(@($procs).Count -gt 0)
$ready=($downloadOk -and $setOk -and $desktopChanged -and $dynamicMoving -and $livelyProcOk -and (Test-Path -LiteralPath $tidy.manifest))
L ('downloaded_existing_mp4_ok='+$downloadOk)
L ('actual_desktop_changed_to_new_wallpaper='+$desktopChanged)
L ('actual_desktop_is_moving='+$dynamicMoving)
L ('lively_process_seen='+$livelyProcOk)
L ('desktop_tidy_ok='+(Test-Path -LiteralPath $tidy.manifest))
L ('R254_EXISTING_ANIME_LIVELY_WALLPAPER_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;sourceName=$sourceName;sourcePage=$sourcePage;downloadUrl=$dl.url;mp4=$mp4;mp4Bytes=$mp4Bytes;livelyExe=$lively;livelySetOk=$setOk;beforeScreenshot=$repoBefore;afterScreenshotA=$repoAfterA;afterScreenshotB=$repoAfterB;livelyScreenshot=$repoLivelyShot;desktopChangedFromBeforeRatio=[double]$diffBefore.ratio;desktopChangedFromBeforeAvg=[double]$diffBefore.avgDiff;dynamicScreenDiffRatio=[double]$diffAB.ratio;dynamicScreenDiffAvg=[double]$diffAB.avgDiff;actualDesktopChangedToNewWallpaper=$desktopChanged;actualDesktopIsMoving=$dynamicMoving;livelyProcessCount=@($procs).Count;wallpaperCommandlineHitCount=@($cmdHits).Count;desktopOrganizer=$org;tidyManifest=$tidy.manifest;pathsSummary=$paths}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){ exit 6 }
exit 0
