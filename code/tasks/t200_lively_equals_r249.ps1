# t200_lively_equals_r249.ps1 - round 249.
# Retry Lively setwp using --file= and --monitor= argv style, then tidy desktop.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function Run-ExeArgs([string]$Exe,[string[]]$Args,[int]$TimeoutSec){
  if(-not $Exe -or -not(Test-Path -LiteralPath $Exe)){ return @{code=127;text='missing exe'} }
  $job=Start-Job -ScriptBlock { param($e,$a); & $e @a 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Exe,$Args
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }
  return @{code=$code;text=$txt}
}
function New-Link([string]$Path,[string]$Target,[string]$Arguments,[string]$WorkingDirectory,[string]$IconLocation,[string]$Description){ try{ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null; $ws=New-Object -ComObject WScript.Shell; $sc=$ws.CreateShortcut($Path); $sc.TargetPath=$Target; if($Arguments){$sc.Arguments=$Arguments}; if($WorkingDirectory){$sc.WorkingDirectory=$WorkingDirectory}; if($IconLocation){$sc.IconLocation=$IconLocation}; if($Description){$sc.Description=$Description}; $sc.Save(); return $true }catch{ return $false } }
function Tidy([string]$Desktop,[string]$Org){ New-Item -ItemType Directory -Force -Path $Org|Out-Null; foreach($c in @('01-Apps-Shortcuts','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){New-Item -ItemType Directory -Force -Path (Join-Path $Org $c)|Out-Null}; $keep=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer','Douyin.lnk','Xiaohongshu.lnk','WeChat Official Account.lnk','Jianying.lnk','DeskBox Cute.lnk','Hypit.lnk','AI Job Search.lnk','Career Ops.lnk','xiutu.skill.lnk','R241 Paths and Tools.lnk','Auto Tidy Desktop.lnk','Cute Anime Dynamic R247.lnk','Cute Anime Live Project R247.lnk','R247 Cute Dynamic Wallpaper Paths.lnk'); $moves=@(); foreach($it in Get-ChildItem -LiteralPath $Desktop -Force -ErrorAction SilentlyContinue){ if($keep -contains $it.Name){continue}; if(($it.Attributes -band [IO.FileAttributes]::System) -or ($it.Attributes -band [IO.FileAttributes]::Hidden)){continue}; $cat='08-Misc'; if($it.PSIsContainer){$cat='07-Old-Folders'}else{$ext=$it.Extension.ToLowerInvariant(); if($ext -in @('.lnk','.url','.cmd','.bat','.ps1')){$cat='01-Apps-Shortcuts'}elseif($ext -in @('.mp4','.mov','.mkv','.avi','.srt','.html')){$cat='03-Video-Creation'}elseif($ext -in @('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')){$cat='04-Images-ID-Photos'}elseif($ext -in @('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.txt','.md','.csv')){$cat='05-Documents'}elseif($ext -in @('.zip','.rar','.7z','.exe','.msi','.msix','.appx')){$cat='06-Archives-Installers'}}; $destDir=Join-Path $Org $cat; $dest=Join-Path $destDir $it.Name; $n=1; while(Test-Path -LiteralPath $dest){$base=[IO.Path]::GetFileNameWithoutExtension($it.Name); $ext2=[IO.Path]::GetExtension($it.Name); $dest=Join-Path $destDir ($base+'_'+$n+$ext2); $n++}; try{Move-Item -LiteralPath $it.FullName -Destination $dest -Force -ErrorAction Stop; $moves += ($it.FullName+' -> '+$dest)}catch{$moves += ('MOVE_ERR '+$it.FullName+' '+(San $_.Exception.Message))} }; $m=Join-Path $Org 'AUTO_TIDY_LAST_RUN.txt'; WriteUtf8 $m (('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`n")+($moves -join "`r`n")+"`r`n"); return [pscustomobject]@{manifest=$m;moved=$moves.Count} }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R249_LIVELY_EQUALS_DYNAMIC.md'; $jsonReport=Join-Path $outDir 'r249-lively-equals-dynamic.json'
$lab='E:\0mcp-agv-arena-optimized'; $project=Join-Path $lab 'wallpapers\cute-anime-live-r247\lively-html-project'; $video=Join-Path $lab 'wallpapers\cute-anime-live-r247\cute_anime_live_wallpaper_r247.mp4'
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop' }
$lively='C:\Program Files\Lively Wallpaper\Lively.exe'; $cu='E:\0mcp-agv-arena-optimized\tools\lively-command-utility\livelycu.exe'
L '# R249 Lively equals-argument dynamic set'
L ('project='+$project+' exists='+(Test-Path -LiteralPath $project)); L ('index_exists='+(Test-Path -LiteralPath (Join-Path $project 'index.html'))); L ('info_exists='+(Test-Path -LiteralPath (Join-Path $project 'LivelyInfo.json')))
L ('video='+$video+' exists='+(Test-Path -LiteralPath $video)); L ('lively='+$lively+' exists='+(Test-Path -LiteralPath $lively)); L ('livelycu='+$cu+' exists='+(Test-Path -LiteralPath $cu))
try{ if(Test-Path -LiteralPath $lively){ Start-Process -FilePath $lively -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 8 } }catch{}
$attempts=@(); $ok=$false; $used=''; $usedArgs=''
$all=@()
if(Test-Path -LiteralPath $cu){ $all += @{exe=$cu; args=@('app','--play=true')}; $all += @{exe=$cu; args=@('app','--volume=0')}; $all += @{exe=$cu; args=@('setwp','--file='+$project,'--monitor=1')}; $all += @{exe=$cu; args=@('setwp','--file='+$project)}; $all += @{exe=$cu; args=@('setwp','--file='+$video,'--monitor=1')} }
if(Test-Path -LiteralPath $lively){ $all += @{exe=$lively; args=@('setwp','--file='+$project,'--monitor=1')}; $all += @{exe=$lively; args=@('setwp','--file='+$project)}; $all += @{exe=$lively; args=@('setwp','--file='+$video,'--monitor=1')} }
foreach($a in $all){ $r=Run-ExeArgs $a.exe ([string[]]$a.args) 240; $argText=($a.args -join ' '); $attempts += [pscustomobject]@{exe=$a.exe;args=$argText;exit=$r.code;tail=(TailText (San $r.text) 8)}; if(($a.args[0] -eq 'setwp') -and $r.code -eq 0){$ok=$true;$used=$a.exe;$usedArgs=$argText;break} }
L ('dynamic_set_ok='+$ok); L ('dynamic_set_exe='+$used); L ('dynamic_set_args='+$usedArgs)
$i=0; foreach($a in $attempts){ L ('attempt_'+$i+'_exe='+$a.exe); L ('attempt_'+$i+'_args='+$a.args); L ('attempt_'+$i+'_exit='+$a.exit); L ('attempt_'+$i+'_tail='+$a.tail); $i++ }
Start-Sleep -Seconds 8
$procs=@(); try{$procs=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Lively*' -or $_.ProcessName -like '*WebView*' -or $_.ProcessName -like '*CefSharp*' -or $_.ProcessName -like '*mpv*' }}catch{}
L ('lively_process_count='+(@($procs).Count)); foreach($p in @($procs|Select-Object -First 20)){ L ('lively_process='+$p.ProcessName+' pid='+$p.Id) }
$cmdHit=$false; try{ $needle='cute-anime-live-r247'; $wps=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($needle) }; if(@($wps).Count -gt 0){$cmdHit=$true; foreach($p in @($wps|Select-Object -First 8)){L ('wallpaper_process_cmd_hit='+$p.Name+' pid='+$p.ProcessId)}} }catch{}
L ('wallpaper_process_commandline_contains_r247='+$cmdHit)
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'; $wallFolder=Join-Path $org '09-Anime-Wallpapers'; New-Item -ItemType Directory -Force -Path $wallFolder|Out-Null
$deskProject=Join-Path $wallFolder 'Cute-Anime-Dynamic-R247-HTML-Project'; if(Test-Path -LiteralPath $project){ if(Test-Path -LiteralPath $deskProject){Remove-Item -LiteralPath $deskProject -Recurse -Force -ErrorAction SilentlyContinue}; Copy-Item -LiteralPath $project -Destination $deskProject -Recurse -Force }
$tidy=Tidy $desktop $org
L ('desktop_project_copy='+$deskProject+' exists='+(Test-Path -LiteralPath $deskProject)); L ('desktop_tidy_manifest='+$tidy.manifest); L ('desktop_tidy_moved_count='+$tidy.moved); L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))
$ready=((Test-Path -LiteralPath (Join-Path $project 'index.html')) -and $ok -and (@($procs).Count -gt 0) -and (Test-Path -LiteralPath $tidy.manifest))
L ('html_dynamic_project_ok='+(Test-Path -LiteralPath (Join-Path $project 'index.html'))); L ('equals_arg_set_ok='+$ok); L ('lively_process_seen='+(@($procs).Count -gt 0)); L ('desktop_tidy_ok='+(Test-Path -LiteralPath $tidy.manifest)); L ('R249_LIVELY_EQUALS_DYNAMIC_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;project=$project;video=$video;dynamicSetOk=$ok;dynamicSetExe=$used;dynamicSetArgs=$usedArgs;livelyProcessCount=@($procs).Count;commandLineHit=$cmdHit;desktopProjectCopy=$deskProject;tidyManifest=$tidy.manifest}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){ exit 6 }
exit 0
