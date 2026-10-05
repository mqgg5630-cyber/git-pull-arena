# t193_finish_media_career_tools_r242.ps1 - round 242.
# Resume and finish the media/career tool install after round 241 partial success.
# ASCII-only.

$ErrorActionPreference='Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace 'gh[pousr]_[A-Za-z0-9_]+','[REDACTED-GITHUB]'}catch{}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
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
  }catch{ L ('shortcut_error='+$Path+' '+(San $_.Exception.Message)); return $false }
}
function Find-Browser(){
  $pf=[Environment]::GetEnvironmentVariable('ProgramFiles'); $pf86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
  foreach($c in @((Join-Path $pf86 'Microsoft\Edge\Application\msedge.exe'),(Join-Path $pf 'Microsoft\Edge\Application\msedge.exe'),(Join-Path $pf 'Google\Chrome\Application\chrome.exe'),(Join-Path $pf86 'Google\Chrome\Application\chrome.exe'))){ if($c -and (Test-Path -LiteralPath $c)){return $c} }
  return (Find-Cmd @('msedge.exe','chrome.exe'))
}
function Ensure-WebLink([string]$Name,[string]$Slug,[string]$Url,[string]$WebRoot,[string]$Desktop,[string]$Browser){
  $dir=Join-Path $WebRoot $Slug; $profile=Join-Path $dir 'profile'; New-Item -ItemType Directory -Force -Path $profile|Out-Null
  $launcher=Join-Path $dir ('launch-'+$Slug+'.cmd')
  $cmd='@echo off' + "`r`n" + 'start "" "' + $Browser + '" --app="' + $Url + '" --user-data-dir="%~dp0profile" --no-first-run' + "`r`n"
  WriteUtf8 $launcher $cmd
  $lnk=Join-Path $Desktop ($Name+'.lnk')
  if($Browser){ $args='--app="'+$Url+'" --user-data-dir="'+$profile+'" --no-first-run'; New-Link $lnk $Browser $args $dir $Browser ('E-drive web app: '+$Name)|Out-Null }
  else{ New-Link $lnk 'explorer.exe' $Url $dir '' ('Web app: '+$Name)|Out-Null }
  return [pscustomobject]@{name=$Name;dir=$dir;shortcut=$lnk;exists=(Test-Path -LiteralPath $lnk)}
}
function Download-File([string]$Url,[string]$Out){
  $curl=Find-Cmd @('curl.exe','curl')
  if($curl){
    $line='"'+$curl+'" -L --retry 3 -A "Mozilla/5.0" -o "'+$Out+'" "'+$Url+'"'
    return (Run-CmdLine $line '' 600)
  }
  try{ Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='Mozilla/5.0'} -Uri $Url -OutFile $Out; return @{code=0;text='Invoke-WebRequest OK'} }catch{ return @{code=1;text=$_.Exception.Message} }
}
function Ensure-SourceTree([string]$Owner,[string]$RepoName,[string]$Dir,[string]$Git){
  if((Test-Path -LiteralPath (Join-Path $Dir '.git')) -or (Test-Path -LiteralPath (Join-Path $Dir 'README.md')) -or (Test-Path -LiteralPath (Join-Path $Dir 'package.json')) -or (Test-Path -LiteralPath (Join-Path $Dir 'SKILL.md'))){ return @{ok=$true;method='existing';text='existing'} }
  if(Test-Path -LiteralPath $Dir){ try{ Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction Stop }catch{} }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dir)|Out-Null
  $url='https://github.com/'+$Owner+'/'+$RepoName+'.git'
  if($Git){
    $line='"'+$Git+'" clone --depth 1 "'+$url+'" "'+$Dir+'"'
    $gr=Run-CmdLine $line '' 900
    if((Test-Path -LiteralPath (Join-Path $Dir '.git')) -or (Test-Path -LiteralPath (Join-Path $Dir 'README.md'))){ return @{ok=$true;method='git';text=$gr.text;code=$gr.code} }
  }else{ $gr=@{code=127;text='git missing'} }
  $tmpRoot=Join-Path $env:TEMP ('arena-r242-'+$Owner+'-'+$RepoName+'-'+(Get-Date).ToString('yyyyMMddHHmmss'))
  New-Item -ItemType Directory -Force -Path $tmpRoot|Out-Null
  $zip=Join-Path $tmpRoot ($RepoName+'.zip')
  $ok=$false; $method='zip'; $txt=''
  foreach($br in @('main','master')){
    $zurl='https://codeload.github.com/'+$Owner+'/'+$RepoName+'/zip/refs/heads/'+$br
    $dr=Download-File $zurl $zip
    $txt += ' branch='+$br+' code='+$dr.code+' tail='+(TailText (San $dr.text) 5)
    if((Test-Path -LiteralPath $zip) -and ((Get-Item -LiteralPath $zip).Length -gt 1000)){
      try{
        Expand-Archive -LiteralPath $zip -DestinationPath $tmpRoot -Force
        $sub=Get-ChildItem -LiteralPath $tmpRoot -Directory | Where-Object { $_.Name -like ($RepoName+'-*') } | Select-Object -First 1
        if($sub){ Move-Item -LiteralPath $sub.FullName -Destination $Dir -Force; $ok=$true; break }
      }catch{ $txt += ' expand_err='+(San $_.Exception.Message) }
    }
  }
  return @{ok=$ok;method=$method;text=$txt;gitText=$gr.text;gitCode=$gr.code}
}
function Find-Ffmpeg(){
  foreach($n in @('ffmpeg.exe','ffmpeg')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue; if($c){return $c.Source} }catch{} }
  $roots=@('E:\0mcp-agv-arena-optimized\tools\ffmpeg','E:\0mcp-agv-arena-optimized')
  if($env:APPDATA){ $roots += (Join-Path $env:APPDATA 'Python') }
  if($env:LOCALAPPDATA){ $roots += (Join-Path $env:LOCALAPPDATA 'Programs\Python') }
  foreach($root in $roots){ if(Test-Path -LiteralPath $root){ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter ffmpeg*.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){return $f.FullName} } }
  return ''
}
function Find-Python(){ return (Find-Cmd @('python.exe','python','py.exe','py')) }
function Export-IdPhoto([string]$Src,[string]$Out,[int]$W,[int]$H){
  try{
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $img=[System.Drawing.Image]::FromFile($Src); $ratio=[double]$W/[double]$H; $sw=$img.Width; $sh=$img.Height; $cw=$sw; $ch=[int]($sw/$ratio); if($ch -gt $sh){$ch=$sh; $cw=[int]($sh*$ratio)}; $sx=[int](($sw-$cw)/2); $sy=[int](($sh-$ch)/2)
    $bmp=New-Object System.Drawing.Bitmap $W,$H; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic; $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.DrawImage($img,(New-Object System.Drawing.Rectangle 0,0,$W,$H),(New-Object System.Drawing.Rectangle $sx,$sy,$cw,$ch),[System.Drawing.GraphicsUnit]::Pixel); $bmp.Save($Out,[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $img.Dispose(); return $true
  }catch{ L ('id_export_error='+(San $_.Exception.Message)); return $false }
}
function FillRR($G,$Brush,[int]$X,[int]$Y,[int]$W,[int]$H,[int]$R){ $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $d=$R*2; $p.AddArc($X,$Y,$d,$d,180,90); $p.AddArc($X+$W-$d,$Y,$d,$d,270,90); $p.AddArc($X+$W-$d,$Y+$H-$d,$d,$d,0,90); $p.AddArc($X,$Y+$H-$d,$d,$d,90,90); $p.CloseFigure(); $G.FillPath($Brush,$p); $p.Dispose() }
function Build-Video([string]$Photo,[string]$Project,[string]$Ffmpeg){
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $Project|Out-Null
  $frames=Join-Path $Project 'frames'; if(Test-Path -LiteralPath $frames){Remove-Item -LiteralPath $frames -Recurse -Force -ErrorAction SilentlyContinue}; New-Item -ItemType Directory -Force -Path $frames|Out-Null
  $out=Join-Path $Project 'hypit_safe_viral_clone_r242.mp4'; $ref=Join-Path $Project 'reference_viral_template_1to1.json'; $srt=Join-Path $Project 'hypit_safe_viral_clone_r242.srt'
  $w=720; $h=1280; $fps=24; $total=288
  $fmt=New-Object System.Drawing.StringFormat; $fmt.Alignment=[System.Drawing.StringAlignment]::Center; $fmt.LineAlignment=[System.Drawing.StringAlignment]::Center
  $big=New-Object System.Drawing.Font 'Segoe UI',50,[System.Drawing.FontStyle]::Bold; $med=New-Object System.Drawing.Font 'Segoe UI',32,[System.Drawing.FontStyle]::Bold; $small=New-Object System.Drawing.Font 'Segoe UI',24,[System.Drawing.FontStyle]::Regular
  $img=$null; if(Test-Path -LiteralPath $Photo){ try{$img=[System.Drawing.Image]::FromFile($Photo)}catch{} }
  for($i=0;$i -lt $total;$i++){
    $t=[double]$i/[double]$fps; $bmp=New-Object System.Drawing.Bitmap $w,$h; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $bg=New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0,0,$w,$h),([System.Drawing.Color]::FromArgb(255,255,245,250)),([System.Drawing.Color]::FromArgb(255,230,247,255)),90; $g.FillRectangle($bg,0,0,$w,$h); $bg.Dispose()
    $white=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245,255,255,255)); $pink=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,255,126,178)); $blue=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,99,154,255)); $dark=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,45,48,70)); $muted=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,92,96,120))
    $pulse=[int](20*[Math]::Sin($t*3.14159)); $g.FillEllipse($pink,40+$pulse,70,160,160); $g.FillEllipse($blue,520-$pulse,220,120,120); FillRR $g $white 70 90 580 1020 42
    $headline='STOP SCROLLING'; $sub='Cute job kit in 10 seconds'; if($t -ge 2 -and $t -lt 5){$headline='PROFILE PHOTO';$sub='Friendly, clean, professional'}elseif($t -ge 5 -and $t -lt 8){$headline='JOB SEARCH STACK';$sub='AI job search + career ops'}elseif($t -ge 8){$headline='READY ON E DRIVE';$sub='Shortcuts, tools, and demo video'}
    $g.DrawString($headline,$big,$dark,(New-Object System.Drawing.RectangleF 90,130,540,120),$fmt); $g.DrawString($sub,$small,$muted,(New-Object System.Drawing.RectangleF 100,245,520,80),$fmt)
    if($img){ $dest=New-Object System.Drawing.Rectangle 175,360,370,370; $srcSide=[Math]::Min($img.Width,$img.Height); $sx=[int](($img.Width-$srcSide)/2); $sy=[int](($img.Height-$srcSide)/2); $g.DrawImage($img,$dest,(New-Object System.Drawing.Rectangle $sx,$sy,$srcSide,$srcSide),[System.Drawing.GraphicsUnit]::Pixel) } else { $g.FillEllipse($blue,210,390,300,300) }
    $chips=@('1. Make it specific','2. Keep it honest','3. Send, track, improve'); if($t -ge 5){$chips=@('CV fit score','ATS resume','Interview prep')}; if($t -ge 8){$chips=@('Douyin / RED / OA','DeskBox cute layout','Hypit safe clone')}
    for($j=0;$j -lt 3;$j++){ $y=790+$j*82; FillRR $g (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,255,238,247))) 115 $y 490 56 24; $g.DrawString($chips[$j],$small,$dark,(New-Object System.Drawing.RectangleF 130,$y,460,56),$fmt) }
    FillRR $g $pink 120 1060 480 90 35; $cta='SAVE THE TEMPLATE'; if($t -ge 8){$cta='OPEN FROM DESKTOP'}; $g.DrawString($cta,$med,(New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)),(New-Object System.Drawing.RectangleF 130,1060,460,90),$fmt)
    $bmp.Save((Join-Path $frames ('frame_'+$i.ToString('0000')+'.png')),[System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
  }
  if($img){$img.Dispose()}; $big.Dispose(); $med.Dispose(); $small.Dispose(); $fmt.Dispose()
  WriteUtf8 $ref '{"name":"safe_viral_template_1to1","resolution":"720x1280","fps":24,"duration_seconds":12,"scene_cut_frames":[0,48,120,192,288],"note":"Non-infringing structural remake."}'
  WriteUtf8 $srt "1`r`n00:00:00,000 --> 00:00:02,000`r`nSTOP SCROLLING`r`n`r`n2`r`n00:00:02,000 --> 00:00:05,000`r`nPROFILE PHOTO`r`n`r`n3`r`n00:00:05,000 --> 00:00:08,000`r`nJOB SEARCH STACK`r`n`r`n4`r`n00:00:08,000 --> 00:00:12,000`r`nREADY ON E DRIVE`r`n"
  $line='"'+$Ffmpeg+'" -y -framerate 24 -i "'+(Join-Path $frames 'frame_%04d.png')+'" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -shortest -t 12 -c:v libx264 -pix_fmt yuv420p -r 24 "'+$out+'"'
  $r=Run-CmdLine $line '' 900; $bytes=0; if(Test-Path -LiteralPath $out){$bytes=(Get-Item -LiteralPath $out).Length}
  return [pscustomobject]@{video=$out;reference=$ref;srt=$srt;frames=$frames;code=$r.code;text=$r.text;bytes=$bytes;exists=(Test-Path -LiteralPath $out)}
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R242_FINISH_MEDIA_CAREER_TOOLS.md'; $jsonReport=Join-Path $outDir 'r242-finish-media-career-tools.json'
$lab='E:\0mcp-agv-arena-optimized'; $appsRoot=Join-Path $lab 'apps'; $webRoot=Join-Path $appsRoot 'web-apps'; $toolsRoot=Join-Path $lab 'tools'; $skillsRoot=Join-Path $lab 'skills'; $careerRoot=Join-Path $lab 'career'; $videoRoot=Join-Path $lab 'video'; $imageRoot=Join-Path $lab 'images\career-id-photo'; $installerRoot=Join-Path $lab 'installers\r242'
foreach($d in @($appsRoot,$webRoot,$toolsRoot,$skillsRoot,$careerRoot,$videoRoot,$imageRoot,$installerRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
L '# R242 finish media/career tools'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('desktop_dir='+$desktop)
L ('e_root='+$lab)

$browser=Find-Browser; L ('browser='+$browser)
$webApps=@(); $webApps += Ensure-WebLink 'Douyin' 'douyin' 'https://www.douyin.com/' $webRoot $desktop $browser; $webApps += Ensure-WebLink 'Xiaohongshu' 'xiaohongshu' 'https://www.xiaohongshu.com/' $webRoot $desktop $browser; $webApps += Ensure-WebLink 'WeChat Official Account' 'wechat-official-account' 'https://mp.weixin.qq.com/' $webRoot $desktop $browser; $webApps += Ensure-WebLink 'Jianying' 'jianying' 'https://www.capcut.cn/' $webRoot $desktop $browser
foreach($wa in $webApps){ L ('web_app_'+$wa.name+'_dir='+$wa.dir); L ('web_app_'+$wa.name+'_shortcut='+$wa.shortcut+' exists='+$wa.exists) }

$deskboxDir=Join-Path $appsRoot 'DeskBox'; $deskboxExe=''; $deskboxInstaller=''
try{ $f=Get-ChildItem -LiteralPath $deskboxDir -Recurse -Filter DeskBox.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){$deskboxExe=$f.FullName} }catch{}
if(-not $deskboxExe){
  foreach($u in @('https://github.com/Tianyu199509/DeskBox/releases/download/v1.5.2/DeskBox_Setup_1.5.2_x64.exe','https://github.com/Tianyu199509/DeskBox/releases/download/v1.5.0/DeskBox_Setup_1.5.0_x64.exe')){
    $name=($u -split '/')[-1]; $out=Join-Path $installerRoot $name; $dr=Download-File $u $out; L ('deskbox_download_'+$name+'_exit='+$dr.code); L ('deskbox_download_'+$name+'_tail='+(TailText (San $dr.text) 5))
    if((Test-Path -LiteralPath $out) -and ((Get-Item -LiteralPath $out).Length -gt 1000000)){ $deskboxInstaller=$out; break }
  }
  if($deskboxInstaller){ $line='"'+$deskboxInstaller+'" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER /DIR="'+$deskboxDir+'"'; $ir=Run-CmdLine $line '' 900; L ('deskbox_install_exit='+$ir.code); L ('deskbox_install_tail='+(TailText (San $ir.text) 8)); try{ $f=Get-ChildItem -LiteralPath $deskboxDir -Recurse -Filter DeskBox.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){$deskboxExe=$f.FullName} }catch{} }
}
$deskboxShortcut=Join-Path $desktop 'DeskBox Cute.lnk'; if($deskboxExe){New-Link $deskboxShortcut $deskboxExe '' (Split-Path -Parent $deskboxExe) $deskboxExe 'DeskBox cute desktop organizer'|Out-Null}elseif($deskboxInstaller){New-Link $deskboxShortcut $deskboxInstaller '' $installerRoot $deskboxInstaller 'DeskBox installer'|Out-Null}else{New-Link $deskboxShortcut 'explorer.exe' (Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer') $desktop '' 'DeskBox organizer folder'|Out-Null}
L ('deskbox_dir='+$deskboxDir); L ('deskbox_installer='+$deskboxInstaller+' exists='+($deskboxInstaller -and (Test-Path -LiteralPath $deskboxInstaller))); L ('deskbox_exe='+$deskboxExe+' exists='+($deskboxExe -and (Test-Path -LiteralPath $deskboxExe))); L ('deskbox_shortcut='+$deskboxShortcut+' exists='+(Test-Path -LiteralPath $deskboxShortcut))

$assetSrc=Join-Path $repo 'deliverable\assets\cute_professional_id_photo.png'; $origPhoto=Join-Path $imageRoot 'cute_professional_id_photo_original.png'; $id295=Join-Path $imageRoot 'career_id_photo_295x413.png'; $id413=Join-Path $imageRoot 'career_id_photo_413x579.png'; $desktopPhoto=Join-Path $desktop 'cute_professional_id_photo_295x413.png'
if((Test-Path -LiteralPath $assetSrc) -and -not(Test-Path -LiteralPath $origPhoto)){Copy-Item -LiteralPath $assetSrc -Destination $origPhoto -Force}
if((Test-Path -LiteralPath $origPhoto) -and -not(Test-Path -LiteralPath $id295)){Export-IdPhoto $origPhoto $id295 295 413|Out-Null}
if((Test-Path -LiteralPath $origPhoto) -and -not(Test-Path -LiteralPath $id413)){Export-IdPhoto $origPhoto $id413 413 579|Out-Null}
if(Test-Path -LiteralPath $id295){Copy-Item -LiteralPath $id295 -Destination $desktopPhoto -Force}
L ('photo_original='+$origPhoto+' exists='+(Test-Path -LiteralPath $origPhoto)); L ('photo_id_295='+$id295+' exists='+(Test-Path -LiteralPath $id295)); L ('photo_id_413='+$id413+' exists='+(Test-Path -LiteralPath $id413)); L ('photo_desktop_copy='+$desktopPhoto+' exists='+(Test-Path -LiteralPath $desktopPhoto))

$git=Find-Cmd @('git.exe','git'); L ('git='+$git)
$xiutuDir=Join-Path $skillsRoot 'xiutu.skill'; $xiutu=Ensure-SourceTree 'Chase-qisiai' 'xiutu.skill' $xiutuDir $git; L ('xiutu_source_ok='+$xiutu.ok); L ('xiutu_method='+$xiutu.method); L ('xiutu_tail='+(TailText (San ($xiutu.text+' '+$xiutu.gitText)) 8)); L ('xiutu_dir='+$xiutuDir+' exists='+(Test-Path -LiteralPath $xiutuDir)); New-Link (Join-Path $desktop 'xiutu.skill.lnk') 'explorer.exe' ('"'+$xiutuDir+'"') $xiutuDir '' 'Open xiutu.skill'|Out-Null
$aiJobDir=Join-Path $careerRoot 'ai-job-search'; $aiJob=Ensure-SourceTree 'MadsLorentzen' 'ai-job-search' $aiJobDir $git; L ('ai_job_search_source_ok='+$aiJob.ok); L ('ai_job_search_method='+$aiJob.method); L ('ai_job_search_tail='+(TailText (San ($aiJob.text+' '+$aiJob.gitText)) 8)); L ('ai_job_search_dir='+$aiJobDir+' exists='+(Test-Path -LiteralPath $aiJobDir)); New-Link (Join-Path $desktop 'AI Job Search.lnk') 'explorer.exe' ('"'+$aiJobDir+'"') $aiJobDir '' 'Open ai-job-search'|Out-Null
$careerOpsDir=Join-Path $careerRoot 'career-ops'; $careerOps=Ensure-SourceTree 'career-ops-hq' 'career-ops' $careerOpsDir $git; L ('career_ops_source_ok='+$careerOps.ok); L ('career_ops_method='+$careerOps.method); L ('career_ops_tail='+(TailText (San ($careerOps.text+' '+$careerOps.gitText)) 8)); L ('career_ops_dir='+$careerOpsDir+' exists='+(Test-Path -LiteralPath $careerOpsDir)); New-Link (Join-Path $desktop 'Career Ops.lnk') 'explorer.exe' ('"'+$careerOpsDir+'"') $careerOpsDir '' 'Open career-ops'|Out-Null
$hypitDir=Join-Path $videoRoot 'hypit'; $hypit=Ensure-SourceTree 'hypit-ai' 'hypit' $hypitDir $git; L ('hypit_source_ok='+$hypit.ok); L ('hypit_method='+$hypit.method); L ('hypit_tail='+(TailText (San ($hypit.text+' '+$hypit.gitText)) 8)); L ('hypit_repo_dir='+$hypitDir+' exists='+(Test-Path -LiteralPath $hypitDir)); New-Link (Join-Path $desktop 'Hypit.lnk') 'explorer.exe' ('"'+$hypitDir+'"') $hypitDir '' 'Open hypit'|Out-Null

$node=Find-Cmd @('node.exe','node'); $npm=Find-Cmd @('npm.cmd','npm'); L ('node='+$node); try{if($node){L ('node_version='+((& $node -v 2>$null|Select-Object -First 1)))}}catch{}; L ('npm='+$npm)
if($npm -and (Test-Path -LiteralPath (Join-Path $careerOpsDir 'package.json'))){$nr=Run-CmdLine ('"'+$npm+'" install --no-audit --fund=false') $careerOpsDir 900; L ('career_ops_npm_install_exit='+$nr.code); L ('career_ops_npm_install_tail='+(TailText (San $nr.text) 8))}else{L 'career_ops_npm_install_skipped=True'}
$hypitLocal=Join-Path $toolsRoot 'hypit-npm-package'; if($npm){New-Item -ItemType Directory -Force -Path $hypitLocal|Out-Null; $hr=Run-CmdLine ('"'+$npm+'" install --prefix "'+$hypitLocal+'" @hypit/hypit@latest --no-audit --fund=false') '' 900; L ('hypit_npm_local_install_exit='+$hr.code); L ('hypit_npm_local_install_tail='+(TailText (San $hr.text) 8))}else{L 'hypit_npm_local_install_skipped=True'}
$hypitPkg=Join-Path $hypitLocal 'node_modules\@hypit\hypit\package.json'; L ('hypit_npm_package='+$hypitPkg+' exists='+(Test-Path -LiteralPath $hypitPkg))

$ffmpeg=Find-Ffmpeg; $py=Find-Python; L ('ffmpeg_initial='+$ffmpeg); L ('python='+$py)
if(-not $ffmpeg -and $py){ $pr=Run-CmdLine ('"'+$py+'" -m pip install --user imageio-ffmpeg') '' 420; L ('imageio_install_exit='+$pr.code); L ('imageio_install_tail='+(TailText (San $pr.text) 8)); $gr=Run-CmdLine ('"'+$py+'" -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"') '' 120; L ('imageio_get_exit='+$gr.code); L ('imageio_get_tail='+(TailText (San $gr.text) 8)); $sel=($gr.text -split "`r?`n" | Where-Object { $_ -match 'ffmpeg' } | Select-Object -Last 1); if($sel){$cand=[string]$sel; $cand=$cand.Trim(); if(Test-Path -LiteralPath $cand){$ffmpeg=$cand}} }
if(-not $ffmpeg){$ffmpeg=Find-Ffmpeg}
L ('ffmpeg_final='+$ffmpeg+' exists='+($ffmpeg -and (Test-Path -LiteralPath $ffmpeg)))
$hypitProject=Join-Path $videoRoot 'hypit-safe-viral-clone-r242'; $videoObj=$null
if($ffmpeg -and (Test-Path -LiteralPath $origPhoto)){ $videoObj=Build-Video $origPhoto $hypitProject $ffmpeg; L ('hypit_safe_clone_video='+$videoObj.video); L ('hypit_safe_clone_video_exists='+$videoObj.exists); L ('hypit_safe_clone_video_bytes='+$videoObj.bytes); L ('hypit_safe_clone_reference='+$videoObj.reference); L ('hypit_safe_clone_ffmpeg_exit='+$videoObj.code); L ('hypit_safe_clone_ffmpeg_tail='+(TailText (San $videoObj.text) 8)) }else{ L 'hypit_safe_clone_video_skipped=True' }
$desktopVideo=Join-Path $desktop 'hypit_safe_viral_clone_r242.mp4'; if($videoObj -and (Test-Path -LiteralPath $videoObj.video)){Copy-Item -LiteralPath $videoObj.video -Destination $desktopVideo -Force}; L ('hypit_safe_clone_desktop_video='+$desktopVideo+' exists='+(Test-Path -LiteralPath $desktopVideo))

$summaryFolder=Join-Path $lab 'r241-paths-and-tools'; New-Item -ItemType Directory -Force -Path $summaryFolder|Out-Null; $pathsTxt=Join-Path $summaryFolder 'PATHS.txt'; $openAll=Join-Path $desktop 'R241 Paths and Tools.lnk'; New-Link $openAll 'explorer.exe' ('"'+$summaryFolder+'"') $summaryFolder '' 'Open paths summary'|Out-Null
$pathLines=@('E root: '+$lab,'Desktop organizer: '+(Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'),'DeskBox: '+$deskboxDir,'DeskBox installer: '+$deskboxInstaller,'DeskBox exe: '+$deskboxExe,'Web apps: '+$webRoot,'Photo folder: '+$imageRoot,'Xiutu skill: '+$xiutuDir,'AI Job Search: '+$aiJobDir,'Career Ops: '+$careerOpsDir,'Hypit repo: '+$hypitDir,'Hypit npm package: '+$hypitLocal,'Hypit demo project: '+$hypitProject,'Hypit demo video: '+$(if($videoObj){$videoObj.video}else{''}),'Desktop video: '+$desktopVideo,'Desktop photo: '+$desktopPhoto)
WriteUtf8 $pathsTxt (($pathLines -join "`r`n")+"`r`n"); L ('paths_summary='+$pathsTxt); L ('paths_shortcut='+$openAll+' exists='+(Test-Path -LiteralPath $openAll))

$shortcutOk=$true; foreach($wa in $webApps){if(-not(Test-Path -LiteralPath $wa.shortcut)){$shortcutOk=$false}}
$deskboxOk=(Test-Path -LiteralPath $deskboxShortcut)
$deskboxInstallOk=(($deskboxExe -and (Test-Path -LiteralPath $deskboxExe)) -or ($deskboxInstaller -and (Test-Path -LiteralPath $deskboxInstaller)))
$xiutuOk=(Test-Path -LiteralPath $xiutuDir) -and ((Test-Path -LiteralPath (Join-Path $xiutuDir 'SKILL.md')) -or (Test-Path -LiteralPath (Join-Path $xiutuDir 'README.md')))
$aiJobOk=(Test-Path -LiteralPath $aiJobDir) -and ((Test-Path -LiteralPath (Join-Path $aiJobDir 'README.md')) -or (Test-Path -LiteralPath (Join-Path $aiJobDir '.agents')))
$careerOk=(Test-Path -LiteralPath $careerOpsDir) -and ((Test-Path -LiteralPath (Join-Path $careerOpsDir 'package.json')) -or (Test-Path -LiteralPath (Join-Path $careerOpsDir 'README.md')))
$hypitOk=(Test-Path -LiteralPath $hypitDir) -and ((Test-Path -LiteralPath (Join-Path $hypitDir 'package.json')) -or (Test-Path -LiteralPath (Join-Path $hypitDir 'README.md')))
$photoOk=(Test-Path -LiteralPath $id295) -and (Test-Path -LiteralPath $id413)
$videoOk=$false; if($videoObj){$videoOk=((Test-Path -LiteralPath $videoObj.video) -and ([int64]$videoObj.bytes -gt 100000))}
$hypitNpmOk=Test-Path -LiteralPath $hypitPkg
L ('web_shortcuts_ok='+$shortcutOk); L ('deskbox_shortcut_ok='+$deskboxOk); L ('deskbox_install_artifact_ok='+$deskboxInstallOk); L ('xiutu_dir_exists='+$xiutuOk); L ('ai_job_search_dir_exists='+$aiJobOk); L ('career_ops_dir_exists='+$careerOk); L ('hypit_repo_dir_exists='+$hypitOk); L ('hypit_npm_package_exists='+$hypitNpmOk); L ('id_photo_295_exists='+(Test-Path -LiteralPath $id295)); L ('hypit_safe_clone_video_exists='+$videoOk)
$ready=($shortcutOk -and $deskboxOk -and $xiutuOk -and $aiJobOk -and $careerOk -and $hypitOk -and $photoOk -and $videoOk)
L ('R242_MEDIA_CAREER_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;desktop=$desktop;eRoot=$lab;webApps=$webApps;deskboxDir=$deskboxDir;deskboxInstaller=$deskboxInstaller;deskboxExe=$deskboxExe;deskboxShortcut=$deskboxShortcut;photoOriginal=$origPhoto;photo295=$id295;photo413=$id413;desktopPhoto=$desktopPhoto;xiutuDir=$xiutuDir;aiJobSearchDir=$aiJobDir;careerOpsDir=$careerOpsDir;hypitDir=$hypitDir;hypitNpmPackage=$hypitPkg;hypitProject=$hypitProject;hypitVideo=$($videoObj.video);desktopVideo=$desktopVideo;pathsSummary=$pathsTxt;pathsShortcut=$openAll}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){exit 6}
exit 0
