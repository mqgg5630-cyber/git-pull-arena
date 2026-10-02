# t188_finish_jianying_video_r237.ps1 - round 237.
# Finish R236 video by provisioning ffmpeg without admin and rerunning builder.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s-replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s-replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function Find-Ffmpeg(){ foreach($n in @('ffmpeg.exe','ffmpeg')){ try{ $cmd=Get-Command $n -ErrorAction SilentlyContinue; if($cmd){return $cmd.Source} }catch{} }; foreach($root in @('E:\0mcp-agv-arena-optimized\tools\ffmpeg','E:\0mcp-agv-arena-optimized','E:\ffmpeg','C:\ffmpeg')){ if(Test-Path -LiteralPath $root){ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter ffmpeg.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){return $f.FullName} } }; return '' }
function Find-Python(){ foreach($n in @('python','py')){ try{ $cmd=Get-Command $n -ErrorAction SilentlyContinue; if($cmd){return $cmd.Source} }catch{} }; return '' }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'JIANYING_VIDEO_FINISH_R237.md'
L '# R237 finish jianying funny video'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$lab='E:\0mcp-agv-arena-optimized'
$project=Join-Path $lab 'jianying-editor-demo'
$materials=Join-Path $project 'materials'
$work=Join-Path $project 'work'
$output=Join-Path $project 'output'
foreach($d in @($project,$materials,$work,$output)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$py=Find-Python
L ('python='+(San $py))
$ffmpeg=Find-Ffmpeg
L ('ffmpeg_initial='+(San $ffmpeg))

# Try extracting previously downloaded zip with Python zipfile.
if(-not $ffmpeg -and $py){
  $zip=Join-Path $lab 'tools\ffmpeg\ffmpeg-release-essentials.zip'
  if(Test-Path -LiteralPath $zip){
    $extractPy=Join-Path $work 'extract_ffmpeg.py'
    $code=@'
import sys, zipfile, pathlib
zip_path=pathlib.Path(sys.argv[1])
out=pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
try:
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(out)
    print('EXTRACT_OK')
except Exception as e:
    print('EXTRACT_ERR', repr(e))
'@
    [IO.File]::WriteAllText($extractPy,$code,(New-Object Text.UTF8Encoding($false)))
    $pypath=$py; $zp=$zip; $ex=Join-Path $lab 'tools\ffmpeg'
    $exOut=Run-Cap { & $using:pypath $using:extractPy $using:zp $using:ex 2>&1|Out-String } 300
    L ('zip_extract='+(San (($exOut -split "`r?`n"|Select-Object -First 8)-join ' | ')))
    $ffmpeg=Find-Ffmpeg
  }
}

# Robust fallback: install imageio-ffmpeg in user site and ask it for bundled ffmpeg.exe.
if(-not $ffmpeg -and $py){
  $pypath=$py
  $inst=Run-Cap { & $using:pypath -m pip install --user imageio-ffmpeg 2>&1|Out-String } 300
  L ('imageio_ffmpeg_install='+(San (($inst -split "`r?`n"|Select-Object -First 10)-join ' | ')))
  $get=Run-Cap { & $using:pypath -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())" 2>&1|Out-String } 60
  $cand=($get -split "`r?`n" | Where-Object { $_ -match 'ffmpeg' } | Select-Object -Last 1).Trim()
  if($cand -and (Test-Path -LiteralPath $cand)){ $ffmpeg=$cand }
  L ('imageio_ffmpeg_path='+(San $cand))
}
L ('ffmpeg_final='+(San $ffmpeg)+' exists='+(Test-Path -LiteralPath $ffmpeg))

# Make sure builder exists. If missing, copy from task r236 is not possible; fail clearly.
$builder=Join-Path $work 'build_funny_talking_head.py'
L ('builder='+(San $builder)+' exists='+(Test-Path -LiteralPath $builder))
$buildOut=''
if($py -and $ffmpeg -and (Test-Path -LiteralPath $builder)){
  $pypath=$py; $bd=$builder; $pr=$project; $ma=$materials; $wo=$work; $ou=$output; $ff=$ffmpeg
  $buildOut=Run-Cap { & $using:pypath $using:bd --project $using:pr --materials $using:ma --work $using:wo --output $using:ou --ffmpeg $using:ff 2>&1|Out-String } 1000
  L ('build_video_head='+(San (($buildOut -split "`r?`n"|Select-Object -First 20)-join ' | ')))
  L ('build_video_tail='+(San (($buildOut -split "`r?`n"|Select-Object -Last 20)-join ' | ')))
}else{ L 'build_video_skipped=True' }

$video=Join-Path $output 'funny_talking_head_r236.mp4'
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop' }
$desktopVideo=Join-Path $desktop 'jianying_funny_talking_head_r236.mp4'
if(Test-Path -LiteralPath $video){ try{ Copy-Item -LiteralPath $video -Destination $desktopVideo -Force }catch{ L ('desktop_copy_error='+(San $_.Exception.Message)) } }
$videoBytes=0; if(Test-Path -LiteralPath $video){$videoBytes=(Get-Item -LiteralPath $video).Length}
$srt=Join-Path $output 'funny_subtitles.srt'
$scriptFile=Join-Path $project 'script_funny_talking_head.md'
L ('video='+(San $video)+' exists='+(Test-Path -LiteralPath $video)+' bytes='+$videoBytes)
L ('desktop_video='+(San $desktopVideo)+' exists='+(Test-Path -LiteralPath $desktopVideo))
L ('subtitle='+(San $srt)+' exists='+(Test-Path -LiteralPath $srt))
L ('script='+(San $scriptFile)+' exists='+(Test-Path -LiteralPath $scriptFile))
$summaryJson=Join-Path $outDir 'jianying-video-finish-r237.json'
$summary=[pscustomobject]@{ffmpeg=$ffmpeg;python=$py;builder=$builder;video=$video;videoBytes=$videoBytes;desktopVideo=$desktopVideo;subtitle=$srt;script=$scriptFile;output=$output;materials=$materials}
[IO.File]::WriteAllText($summaryJson,($summary|ConvertTo-Json -Depth 6)+"`r`n",(New-Object Text.UTF8Encoding($false)))
$status=if((Test-Path -LiteralPath $video) -and $videoBytes -gt 100000){'JIANYING_FUNNY_VIDEO_READY'}else{'JIANYING_FUNNY_VIDEO_STILL_INCOMPLETE'}
L ('status='+$status)
L ('FINAL_R237: '+$status)
W $report $script:Lines
exit 0
