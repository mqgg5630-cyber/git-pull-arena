# t199_force_lively_args_r248.ps1 - round 248.
# Force-set the R247 cute anime HTML wallpaper using argv-safe Lively commands.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function Run-ExeArgs([string]$Exe,[string[]]$Args,[int]$TimeoutSec){
  if(-not $Exe -or -not(Test-Path -LiteralPath $Exe)){ return @{code=127;text='missing exe'} }
  $job=Start-Job -ScriptBlock {
    param($e,$a)
    & $e @a 2>&1 | Out-String
    $c=$LASTEXITCODE; if($null -eq $c){$c=0}
    Write-Output ('===EXITCODE:'+[string]$c)
  } -ArgumentList $Exe,$Args
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
  try{ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null; $ws=New-Object -ComObject WScript.Shell; $sc=$ws.CreateShortcut($Path); $sc.TargetPath=$Target; if($Arguments){$sc.Arguments=$Arguments}; if($WorkingDirectory){$sc.WorkingDirectory=$WorkingDirectory}; if($IconLocation){$sc.IconLocation=$IconLocation}; if($Description){$sc.Description=$Description}; $sc.Save(); return $true }catch{ return $false }
}
function Find-LivelyExe(){ foreach($p in @('C:\Program Files\Lively Wallpaper\Lively.exe','C:\Program Files (x86)\Lively Wallpaper\Lively.exe')){ if(Test-Path -LiteralPath $p){ return $p } }; return '' }
function Find-LivelyCU(){
  $out=@()
  foreach($p in @('C:\Program Files\Lively Wallpaper\livelycu.exe','C:\Program Files (x86)\Lively Wallpaper\livelycu.exe','E:\0mcp-agv-arena-optimized\tools\lively-command-utility\livelycu.exe')){ if(Test-Path -LiteralPath $p){ $out += $p } }
  return $out
}
function Tidy-Desktop([string]$Desktop,[string]$OrgRoot){
  New-Item -ItemType Directory -Force -Path $OrgRoot|Out-Null
  foreach($c in @('01-Apps-Shortcuts','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){ New-Item -ItemType Directory -Force -Path (Join-Path $OrgRoot $c)|Out-Null }
  $keep=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer','Douyin.lnk','Xiaohongshu.lnk','WeChat Official Account.lnk','Jianying.lnk','DeskBox Cute.lnk','Hypit.lnk','AI Job Search.lnk','Career Ops.lnk','xiutu.skill.lnk','R241 Paths and Tools.lnk','Auto Tidy Desktop.lnk','Cute Anime Dynamic R247.lnk','Cute Anime Live Project R247.lnk','R247 Cute Dynamic Wallpaper Paths.lnk')
  $moves=@()
  foreach($it in Get-ChildItem -LiteralPath $Desktop -Force -ErrorAction SilentlyContinue){
    if($keep -contains $it.Name){ continue }
    if(($it.Attributes -band [IO.FileAttributes]::System) -or ($it.Attributes -band [IO.FileAttributes]::Hidden)){ continue }
    $cat='08-Misc'; if($it.PSIsContainer){$cat='07-Old-Folders'} else { $ext=$it.Extension.ToLowerInvariant(); if($ext -in @('.lnk','.url','.cmd','.bat','.ps1')){$cat='01-Apps-Shortcuts'} elseif($ext -in @('.mp4','.mov','.mkv','.avi','.srt','.html')){$cat='03-Video-Creation'} elseif($ext -in @('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')){$cat='04-Images-ID-Photos'} elseif($ext -in @('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.txt','.md','.csv')){$cat='05-Documents'} elseif($ext -in @('.zip','.rar','.7z','.exe','.msi','.msix','.appx')){$cat='06-Archives-Installers'} }
    $destDir=Join-Path $OrgRoot $cat; $dest=Join-Path $destDir $it.Name; $n=1
    while(Test-Path -LiteralPath $dest){ $base=[IO.Path]::GetFileNameWithoutExtension($it.Name); $ext2=[IO.Path]::GetExtension($it.Name); $dest=Join-Path $destDir ($base+'_'+$n+$ext2); $n++ }
    try{ Move-Item -LiteralPath $it.FullName -Destination $dest -Force -ErrorAction Stop; $moves += ($it.FullName+' -> '+$dest) }catch{ $moves += ('MOVE_ERR '+$it.FullName+' '+(San $_.Exception.Message)) }
  }
  $manifest=Join-Path $OrgRoot 'AUTO_TIDY_LAST_RUN.txt'; WriteUtf8 $manifest (('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`n")+($moves -join "`r`n")+"`r`n")
  return [pscustomobject]@{manifest=$manifest;moved=$moves.Count}
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R248_FORCE_LIVELY_DYNAMIC.md'; $jsonReport=Join-Path $outDir 'r248-force-lively-dynamic.json'
$lab='E:\0mcp-agv-arena-optimized'
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
$project=Join-Path $lab 'wallpapers\cute-anime-live-r247\lively-html-project'
$video=Join-Path $lab 'wallpapers\cute-anime-live-r247\cute_anime_live_wallpaper_r247.mp4'
$lively=Find-LivelyExe
$cus=Find-LivelyCU
L '# R248 force Lively dynamic wallpaper with argv-safe calls'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('project='+$project+' exists='+(Test-Path -LiteralPath $project))
L ('project_index='+(Join-Path $project 'index.html')+' exists='+(Test-Path -LiteralPath (Join-Path $project 'index.html')))
L ('project_info='+(Join-Path $project 'LivelyInfo.json')+' exists='+(Test-Path -LiteralPath (Join-Path $project 'LivelyInfo.json')))
L ('backup_video='+$video+' exists='+(Test-Path -LiteralPath $video))
L ('lively_exe='+$lively+' exists='+($lively -and (Test-Path -LiteralPath $lively)))
foreach($cu in $cus){ L ('livelycu='+$cu+' exists='+(Test-Path -LiteralPath $cu)) }
if($lively -and (Test-Path -LiteralPath $lively)){ try{ Start-Process -FilePath $lively -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 8 }catch{} }
$attempts=@(); $ok=$false; $used=''; $usedArgs=''
foreach($cu in $cus){
  foreach($args in @(
    @('closewp','--monitor','-1'),
    @('app','--play','true'),
    @('app','--volume','0'),
    @('setwp','--file',$project,'--monitor','1'),
    @('setwp','--file',$project),
    @('setwp','--file',$video,'--monitor','1')
  )){
    $r=Run-ExeArgs $cu ([string[]]$args) 240
    $argText=($args -join ' ')
    $attempts += [pscustomobject]@{exe=$cu;args=$argText;exit=$r.code;tail=(TailText (San $r.text) 8)}
    if($args[0] -eq 'setwp' -and $r.code -eq 0){ $ok=$true; $used=$cu; $usedArgs=$argText; break }
  }
  if($ok){ break }
}
if(-not $ok -and $lively){
  foreach($args in @(@('setwp','--file',$project,'--monitor','1'),@('setwp','--file',$project),@('setwp','--file',$video,'--monitor','1'))){
    $r=Run-ExeArgs $lively ([string[]]$args) 240
    $argText=($args -join ' ')
    $attempts += [pscustomobject]@{exe=$lively;args=$argText;exit=$r.code;tail=(TailText (San $r.text) 8)}
    if($r.code -eq 0){ $ok=$true; $used=$lively; $usedArgs=$argText; break }
  }
}
L ('dynamic_set_ok='+$ok)
L ('dynamic_set_exe='+$used)
L ('dynamic_set_args='+$usedArgs)
$i=0; foreach($a in $attempts){ L ('attempt_'+$i+'_exe='+$a.exe); L ('attempt_'+$i+'_args='+$a.args); L ('attempt_'+$i+'_exit='+$a.exit); L ('attempt_'+$i+'_tail='+$a.tail); $i++ }
Start-Sleep -Seconds 6
$procs=@(); try{ $procs=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Lively*' -or $_.ProcessName -like '*CefSharp*' -or $_.ProcessName -like '*WebView*' -or $_.ProcessName -like '*mpv*' } }catch{}
L ('lively_process_count='+(@($procs).Count))
foreach($p in @($procs|Select-Object -First 16)){ L ('lively_process='+$p.ProcessName+' pid='+$p.Id) }
$libraryHit=$false
foreach($root in @((Join-Path $env:LOCALAPPDATA 'Lively Wallpaper'),(Join-Path $env:LOCALAPPDATA 'Packages'))){
  if($root -and (Test-Path -LiteralPath $root)){
    try{ $hit=Get-ChildItem -LiteralPath $root -Recurse -Filter LivelyInfo.json -File -ErrorAction SilentlyContinue | Select-String -Pattern 'Cute Anime Dynamic R247' -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1; if($hit){$libraryHit=$true; L ('library_hit='+$hit.Path); break} }catch{}
  }
}
L ('lively_library_contains_project='+$libraryHit)
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'; $wallFolder=Join-Path $org '09-Anime-Wallpapers'; New-Item -ItemType Directory -Force -Path $wallFolder|Out-Null
$deskProject=Join-Path $wallFolder 'Cute-Anime-Dynamic-R247-HTML-Project'; if(Test-Path -LiteralPath $project){ if(Test-Path -LiteralPath $deskProject){ Remove-Item -LiteralPath $deskProject -Recurse -Force -ErrorAction SilentlyContinue }; Copy-Item -LiteralPath $project -Destination $deskProject -Recurse -Force }
$deskVideo=Join-Path $wallFolder 'cute_anime_live_wallpaper_r247.mp4'; if(Test-Path -LiteralPath $video){ Copy-Item -LiteralPath $video -Destination $deskVideo -Force }
New-Link (Join-Path $desktop 'Cute Anime Dynamic R247.lnk') $video '' (Split-Path -Parent $video) $video 'Open cute anime backup video'|Out-Null
New-Link (Join-Path $desktop 'Cute Anime Live Project R247.lnk') 'explorer.exe' ('"'+$project+'"') $project '' 'Open cute anime Lively HTML project'|Out-Null
$tidy=Tidy-Desktop $desktop $org
L ('desktop_project_copy='+$deskProject+' exists='+(Test-Path -LiteralPath $deskProject))
L ('desktop_video_copy='+$deskVideo+' exists='+(Test-Path -LiteralPath $deskVideo))
L ('desktop_tidy_manifest='+$tidy.manifest)
L ('desktop_tidy_moved_count='+$tidy.moved)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))
$pathsDir=Join-Path $lab 'r247-cute-dynamic-wallpaper'; New-Item -ItemType Directory -Force -Path $pathsDir|Out-Null
$pathsTxt=Join-Path $pathsDir 'PATHS.txt'
$pathLines=@('Cute dynamic HTML project: '+$project,'Index: '+(Join-Path $project 'index.html'),'LivelyInfo: '+(Join-Path $project 'LivelyInfo.json'),'Backup MP4: '+$video,'Lively command used: '+$used+' '+$usedArgs,'Library imported project: '+$libraryHit,'Desktop project copy: '+$deskProject,'Desktop MP4 copy: '+$deskVideo,'Tidy manifest: '+$tidy.manifest)
WriteUtf8 $pathsTxt (($pathLines -join "`r`n")+"`r`n")
New-Link (Join-Path $desktop 'R247 Cute Dynamic Wallpaper Paths.lnk') 'explorer.exe' ('"'+$pathsDir+'"') $pathsDir '' 'Open R247 paths'|Out-Null
L ('paths_summary='+$pathsTxt+' exists='+(Test-Path -LiteralPath $pathsTxt))
$htmlOk=(Test-Path -LiteralPath (Join-Path $project 'index.html')) -and (Test-Path -LiteralPath (Join-Path $project 'LivelyInfo.json'))
$procOk=(@($procs).Count -gt 0)
$ready=($htmlOk -and $ok -and $procOk -and (Test-Path -LiteralPath $tidy.manifest))
L ('html_dynamic_project_ok='+$htmlOk)
L ('argv_safe_set_ok='+$ok)
L ('lively_process_seen='+$procOk)
L ('desktop_tidy_ok='+(Test-Path -LiteralPath $tidy.manifest))
L ('R248_FORCE_LIVELY_DYNAMIC_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;htmlProject=$project;backupVideo=$video;livelyExe=$lively;livelyCu=$cus;dynamicSetOk=$ok;dynamicSetExe=$used;dynamicSetArgs=$usedArgs;livelyProcessCount=@($procs).Count;libraryHit=$libraryHit;desktopProjectCopy=$deskProject;desktopVideoCopy=$deskVideo;tidyManifest=$tidy.manifest;pathsSummary=$pathsTxt}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){ exit 6 }
exit 0
