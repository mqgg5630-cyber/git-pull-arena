# t196_set_dynamic_wallpaper_report_r245.ps1 - round 245.
# Set the existing R244 anime MP4 as a real Lively dynamic wallpaper, write a
# full final report, and tidy the desktop after completion. ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function Run-CmdLine([string]$Line,[string]$Cwd,[int]$TimeoutSec){
  $job=Start-Job -ScriptBlock {
    param($line,$wd)
    if($wd -and (Test-Path -LiteralPath $wd)){ Set-Location -LiteralPath $wd }
    cmd.exe /d /s /c $line 2>&1 | Out-String
    $c=$LASTEXITCODE; if($null -eq $c){$c=0}
    Write-Output ('===EXITCODE:'+[string]$c)
  } -ArgumentList $Line,$Cwd
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return @{code=-1;text='TIMEOUT'}
  }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim()
  Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0
  if($txt -match '===EXITCODE:(-?\d+)'){
    $code=[int]$Matches[1]
    $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim()
  }
  return @{code=$code;text=$txt}
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
function Find-LivelyCandidates(){
  $roots=@()
  if($env:ProgramFiles){ $roots += (Join-Path $env:ProgramFiles 'Lively Wallpaper') }
  if(${env:ProgramFiles(x86)}){ $roots += (Join-Path ${env:ProgramFiles(x86)} 'Lively Wallpaper') }
  if($env:LOCALAPPDATA){ $roots += (Join-Path $env:LOCALAPPDATA 'Programs\Lively Wallpaper'); $roots += (Join-Path $env:LOCALAPPDATA 'Lively Wallpaper') }
  $roots += 'C:\Program Files\Lively Wallpaper'
  $roots += 'E:\0mcp-agv-arena-optimized\apps\Lively Wallpaper'
  $out=@()
  foreach($root in $roots){
    if($root -and (Test-Path -LiteralPath $root)){
      foreach($name in @('livelycu.exe','Lively.exe','lively.exe')){
        try{
          $f=Get-ChildItem -LiteralPath $root -Recurse -Filter $name -File -ErrorAction SilentlyContinue | Select-Object -First 1
          if($f -and -not($out -contains $f.FullName)){ $out += $f.FullName }
        }catch{}
      }
    }
  }
  foreach($n in @('livelycu.exe','Lively.exe','lively.exe')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue; if($c -and -not($out -contains $c.Source)){ $out += $c.Source } }catch{} }
  return $out
}
function Set-Lively([string[]]$Candidates,[string]$Video){
  $attempts=@()
  foreach($exe in $Candidates){
    if(-not(Test-Path -LiteralPath $exe)){ continue }
    try{ if((Split-Path -Leaf $exe) -match 'Lively\.exe'){ Start-Process -FilePath $exe -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 8 } }catch{}
    foreach($cmd in @('setwp --file "'+$Video+'"','setwp --file "'+$Video+'" --monitor 1')){
      $line='"'+$exe+'" '+$cmd
      $r=Run-CmdLine $line '' 240
      $attempts += [pscustomobject]@{exe=$exe;cmd=$cmd;exit=$r.code;tail=(TailText (San $r.text) 8)}
      if($r.code -eq 0){ return [pscustomobject]@{ok=$true;exe=$exe;cmd=$cmd;attempts=$attempts} }
    }
  }
  return [pscustomobject]@{ok=$false;exe='';cmd='';attempts=$attempts}
}
function Tidy-Desktop([string]$Desktop,[string]$OrgRoot){
  New-Item -ItemType Directory -Force -Path $OrgRoot|Out-Null
  foreach($c in @('01-Apps-Shortcuts','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){ New-Item -ItemType Directory -Force -Path (Join-Path $OrgRoot $c)|Out-Null }
  $keep=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer','Douyin.lnk','Xiaohongshu.lnk','WeChat Official Account.lnk','Jianying.lnk','DeskBox Cute.lnk','Hypit.lnk','AI Job Search.lnk','Career Ops.lnk','xiutu.skill.lnk','R241 Paths and Tools.lnk','Hypit Hard Anime Viral R244.lnk','Anime Live Wallpaper R244.lnk','Auto Tidy Desktop.lnk','R244 Anime Video Wallpaper Paths.lnk')
  $moves=@()
  foreach($it in Get-ChildItem -LiteralPath $Desktop -Force -ErrorAction SilentlyContinue){
    if($keep -contains $it.Name){ continue }
    if(($it.Attributes -band [IO.FileAttributes]::System) -or ($it.Attributes -band [IO.FileAttributes]::Hidden)){ continue }
    $cat='08-Misc'
    if($it.PSIsContainer){ $cat='07-Old-Folders' } else { $ext=$it.Extension.ToLowerInvariant(); if($ext -in @('.lnk','.url','.cmd','.bat','.ps1')){$cat='01-Apps-Shortcuts'} elseif($ext -in @('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')){$cat='04-Images-ID-Photos'} elseif($ext -in @('.mp4','.mov','.mkv','.avi','.srt')){$cat='03-Video-Creation'} elseif($ext -in @('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.txt','.md','.csv')){$cat='05-Documents'} elseif($ext -in @('.zip','.rar','.7z','.exe','.msi','.msix','.appx')){$cat='06-Archives-Installers'} }
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
$report=Join-Path $outDir 'R245_DYNAMIC_WALLPAPER_VERIFY.md'
$jsonReport=Join-Path $outDir 'r245-dynamic-wallpaper-verify.json'
$lab='E:\0mcp-agv-arena-optimized'
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
$hardVideo=Join-Path $lab 'video\hypit-hard-anime-viral-r244\hypit_hard_anime_viral_r244.mp4'
$wallVideo=Join-Path $lab 'wallpapers\anime-live-r244\anime_live_wallpaper_r244.mp4'
$story=Join-Path $lab 'video\hypit-hard-anime-viral-r244\hypit_storyboard_hard_viral_anime.svml'
$manifest=Join-Path $lab 'video\hypit-hard-anime-viral-r244\viral_rebuild_manifest.json'
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'
$hardBytes=0; if(Test-Path -LiteralPath $hardVideo){$hardBytes=(Get-Item -LiteralPath $hardVideo).Length}
$wallBytes=0; if(Test-Path -LiteralPath $wallVideo){$wallBytes=(Get-Item -LiteralPath $wallVideo).Length}
L '# R245 dynamic wallpaper verify and final report'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('desktop_dir='+$desktop)
L ('hard_video='+$hardVideo)
L ('hard_video_exists='+(Test-Path -LiteralPath $hardVideo))
L ('hard_video_bytes='+$hardBytes)
L ('wallpaper_video='+$wallVideo)
L ('wallpaper_video_exists='+(Test-Path -LiteralPath $wallVideo))
L ('wallpaper_video_bytes='+$wallBytes)
L ('storyboard='+$story+' exists='+(Test-Path -LiteralPath $story))
L ('viral_manifest='+$manifest+' exists='+(Test-Path -LiteralPath $manifest))
$cands=Find-LivelyCandidates
foreach($c in $cands){ L ('lively_candidate='+$c) }
$set=Set-Lively $cands $wallVideo
L ('dynamic_wallpaper_set_ok='+$set.ok)
L ('dynamic_wallpaper_exe='+$set.exe)
L ('dynamic_wallpaper_cmd='+$set.cmd)
$i=0; foreach($a in $set.attempts){ L ('dynamic_attempt_'+$i+'_exe='+$a.exe); L ('dynamic_attempt_'+$i+'_exit='+$a.exit); L ('dynamic_attempt_'+$i+'_tail='+$a.tail); $i++ }
$deskVideo=Join-Path $org '03-Video-Creation\hypit_hard_anime_viral_r244.mp4'
$deskWall=Join-Path $org '09-Anime-Wallpapers\anime_live_wallpaper_r244.mp4'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $deskVideo),(Split-Path -Parent $deskWall)|Out-Null
if(Test-Path -LiteralPath $hardVideo){ Copy-Item -LiteralPath $hardVideo -Destination $deskVideo -Force; New-Link (Join-Path $desktop 'Hypit Hard Anime Viral R244.lnk') $hardVideo '' (Split-Path -Parent $hardVideo) $hardVideo 'Open hard anime viral video'|Out-Null }
if(Test-Path -LiteralPath $wallVideo){ Copy-Item -LiteralPath $wallVideo -Destination $deskWall -Force; New-Link (Join-Path $desktop 'Anime Live Wallpaper R244.lnk') $wallVideo '' (Split-Path -Parent $wallVideo) $wallVideo 'Open anime live wallpaper video'|Out-Null }
$tidy=Tidy-Desktop $desktop $org
L ('desktop_organized_video='+$deskVideo+' exists='+(Test-Path -LiteralPath $deskVideo))
L ('desktop_organized_wallpaper='+$deskWall+' exists='+(Test-Path -LiteralPath $deskWall))
L ('desktop_tidy_manifest='+$tidy.manifest)
L ('desktop_tidy_moved_count='+$tidy.moved)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))
$pathsDir=Join-Path $lab 'r244-hard-anime-video-wallpaper'; New-Item -ItemType Directory -Force -Path $pathsDir|Out-Null
$pathsTxt=Join-Path $pathsDir 'PATHS.txt'
$pathLines=@('Hard anime viral video: '+$hardVideo,'Hard video bytes: '+$hardBytes,'Hard video desktop organized copy: '+$deskVideo,'Storyboard: '+$story,'Manifest: '+$manifest,'Anime live wallpaper video: '+$wallVideo,'Wallpaper bytes: '+$wallBytes,'Wallpaper desktop organized copy: '+$deskWall,'Dynamic wallpaper command: '+$set.exe+' '+$set.cmd,'Desktop organizer: '+$org,'Auto tidy manifest: '+$tidy.manifest)
WriteUtf8 $pathsTxt (($pathLines -join "`r`n")+"`r`n")
New-Link (Join-Path $desktop 'R244 Anime Video Wallpaper Paths.lnk') 'explorer.exe' ('"'+$pathsDir+'"') $pathsDir '' 'Open R244 paths'|Out-Null
L ('paths_summary='+$pathsTxt+' exists='+(Test-Path -LiteralPath $pathsTxt))
$hardOk=((Test-Path -LiteralPath $hardVideo) -and ([int64]$hardBytes -gt 1000000))
$wallOk=((Test-Path -LiteralPath $wallVideo) -and ([int64]$wallBytes -gt 1000000))
$tidyOk=Test-Path -LiteralPath $tidy.manifest
$ready=($hardOk -and $wallOk -and $set.ok -and $tidyOk)
L ('hard_video_ok='+$hardOk)
L ('wallpaper_video_ok='+$wallOk)
L ('dynamic_wallpaper_ok='+$set.ok)
L ('desktop_tidy_ok='+$tidyOk)
L ('R245_DYNAMIC_WALLPAPER_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;desktop=$desktop;eRoot=$lab;hardVideo=$hardVideo;hardVideoBytes=$hardBytes;wallpaperVideo=$wallVideo;wallpaperBytes=$wallBytes;storyboard=$story;manifest=$manifest;dynamicWallpaperSetOk=$set.ok;dynamicWallpaperExe=$set.exe;dynamicWallpaperCmd=$set.cmd;desktopOrganizedVideo=$deskVideo;desktopOrganizedWallpaper=$deskWall;desktopOrganizer=$org;tidyManifest=$tidy.manifest;pathsSummary=$pathsTxt}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){exit 6}
exit 0
