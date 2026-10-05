# t197_ultra_hypit_wallpaper_r246.ps1 - round 246.
# Make a more complex original viral-style anime edit, replace dynamic wallpaper,
# and tidy the desktop at the end. ASCII-only.

$ErrorActionPreference='Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
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
function Find-Ffmpeg(){
  foreach($n in @('ffmpeg.exe','ffmpeg')){ try{ $c=Get-Command $n -ErrorAction SilentlyContinue; if($c){return $c.Source} }catch{} }
  $roots=@('E:\0mcp-agv-arena-optimized')
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
function Find-LivelyCandidates(){
  $roots=@()
  if($env:ProgramFiles){ $roots += (Join-Path $env:ProgramFiles 'Lively Wallpaper') }
  if(${env:ProgramFiles(x86)}){ $roots += (Join-Path ${env:ProgramFiles(x86)} 'Lively Wallpaper') }
  if($env:LOCALAPPDATA){ $roots += (Join-Path $env:LOCALAPPDATA 'Programs\Lively Wallpaper'); $roots += (Join-Path $env:LOCALAPPDATA 'Lively Wallpaper') }
  $roots += 'C:\Program Files\Lively Wallpaper'
  $out=@()
  foreach($root in $roots){
    if($root -and (Test-Path -LiteralPath $root)){
      foreach($name in @('livelycu.exe','Lively.exe','lively.exe')){ try{ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter $name -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f -and -not($out -contains $f.FullName)){ $out += $f.FullName } }catch{} }
    }
  }
  return $out
}
function Set-Lively([string[]]$Candidates,[string]$Video){
  $attempts=@()
  foreach($exe in $Candidates){
    if(-not(Test-Path -LiteralPath $exe)){ continue }
    try{ if((Split-Path -Leaf $exe) -match 'Lively\.exe'){ Start-Process -FilePath $exe -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null; Start-Sleep -Seconds 6 } }catch{}
    foreach($cmd in @('setwp --file "'+$Video+'"','setwp --file "'+$Video+'" --monitor 1')){
      $r=Run-CmdLine ('"'+$exe+'" '+$cmd) '' 240
      $attempts += [pscustomobject]@{exe=$exe;cmd=$cmd;exit=$r.code;tail=(TailText (San $r.text) 8)}
      if($r.code -eq 0){ return [pscustomobject]@{ok=$true;exe=$exe;cmd=$cmd;attempts=$attempts} }
    }
  }
  return [pscustomobject]@{ok=$false;exe='';cmd='';attempts=$attempts}
}
function Tidy-Desktop([string]$Desktop,[string]$OrgRoot){
  New-Item -ItemType Directory -Force -Path $OrgRoot|Out-Null
  foreach($c in @('01-Apps-Shortcuts','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){ New-Item -ItemType Directory -Force -Path (Join-Path $OrgRoot $c)|Out-Null }
  $keep=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer','Douyin.lnk','Xiaohongshu.lnk','WeChat Official Account.lnk','Jianying.lnk','DeskBox Cute.lnk','Hypit.lnk','AI Job Search.lnk','Career Ops.lnk','xiutu.skill.lnk','R241 Paths and Tools.lnk','Hypit Hard Anime Viral R244.lnk','Anime Live Wallpaper R244.lnk','Hypit Ultra Anime Viral R246.lnk','Anime Live Wallpaper R246.lnk','R246 Ultra Anime Paths.lnk','Auto Tidy Desktop.lnk')
  $moves=@()
  foreach($it in Get-ChildItem -LiteralPath $Desktop -Force -ErrorAction SilentlyContinue){
    if($keep -contains $it.Name){ continue }
    if(($it.Attributes -band [IO.FileAttributes]::System) -or ($it.Attributes -band [IO.FileAttributes]::Hidden)){ continue }
    $cat='08-Misc'; if($it.PSIsContainer){$cat='07-Old-Folders'} else { $ext=$it.Extension.ToLowerInvariant(); if($ext -in @('.lnk','.url','.cmd','.bat','.ps1')){$cat='01-Apps-Shortcuts'} elseif($ext -in @('.mp4','.mov','.mkv','.avi','.srt')){$cat='03-Video-Creation'} elseif($ext -in @('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')){$cat='04-Images-ID-Photos'} elseif($ext -in @('.doc','.docx','.pdf','.xls','.xlsx','.ppt','.pptx','.txt','.md','.csv')){$cat='05-Documents'} elseif($ext -in @('.zip','.rar','.7z','.exe','.msi','.msix','.appx')){$cat='06-Archives-Installers'} }
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
$report=Join-Path $outDir 'R246_ULTRA_HYPIT_ANIME_WALLPAPER.md'; $jsonReport=Join-Path $outDir 'r246-ultra-hypit-anime-wallpaper.json'
$lab='E:\0mcp-agv-arena-optimized'; $project=Join-Path $lab 'video\hypit-ultra-anime-viral-r246'; $wallDir=Join-Path $lab 'wallpapers\anime-live-r246'; $imageDir=Join-Path $lab 'images\anime-wallpaper-r246'; $tools=Join-Path $lab 'tools\desktop-organizer'
foreach($d in @($project,$wallDir,$imageDir,$tools)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
$asset=Join-Path $repo 'deliverable\assets\anime_ultra_dynamic_wallpaper_r246.png'
$image=Join-Path $imageDir 'anime_ultra_dynamic_wallpaper_r246.png'
if(Test-Path -LiteralPath $asset){ Copy-Item -LiteralPath $asset -Destination $image -Force }
L '# R246 ultra Hypit-style anime viral edit + wallpaper'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('desktop_dir='+$desktop)
L ('asset='+$asset+' exists='+(Test-Path -LiteralPath $asset))
L ('source_image='+$image+' exists='+(Test-Path -LiteralPath $image))
$py=Find-Cmd @('python.exe','python','py.exe','py')
$ff=Ensure-Ffmpeg $py
L ('python='+$py)
L ('ffmpeg='+$ff+' exists='+($ff -and (Test-Path -LiteralPath $ff)))
if($py){
  $pip=Run-CmdLine ('"'+$py+'" -m pip install --user pillow') '' 420
  L ('pillow_install_exit='+$pip.code)
  L ('pillow_install_tail='+(TailText (San $pip.text) 8))
}
$renderer=Join-Path $project 'render_ultra_hypit_anime.py'
$pycode=@'
import argparse, json, math, os, random, struct, subprocess, wave
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter

def font(size, bold=False):
    cands=[r"C:\Windows\Fonts\segoeuib.ttf", r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\arial.ttf"] if bold else [r"C:\Windows\Fonts\segoeui.ttf", r"C:\Windows\Fonts\arial.ttf"]
    for p in cands:
        if os.path.exists(p):
            return ImageFont.truetype(p, size=size)
    return ImageFont.load_default()

def cover(img, size, zoom=1.0, pan=(0,0)):
    W,H=size; iw,ih=img.size; ratio=W/H; ir=iw/ih
    if ir>ratio:
        ch=ih/zoom; cw=ch*ratio
    else:
        cw=iw/zoom; ch=cw/ratio
    cw=min(cw,iw); ch=min(ch,ih)
    mx=iw-cw; my=ih-ch
    x=max(0,min(mx,mx/2+pan[0]*mx/2)); y=max(0,min(my,my/2+pan[1]*my/2))
    return img.crop((int(x),int(y),int(x+cw),int(y+ch))).resize(size, Image.Resampling.LANCZOS)

def glow_text(draw, xy, text, fnt, fill, anchor='mm', stroke=2):
    x,y=xy
    for r,a in [(8,40),(4,70),(2,110)]:
        draw.text((x,y), text, font=fnt, fill=(fill[0],fill[1],fill[2],a), anchor=anchor, stroke_width=stroke+r, stroke_fill=(fill[0],fill[1],fill[2],max(20,a//2)))
    draw.text((x,y), text, font=fnt, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=(6,8,24,220))

def rounded(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)

def make_audio(path, dur, bpm=150):
    sr=44100; samples=int(sr*dur)
    w=wave.open(str(path),'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
    for n in range(samples):
        t=n/sr; beat=(t*bpm/60)%1.0; bar=(t*bpm/60)%4.0
        kick=0.0
        if beat<0.16:
            kick=math.sin(2*math.pi*(92-50*beat/0.16)*t)*math.exp(-22*beat)
        sn=0.0
        if 1.95<bar<2.08 or 3.95<bar<4.0:
            sn=(random.random()*2-1)*0.22*math.exp(-32*((bar%1)))
        hat=(0.11 if beat<0.055 else 0)*math.sin(2*math.pi*7600*t)
        lead=0.13*math.sin(2*math.pi*(440+110*math.sin(t*1.7))*t)
        arp=0.10*math.sin(2*math.pi*(330*(1+[0,.25,.5,.75][int((t*8)%4)]))*t)
        bass=0.18*math.sin(2*math.pi*55*t)
        val=max(-0.95,min(0.95,0.72*kick+sn+hat+lead+arp+bass))
        iv=int(val*32767)
        w.writeframes(struct.pack('<hh',iv,iv))
    w.close()

def render_video(src, outdir, ffmpeg):
    outdir=Path(outdir); frames=outdir/'frames_ultra'; frames.mkdir(parents=True, exist_ok=True)
    for f in frames.glob('*.jpg'): f.unlink()
    base=Image.open(src).convert('RGB')
    W,H=720,1280; fps=30; dur=32; total=fps*dur
    big=font(58,True); med=font(38,True); small=font(26,False); tiny=font(19,False)
    rnd=random.Random(246)
    petals=[(rnd.random(),rnd.random(),rnd.random()*2+0.35,rnd.random()*6.28,rnd.random()*7+2) for _ in range(260)]
    scene_names=['OPEN LOOP','AI DREAM CUT','MULTI PANEL','SPEED RAMP','REVEAL','LOOP WALLPAPER']
    for i in range(total):
        t=i/fps; beat=(t*2.5)%1.0; scene=min(5,int(t/(dur/6)))
        zoom=1.05+0.09*math.sin(t*0.42)+scene*0.018+0.018*math.sin(beat*math.pi)
        bg=cover(base,(W,H),zoom,(math.sin(t*.23+scene)*.62, math.cos(t*.19)*.42))
        bg=ImageEnhance.Color(bg).enhance(1.20+0.18*math.sin(t*.7))
        im=bg.convert('RGBA')
        d=ImageDraw.Draw(im,'RGBA')
        d.rectangle((0,0,W,H), fill=(5,7,24,48+scene*5))
        if scene==0:
            for r in range(13):
                rad=130+r*70+28*math.sin(t*3.2+r)
                col=(110,220,255,90-r*4)
                d.ellipse((W/2-rad/2,520-rad/2,W/2+rad/2,520+rad/2), outline=col, width=3)
            glow_text(d,(W/2,154),'STOP SCROLLING',big,(255,245,255,255))
            glow_text(d,(W/2,238),'THIS IS NOT A TEMPLATE',small,(150,235,255,245),stroke=1)
        elif scene==1:
            for k in range(5):
                x=70+k*115+25*math.sin(t*2+k); y=150+k*70
                crop=cover(base,(180,330),1.35+0.05*k,(math.sin(t+k),math.cos(t*0.8+k)))
                card=Image.new('RGBA',(200,360),(255,255,255,205)); card.alpha_composite(crop.convert('RGBA'),(10,15))
                card=card.rotate(-18+k*9+math.sin(t*3+k)*4, resample=Image.Resampling.BICUBIC, expand=True)
                im.alpha_composite(card,(int(x),int(y)))
            glow_text(d,(W/2,1040),'6 LAYERS / BEAT SYNC',med,(255,190,230,255),stroke=1)
        elif scene==2:
            for k in range(6):
                x=k*W//6; crop=cover(base,(W//6+20,H-220),1.55+0.06*k,(math.sin(t+k),math.cos(t+k)))
                im.alpha_composite(crop.convert('RGBA'),(x,120+int(26*math.sin(t*3+k))))
                d.rectangle((x,118,x+W//6,H-100), outline=(120,230,255,170), width=3)
            glow_text(d,(W/2,96),'CLONE THE STRUCTURE',med,(255,255,255,255),stroke=1)
        elif scene==3:
            for k in range(18):
                y=int((k*86+t*190)%H); d.line((0,y,W,y-220), fill=(255,255,255,56), width=3)
            for r in range(18):
                rad=90+r*58+30*math.sin(t*6+r)
                d.ellipse((W/2-rad/2,690-rad/2,W/2+rad/2,690+rad/2), outline=(255,110,220,150-r*5), width=2)
            glow_text(d,(W/2,1120),'SPEED RAMP MOMENT',med,(120,235,255,255),stroke=1)
        elif scene==4:
            left=cover(base,(W//2,H),1.35,(-.7,0)); right=cover(base,(W//2,H),1.12,(.7,0))
            left=ImageEnhance.Brightness(left).enhance(.55).convert('RGBA'); right=ImageEnhance.Contrast(right).enhance(1.45).convert('RGBA')
            im.alpha_composite(left,(0,0)); im.alpha_composite(right,(W//2,0)); d.line((W//2,0,W//2,H), fill=(255,255,255,230), width=5)
            glow_text(d,(W*.25,120),'BEFORE',med,(210,220,255,255),stroke=1); glow_text(d,(W*.75,120),'AFTER',med,(255,180,230,255),stroke=1)
        else:
            for r in range(20):
                rad=150+r*65+20*math.sin(t*5+r)
                d.ellipse((W/2-rad/2,H/2-rad/2,W/2+rad/2,H/2+rad/2), outline=(160,235,255,150-r*5), width=2)
            glow_text(d,(W/2,150),'LIVE WALLPAPER READY',med,(255,255,255,255),stroke=1)
            glow_text(d,(W/2,1130),'SAVE / REMIX / POST',med,(255,160,215,255),stroke=1)
        for px,py,sp,ph,sz in petals:
            x=int((px*W+42*math.sin(t*0.9+ph))%W); y=int(((py*H+t*260*sp)%(H+120))-60)
            col=(255,170,225,170) if int(ph*10)%3==0 else ((125,230,255,145) if int(ph*10)%3==1 else (255,245,170,120))
            d.ellipse((x,y,x+sz*2,y+sz), fill=col)
        if i%18<2:
            d.rectangle((0,0,W,H), fill=(255,255,255,30))
        d.rounded_rectangle((42,H-85,W-42,H-32), radius=22, fill=(8,10,30,178), outline=(255,255,255,120), width=2)
        d.text((W/2,H-58), scene_names[scene]+'  |  HYPIT STYLE WORKFLOW', font=tiny, anchor='mm', fill=(245,245,255,235))
        im.convert('RGB').save(frames/f'frame_{i:04d}.jpg', quality=92)
    audio=outdir/'original_ultra_beat.wav'; make_audio(audio,dur)
    video=outdir/'hypit_ultra_anime_viral_r246.mp4'
    subprocess.run([ffmpeg,'-y','-framerate',str(fps),'-i',str(frames/'frame_%04d.jpg'),'-i',str(audio),'-shortest','-c:v','libx264','-preset','medium','-crf','16','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k',str(video)], check=False)
    storyboard=outdir/'hypit_ultra_viral_storyboard.svml'
    storyboard.write_text('<video aspect="9:16" duration="32" style="ultra-viral-anime"><scene seconds="0-5.3" name="open-loop"/><scene seconds="5.3-10.6" name="ai-dream-cut"/><scene seconds="10.6-16" name="multi-panel"/><scene seconds="16-21.3" name="speed-ramp"/><scene seconds="21.3-26.6" name="before-after"/><scene seconds="26.6-32" name="wallpaper-reveal"/></video>', encoding='utf-8')
    manifest=outdir/'ultra_viral_manifest.json'
    manifest.write_text(json.dumps({'workflow':'hypit-ultra-viral-original','note':'original anime visual, synthetic beat, no copied face/music/watermark','layers':['ken-burns','glow text','rotating cards','multi-panel split','radial tunnel','particles','beat flashes','original audio'], 'duration':dur,'fps':fps}, ensure_ascii=False, indent=2), encoding='utf-8')
    return video, storyboard, manifest

def render_wallpaper(src, outdir, ffmpeg):
    outdir=Path(outdir); frames=outdir/'frames_wall_loop'; frames.mkdir(parents=True, exist_ok=True)
    for f in frames.glob('*.jpg'): f.unlink()
    base=Image.open(src).convert('RGB')
    W,H=1600,900; fps=30; dur=20; total=fps*dur
    rnd=random.Random(247); stars=[(rnd.random(),rnd.random(),rnd.random()*0.55+0.12,rnd.random()*6.28,rnd.random()*4+1) for _ in range(360)]
    for i in range(total):
        t=i/fps
        im=cover(base,(W,H),1.035+0.018*math.sin(t*.45),(math.sin(t*.22)*.28,math.cos(t*.19)*.18)).convert('RGBA')
        d=ImageDraw.Draw(im,'RGBA')
        d.rectangle((0,0,W,H), fill=(3,5,20,32))
        for x,y,sp,ph,sz in stars:
            xx=int((x*W+32*math.sin(t*.55+ph))%W); yy=int(((y*H+t*40*sp)%(H+40))-20); a=int(90+85*math.sin(t*1.2+ph)); a=max(25,min(205,a))
            d.ellipse((xx,yy,xx+sz*2,yy+sz), fill=(255,180,230,a))
        for r in range(11):
            rad=250+r*150+30*math.sin(t*.8+r)
            d.ellipse((W/2-rad/2,H/2-rad/2,W/2+rad/2,H/2+rad/2), outline=(120,225,255,32), width=2)
        im.convert('RGB').save(frames/f'wall_{i:04d}.jpg', quality=93)
    video=outdir/'anime_ultra_live_wallpaper_r246.mp4'
    subprocess.run([ffmpeg,'-y','-framerate',str(fps),'-i',str(frames/'wall_%04d.jpg'),'-f','lavfi','-i','anullsrc=channel_layout=stereo:sample_rate=44100','-shortest','-t',str(dur),'-c:v','libx264','-preset','medium','-crf','17','-pix_fmt','yuv420p','-c:a','aac','-b:a','96k',str(video)], check=False)
    return video

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--image'); ap.add_argument('--project'); ap.add_argument('--wall'); ap.add_argument('--ffmpeg'); ap.add_argument('--json')
    a=ap.parse_args(); Path(a.project).mkdir(parents=True, exist_ok=True); Path(a.wall).mkdir(parents=True, exist_ok=True)
    v,story,manifest=render_video(a.image,a.project,a.ffmpeg); w=render_wallpaper(a.image,a.wall,a.ffmpeg)
    data={'video':str(v),'videoBytes':v.stat().st_size if v.exists() else 0,'storyboard':str(story),'manifest':str(manifest),'wallpaper':str(w),'wallpaperBytes':w.stat().st_size if w.exists() else 0}
    Path(a.json).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(data, ensure_ascii=False))
if __name__=='__main__': main()
'@
WriteUtf8 $renderer $pycode
$renderJson=Join-Path $project 'render_result.json'
$renderOut=@{code=999;text='not-run'}
if($py -and $ff -and (Test-Path -LiteralPath $image)){
  $cmd='"'+$py+'" "'+$renderer+'" --image "'+$image+'" --project "'+$project+'" --wall "'+$wallDir+'" --ffmpeg "'+$ff+'" --json "'+$renderJson+'"'
  $renderOut=Run-CmdLine $cmd $project 2400
}
L ('render_exit='+$renderOut.code)
L ('render_tail='+(TailText (San $renderOut.text) 20))
$res=$null; if(Test-Path -LiteralPath $renderJson){ try{ $res=Get-Content -LiteralPath $renderJson -Raw -Encoding UTF8 | ConvertFrom-Json }catch{} }
$video=''; $videoBytes=0; $wall=''; $wallBytes=0; $story=''; $manifest=''
if($res){ $video=[string]$res.video; $videoBytes=[int64]$res.videoBytes; $wall=[string]$res.wallpaper; $wallBytes=[int64]$res.wallpaperBytes; $story=[string]$res.storyboard; $manifest=[string]$res.manifest }
L ('ultra_video='+$video)
L ('ultra_video_exists='+(Test-Path -LiteralPath $video))
L ('ultra_video_bytes='+$videoBytes)
L ('ultra_storyboard='+$story+' exists='+(Test-Path -LiteralPath $story))
L ('ultra_manifest='+$manifest+' exists='+(Test-Path -LiteralPath $manifest))
L ('wallpaper_video='+$wall)
L ('wallpaper_video_exists='+(Test-Path -LiteralPath $wall))
L ('wallpaper_video_bytes='+$wallBytes)
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'; $vidFolder=Join-Path $org '03-Video-Creation'; $wallFolder=Join-Path $org '09-Anime-Wallpapers'; New-Item -ItemType Directory -Force -Path $vidFolder,$wallFolder|Out-Null
$deskVideo=Join-Path $vidFolder 'hypit_ultra_anime_viral_r246.mp4'; $deskWall=Join-Path $wallFolder 'anime_ultra_live_wallpaper_r246.mp4'
if(Test-Path -LiteralPath $video){ Copy-Item -LiteralPath $video -Destination $deskVideo -Force; New-Link (Join-Path $desktop 'Hypit Ultra Anime Viral R246.lnk') $video '' (Split-Path -Parent $video) $video 'Open ultra anime viral video'|Out-Null }
if(Test-Path -LiteralPath $wall){ Copy-Item -LiteralPath $wall -Destination $deskWall -Force; New-Link (Join-Path $desktop 'Anime Live Wallpaper R246.lnk') $wall '' (Split-Path -Parent $wall) $wall 'Open anime live wallpaper'|Out-Null }
$cands=Find-LivelyCandidates; foreach($c in $cands){ L ('lively_candidate='+$c) }
$set=Set-Lively $cands $wall
L ('dynamic_wallpaper_set_ok='+$set.ok)
L ('dynamic_wallpaper_exe='+$set.exe)
L ('dynamic_wallpaper_cmd='+$set.cmd)
$i=0; foreach($a in $set.attempts){ L ('dynamic_attempt_'+$i+'_exit='+$a.exit); L ('dynamic_attempt_'+$i+'_tail='+$a.tail); $i++ }
$tidy=Tidy-Desktop $desktop $org
L ('desktop_organized_video='+$deskVideo+' exists='+(Test-Path -LiteralPath $deskVideo))
L ('desktop_organized_wallpaper='+$deskWall+' exists='+(Test-Path -LiteralPath $deskWall))
L ('desktop_tidy_manifest='+$tidy.manifest)
L ('desktop_tidy_moved_count='+$tidy.moved)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))
$pathsDir=Join-Path $lab 'r246-ultra-anime-video-wallpaper'; New-Item -ItemType Directory -Force -Path $pathsDir|Out-Null
$pathsTxt=Join-Path $pathsDir 'PATHS.txt'
$pathLines=@('Ultra anime viral video: '+$video,'Video bytes: '+$videoBytes,'Organized desktop video: '+$deskVideo,'Hypit-style storyboard: '+$story,'Workflow manifest: '+$manifest,'Anime dynamic wallpaper: '+$wall,'Wallpaper bytes: '+$wallBytes,'Organized wallpaper copy: '+$deskWall,'Lively command: '+$set.exe+' '+$set.cmd,'Desktop organizer: '+$org,'Auto tidy manifest: '+$tidy.manifest)
WriteUtf8 $pathsTxt (($pathLines -join "`r`n")+"`r`n")
New-Link (Join-Path $desktop 'R246 Ultra Anime Paths.lnk') 'explorer.exe' ('"'+$pathsDir+'"') $pathsDir '' 'Open R246 paths'|Out-Null
L ('paths_summary='+$pathsTxt+' exists='+(Test-Path -LiteralPath $pathsTxt))
$videoOk=((Test-Path -LiteralPath $video) -and ([int64]$videoBytes -gt 20000000))
$wallOk=((Test-Path -LiteralPath $wall) -and ([int64]$wallBytes -gt 10000000))
$ready=($videoOk -and $wallOk -and $set.ok -and (Test-Path -LiteralPath $tidy.manifest))
L ('ultra_video_ok='+$videoOk)
L ('wallpaper_video_ok='+$wallOk)
L ('dynamic_wallpaper_ok='+$set.ok)
L ('desktop_tidy_ok='+(Test-Path -LiteralPath $tidy.manifest))
L ('R246_ULTRA_HYPIT_WALLPAPER_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;desktop=$desktop;eRoot=$lab;sourceImage=$image;video=$video;videoBytes=$videoBytes;storyboard=$story;manifest=$manifest;organizedVideo=$deskVideo;wallpaper=$wall;wallpaperBytes=$wallBytes;organizedWallpaper=$deskWall;dynamicWallpaperSetOk=$set.ok;dynamicWallpaperExe=$set.exe;dynamicWallpaperCmd=$set.cmd;desktopOrganizer=$org;tidyManifest=$tidy.manifest;pathsSummary=$pathsTxt}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){ exit 6 }
exit 0
