# t195_hard_anime_video_wallpaper_r244.ps1 - round 244.
# Create a harder original viral-style anime video, create/set an animated anime
# wallpaper, and run desktop tidy after generation. ASCII-only.

$ErrorActionPreference='Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { [System.Net.ServicePointManager]::CheckCertificateRevocationList = $false } catch {}
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
  }catch{ L ('shortcut_error='+(San $_.Exception.Message)); return $false }
}
function Find-Python(){ return (Find-Cmd @('python.exe','python','py.exe','py')) }
function Find-Ffmpeg(){
  foreach($n in @('ffmpeg.exe','ffmpeg')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue; if($c){return $c.Source} }catch{} }
  $roots=@('E:\0mcp-agv-arena-optimized\tools\ffmpeg','E:\0mcp-agv-arena-optimized')
  if($env:APPDATA){ $roots += (Join-Path $env:APPDATA 'Python') }
  if($env:LOCALAPPDATA){ $roots += (Join-Path $env:LOCALAPPDATA 'Programs\Python') }
  foreach($root in $roots){ if($root -and (Test-Path -LiteralPath $root)){ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter ffmpeg*.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){return $f.FullName} } }
  return ''
}
function Ensure-Ffmpeg([string]$Py){
  $ff=Find-Ffmpeg
  if($ff){ return $ff }
  if($Py){
    $r=Run-CmdLine ('"'+$Py+'" -m pip install --user imageio-ffmpeg') '' 420
    L ('imageio_ffmpeg_install_exit='+$r.code)
    L ('imageio_ffmpeg_install_tail='+(TailText (San $r.text) 8))
    $g=Run-CmdLine ('"'+$Py+'" -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"') '' 120
    L ('imageio_ffmpeg_get_exit='+$g.code)
    L ('imageio_ffmpeg_get_tail='+(TailText (San $g.text) 8))
    $sel=($g.text -split "`r?`n" | Where-Object { $_ -match 'ffmpeg' } | Select-Object -Last 1)
    if($sel){ $cand=[string]$sel; $cand=$cand.Trim(); if(Test-Path -LiteralPath $cand){ return $cand } }
  }
  return (Find-Ffmpeg)
}
function Draw-Cover($g,$img,[double]$x,[double]$y,[double]$w,[double]$h,[double]$zoom,[double]$panX,[double]$panY){
  $iw=[double]$img.Width; $ih=[double]$img.Height; $dstRatio=$w/$h; $srcRatio=$iw/$ih
  if($srcRatio -gt $dstRatio){ $srcH=$ih/$zoom; $srcW=$srcH*$dstRatio } else { $srcW=$iw/$zoom; $srcH=$srcW/$dstRatio }
  if($srcW -gt $iw){$srcW=$iw}; if($srcH -gt $ih){$srcH=$ih}
  $maxX=$iw-$srcW; $maxY=$ih-$srcH
  $sx=($maxX/2.0)+($panX*$maxX/2.0); $sy=($maxY/2.0)+($panY*$maxY/2.0)
  if($sx -lt 0){$sx=0}; if($sy -lt 0){$sy=0}; if($sx -gt $maxX){$sx=$maxX}; if($sy -gt $maxY){$sy=$maxY}
  $src=New-Object System.Drawing.Rectangle ([int]$sx),([int]$sy),([int]$srcW),([int]$srcH)
  $dst=New-Object System.Drawing.Rectangle ([int]$x),([int]$y),([int]$w),([int]$h)
  $g.DrawImage($img,$dst,$src,[System.Drawing.GraphicsUnit]::Pixel)
}
function Fill-RR($g,$brush,[int]$x,[int]$y,[int]$w,[int]$h,[int]$r){
  $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $d=$r*2
  $p.AddArc($x,$y,$d,$d,180,90); $p.AddArc($x+$w-$d,$y,$d,$d,270,90); $p.AddArc($x+$w-$d,$y+$h-$d,$d,$d,0,90); $p.AddArc($x,$y+$h-$d,$d,$d,90,90); $p.CloseFigure(); $g.FillPath($brush,$p); $p.Dispose()
}
function Render-HardVideo([string]$ImagePath,[string]$ProjectDir,[string]$Ffmpeg,[string]$Py){
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $ProjectDir|Out-Null
  $frames=Join-Path $ProjectDir 'frames_vertical_hard'; if(Test-Path -LiteralPath $frames){Remove-Item -LiteralPath $frames -Recurse -Force -ErrorAction SilentlyContinue}; New-Item -ItemType Directory -Force -Path $frames|Out-Null
  $out=Join-Path $ProjectDir 'hypit_hard_anime_viral_r244.mp4'; $audio=Join-Path $ProjectDir 'original_synth_beat.wav'
  $fps=30; $dur=22; $total=$fps*$dur; $w=900; $h=1600
  $img=[System.Drawing.Image]::FromFile($ImagePath)
  $rand=New-Object System.Random 244
  $parts=@(); for($i=0;$i -lt 180;$i++){ $parts += [pscustomobject]@{x=$rand.NextDouble(); y=$rand.NextDouble(); sp=(0.25+$rand.NextDouble()*0.95); sz=(2+$rand.NextDouble()*7); ph=$rand.NextDouble()*6.283; hue=$rand.Next(0,3)} }
  for($i=0;$i -lt $total;$i++){
    $t=[double]$i/[double]$fps
    $bmp=New-Object System.Drawing.Bitmap $w,$h
    $g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias; $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $scene=[int][Math]::Floor($t/4.4); if($scene -gt 4){$scene=4}
    $zoom=1.08+0.06*[Math]::Sin($t*0.7)+0.025*$scene
    $panX=[Math]::Sin($t*0.32+$scene)*0.65; $panY=[Math]::Cos($t*0.28)*0.42
    Draw-Cover $g $img 0 0 $w $h $zoom $panX $panY
    $shade=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(55,8,10,28)); $g.FillRectangle($shade,0,0,$w,$h); $shade.Dispose()
    if($scene -eq 0){
      $brush=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(62,255,105,185)); Fill-RR $g $brush 70 110 760 1170 60; $brush.Dispose()
      $pen=New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(170,255,235,255)),3
      for($r=0;$r -lt 8;$r++){ $rad=160+$r*75+35*[Math]::Sin($t*4+$r); $g.DrawEllipse($pen,[int]($w/2-$rad/2),[int](610-$rad/2),[int]$rad,[int]$rad) }
      $pen.Dispose()
    } elseif($scene -eq 1){
      $overlay=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(95,3,4,20)); $g.FillRectangle($overlay,0,0,$w,$h); $overlay.Dispose()
      for($c=0;$c -lt 4;$c++){
        $cx=180+$c*170+[Math]::Sin($t*2+$c)*35; $cy=310+$c*210; $ang=-14+$c*9+[Math]::Sin($t*2.5+$c)*5
        $g.TranslateTransform([float]$cx,[float]$cy); $g.RotateTransform([float]$ang)
        $cardBrush=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(185,255,255,255)); Fill-RR $g $cardBrush -135 -190 270 380 24; $cardBrush.Dispose()
        Draw-Cover $g $img -120 -175 240 350 (1.25+0.04*$c) ([Math]::Sin($t+$c)) ([Math]::Cos($t+$c))
        $g.ResetTransform()
      }
    } elseif($scene -eq 2){
      $overlay=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(65,0,0,0)); $g.FillRectangle($overlay,0,0,$w,$h); $overlay.Dispose()
      for($p=0;$p -lt 5;$p++){
        $px=25+$p*172; $py=150+([Math]::Sin($t*3+$p)*30); $pw=145; $ph=980
        Draw-Cover $g $img $px $py $pw $ph (1.55+0.08*$p) ([Math]::Sin($t+$p)) ([Math]::Cos($t*0.8+$p))
        $pn=New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(210,120,220,255)),3; $g.DrawRectangle($pn,[int]$px,[int]$py,[int]$pw,[int]$ph); $pn.Dispose()
      }
    } elseif($scene -eq 3){
      $overlay=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(80,8,0,28)); $g.FillRectangle($overlay,0,0,$w,$h); $overlay.Dispose()
      for($r=0;$r -lt 14;$r++){ $rad=120+$r*58+22*[Math]::Sin($t*5+$r); $alpha=220-($r*12); if($alpha -lt 30){$alpha=30}; $pen=New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($alpha,255,125,210)),2; $g.DrawEllipse($pen,[int]($w/2-$rad/2),[int](770-$rad/2),[int]$rad,[int]$rad); $pen.Dispose() }
      for($b=0;$b -lt 16;$b++){ $x1=$w/2; $y1=770; $ang=($b/16.0)*6.283+$t*0.8; $x2=$x1+[Math]::Cos($ang)*900; $y2=$y1+[Math]::Sin($ang)*900; $pen=New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(65,120,230,255)),4; $g.DrawLine($pen,[int]$x1,[int]$y1,[int]$x2,[int]$y2); $pen.Dispose() }
    } else {
      $veil=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(35,255,225,245)); $g.FillRectangle($veil,0,0,$w,$h); $veil.Dispose()
    }
    for($j=0;$j -lt $parts.Count;$j++){
      $p=$parts[$j]; $px=[int](($p.x*$w + 60*[Math]::Sin($t*0.9+$p.ph)) % $w); $py=[int]((($p.y*$h + $t*260*$p.sp) % ($h+160))-80); $sz=[int]$p.sz
      if($p.hue -eq 0){$col=[System.Drawing.Color]::FromArgb(185,255,170,220)}elseif($p.hue -eq 1){$col=[System.Drawing.Color]::FromArgb(155,130,230,255)}else{$col=[System.Drawing.Color]::FromArgb(145,255,245,160)}
      $br=New-Object System.Drawing.SolidBrush $col; $g.FillEllipse($br,$px,$py,$sz*2,$sz); $br.Dispose()
    }
    for($k=0;$k -lt 22;$k++){ $x=[int](($k*43+$t*145) % $w); $pen=New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(44,255,255,255)),1; $g.DrawLine($pen,$x,0,$x-260,$h); $pen.Dispose() }
    if(($i % 33) -lt 3){ $flash=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(28,255,255,255)); $g.FillRectangle($flash,0,0,$w,$h); $flash.Dispose() }
    $path=Join-Path $frames ('frame_'+$i.ToString('0000')+'.jpg'); $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Jpeg); $g.Dispose(); $bmp.Dispose()
  }
  $img.Dispose()
  if($Py){
    $audioPy=Join-Path $ProjectDir 'make_original_beat.py'
    $code=@'
import sys, wave, math, struct
out=sys.argv[1]
dur=float(sys.argv[2])
sr=44100
samples=int(sr*dur)
w=wave.open(out,'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
for n in range(samples):
    t=n/sr
    beat=(t*2.0)%1.0
    kick=0.0
    if beat < 0.18:
        f=92-58*beat/0.18
        kick=math.sin(2*math.pi*f*t)*math.exp(-19*beat)
    hat=(0.18 if ((t*8)%1)<0.05 else 0.0)*math.sin(2*math.pi*8000*t)
    lead=0.18*math.sin(2*math.pi*(220+55*math.sin(2*math.pi*0.125*t))*t)
    bass=0.12*math.sin(2*math.pi*55*t)
    v=max(-0.95,min(0.95,0.55*kick+0.15*hat+0.18*lead+0.22*bass))
    w.writeframes(struct.pack('<h', int(v*32767)))
w.close()
'@
    WriteUtf8 $audioPy $code
    $ar=Run-CmdLine ('"'+$Py+'" "'+$audioPy+'" "'+$audio+'" '+$dur) $ProjectDir 240
    L ('hard_video_audio_exit='+$ar.code)
    L ('hard_video_audio_tail='+(TailText (San $ar.text) 8))
  }
  if(-not(Test-Path -LiteralPath $audio)){
    $ar=Run-CmdLine ('"'+$Ffmpeg+'" -y -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -t '+$dur+' "'+$audio+'"') '' 180
    L ('hard_video_silent_audio_exit='+$ar.code)
  }
  $story=Join-Path $ProjectDir 'hypit_storyboard_hard_viral_anime.svml'
  $svml='<video aspect="9:16" duration="22" style="hard-viral-anime-edit"><scene name="neon-hook" seconds="0-4.4" effects="portal,flash,petals"/><scene name="card-stack" seconds="4.4-8.8" effects="rotating-panels,parallax"/><scene name="split-panel" seconds="8.8-13.2" effects="multi-strip,scanline"/><scene name="energy-portal" seconds="13.2-17.6" effects="rings,beams,beat-sync"/><scene name="live-wallpaper-reveal" seconds="17.6-22" effects="loop-ready,petals"/></video>'
  WriteUtf8 $story $svml
  $manifest=Join-Path $ProjectDir 'viral_rebuild_manifest.json'
  $mf='{"workflow":"hypit-hard-viral-style-rebuild","copyright_note":"original generated anime visual; no copied creator, face, audio, watermark, or copyrighted character","resolution":"900x1600","fps":30,"duration_seconds":22,"complexity_layers":["camera parallax","rotating cards","split panels","portal rings","particle petals","rain streaks","flash beats","original synth beat"]}'
  WriteUtf8 $manifest $mf
  $line='"'+$Ffmpeg+'" -y -framerate '+$fps+' -i "'+(Join-Path $frames 'frame_%04d.jpg')+'" -i "'+$audio+'" -shortest -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p -c:a aac -b:a 160k "'+$out+'"'
  $r=Run-CmdLine $line '' 1200
  $bytes=0; if(Test-Path -LiteralPath $out){$bytes=(Get-Item -LiteralPath $out).Length}
  return [pscustomobject]@{video=$out;audio=$audio;frames=$frames;storyboard=$story;manifest=$manifest;code=$r.code;text=$r.text;bytes=$bytes;exists=(Test-Path -LiteralPath $out)}
}
function Render-Wallpaper([string]$ImagePath,[string]$ProjectDir,[string]$Ffmpeg){
  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $ProjectDir|Out-Null
  $frames=Join-Path $ProjectDir 'frames_wallpaper_loop'; if(Test-Path -LiteralPath $frames){Remove-Item -LiteralPath $frames -Recurse -Force -ErrorAction SilentlyContinue}; New-Item -ItemType Directory -Force -Path $frames|Out-Null
  $out=Join-Path $ProjectDir 'anime_live_wallpaper_r244.mp4'; $w=1600; $h=900; $fps=30; $dur=16; $total=$fps*$dur
  $img=[System.Drawing.Image]::FromFile($ImagePath); $rand=New-Object System.Random 245; $stars=@(); for($i=0;$i -lt 220;$i++){ $stars += [pscustomobject]@{x=$rand.NextDouble(); y=$rand.NextDouble(); sp=(0.15+$rand.NextDouble()*0.45); sz=(1+$rand.NextDouble()*5); ph=$rand.NextDouble()*6.283} }
  for($i=0;$i -lt $total;$i++){
    $t=[double]$i/[double]$fps
    $bmp=New-Object System.Drawing.Bitmap $w,$h; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias; $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    Draw-Cover $g $img 0 0 $w $h (1.04+0.015*[Math]::Sin($t*0.45)) ([Math]::Sin($t*0.22)*0.35) ([Math]::Cos($t*0.18)*0.20)
    $veil=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(28,10,8,30)); $g.FillRectangle($veil,0,0,$w,$h); $veil.Dispose()
    foreach($s in $stars){ $x=[int](($s.x*$w + 28*[Math]::Sin($t+$s.ph)) % $w); $y=[int]((($s.y*$h + $t*55*$s.sp) % ($h+40))-20); $alpha=[int](110+80*[Math]::Sin($t*1.7+$s.ph)); if($alpha -lt 20){$alpha=20}; if($alpha -gt 210){$alpha=210}; $br=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alpha,255,190,225)); $g.FillEllipse($br,$x,$y,[int]$s.sz*2,[int]$s.sz); $br.Dispose() }
    for($r=0;$r -lt 8;$r++){ $rad=240+$r*145+30*[Math]::Sin($t*0.9+$r); $pen=New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(32,120,220,255)),2; $g.DrawEllipse($pen,[int]($w/2-$rad/2),[int]($h/2-$rad/2),[int]$rad,[int]$rad); $pen.Dispose() }
    $path=Join-Path $frames ('wall_'+$i.ToString('0000')+'.jpg'); $bmp.Save($path,[System.Drawing.Imaging.ImageFormat]::Jpeg); $g.Dispose(); $bmp.Dispose()
  }
  $img.Dispose()
  $line='"'+$Ffmpeg+'" -y -framerate '+$fps+' -i "'+(Join-Path $frames 'wall_%04d.jpg')+'" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -shortest -t '+$dur+' -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -b:a 64k "'+$out+'"'
  $r=Run-CmdLine $line '' 900
  $bytes=0; if(Test-Path -LiteralPath $out){$bytes=(Get-Item -LiteralPath $out).Length}
  return [pscustomobject]@{video=$out;frames=$frames;code=$r.code;text=$r.text;bytes=$bytes;exists=(Test-Path -LiteralPath $out)}
}
function Find-Lively(){
  $roots=@()
  if($env:LOCALAPPDATA){ $roots += (Join-Path $env:LOCALAPPDATA 'Programs'); $roots += (Join-Path $env:LOCALAPPDATA 'Lively Wallpaper') }
  if($env:ProgramFiles){ $roots += $env:ProgramFiles }
  if(${env:ProgramFiles(x86)}){ $roots += ${env:ProgramFiles(x86)} }
  $roots += 'E:\0mcp-agv-arena-optimized\apps'
  foreach($root in $roots){ if($root -and (Test-Path -LiteralPath $root)){ foreach($name in @('livelycu.exe','Lively.exe','lively.exe')){ try{ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter $name -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){return $f.FullName} }catch{} } } }
  return (Find-Cmd @('livelycu.exe','lively.exe','Lively.exe'))
}
function Download-File([string]$Url,[string]$Out){
  $curl=Find-Cmd @('curl.exe','curl')
  if($curl){
    $line='"'+$curl+'" -L --ssl-no-revoke --retry 3 -A "Mozilla/5.0" -o "'+$Out+'" "'+$Url+'"'
    $r=Run-CmdLine $line '' 900
    if((Test-Path -LiteralPath $Out) -and ((Get-Item -LiteralPath $Out).Length -gt 1000000)){ return $r }
    L ('download_curl_tail='+(TailText (San $r.text) 6))
  }
  try{ Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='Mozilla/5.0'} -Uri $Url -OutFile $Out; return @{code=0;text='Invoke-WebRequest OK'} }catch{ return @{code=1;text=$_.Exception.Message} }
}
function Ensure-Lively([string]$Installers){
  $lv=Find-Lively
  if($lv){ return $lv }
  $winget=Find-Cmd @('winget.exe','winget')
  if($winget){
    $wr=Run-CmdLine ('"'+$winget+'" install --id rocksdanister.LivelyWallpaper -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity') '' 1800
    L ('lively_winget_install_exit='+$wr.code)
    L ('lively_winget_install_tail='+(TailText (San $wr.text) 12))
    $lv=Find-Lively; if($lv){ return $lv }
  } else { L 'lively_winget_missing=True' }
  $url='https://github.com/rocksdanister/lively/releases/download/v2.2.1.0/lively_setup_x86_full_v2210.exe'
  New-Item -ItemType Directory -Force -Path $Installers|Out-Null
  $exe=Join-Path $Installers 'lively_setup_x86_full_v2210.exe'
  $dr=Download-File $url $exe
  $sz=0; if(Test-Path -LiteralPath $exe){$sz=(Get-Item -LiteralPath $exe).Length}
  L ('lively_direct_download_exit='+$dr.code)
  L ('lively_direct_download_bytes='+$sz)
  L ('lively_direct_download_tail='+(TailText (San $dr.text) 10))
  if($sz -gt 1000000){
    $ir=Run-CmdLine ('"'+$exe+'" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /CURRENTUSER') '' 1800
    L ('lively_direct_install_exit='+$ir.code)
    L ('lively_direct_install_tail='+(TailText (San $ir.text) 12))
    $lv=Find-Lively; if($lv){ return $lv }
  }
  return ''
}
function Set-LivelyWallpaper([string]$Lively,[string]$Video){
  if(-not $Lively -or -not(Test-Path -LiteralPath $Video)){ return @{ok=$false;text='missing lively or video';code=127} }
  try{ Start-Process -FilePath $Lively -ArgumentList @('app','--showApp','false') -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 4 }catch{}
  $r=Run-CmdLine ('"'+$Lively+'" setwp --file "'+$Video+'"') '' 180
  if($r.code -ne 0){ $r=Run-CmdLine ('"'+$Lively+'" setwp --file "'+$Video+'" --monitor 1') '' 180 }
  return @{ok=($r.code -eq 0);text=$r.text;code=$r.code}
}
function Set-StaticWallpaper([string]$ImagePath){
  try{
    $code='using System; using System.Runtime.InteropServices; public class Wp { [DllImport("user32.dll", SetLastError=true)] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni); }'
    Add-Type $code -ErrorAction SilentlyContinue
    return [Wp]::SystemParametersInfo(20,0,$ImagePath,3)
  }catch{ return $false }
}
function Tidy-Desktop([string]$Desktop,[string]$OrgRoot){
  New-Item -ItemType Directory -Force -Path $OrgRoot|Out-Null
  $cats=@('01-Apps-Shortcuts','02-Job-Tools','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')
  foreach($c in $cats){ New-Item -ItemType Directory -Force -Path (Join-Path $OrgRoot $c)|Out-Null }
  $keep=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer','Douyin.lnk','Xiaohongshu.lnk','WeChat Official Account.lnk','Jianying.lnk','DeskBox Cute.lnk','Hypit.lnk','AI Job Search.lnk','Career Ops.lnk','xiutu.skill.lnk','R241 Paths and Tools.lnk','Hypit Hard Anime Viral R244.lnk','Anime Live Wallpaper R244.lnk','Auto Tidy Desktop.lnk')
  $moves=@(); $items=Get-ChildItem -LiteralPath $Desktop -Force -ErrorAction SilentlyContinue
  foreach($it in $items){
    if($keep -contains $it.Name){ continue }
    if(($it.Attributes -band [IO.FileAttributes]::System) -or ($it.Attributes -band [IO.FileAttributes]::Hidden)){ continue }
    $cat='08-Misc'; if($it.PSIsContainer){$cat='07-Old-Folders'} else { $ext=$it.Extension.ToLowerInvariant(); if($ext -in @('.lnk','.url','.cmd','.bat','.ps1')){$cat='01-Apps-Shortcuts'} elseif($ext -in @('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.txt','.md','.csv')){$cat='05-Documents'} elseif($ext -in @('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')){$cat='04-Images-ID-Photos'} elseif($ext -in @('.mp4','.mov','.mkv','.avi','.srt')){$cat='03-Video-Creation'} elseif($ext -in @('.zip','.rar','.7z','.exe','.msi','.msix','.appx')){$cat='06-Archives-Installers'} }
    $destDir=Join-Path $OrgRoot $cat; $dest=Join-Path $destDir $it.Name; $n=1
    while(Test-Path -LiteralPath $dest){ $base=[IO.Path]::GetFileNameWithoutExtension($it.Name); $ext2=[IO.Path]::GetExtension($it.Name); $dest=Join-Path $destDir ($base+'_'+$n+$ext2); $n++ }
    try{ Move-Item -LiteralPath $it.FullName -Destination $dest -Force -ErrorAction Stop; $moves += ($it.FullName+' -> '+$dest) }catch{ $moves += ('MOVE_ERR '+$it.FullName+' '+(San $_.Exception.Message)) }
  }
  $manifest=Join-Path $OrgRoot 'AUTO_TIDY_LAST_RUN.txt'; WriteUtf8 $manifest (('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')+"`r`n")+($moves -join "`r`n")+"`r`n")
  return [pscustomobject]@{manifest=$manifest;moved=$moves.Count;root=$OrgRoot}
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'R244_HARD_ANIME_VIDEO_WALLPAPER.md'; $jsonReport=Join-Path $outDir 'r244-hard-anime-video-wallpaper.json'
$lab='E:\0mcp-agv-arena-optimized'; $videoRoot=Join-Path $lab 'video'; $wallRoot=Join-Path $lab 'wallpapers\anime-live-r244'; $installers=Join-Path $lab 'installers\r244'; $toolsRoot=Join-Path $lab 'tools'; $imageRoot=Join-Path $lab 'images\anime-wallpaper-r244'
foreach($d in @($videoRoot,$wallRoot,$installers,$toolsRoot,$imageRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
$asset=Join-Path $repo 'deliverable\assets\anime_dynamic_wallpaper_v2.png'
$animeImage=Join-Path $imageRoot 'anime_dynamic_wallpaper_v2.png'
if(Test-Path -LiteralPath $asset){ Copy-Item -LiteralPath $asset -Destination $animeImage -Force }
L '# R244 hard anime viral video + dynamic wallpaper'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('desktop_dir='+$desktop)
L ('asset='+$asset+' exists='+(Test-Path -LiteralPath $asset))
L ('anime_source_image='+$animeImage+' exists='+(Test-Path -LiteralPath $animeImage))
$py=Find-Python; $ff=Ensure-Ffmpeg $py
L ('python='+$py)
L ('ffmpeg='+$ff+' exists='+($ff -and (Test-Path -LiteralPath $ff)))
$project=Join-Path $videoRoot 'hypit-hard-anime-viral-r244'
$hard=$null; if($ff -and (Test-Path -LiteralPath $animeImage)){ $hard=Render-HardVideo $animeImage $project $ff $py } else { L 'hard_video_skipped=True' }
if($hard){ L ('hard_video='+$hard.video); L ('hard_video_exists='+$hard.exists); L ('hard_video_bytes='+$hard.bytes); L ('hard_video_storyboard='+$hard.storyboard); L ('hard_video_manifest='+$hard.manifest); L ('hard_video_ffmpeg_exit='+$hard.code); L ('hard_video_ffmpeg_tail='+(TailText (San $hard.text) 10)) }
$wall=$null; if($ff -and (Test-Path -LiteralPath $animeImage)){ $wall=Render-Wallpaper $animeImage $wallRoot $ff } else { L 'wallpaper_video_skipped=True' }
if($wall){ L ('wallpaper_video='+$wall.video); L ('wallpaper_video_exists='+$wall.exists); L ('wallpaper_video_bytes='+$wall.bytes); L ('wallpaper_ffmpeg_exit='+$wall.code); L ('wallpaper_ffmpeg_tail='+(TailText (San $wall.text) 8)) }
$desktopOrg=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'; $vidFolder=Join-Path $desktopOrg '03-Video-Creation'; $wallFolder=Join-Path $desktopOrg '09-Anime-Wallpapers'; New-Item -ItemType Directory -Force -Path $vidFolder,$wallFolder|Out-Null
$deskVideo=Join-Path $vidFolder 'hypit_hard_anime_viral_r244.mp4'; $deskWall=Join-Path $wallFolder 'anime_live_wallpaper_r244.mp4'
if($hard -and (Test-Path -LiteralPath $hard.video)){ Copy-Item -LiteralPath $hard.video -Destination $deskVideo -Force; New-Link (Join-Path $desktop 'Hypit Hard Anime Viral R244.lnk') $hard.video '' (Split-Path -Parent $hard.video) $hard.video 'Open hard anime viral video'|Out-Null }
if($wall -and (Test-Path -LiteralPath $wall.video)){ Copy-Item -LiteralPath $wall.video -Destination $deskWall -Force; New-Link (Join-Path $desktop 'Anime Live Wallpaper R244.lnk') $wall.video '' (Split-Path -Parent $wall.video) $wall.video 'Open anime live wallpaper video'|Out-Null }
L ('desktop_organized_video='+$deskVideo+' exists='+(Test-Path -LiteralPath $deskVideo))
L ('desktop_organized_wallpaper='+$deskWall+' exists='+(Test-Path -LiteralPath $deskWall))
$lively=Ensure-Lively $installers
L ('lively_command='+$lively+' exists='+($lively -and (Test-Path -LiteralPath $lively)))
$wallSet=@{ok=$false;text='not-run';code=999}
if($lively -and $wall -and (Test-Path -LiteralPath $wall.video)){ $wallSet=Set-LivelyWallpaper $lively $wall.video }
L ('dynamic_wallpaper_set_ok='+$wallSet.ok)
L ('dynamic_wallpaper_set_exit='+$wallSet.code)
L ('dynamic_wallpaper_set_tail='+(TailText (San $wallSet.text) 10))
$staticOk=$false; if(-not $wallSet.ok -and (Test-Path -LiteralPath $animeImage)){ $staticOk=Set-StaticWallpaper $animeImage }
L ('static_wallpaper_fallback_ok='+$staticOk)
$tidyScriptDir=Join-Path $toolsRoot 'desktop-organizer'; New-Item -ItemType Directory -Force -Path $tidyScriptDir|Out-Null
$tidyScript=Join-Path $tidyScriptDir 'auto_tidy_desktop.ps1'
$tidyCode=@'
$ErrorActionPreference='Continue'
$desktop=[Environment]::GetFolderPath('Desktop')
if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop' }
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'
New-Item -ItemType Directory -Force -Path $org|Out-Null
Write-Output ('Auto tidy entrypoint. Main generation task already tidies desktop into: '+$org)
'@
WriteUtf8 $tidyScript $tidyCode
New-Link (Join-Path $desktop 'Auto Tidy Desktop.lnk') (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') ('-NoProfile -ExecutionPolicy Bypass -File "'+$tidyScript+'"') $tidyScriptDir '' 'Run desktop tidy'|Out-Null
$tidy=Tidy-Desktop $desktop $desktopOrg
L ('desktop_tidy_manifest='+$tidy.manifest)
L ('desktop_tidy_moved_count='+$tidy.moved)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))
$pathsTxt=Join-Path (Join-Path $lab 'r244-hard-anime-video-wallpaper') 'PATHS.txt'
$lines=@('Hard anime viral video: '+$(if($hard){$hard.video}else{''}),'Hard video desktop organized copy: '+$deskVideo,'Storyboard: '+$(if($hard){$hard.storyboard}else{''}),'Manifest: '+$(if($hard){$hard.manifest}else{''}),'Anime live wallpaper video: '+$(if($wall){$wall.video}else{''}),'Wallpaper organized copy: '+$deskWall,'Anime source image: '+$animeImage,'Lively command: '+$lively,'Desktop organizer: '+$desktopOrg,'Auto tidy script: '+$tidyScript,'Tidy manifest: '+$tidy.manifest)
WriteUtf8 $pathsTxt (($lines -join "`r`n")+"`r`n")
New-Link (Join-Path $desktop 'R244 Anime Video Wallpaper Paths.lnk') 'explorer.exe' ('"'+(Split-Path -Parent $pathsTxt)+'"') (Split-Path -Parent $pathsTxt) '' 'Open R244 paths'|Out-Null
L ('paths_summary='+$pathsTxt+' exists='+(Test-Path -LiteralPath $pathsTxt))
$hardOk=$false; if($hard){$hardOk=((Test-Path -LiteralPath $hard.video) -and ([int64]$hard.bytes -gt 1000000))}
$wallOk=$false; if($wall){$wallOk=((Test-Path -LiteralPath $wall.video) -and ([int64]$wall.bytes -gt 500000))}
$ready=($hardOk -and $wallOk -and ($wallSet.ok -or $staticOk) -and (Test-Path -LiteralPath $tidy.manifest))
L ('hard_video_ok='+$hardOk)
L ('wallpaper_video_ok='+$wallOk)
L ('wallpaper_applied_ok='+($wallSet.ok -or $staticOk))
L ('R244_HARD_VIDEO_WALLPAPER_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;desktop=$desktop;eRoot=$lab;animeImage=$animeImage;hardVideo=$($hard.video);hardVideoBytes=$($hard.bytes);hardStoryboard=$($hard.storyboard);hardManifest=$($hard.manifest);desktopOrganizedVideo=$deskVideo;wallpaperVideo=$($wall.video);wallpaperBytes=$($wall.bytes);desktopOrganizedWallpaper=$deskWall;lively=$lively;dynamicWallpaperSetOk=$wallSet.ok;staticWallpaperFallbackOk=$staticOk;desktopOrganizer=$desktopOrg;autoTidyScript=$tidyScript;tidyManifest=$tidy.manifest;pathsSummary=$pathsTxt}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){ exit 6 }
exit 0
