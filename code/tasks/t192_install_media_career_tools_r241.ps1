# t192_install_media_career_tools_r241.ps1 - round 241.
# Install E-drive app launchers, DeskBox, requested GitHub tools, a job ID photo,
# and a safe viral-style Hypit demo video. ASCII-only.

$ErrorActionPreference='Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function San([string]$s){
  if($null -eq $s){ return '' }
  try{ $s=$s -replace 'ya29\.[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]' }catch{}
  try{ $s=$s -replace '1//[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]' }catch{}
  try{ $s=$s -replace 'gh[pousr]_[A-Za-z0-9_]+','[REDACTED-GITHUB]' }catch{}
  try{ $s=$s -replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]' }catch{}
  return $s
}
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function Find-Cmd([string[]]$Names){
  foreach($n in $Names){
    try{ $c=Get-Command $n -ErrorAction SilentlyContinue; if($c){ return $c.Source } }catch{}
  }
  return ''
}
function Run-Exe([string]$Exe,[string[]]$Args,[string]$Cwd,[int]$TimeoutSec){
  if(-not $Exe){ return @{code=127;text='missing exe'} }
  $job=Start-Job -ScriptBlock {
    param($e,$a,$w)
    if($w -and (Test-Path -LiteralPath $w)){ Set-Location -LiteralPath $w }
    & $e @a 2>&1 | Out-String
    $c=$LASTEXITCODE
    if($null -eq $c){ $c=0 }
    Write-Output ('===EXITCODE:'+[string]$c)
  } -ArgumentList $Exe,$Args,$Cwd
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
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){
  $job=Start-Job -ScriptBlock $Block
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
function Escape-PS([string]$s){ return ($s -replace "'","''") }
function New-Link([string]$Path,[string]$Target,[string]$Arguments,[string]$WorkingDirectory,[string]$IconLocation,[string]$Description){
  try{
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null
    $ws=New-Object -ComObject WScript.Shell
    $sc=$ws.CreateShortcut($Path)
    $sc.TargetPath=$Target
    if($Arguments){ $sc.Arguments=$Arguments }
    if($WorkingDirectory){ $sc.WorkingDirectory=$WorkingDirectory }
    if($IconLocation){ $sc.IconLocation=$IconLocation }
    if($Description){ $sc.Description=$Description }
    $sc.Save()
    return $true
  }catch{
    L ('shortcut_error path='+$Path+' msg='+(San $_.Exception.Message))
    return $false
  }
}
function Find-Browser(){
  $pf=[Environment]::GetEnvironmentVariable('ProgramFiles')
  $pf86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
  $cands=@()
  if($pf86){ $cands += (Join-Path $pf86 'Microsoft\Edge\Application\msedge.exe') }
  if($pf){ $cands += (Join-Path $pf 'Microsoft\Edge\Application\msedge.exe') }
  if($pf){ $cands += (Join-Path $pf 'Google\Chrome\Application\chrome.exe') }
  if($pf86){ $cands += (Join-Path $pf86 'Google\Chrome\Application\chrome.exe') }
  foreach($c in $cands){ if($c -and (Test-Path -LiteralPath $c)){ return $c } }
  $cmd=Find-Cmd @('msedge.exe','chrome.exe')
  if($cmd){ return $cmd }
  return ''
}
function Install-WebApp([string]$Name,[string]$Slug,[string]$Url,[string]$WebRoot,[string]$Desktop,[string]$CuteLinks,[string]$Browser){
  $dir=Join-Path $WebRoot $Slug
  $profile=Join-Path $dir 'profile'
  New-Item -ItemType Directory -Force -Path $profile|Out-Null
  $launcher=Join-Path $dir ('launch-'+$Slug+'.cmd')
  if($Browser){
    $cmd='@echo off' + "`r`n" + 'start "" "' + $Browser + '" --app="' + $Url + '" --user-data-dir="%~dp0profile" --no-first-run' + "`r`n"
  }else{
    $cmd='@echo off' + "`r`n" + 'start "" "' + $Url + '"' + "`r`n"
  }
  WriteUtf8 $launcher $cmd
  $desktopLink=Join-Path $Desktop ($Name+'.lnk')
  $cuteLink=Join-Path $CuteLinks ($Name+'.lnk')
  if($Browser){
    $args='--app="'+$Url+'" --user-data-dir="'+$profile+'" --no-first-run'
    New-Link $desktopLink $Browser $args $dir $Browser ('E-drive web app: '+$Name)|Out-Null
    New-Link $cuteLink $Browser $args $dir $Browser ('E-drive web app: '+$Name)|Out-Null
  }else{
    New-Link $desktopLink 'explorer.exe' $Url $dir '' ('Web app: '+$Name)|Out-Null
    New-Link $cuteLink 'explorer.exe' $Url $dir '' ('Web app: '+$Name)|Out-Null
  }
  return [pscustomobject]@{name=$Name;url=$Url;dir=$dir;profile=$profile;launcher=$launcher;desktopShortcut=$desktopLink;cuteShortcut=$cuteLink;exists=(Test-Path -LiteralPath $desktopLink)}
}
function Ensure-GitRepo([string]$Url,[string]$Dir,[string]$Git){
  if(-not $Git){ return @{ok=$false;text='git missing'} }
  if(Test-Path -LiteralPath (Join-Path $Dir '.git')){
    $r=Run-Exe $Git @('-C',$Dir,'pull','--ff-only') '' 420
    return @{ok=(Test-Path -LiteralPath (Join-Path $Dir '.git'));text=$r.text;code=$r.code}
  }
  if(Test-Path -LiteralPath $Dir){
    $bak=$Dir+'.bak-'+(Get-Date).ToString('yyyyMMddHHmmss')
    try{ Rename-Item -LiteralPath $Dir -NewName (Split-Path -Leaf $bak) -ErrorAction Stop }catch{}
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dir)|Out-Null
  $r=Run-Exe $Git @('clone',$Url,$Dir) '' 900
  return @{ok=(Test-Path -LiteralPath (Join-Path $Dir '.git'));text=$r.text;code=$r.code}
}
function Find-Ffmpeg(){
  foreach($n in @('ffmpeg.exe','ffmpeg')){ try{ $cmd=Get-Command $n -ErrorAction SilentlyContinue; if($cmd){return $cmd.Source} }catch{} }
  foreach($root in @('E:\0mcp-agv-arena-optimized\tools\ffmpeg','E:\0mcp-agv-arena-optimized','C:\ffmpeg')){
    if(Test-Path -LiteralPath $root){
      $f=Get-ChildItem -LiteralPath $root -Recurse -Filter ffmpeg.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
      if($f){ return $f.FullName }
    }
  }
  return ''
}
function Find-Python(){ return (Find-Cmd @('python.exe','python','py.exe','py')) }
function Test-NodeOk([string]$NodePath){
  if(-not $NodePath){ return $false }
  try{
    $v=(& $NodePath -v 2>$null | Select-Object -First 1)
    if($v -match '^v(\d+)\.(\d+)\.(\d+)'){
      $maj=[int]$Matches[1]; $min=[int]$Matches[2]
      if($maj -gt 22){ return $true }
      if($maj -eq 22 -and $min -ge 15){ return $true }
    }
  }catch{}
  return $false
}
function Find-NodePair(){
  $node=Find-Cmd @('node.exe','node')
  $npm=Find-Cmd @('npm.cmd','npm')
  return @{node=$node;npm=$npm}
}
function Ensure-Node([string]$ToolsRoot){
  $pair=Find-NodePair
  if((Test-NodeOk $pair.node) -and $pair.npm){ return $pair }
  $nodeHome=Join-Path $ToolsRoot 'nodejs'
  New-Item -ItemType Directory -Force -Path $nodeHome|Out-Null
  $existing=Get-ChildItem -LiteralPath $nodeHome -Recurse -Filter node.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if($existing){
    $dir=Split-Path -Parent $existing.FullName
    $env:Path=$dir+';'+$env:Path
    $pair=Find-NodePair
    if((Test-NodeOk $pair.node) -and $pair.npm){ return $pair }
  }
  try{
    $idx=Invoke-RestMethod -UseBasicParsing -Headers @{'User-Agent'='Arena-Agent'} -Uri 'https://nodejs.org/dist/index.json'
    $sel=$idx | Where-Object { $_.version -like 'v22.*' -and ($_.files -contains 'win-x64-zip') } | Select-Object -First 1
    if($sel){
      $ver=[string]$sel.version
      $zip=Join-Path $nodeHome ('node-'+$ver+'-win-x64.zip')
      $url='https://nodejs.org/dist/'+$ver+'/node-'+$ver+'-win-x64.zip'
      if(-not(Test-Path -LiteralPath $zip)){ Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip }
      Expand-Archive -LiteralPath $zip -DestinationPath $nodeHome -Force
      $nodeExe=Get-ChildItem -LiteralPath $nodeHome -Recurse -Filter node.exe -File -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
      if($nodeExe){
        $dir=Split-Path -Parent $nodeExe.FullName
        $env:Path=$dir+';'+$env:Path
      }
    }
  }catch{
    L ('node_download_error='+(San $_.Exception.Message))
  }
  return (Find-NodePair)
}
function Organize-Desktop([string]$Desktop){
  $org=Join-Path $Desktop 'DeskBox-Cute-Desktop-Organizer'
  $folders=@('01-Apps-Shortcuts','02-Job-Tools','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc')
  foreach($f in $folders){ New-Item -ItemType Directory -Force -Path (Join-Path $org $f)|Out-Null }
  $moves=@()
  $restore=@('# restore desktop moves generated by Arena round 241')
  $skip=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer')
  $items=Get-ChildItem -LiteralPath $Desktop -Force -ErrorAction SilentlyContinue
  foreach($it in $items){
    if($skip -contains $it.Name){ continue }
    if(($it.Attributes -band [IO.FileAttributes]::System) -or ($it.Attributes -band [IO.FileAttributes]::Hidden)){ continue }
    $cat='08-Misc'
    if($it.PSIsContainer){ $cat='07-Old-Folders' }
    else{
      $ext=$it.Extension.ToLowerInvariant()
      if($ext -in @('.lnk','.url','.cmd','.bat','.ps1')){ $cat='01-Apps-Shortcuts' }
      elseif($ext -in @('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.txt','.md','.csv')){ $cat='05-Documents' }
      elseif($ext -in @('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')){ $cat='04-Images-ID-Photos' }
      elseif($ext -in @('.mp4','.mov','.mkv','.avi','.srt')){ $cat='03-Video-Creation' }
      elseif($ext -in @('.zip','.rar','.7z','.exe','.msi','.msix','.appx')){ $cat='06-Archives-Installers' }
    }
    $destDir=Join-Path $org $cat
    $dest=Join-Path $destDir $it.Name
    $n=1
    while(Test-Path -LiteralPath $dest){
      $base=[IO.Path]::GetFileNameWithoutExtension($it.Name); $ext2=[IO.Path]::GetExtension($it.Name)
      $dest=Join-Path $destDir ($base+'_'+$n+$ext2); $n++
    }
    try{
      Move-Item -LiteralPath $it.FullName -Destination $dest -Force -ErrorAction Stop
      $moves += ($it.FullName+' -> '+$dest)
      $restore += ('if(Test-Path -LiteralPath '''+(Escape-PS $dest)+'''){ Move-Item -LiteralPath '''+(Escape-PS $dest)+''' -Destination '''+(Escape-PS $it.FullName)+''' -Force }')
    }catch{
      $moves += ('MOVE_ERR '+$it.FullName+' '+(San $_.Exception.Message))
    }
  }
  $manifest=Join-Path $org 'MOVE_MANIFEST.txt'
  WriteUtf8 $manifest (($moves -join "`r`n")+"`r`n")
  $restorePath=Join-Path $org 'RESTORE_MOVES.ps1'
  WriteUtf8 $restorePath (($restore -join "`r`n")+"`r`n")
  $html=Join-Path $org 'cute_desktop_dashboard.html'
  $htmlText=@'
<!doctype html><meta charset="utf-8"><title>Cute Desktop Organizer</title>
<style>body{font-family:Segoe UI,Arial;background:linear-gradient(135deg,#fff3f8,#e9f7ff);color:#333;padding:32px}h1{color:#e86aa5}.card{background:white;border-radius:22px;padding:18px;margin:14px;box-shadow:0 8px 24px #0001}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px}a{color:#4776d0;font-weight:700}</style>
<h1>&#x1F338; DeskBox Cute Desktop Organizer</h1><p>Pastel folders prepared for DeskBox or manual use. Nothing was deleted; moved items are listed in MOVE_MANIFEST.txt and can be restored with RESTORE_MOVES.ps1.</p>
<div class="grid"><div class="card">Apps and shortcuts</div><div class="card">Job tools</div><div class="card">Video creation</div><div class="card">Images and ID photos</div><div class="card">Documents</div><div class="card">Archives and installers</div></div>
'@
  WriteUtf8 $html $htmlText
  return [pscustomobject]@{dir=$org;manifest=$manifest;restore=$restorePath;dashboard=$html;moved=$moves.Count}
}
function Export-IdPhoto([string]$Src,[string]$Out,[int]$W,[int]$H){
  try{
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $img=[System.Drawing.Image]::FromFile($Src)
    $ratio=[double]$W/[double]$H
    $sw=$img.Width; $sh=$img.Height
    $cropW=$sw; $cropH=[int]($sw/$ratio)
    if($cropH -gt $sh){ $cropH=$sh; $cropW=[int]($sh*$ratio) }
    $sx=[int](($sw-$cropW)/2); $sy=[int](($sh-$cropH)/2)
    $bmp=New-Object System.Drawing.Bitmap $W,$H
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $dest=New-Object System.Drawing.Rectangle 0,0,$W,$H
    $srcRect=New-Object System.Drawing.Rectangle $sx,$sy,$cropW,$cropH
    $g.DrawImage($img,$dest,$srcRect,[System.Drawing.GraphicsUnit]::Pixel)
    $bmp.Save($Out,[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $img.Dispose()
    return $true
  }catch{
    L ('id_photo_export_error='+(San $_.Exception.Message))
    return $false
  }
}
function Fill-RoundedRect($G,$Brush,[int]$X,[int]$Y,[int]$W,[int]$H,[int]$R){
  $path=New-Object System.Drawing.Drawing2D.GraphicsPath
  $d=$R*2
  $path.AddArc($X,$Y,$d,$d,180,90)
  $path.AddArc($X+$W-$d,$Y,$d,$d,270,90)
  $path.AddArc($X+$W-$d,$Y+$H-$d,$d,$d,0,90)
  $path.AddArc($X,$Y+$H-$d,$d,$d,90,90)
  $path.CloseFigure()
  $G.FillPath($Brush,$path)
  $path.Dispose()
}
function Build-SafeViralVideo([string]$Photo,[string]$ProjectDir,[string]$Ffmpeg){
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $ProjectDir|Out-Null
  $frames=Join-Path $ProjectDir 'frames'
  $out=Join-Path $ProjectDir 'hypit_safe_viral_clone_r241.mp4'
  $srt=Join-Path $ProjectDir 'hypit_safe_viral_clone_r241.srt'
  $ref=Join-Path $ProjectDir 'reference_viral_template_1to1.json'
  if(Test-Path -LiteralPath $frames){ Remove-Item -LiteralPath $frames -Recurse -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Force -Path $frames|Out-Null
  $w=720; $h=1280; $fps=24; $dur=12; $total=$fps*$dur
  $fontBig=New-Object System.Drawing.Font 'Segoe UI',52,[System.Drawing.FontStyle]::Bold
  $fontMed=New-Object System.Drawing.Font 'Segoe UI',34,[System.Drawing.FontStyle]::Bold
  $fontSmall=New-Object System.Drawing.Font 'Segoe UI',24,[System.Drawing.FontStyle]::Regular
  $fmt=New-Object System.Drawing.StringFormat
  $fmt.Alignment=[System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment=[System.Drawing.StringAlignment]::Center
  $photoImg=$null
  if(Test-Path -LiteralPath $Photo){ try{ $photoImg=[System.Drawing.Image]::FromFile($Photo) }catch{} }
  for($i=0;$i -lt $total;$i++){
    $t=[double]$i/[double]$fps
    $bmp=New-Object System.Drawing.Bitmap $w,$h
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $bg=New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0,0,$w,$h), ([System.Drawing.Color]::FromArgb(255,255,245,250)), ([System.Drawing.Color]::FromArgb(255,230,247,255)), 90
    $g.FillRectangle($bg,0,0,$w,$h)
    $bg.Dispose()
    $pink=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,255,126,178))
    $blue=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,99,154,255))
    $white=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245,255,255,255))
    $dark=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,45,48,70))
    $muted=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,92,96,120))
    $pulse=[int](20*[Math]::Sin($t*3.14159))
    $g.FillEllipse($pink,40+$pulse,70,160,160)
    $g.FillEllipse($blue,520-$pulse,220,120,120)
    Fill-RoundedRect $g $white 70 90 580 1020 42
    $headline='STOP SCROLLING'
    $sub='Cute job kit in 10 seconds'
    if($t -ge 2 -and $t -lt 5){ $headline='PROFILE PHOTO'; $sub='Friendly, clean, professional' }
    elseif($t -ge 5 -and $t -lt 8){ $headline='JOB SEARCH STACK'; $sub='AI job search + career ops' }
    elseif($t -ge 8){ $headline='READY ON E DRIVE'; $sub='Shortcuts, tools, and demo video' }
    $rect1=New-Object System.Drawing.RectangleF 90,130,540,120
    $g.DrawString($headline,$fontBig,$dark,$rect1,$fmt)
    $rect2=New-Object System.Drawing.RectangleF 100,245,520,80
    $g.DrawString($sub,$fontSmall,$muted,$rect2,$fmt)
    if($photoImg){
      $card=New-Object System.Drawing.Rectangle 175,360,370,370
      $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,235,243,255))),155,340,410,410)
      $srcW=$photoImg.Width; $srcH=$photoImg.Height; $side=[Math]::Min($srcW,$srcH); $sx=[int](($srcW-$side)/2); $sy=[int](($srcH-$side)/2)
      $srcR=New-Object System.Drawing.Rectangle $sx,$sy,$side,$side
      $g.DrawImage($photoImg,$card,$srcR,[System.Drawing.GraphicsUnit]::Pixel)
    }else{
      $g.FillEllipse($blue,210,390,300,300)
    }
    $chips=@('1. Make it specific','2. Keep it honest','3. Send, track, improve')
    if($t -ge 5){ $chips=@('CV fit score','ATS resume','Interview prep') }
    if($t -ge 8){ $chips=@('Douyin / RED / OA','DeskBox cute layout','Hypit safe clone') }
    for($j=0;$j -lt 3;$j++){
      $y=790+$j*82
      Fill-RoundedRect $g (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,255,238,247))) 115 $y 490 56 24
      $r=New-Object System.Drawing.RectangleF 130,$y,460,56
      $g.DrawString($chips[$j],$fontSmall,$dark,$r,$fmt)
    }
    Fill-RoundedRect $g $pink 120 1060 480 90 35
    $cta='SAVE THE TEMPLATE'
    if($t -ge 8){ $cta='OPEN FROM DESKTOP' }
    $g.DrawString($cta,$fontMed,(New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)),(New-Object System.Drawing.RectangleF 130,1060,460,90),$fmt)
    $outFrame=Join-Path $frames ('frame_'+$i.ToString('0000')+'.png')
    $bmp.Save($outFrame,[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
  }
  if($photoImg){ $photoImg.Dispose() }
  $fontBig.Dispose(); $fontMed.Dispose(); $fontSmall.Dispose(); $fmt.Dispose()
  $srtText="1`r`n00:00:00,000 --> 00:00:02,000`r`nSTOP SCROLLING`r`n`r`n2`r`n00:00:02,000 --> 00:00:05,000`r`nPROFILE PHOTO`r`n`r`n3`r`n00:00:05,000 --> 00:00:08,000`r`nJOB SEARCH STACK`r`n`r`n4`r`n00:00:08,000 --> 00:00:12,000`r`nREADY ON E DRIVE`r`n"
  WriteUtf8 $srt $srtText
  $refText='{"name":"safe_viral_template_1to1","resolution":"720x1280","fps":24,"duration_seconds":12,"scene_cut_frames":[0,48,120,192,288],"note":"Non-infringing structural remake; no copied face, music, watermark, or creator identity."}'
  WriteUtf8 $ref $refText
  $args=@('-y','-framerate','24','-i',(Join-Path $frames 'frame_%04d.png'),'-f','lavfi','-i','anullsrc=channel_layout=stereo:sample_rate=44100','-shortest','-t','12','-c:v','libx264','-pix_fmt','yuv420p','-r','24',$out)
  $r=Run-Exe $Ffmpeg $args '' 900
  $bytes=0; if(Test-Path -LiteralPath $out){ $bytes=(Get-Item -LiteralPath $out).Length }
  return [pscustomobject]@{video=$out;srt=$srt;reference=$ref;frames=$frames;ffmpeg=$Ffmpeg;code=$r.code;text=$r.text;bytes=$bytes;exists=(Test-Path -LiteralPath $out)}
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R241_INSTALL_MEDIA_CAREER_TOOLS.md'
$jsonReport=Join-Path $outDir 'r241-install-media-career-tools.json'
$assetSrc=Join-Path $repo 'deliverable\assets\cute_professional_id_photo.png'
$lab='E:\0mcp-agv-arena-optimized'
$appsRoot=Join-Path $lab 'apps'
$webRoot=Join-Path $appsRoot 'web-apps'
$installerRoot=Join-Path $lab 'installers\r241'
$skillsRoot=Join-Path $lab 'skills'
$careerRoot=Join-Path $lab 'career'
$videoRoot=Join-Path $lab 'video'
$imageRoot=Join-Path $lab 'images\career-id-photo'
$toolsRoot=Join-Path $lab 'tools'
foreach($d in @($appsRoot,$webRoot,$installerRoot,$skillsRoot,$careerRoot,$videoRoot,$imageRoot,$toolsRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$desktop=[Environment]::GetFolderPath('Desktop')
if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }

L '# R241 install media, desktop, photo, career, and Hypit tools'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('host='+$env:COMPUTERNAME)
L ('repo='+$repo)
L ('desktop_dir='+$desktop)
L ('e_root='+$lab)
L ('asset_src='+$assetSrc+' exists='+(Test-Path -LiteralPath $assetSrc))

$desktopOrg=Organize-Desktop $desktop
L ('desktop_organizer_dir='+$desktopOrg.dir)
L ('desktop_organizer_manifest='+$desktopOrg.manifest)
L ('desktop_restore_script='+$desktopOrg.restore)
L ('desktop_moved_count='+$desktopOrg.moved)

$cuteLinks=Join-Path $desktopOrg.dir 'New-Shortcuts'
New-Item -ItemType Directory -Force -Path $cuteLinks|Out-Null
$browser=Find-Browser
L ('browser='+$browser)
$webApps=@()
$webApps += Install-WebApp 'Douyin' 'douyin' 'https://www.douyin.com/' $webRoot $desktop $cuteLinks $browser
$webApps += Install-WebApp 'Xiaohongshu' 'xiaohongshu' 'https://www.xiaohongshu.com/' $webRoot $desktop $cuteLinks $browser
$webApps += Install-WebApp 'WeChat Official Account' 'wechat-official-account' 'https://mp.weixin.qq.com/' $webRoot $desktop $cuteLinks $browser
$webApps += Install-WebApp 'Jianying' 'jianying' 'https://www.capcut.cn/' $webRoot $desktop $cuteLinks $browser
foreach($wa in $webApps){ L ('web_app_'+$wa.name+'_dir='+$wa.dir); L ('web_app_'+$wa.name+'_desktop_shortcut='+$wa.desktopShortcut+' exists='+$wa.exists) }

$winget=Find-Cmd @('winget.exe','winget')
L ('winget='+$winget)
$nativeResults=@()
if($winget){
  $pkgList=@(
    @{id='ByteDance.Douyin';loc=(Join-Path $appsRoot 'DouyinNative')},
    @{id='ByteDance.JianyingPro';loc=(Join-Path $appsRoot 'JianyingNative')}
  )
  foreach($pkg in $pkgList){
    New-Item -ItemType Directory -Force -Path $pkg.loc|Out-Null
    $args=@('install','--id',$pkg.id,'--exact','--source','winget','--silent','--accept-package-agreements','--accept-source-agreements','--disable-interactivity','--location',$pkg.loc)
    $r=Run-Exe $winget $args '' 1800
    $nativeResults += [pscustomobject]@{id=$pkg.id;location=$pkg.loc;exit=$r.code;tail=(TailText (San $r.text) 12)}
    L ('winget_install_'+$pkg.id+'_exit='+$r.code)
    L ('winget_install_'+$pkg.id+'_tail='+(TailText (San $r.text) 8))
  }
}else{
  L 'winget_native_install_skipped=True'
}

$deskboxDir=Join-Path $appsRoot 'DeskBox'
$deskboxInstaller=''
$deskboxExe=''
$deskboxInstallExit=999
try{
  $rel=Invoke-RestMethod -UseBasicParsing -Headers @{'User-Agent'='Arena-Agent'} -Uri 'https://api.github.com/repos/Tianyu199509/DeskBox/releases/latest'
  $asset=$rel.assets | Where-Object { $_.name -match 'DeskBox_Setup_.*_x64\.exe$' } | Select-Object -First 1
  if($asset){
    $deskboxInstaller=Join-Path $installerRoot ([string]$asset.name)
    if(-not(Test-Path -LiteralPath $deskboxInstaller)){ Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $deskboxInstaller }
    $args=@('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/CURRENTUSER','/DIR='+$deskboxDir)
    $r=Run-Exe $deskboxInstaller $args '' 900
    $deskboxInstallExit=$r.code
    L ('deskbox_installer='+$deskboxInstaller)
    L ('deskbox_install_exit='+$deskboxInstallExit)
    L ('deskbox_install_tail='+(TailText (San $r.text) 10))
  }else{ L 'deskbox_release_asset_missing=True' }
}catch{
  L ('deskbox_download_install_error='+(San $_.Exception.Message))
}
try{
  $f=Get-ChildItem -LiteralPath $deskboxDir -Recurse -Filter DeskBox.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if($f){ $deskboxExe=$f.FullName }
}catch{}
if(-not $deskboxExe){
  try{
    $local=Join-Path $env:LOCALAPPDATA 'Programs'
    if(Test-Path -LiteralPath $local){
      $f=Get-ChildItem -LiteralPath $local -Recurse -Filter DeskBox.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
      if($f){ $deskboxExe=$f.FullName }
    }
  }catch{}
}
$deskboxShortcut=Join-Path $desktop 'DeskBox Cute.lnk'
if($deskboxExe){ New-Link $deskboxShortcut $deskboxExe '' (Split-Path -Parent $deskboxExe) $deskboxExe 'DeskBox cute desktop organizer'|Out-Null }
elseif($deskboxInstaller){ New-Link $deskboxShortcut $deskboxInstaller '' $installerRoot $deskboxInstaller 'DeskBox installer'|Out-Null }
else{ New-Link $deskboxShortcut 'explorer.exe' $desktopOrg.dir $desktopOrg.dir '' 'DeskBox organizer folder'|Out-Null }
L ('deskbox_dir='+$deskboxDir)
L ('deskbox_exe='+$deskboxExe+' exists='+(Test-Path -LiteralPath $deskboxExe))
L ('deskbox_shortcut='+$deskboxShortcut+' exists='+(Test-Path -LiteralPath $deskboxShortcut))

$origPhoto=Join-Path $imageRoot 'cute_professional_id_photo_original.png'
$id295=Join-Path $imageRoot 'career_id_photo_295x413.png'
$id413=Join-Path $imageRoot 'career_id_photo_413x579.png'
$desktopPhoto=Join-Path $desktop 'cute_professional_id_photo_295x413.png'
if(Test-Path -LiteralPath $assetSrc){ Copy-Item -LiteralPath $assetSrc -Destination $origPhoto -Force }
$idOk1=$false; $idOk2=$false
if(Test-Path -LiteralPath $origPhoto){
  $idOk1=Export-IdPhoto $origPhoto $id295 295 413
  $idOk2=Export-IdPhoto $origPhoto $id413 413 579
  if(Test-Path -LiteralPath $id295){ Copy-Item -LiteralPath $id295 -Destination $desktopPhoto -Force }
}
L ('photo_original='+$origPhoto+' exists='+(Test-Path -LiteralPath $origPhoto))
L ('photo_id_295='+$id295+' exists='+(Test-Path -LiteralPath $id295))
L ('photo_id_413='+$id413+' exists='+(Test-Path -LiteralPath $id413))
L ('photo_desktop_copy='+$desktopPhoto+' exists='+(Test-Path -LiteralPath $desktopPhoto))

$git=Find-Cmd @('git.exe','git')
L ('git='+$git)
$xiutuDir=Join-Path $skillsRoot 'xiutu.skill'
$xiutu=Ensure-GitRepo 'https://github.com/Chase-qisiai/xiutu.skill.git' $xiutuDir $git
L ('xiutu_clone_ok='+$xiutu.ok)
L ('xiutu_dir='+$xiutuDir+' exists='+(Test-Path -LiteralPath $xiutuDir))
New-Link (Join-Path $desktop 'xiutu.skill.lnk') 'explorer.exe' ('"'+$xiutuDir+'"') $xiutuDir '' 'Open xiutu.skill folder'|Out-Null

$aiJobDir=Join-Path $careerRoot 'ai-job-search'
$aiJob=Ensure-GitRepo 'https://github.com/MadsLorentzen/ai-job-search.git' $aiJobDir $git
L ('ai_job_search_clone_ok='+$aiJob.ok)
L ('ai_job_search_dir='+$aiJobDir+' exists='+(Test-Path -LiteralPath $aiJobDir))
New-Link (Join-Path $desktop 'AI Job Search.lnk') 'explorer.exe' ('"'+$aiJobDir+'"') $aiJobDir '' 'Open ai-job-search'|Out-Null

$nodePair=Ensure-Node $toolsRoot
$node=$nodePair.node; $npm=$nodePair.npm
L ('node='+$node)
try{ if($node){ L ('node_version='+((& $node -v 2>$null | Select-Object -First 1))) } }catch{}
L ('npm='+$npm)
$bun=Find-Cmd @('bun.exe','bun')
L ('bun='+$bun)
if($bun -and (Test-Path -LiteralPath $aiJobDir)){
  foreach($tool in @('jobbank-search','jobdanmark-search','jobindex-search','jobnet-search','linkedin-search','freehire-search')){
    $td=Join-Path $aiJobDir ('.agents\skills\'+$tool+'\cli')
    if(Test-Path -LiteralPath (Join-Path $td 'package.json')){
      $br=Run-Exe $bun @('install') $td 420
      L ('bun_install_'+$tool+'_exit='+$br.code)
    }
  }
}else{ L 'ai_job_search_bun_cli_install_skipped=True' }

$careerOpsDir=Join-Path $careerRoot 'career-ops'
$careerOps=Ensure-GitRepo 'https://github.com/career-ops-hq/career-ops.git' $careerOpsDir $git
L ('career_ops_clone_ok='+$careerOps.ok)
L ('career_ops_dir='+$careerOpsDir+' exists='+(Test-Path -LiteralPath $careerOpsDir))
if($npm -and (Test-Path -LiteralPath (Join-Path $careerOpsDir 'package.json'))){
  $nr=Run-Exe $npm @('install','--no-audit','--fund=false') $careerOpsDir 900
  L ('career_ops_npm_install_exit='+$nr.code)
  L ('career_ops_npm_install_tail='+(TailText (San $nr.text) 10))
  $doctor=Run-Exe $npm @('run','doctor') $careerOpsDir 300
  L ('career_ops_doctor_exit='+$doctor.code)
  L ('career_ops_doctor_tail='+(TailText (San $doctor.text) 12))
}else{ L 'career_ops_npm_install_skipped=True' }
New-Link (Join-Path $desktop 'Career Ops.lnk') 'explorer.exe' ('"'+$careerOpsDir+'"') $careerOpsDir '' 'Open career-ops'|Out-Null

$hypitDir=Join-Path $videoRoot 'hypit'
$hypit=Ensure-GitRepo 'https://github.com/hypit-ai/hypit.git' $hypitDir $git
L ('hypit_repo_clone_ok='+$hypit.ok)
L ('hypit_repo_dir='+$hypitDir+' exists='+(Test-Path -LiteralPath $hypitDir))
$hypitGlobal=Join-Path $toolsRoot 'npm-global-hypit'
$hypitCmd=Join-Path $hypitGlobal 'hypit.cmd'
if($npm){
  New-Item -ItemType Directory -Force -Path $hypitGlobal|Out-Null
  $hr=Run-Exe $npm @('install','-g','--prefix',$hypitGlobal,'@hypit/hypit@latest') '' 900
  L ('hypit_npm_global_install_exit='+$hr.code)
  L ('hypit_npm_global_install_tail='+(TailText (San $hr.text) 10))
  if(Test-Path -LiteralPath $hypitCmd){
    $ver=Run-Exe $hypitCmd @('--version') '' 120
    L ('hypit_version_exit='+$ver.code)
    L ('hypit_version_tail='+(TailText (San $ver.text) 6))
  }
  $npx=Find-Cmd @('npx.cmd','npx')
  if($npx){
    $sr=Run-Exe $npx @('--yes','skills','add','hypit-ai/hypit','-g') '' 900
    L ('hypit_skill_add_exit='+$sr.code)
    L ('hypit_skill_add_tail='+(TailText (San $sr.text) 10))
  }else{ L 'hypit_skill_add_skipped_no_npx=True' }
}else{ L 'hypit_npm_install_skipped_no_npm=True' }
New-Link (Join-Path $desktop 'Hypit.lnk') 'explorer.exe' ('"'+$hypitDir+'"') $hypitDir '' 'Open hypit'|Out-Null

$ffmpeg=Find-Ffmpeg
$py=Find-Python
L ('ffmpeg_initial='+$ffmpeg)
L ('python='+$py)
if(-not $ffmpeg -and $py){
  $ir=Run-Exe $py @('-m','pip','install','--user','imageio-ffmpeg') '' 420
  L ('imageio_ffmpeg_install_exit='+$ir.code)
  L ('imageio_ffmpeg_install_tail='+(TailText (San $ir.text) 8))
  $get=Run-Exe $py @('-c','import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())') '' 90
  $cand=($get.text -split "`r?`n" | Where-Object { $_ -match 'ffmpeg' } | Select-Object -Last 1).Trim()
  if($cand -and (Test-Path -LiteralPath $cand)){ $ffmpeg=$cand }
  L ('imageio_ffmpeg_path='+$cand)
}
L ('ffmpeg_final='+$ffmpeg+' exists='+(Test-Path -LiteralPath $ffmpeg))
$hypitProject=Join-Path $videoRoot 'hypit-safe-viral-clone-r241'
$videoObj=$null
if($ffmpeg -and (Test-Path -LiteralPath $origPhoto)){
  $videoObj=Build-SafeViralVideo $origPhoto $hypitProject $ffmpeg
  L ('hypit_safe_clone_video='+$videoObj.video)
  L ('hypit_safe_clone_video_exists='+$videoObj.exists)
  L ('hypit_safe_clone_video_bytes='+$videoObj.bytes)
  L ('hypit_safe_clone_reference='+$videoObj.reference)
  L ('hypit_safe_clone_ffmpeg_exit='+$videoObj.code)
  L ('hypit_safe_clone_ffmpeg_tail='+(TailText (San $videoObj.text) 8))
}else{
  L 'hypit_safe_clone_video_skipped=True'
}
$desktopVideo=Join-Path $desktop 'hypit_safe_viral_clone_r241.mp4'
if($videoObj -and (Test-Path -LiteralPath $videoObj.video)){ Copy-Item -LiteralPath $videoObj.video -Destination $desktopVideo -Force }
L ('hypit_safe_clone_desktop_video='+$desktopVideo+' exists='+(Test-Path -LiteralPath $desktopVideo))

$openAll=Join-Path $desktop 'R241 Paths and Tools.lnk'
$summaryFolder=Join-Path $lab 'r241-paths-and-tools'
New-Item -ItemType Directory -Force -Path $summaryFolder|Out-Null
New-Link $openAll 'explorer.exe' ('"'+$summaryFolder+'"') $summaryFolder '' 'Open all R241 paths'|Out-Null
$pathsTxt=Join-Path $summaryFolder 'PATHS.txt'
$pathLines=@()
$pathLines += 'E root: '+$lab
$pathLines += 'Desktop organizer: '+$desktopOrg.dir
$pathLines += 'DeskBox: '+$deskboxDir
$pathLines += 'Web apps: '+$webRoot
$pathLines += 'Photo folder: '+$imageRoot
$pathLines += 'Xiutu skill: '+$xiutuDir
$pathLines += 'AI Job Search: '+$aiJobDir
$pathLines += 'Career Ops: '+$careerOpsDir
$pathLines += 'Hypit repo: '+$hypitDir
$pathLines += 'Hypit demo project: '+$hypitProject
if($videoObj){ $pathLines += 'Hypit demo video: '+$videoObj.video }
$pathLines += 'Desktop video: '+$desktopVideo
$pathLines += 'Desktop photo: '+$desktopPhoto
WriteUtf8 $pathsTxt (($pathLines -join "`r`n")+"`r`n")
L ('paths_summary='+$pathsTxt)
L ('paths_shortcut='+$openAll+' exists='+(Test-Path -LiteralPath $openAll))

$shortcutOk=$true
foreach($wa in $webApps){ if(-not(Test-Path -LiteralPath $wa.desktopShortcut)){ $shortcutOk=$false } }
$deskboxShortcutOk=Test-Path -LiteralPath $deskboxShortcut
$xiutuOk=Test-Path -LiteralPath (Join-Path $xiutuDir '.git')
$aiJobOk=Test-Path -LiteralPath (Join-Path $aiJobDir '.git')
$careerOpsOk=Test-Path -LiteralPath (Join-Path $careerOpsDir '.git')
$hypitRepoOk=Test-Path -LiteralPath (Join-Path $hypitDir '.git')
$photoOk=(Test-Path -LiteralPath $id295) -and (Test-Path -LiteralPath $id413)
$videoOk=$false
if($videoObj){ $videoOk=((Test-Path -LiteralPath $videoObj.video) -and ([int64]$videoObj.bytes -gt 100000)) }
L ('web_shortcuts_ok='+$shortcutOk)
L ('deskbox_shortcut_ok='+$deskboxShortcutOk)
L ('xiutu_dir_exists='+$xiutuOk)
L ('ai_job_search_dir_exists='+$aiJobOk)
L ('career_ops_dir_exists='+$careerOpsOk)
L ('hypit_repo_dir_exists='+$hypitRepoOk)
L ('id_photo_295_exists='+(Test-Path -LiteralPath $id295))
L ('hypit_cli_exists='+(Test-Path -LiteralPath $hypitCmd))
L ('hypit_safe_clone_video_exists='+$videoOk)
$ready=($shortcutOk -and $deskboxShortcutOk -and $xiutuOk -and $aiJobOk -and $careerOpsOk -and $hypitRepoOk -and $photoOk -and $videoOk)
L ('R241_MEDIA_CAREER_READY='+$ready)

$summary=[pscustomobject]@{
  ready=$ready
  desktop=$desktop
  eRoot=$lab
  desktopOrganizer=$desktopOrg
  webApps=$webApps
  winget=$winget
  nativeResults=$nativeResults
  deskboxDir=$deskboxDir
  deskboxInstaller=$deskboxInstaller
  deskboxExe=$deskboxExe
  deskboxShortcut=$deskboxShortcut
  photoOriginal=$origPhoto
  photo295=$id295
  photo413=$id413
  desktopPhoto=$desktopPhoto
  xiutuDir=$xiutuDir
  aiJobSearchDir=$aiJobDir
  careerOpsDir=$careerOpsDir
  node=$node
  npm=$npm
  bun=$bun
  hypitDir=$hypitDir
  hypitGlobal=$hypitGlobal
  hypitCmd=$hypitCmd
  hypitProject=$hypitProject
  hypitVideo=$($videoObj.video)
  desktopVideo=$desktopVideo
  pathsSummary=$pathsTxt
  pathsShortcut=$openAll
}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){ exit 6 }
exit 0
