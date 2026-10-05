# t198_cute_dynamic_wallpaper_r247.ps1 - round 247.
# Create a visibly animated cute anime Lively HTML wallpaper, set it with
# livelycu/Lively, and tidy the desktop. ASCII-only.

$ErrorActionPreference='Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { [System.Net.ServicePointManager]::CheckCertificateRevocationList=$false } catch {}
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function Find-Cmd([string[]]$Names){ foreach($n in $Names){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue; if($c){ return $c.Source } }catch{} }; return '' }
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
function Download-File([string]$Url,[string]$Out){
  $curl=Find-Cmd @('curl.exe','curl')
  if($curl){
    $r=Run-CmdLine ('"'+$curl+'" -L --ssl-no-revoke --retry 3 -A "Mozilla/5.0" -o "'+$Out+'" "'+$Url+'"') '' 900
    if((Test-Path -LiteralPath $Out) -and ((Get-Item -LiteralPath $Out).Length -gt 100000)){ return $r }
  }
  try{ Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='Mozilla/5.0'} -Uri $Url -OutFile $Out; return @{code=0;text='Invoke-WebRequest OK'} }catch{ return @{code=1;text=$_.Exception.Message} }
}
function Find-LivelyExe(){
  foreach($p in @('C:\Program Files\Lively Wallpaper\Lively.exe','C:\Program Files (x86)\Lively Wallpaper\Lively.exe')){ if(Test-Path -LiteralPath $p){ return $p } }
  foreach($root in @($env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)){
    if($root -and (Test-Path -LiteralPath $root)){ try{ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter Lively.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){return $f.FullName} }catch{} }
  }
  return (Find-Cmd @('Lively.exe','lively.exe'))
}
function Find-LivelyCU([string]$ToolsRoot){
  $cands=@()
  foreach($p in @('C:\Program Files\Lively Wallpaper\livelycu.exe','C:\Program Files (x86)\Lively Wallpaper\livelycu.exe',(Join-Path $ToolsRoot 'lively-command-utility\livelycu.exe'))){ if(Test-Path -LiteralPath $p){ $cands += $p } }
  foreach($root in @($ToolsRoot,$env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)){
    if($root -and (Test-Path -LiteralPath $root)){ try{ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter livelycu.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f -and -not($cands -contains $f.FullName)){ $cands += $f.FullName } }catch{} }
  }
  $cmd=Find-Cmd @('livelycu.exe')
  if($cmd -and -not($cands -contains $cmd)){ $cands += $cmd }
  return $cands
}
function Ensure-LivelyCU([string]$ToolsRoot){
  $existing=Find-LivelyCU $ToolsRoot
  if($existing.Count -gt 0){ return $existing }
  $dir=Join-Path $ToolsRoot 'lively-command-utility'; New-Item -ItemType Directory -Force -Path $dir|Out-Null
  $zip=Join-Path $dir 'lively_command_utility.zip'
  $url='https://github.com/rocksdanister/lively/releases/download/v2.2.1.0/lively_command_utility.zip'
  $dl=Download-File $url $zip
  L ('livelycu_download_exit='+$dl.code)
  L ('livelycu_download_tail='+(TailText (San $dl.text) 8))
  if(Test-Path -LiteralPath $zip){ try{ Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force }catch{ L ('livelycu_expand_error='+(San $_.Exception.Message)) } }
  return (Find-LivelyCU $ToolsRoot)
}
function Find-Ffmpeg(){
  foreach($n in @('ffmpeg.exe','ffmpeg')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue; if($c){return $c.Source} }catch{} }
  foreach($root in @('E:\0mcp-agv-arena-optimized',$env:APPDATA,$env:LOCALAPPDATA)){ if($root -and (Test-Path -LiteralPath $root)){ try{ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter ffmpeg*.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){return $f.FullName} }catch{} } }
  return ''
}
function Set-LivelyProject([string]$Project,[string]$Video,[string]$Lively,[string[]]$Cus){
  $attempts=@(); $ok=$false; $used=''; $cmdUsed=''
  if($Lively -and (Test-Path -LiteralPath $Lively)){ try{ Start-Process -FilePath $Lively -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 8 }catch{} }
  foreach($cu in $Cus){
    if(-not(Test-Path -LiteralPath $cu)){ continue }
    foreach($cmd in @('closewp --monitor -1','app --play true','app --volume 0','setwp --file "'+$Project+'" --monitor 1','setwp --file "'+$Project+'"','setwp --file "'+$Video+'" --monitor 1')){
      $r=Run-CmdLine ('"'+$cu+'" '+$cmd) '' 240
      $attempts += [pscustomobject]@{exe=$cu;cmd=$cmd;exit=$r.code;tail=(TailText (San $r.text) 6)}
      if(($cmd -like 'setwp*') -and $r.code -eq 0){ $ok=$true; $used=$cu; $cmdUsed=$cmd; break }
    }
    if($ok){ break }
  }
  if(-not $ok -and $Lively -and (Test-Path -LiteralPath $Lively)){
    foreach($cmd in @('setwp --file "'+$Project+'" --monitor 1','setwp --file "'+$Project+'"','setwp --file "'+$Video+'" --monitor 1')){
      $r=Run-CmdLine ('"'+$Lively+'" '+$cmd) '' 240
      $attempts += [pscustomobject]@{exe=$Lively;cmd=$cmd;exit=$r.code;tail=(TailText (San $r.text) 6)}
      if($r.code -eq 0){ $ok=$true; $used=$Lively; $cmdUsed=$cmd; break }
    }
  }
  return [pscustomobject]@{ok=$ok;exe=$used;cmd=$cmdUsed;attempts=$attempts}
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
  $manifest=Join-Path $OrgRoot 'AUTO_TIDY_LAST_RUN.txt'
  WriteUtf8 $manifest (('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`n")+($moves -join "`r`n")+"`r`n")
  return [pscustomobject]@{manifest=$manifest;moved=$moves.Count}
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R247_CUTE_DYNAMIC_WALLPAPER.md'; $jsonReport=Join-Path $outDir 'r247-cute-dynamic-wallpaper.json'
$lab='E:\0mcp-agv-arena-optimized'; $wallRoot=Join-Path $lab 'wallpapers\cute-anime-live-r247'; $project=Join-Path $wallRoot 'lively-html-project'; $imageDir=Join-Path $lab 'images\cute-anime-wallpaper-r247'; $tools=Join-Path $lab 'tools'
foreach($d in @($wallRoot,$project,$imageDir,$tools)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
$asset=Join-Path $repo 'deliverable\assets\cute_anime_live_wallpaper_r247.png'
$image=Join-Path $imageDir 'cute_anime_live_wallpaper_r247.png'
if(Test-Path -LiteralPath $asset){ Copy-Item -LiteralPath $asset -Destination $image -Force; Copy-Item -LiteralPath $asset -Destination (Join-Path $project 'background.png') -Force }
L '# R247 cute anime real dynamic wallpaper'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('desktop_dir='+$desktop)
L ('asset='+$asset+' exists='+(Test-Path -LiteralPath $asset))
L ('source_image='+$image+' exists='+(Test-Path -LiteralPath $image))
$info=@{
  AppVersion='2.2.1.0'; Title='Cute Anime Dynamic R247'; Desc='Cute anime character with animated petals, rain, sparkles, aurora, and glowing cat spirit.'; Author='Arena'; License='Original generated artwork'; Contact=''; Type=1; FileName='index.html'; Arguments=''; IsAbsolutePath=$false; Thumbnail='background.png'; Preview='background.png'
} | ConvertTo-Json -Depth 4
WriteUtf8 (Join-Path $project 'LivelyInfo.json') $info
$html=@'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>
*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#090a22}body{font-family:Segoe UI,Arial,sans-serif}.scene{position:fixed;inset:0;background-image:linear-gradient(120deg,rgba(255,111,196,.24),rgba(95,222,255,.16),rgba(135,90,255,.19)),url('background.png');background-size:cover;background-position:center;animation:ken 18s ease-in-out infinite alternate;filter:saturate(1.25) contrast(1.05)}.aurora{position:fixed;inset:-20%;background:radial-gradient(circle at 20% 20%,rgba(255,142,210,.42),transparent 26%),radial-gradient(circle at 72% 30%,rgba(75,224,255,.36),transparent 28%),radial-gradient(circle at 50% 82%,rgba(178,100,255,.30),transparent 32%);mix-blend-mode:screen;animation:aur 9s linear infinite alternate}.glass{position:fixed;left:6vw;right:6vw;bottom:5vh;height:18vh;border-radius:34px;background:linear-gradient(90deg,rgba(255,255,255,.12),rgba(255,255,255,.035));border:1px solid rgba(255,255,255,.28);box-shadow:0 0 40px rgba(255,140,220,.22);animation:pulse 2.6s ease-in-out infinite}.cat{position:fixed;right:11vw;bottom:17vh;width:90px;height:70px;border-radius:50%;background:radial-gradient(circle,#fff 0,#ffe5fb 45%,#ff78d0 80%);box-shadow:0 0 40px #ff8ce5,0 0 90px #5de4ff;animation:float 3.2s ease-in-out infinite}.cat:before,.cat:after{content:"";position:absolute;top:-16px;border-left:18px solid transparent;border-right:18px solid transparent;border-bottom:34px solid #ffe5fb}.cat:before{left:10px;transform:rotate(-18deg)}.cat:after{right:10px;transform:rotate(18deg)}.spark,.petal,.rain{position:fixed;pointer-events:none}.spark{width:5px;height:5px;border-radius:50%;background:#fff;box-shadow:0 0 12px #fff}.petal{width:16px;height:9px;border-radius:70% 30% 70% 30%;background:linear-gradient(90deg,#fff0fa,#ff8ed9);box-shadow:0 0 12px rgba(255,160,220,.65)}.rain{width:1.5px;height:38px;background:linear-gradient(transparent,rgba(180,235,255,.75));transform:rotate(12deg)}@keyframes ken{0%{transform:scale(1.03) translate(-1.2%,-.6%)}100%{transform:scale(1.12) translate(1.2%,.8%)}}@keyframes aur{0%{transform:translate(-4%,-2%) rotate(0deg);filter:hue-rotate(0deg)}100%{transform:translate(4%,2%) rotate(8deg);filter:hue-rotate(38deg)}}@keyframes pulse{0%,100%{opacity:.45;transform:translateY(0)}50%{opacity:.75;transform:translateY(-8px)}}@keyframes float{0%,100%{transform:translateY(0) scale(1)}50%{transform:translateY(-28px) scale(1.06)}}
</style></head><body><div class="scene"></div><div class="aurora"></div><div class="glass"></div><div class="cat"></div><script>
const N=110,R=80,S=90;function add(c,n){for(let i=0;i<n;i++){const e=document.createElement('i');e.className=c;document.body.appendChild(e);e.style.left=(Math.random()*100)+'vw';e.style.top=(-20+Math.random()*120)+'vh';e.dataset.x=Math.random()*100;e.dataset.y=Math.random()*100;e.dataset.s=(.4+Math.random()*1.7);e.dataset.p=Math.random()*6.28}}add('petal',N);add('rain',R);add('spark',S);const els=[...document.querySelectorAll('.petal,.rain,.spark')];let t=0;function step(){t+=.016;for(const e of els){let x=+e.dataset.x,y=+e.dataset.y,s=+e.dataset.s,p=+e.dataset.p;if(e.className==='rain'){y=(y+t*38*s)%120;x=(x+t*2)%105;e.style.opacity=.25+.35*Math.sin(t*3+p)}else if(e.className==='petal'){y=(y+t*10*s)%125;x=(x+Math.sin(t*s+p)*8+t*1.2)%110;e.style.transform=`rotate(${(t*80*s+p*80)%360}deg)`}else{y=(y+Math.sin(t*s+p)*.05)%105;x=(x+Math.cos(t*.7*s+p)*.08)%105;e.style.opacity=.35+.65*Math.abs(Math.sin(t*2*s+p));e.style.transform=`scale(${.6+.8*Math.abs(Math.sin(t*s+p))})`}e.style.left=x+'vw';e.style.top=(y-15)+'vh'}requestAnimationFrame(step)}step();</script></body></html>
'@
WriteUtf8 (Join-Path $project 'index.html') $html
$ff=Find-Ffmpeg
$video=Join-Path $wallRoot 'cute_anime_live_wallpaper_r247.mp4'
if($ff -and (Test-Path -LiteralPath $image)){
  $cmd='"'+$ff+'" -y -loop 1 -i "'+$image+'" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -t 18 -vf "scale=1600:900:force_original_aspect_ratio=increase,crop=1600:900,zoompan=z=1.04+0.035*sin(on/45):x=iw/2-(iw/zoom/2):y=ih/2-(ih/zoom/2):d=1:s=1600x900:fps=30,format=yuv420p" -c:v libx264 -preset medium -crf 17 -c:a aac -b:a 96k "'+$video+'"'
  $vr=Run-CmdLine $cmd '' 900
  L ('backup_video_render_exit='+$vr.code)
  L ('backup_video_render_tail='+(TailText (San $vr.text) 8))
}else{ L 'backup_video_render_skipped=True' }
$videoBytes=0; if(Test-Path -LiteralPath $video){ $videoBytes=(Get-Item -LiteralPath $video).Length }
L ('html_project='+$project+' exists='+(Test-Path -LiteralPath (Join-Path $project 'index.html')))
L ('html_lively_info='+(Join-Path $project 'LivelyInfo.json')+' exists='+(Test-Path -LiteralPath (Join-Path $project 'LivelyInfo.json')))
L ('backup_video='+$video+' exists='+(Test-Path -LiteralPath $video))
L ('backup_video_bytes='+$videoBytes)
$lively=Find-LivelyExe
$cus=Ensure-LivelyCU $tools
L ('lively_exe='+$lively+' exists='+($lively -and (Test-Path -LiteralPath $lively)))
foreach($cu in $cus){ L ('livelycu_candidate='+$cu+' exists='+(Test-Path -LiteralPath $cu)) }
$set=Set-LivelyProject $project $video $lively $cus
L ('dynamic_set_ok='+$set.ok)
L ('dynamic_set_exe='+$set.exe)
L ('dynamic_set_cmd='+$set.cmd)
$i=0; foreach($a in $set.attempts){ L ('dynamic_attempt_'+$i+'_exe='+$a.exe); L ('dynamic_attempt_'+$i+'_cmd='+$a.cmd); L ('dynamic_attempt_'+$i+'_exit='+$a.exit); L ('dynamic_attempt_'+$i+'_tail='+$a.tail); $i++ }
Start-Sleep -Seconds 5
$procs=@(); try{ $procs=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Lively*' -or $_.ProcessName -like '*mpv*' -or $_.ProcessName -like '*CefSharp*' } }catch{}
L ('lively_process_count='+(@($procs).Count))
foreach($p in @($procs|Select-Object -First 12)){ L ('lively_process='+$p.ProcessName+' pid='+$p.Id) }
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'; $wallFolder=Join-Path $org '09-Anime-Wallpapers'; New-Item -ItemType Directory -Force -Path $wallFolder|Out-Null
$deskHtml=Join-Path $wallFolder 'Cute-Anime-Dynamic-R247-HTML-Project'; if(Test-Path -LiteralPath $deskHtml){ Remove-Item -LiteralPath $deskHtml -Recurse -Force -ErrorAction SilentlyContinue }; Copy-Item -LiteralPath $project -Destination $deskHtml -Recurse -Force
$deskVideo=Join-Path $wallFolder 'cute_anime_live_wallpaper_r247.mp4'; if(Test-Path -LiteralPath $video){ Copy-Item -LiteralPath $video -Destination $deskVideo -Force }
New-Link (Join-Path $desktop 'Cute Anime Dynamic R247.lnk') $video '' (Split-Path -Parent $video) $video 'Open cute anime backup video'|Out-Null
New-Link (Join-Path $desktop 'Cute Anime Live Project R247.lnk') 'explorer.exe' ('"'+$project+'"') $project '' 'Open cute anime Lively HTML project'|Out-Null
$tidyScriptDir=Join-Path $tools 'desktop-organizer'; New-Item -ItemType Directory -Force -Path $tidyScriptDir|Out-Null
$tidyScript=Join-Path $tidyScriptDir 'auto_tidy_desktop.ps1'
$tidyCode=@'
$ErrorActionPreference='Continue'
$desktop=[Environment]::GetFolderPath('Desktop')
if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop' }
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'
New-Item -ItemType Directory -Force -Path $org|Out-Null
Write-Output ('Desktop organizer folder: '+$org)
'@
WriteUtf8 $tidyScript $tidyCode
New-Link (Join-Path $desktop 'Auto Tidy Desktop.lnk') (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') ('-NoProfile -ExecutionPolicy Bypass -File "'+$tidyScript+'"') $tidyScriptDir '' 'Run desktop tidy'|Out-Null
$tidy=Tidy-Desktop $desktop $org
L ('desktop_project_copy='+$deskHtml+' exists='+(Test-Path -LiteralPath $deskHtml))
L ('desktop_video_copy='+$deskVideo+' exists='+(Test-Path -LiteralPath $deskVideo))
L ('desktop_tidy_manifest='+$tidy.manifest)
L ('desktop_tidy_moved_count='+$tidy.moved)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))
$pathsDir=Join-Path $lab 'r247-cute-dynamic-wallpaper'; New-Item -ItemType Directory -Force -Path $pathsDir|Out-Null
$pathsTxt=Join-Path $pathsDir 'PATHS.txt'
$pathLines=@('Cute dynamic Lively HTML project: '+$project,'HTML index: '+(Join-Path $project 'index.html'),'LivelyInfo: '+(Join-Path $project 'LivelyInfo.json'),'Source cute anime image: '+$image,'Backup MP4: '+$video,'Organized desktop HTML copy: '+$deskHtml,'Organized desktop MP4 copy: '+$deskVideo,'Lively executable: '+$lively,'Lively command used: '+$set.exe+' '+$set.cmd,'Desktop organizer: '+$org,'Desktop tidy manifest: '+$tidy.manifest)
WriteUtf8 $pathsTxt (($pathLines -join "`r`n")+"`r`n")
New-Link (Join-Path $desktop 'R247 Cute Dynamic Wallpaper Paths.lnk') 'explorer.exe' ('"'+$pathsDir+'"') $pathsDir '' 'Open R247 paths'|Out-Null
L ('paths_summary='+$pathsTxt+' exists='+(Test-Path -LiteralPath $pathsTxt))
$htmlOk=(Test-Path -LiteralPath (Join-Path $project 'index.html')) -and (Test-Path -LiteralPath (Join-Path $project 'LivelyInfo.json'))
$videoOk=(Test-Path -LiteralPath $video) -and ([int64]$videoBytes -gt 1000000)
$procOk=(@($procs).Count -gt 0)
$ready=($htmlOk -and $set.ok -and $procOk -and (Test-Path -LiteralPath $tidy.manifest))
L ('html_dynamic_project_ok='+$htmlOk)
L ('backup_video_ok='+$videoOk)
L ('lively_process_seen='+$procOk)
L ('desktop_tidy_ok='+(Test-Path -LiteralPath $tidy.manifest))
L ('R247_CUTE_DYNAMIC_WALLPAPER_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;desktop=$desktop;eRoot=$lab;htmlProject=$project;htmlIndex=(Join-Path $project 'index.html');livelyInfo=(Join-Path $project 'LivelyInfo.json');sourceImage=$image;backupVideo=$video;backupVideoBytes=$videoBytes;organizedHtmlProject=$deskHtml;organizedVideo=$deskVideo;livelyExe=$lively;livelyCu=$cus;dynamicSetOk=$set.ok;dynamicSetExe=$set.exe;dynamicSetCmd=$set.cmd;livelyProcessCount=@($procs).Count;desktopOrganizer=$org;tidyManifest=$tidy.manifest;pathsSummary=$pathsTxt}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){ exit 6 }
exit 0
