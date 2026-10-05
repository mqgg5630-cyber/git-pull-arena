# t201_lively_exact_args_r250.ps1 - round 250.
# Use exact --file=<path> and --monitor=1 argv strings for Lively.exe.
# ASCII-only.

$ErrorActionPreference='Continue'
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
function Tidy([string]$Desktop,[string]$Org){ New-Item -ItemType Directory -Force -Path $Org|Out-Null; foreach($c in @('01-Apps-Shortcuts','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){New-Item -ItemType Directory -Force -Path (Join-Path $Org $c)|Out-Null}; $m=Join-Path $Org 'AUTO_TIDY_LAST_RUN.txt'; WriteUtf8 $m ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`n"); return $m }
$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R250_LIVELY_EXACT_ARGS.md'; $jsonReport=Join-Path $outDir 'r250-lively-exact-args.json'
$lab='E:\0mcp-agv-arena-optimized'; $project=Join-Path $lab 'wallpapers\cute-anime-live-r247\lively-html-project'; $video=Join-Path $lab 'wallpapers\cute-anime-live-r247\cute_anime_live_wallpaper_r247.mp4'; $lively='C:\Program Files\Lively Wallpaper\Lively.exe'
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop' }
L '# R250 Lively exact argument set'
L ('project='+$project+' exists='+(Test-Path -LiteralPath $project)); L ('index_exists='+(Test-Path -LiteralPath (Join-Path $project 'index.html'))); L ('lively='+$lively+' exists='+(Test-Path -LiteralPath $lively))
try{ Start-Process -FilePath $lively -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 8 }catch{}
$fileProject='--file='+$project; $fileVideo='--file='+$video; $mon='--monitor=1'
$attempts=@(); $ok=$false; $usedArgs=''
foreach($args in @(@('setwp',$fileProject,$mon),@('setwp',$fileProject),@('setwp',$fileVideo,$mon))){ $r=Run-ExeArgs $lively ([string[]]$args) 240; $argText=($args -join ' '); $attempts += [pscustomobject]@{args=$argText;exit=$r.code;tail=(TailText $r.text 8)}; if($r.code -eq 0){$ok=$true;$usedArgs=$argText;break} }
L ('dynamic_set_ok='+$ok); L ('dynamic_set_args='+$usedArgs); $i=0; foreach($a in $attempts){L ('attempt_'+$i+'_args='+$a.args); L ('attempt_'+$i+'_exit='+$a.exit); L ('attempt_'+$i+'_tail='+$a.tail); $i++}
Start-Sleep -Seconds 10
$procs=@(); try{$procs=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Lively*' -or $_.ProcessName -like '*WebView*' -or $_.ProcessName -like '*CefSharp*' -or $_.ProcessName -like '*mpv*' }}catch{}
L ('lively_process_count='+(@($procs).Count)); foreach($p in @($procs|Select-Object -First 16)){L ('lively_process='+$p.ProcessName+' pid='+$p.Id)}
$cmdHit=$false; try{$needle='cute-anime-live-r247'; $wps=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($needle) }; if(@($wps).Count -gt 0){$cmdHit=$true; foreach($p in @($wps|Select-Object -First 8)){L ('wallpaper_process_cmd_hit='+$p.Name+' pid='+$p.ProcessId)}}}catch{}
L ('wallpaper_process_commandline_contains_r247='+$cmdHit)
$tidy=Tidy $desktop (Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer')
L ('desktop_tidy_manifest='+$tidy); L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy))
$htmlOk=(Test-Path -LiteralPath (Join-Path $project 'index.html'))
$ready=($htmlOk -and $ok -and (@($procs).Count -gt 0) -and (Test-Path -LiteralPath $tidy))
L ('html_dynamic_project_ok='+$htmlOk); L ('exact_arg_set_ok='+$ok); L ('lively_process_seen='+(@($procs).Count -gt 0)); L ('desktop_tidy_ok='+(Test-Path -LiteralPath $tidy)); L ('R250_LIVELY_EXACT_ARGS_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;project=$project;dynamicSetOk=$ok;dynamicSetArgs=$usedArgs;livelyProcessCount=@($procs).Count;commandLineHit=$cmdHit;tidyManifest=$tidy}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 5)+"`r`n")
W $report $script:Lines
if(-not $ready){exit 6}
exit 0
