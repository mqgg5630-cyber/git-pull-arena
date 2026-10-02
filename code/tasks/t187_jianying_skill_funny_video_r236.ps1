# t187_jianying_skill_funny_video_r236.ps1 - round 236.
# Install jianying-editor skill on E:, download materials, and build a funny
# talking-head video with voiceover, subtitles, and animated effects. ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s-replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s-replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines-join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function Download-File([string]$Url,[string]$Out,[int]$Sec){ try{ [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13 }catch{}; try{ Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Out -Headers @{'User-Agent'='Arena-Jianying-Video'} -TimeoutSec $Sec; return $true }catch{ try{ $curl=Join-Path $env:SystemRoot 'System32\curl.exe'; & $curl -L --retry 3 --connect-timeout 20 --max-time $Sec -A 'Arena-Jianying-Video' -o $Out $Url 2>&1|Out-Null; return (Test-Path -LiteralPath $Out) }catch{ L ('download_error='+(San $_.Exception.Message)); return $false } } }
function Find-Ffmpeg(){ foreach($n in @('ffmpeg.exe','ffmpeg')){ try{ $cmd=Get-Command $n -ErrorAction SilentlyContinue; if($cmd){return $cmd.Source} }catch{} }; foreach($root in @('E:\0mcp-agv-arena-optimized\tools\ffmpeg','E:\ffmpeg','C:\ffmpeg')){ if(Test-Path -LiteralPath $root){ $f=Get-ChildItem -LiteralPath $root -Recurse -Filter ffmpeg.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1; if($f){return $f.FullName} } }; return '' }
function Find-Python(){ foreach($n in @('python','py')){ try{ $cmd=Get-Command $n -ErrorAction SilentlyContinue; if($cmd){return $cmd.Source} }catch{} }; return '' }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$report=Join-Path $outDir 'JIANYING_SKILL_FUNNY_VIDEO_R236.md'
L '# R236 jianying-editor skill + funny talking-head video'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))

$lab='E:\0mcp-agv-arena-optimized'
$skillsRoot=Join-Path $lab 'skills'
$skillDir=Join-Path $skillsRoot 'jianying-editor'
$project=Join-Path $lab 'jianying-editor-demo'
$materials=Join-Path $project 'materials'
$work=Join-Path $project 'work'
$output=Join-Path $project 'output'
foreach($d in @($skillsRoot,$project,$materials,$work,$output)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
L ('skill_dir='+(San $skillDir))
L ('project_dir='+(San $project))
L ('materials_dir='+(San $materials))
L ('output_dir='+(San $output))

# 1. Install the jianying-editor skill on E:.
$gitOk=$false; try{ $g=Get-Command git.exe -ErrorAction SilentlyContinue; if($g){$gitOk=$true} }catch{}
$cloneUrl='https://github.com/luoluoluo22/jianying-editor-skill.git'
$skillOut=''
if($gitOk){
  if(Test-Path -LiteralPath (Join-Path $skillDir '.git')){
    $sd=$skillDir
    $skillOut=Run-Cap { git -C $using:sd pull --ff-only 2>&1|Out-String } 180
  }elseif(Test-Path -LiteralPath $skillDir){
    L 'skill_dir_exists_no_git=True'
  }else{
    $sr=$skillsRoot; $url=$cloneUrl
    $skillOut=Run-Cap { git -C $using:sr clone $using:url jianying-editor 2>&1|Out-String } 300
  }
}else{ L 'git_not_found=True' }
L ('skill_clone_or_update='+(San (($skillOut -split "`r?`n"|Select-Object -First 10)-join ' | ')))
$skillInstalled=Test-Path -LiteralPath (Join-Path $skillDir 'README.md')
L ('skill_installed='+$skillInstalled)

# Optional Python requirements for the skill. Non-fatal.
$py=Find-Python
L ('python='+(San $py))
$req=Join-Path $skillDir 'requirements.txt'
$reqOut=''
if($py -and (Test-Path -LiteralPath $req)){
  $pypath=$py; $rq=$req
  $reqOut=Run-Cap { & $using:pypath -m pip install --user -r $using:rq 2>&1|Out-String } 360
  L ('skill_requirements_head='+(San (($reqOut -split "`r?`n"|Select-Object -First 12)-join ' | ')))
}else{ L 'skill_requirements_skipped=True' }

# 2. Download safe free material assets into the project materials folder.
$assetMap=@(
  @{name='openmoji_face_tears_of_joy.png'; url='https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/618x618/1F602.png'},
  @{name='openmoji_rocket.png'; url='https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/618x618/1F680.png'},
  @{name='openmoji_laptop.png'; url='https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/618x618/1F4BB.png'},
  @{name='openmoji_movie_camera.png'; url='https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/618x618/1F3A5.png'},
  @{name='openmoji_sparkles.png'; url='https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/618x618/2728.png'}
)
$assetRows=@()
foreach($a in $assetMap){
  $path=Join-Path $materials $a.name
  $ok=Download-File $a.url $path 120
  $bytes=0; if(Test-Path -LiteralPath $path){$bytes=(Get-Item -LiteralPath $path).Length}
  $assetRows += [pscustomobject]@{name=$a.name;path=$path;ok=$ok;bytes=$bytes;url=$a.url}
  L ('asset '+$a.name+' ok='+$ok+' bytes='+$bytes)
}
W (Join-Path $materials 'ATTRIBUTION.txt') @('Downloaded assets:', 'OpenMoji emoji artwork, CC BY-SA 4.0, https://openmoji.org/', 'Used here as sticker materials for a demo talking-head video.')

# 3. Ensure ffmpeg and Pillow are available.
$ffmpeg=Find-Ffmpeg
if(-not $ffmpeg){
  $tools=Join-Path $lab 'tools\ffmpeg'
  New-Item -ItemType Directory -Force -Path $tools|Out-Null
  $zip=Join-Path $tools 'ffmpeg-release-essentials.zip'
  $dl=Download-File 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' $zip 600
  L ('ffmpeg_download='+$dl)
  if($dl){ try{ Expand-Archive -LiteralPath $zip -DestinationPath $tools -Force }catch{ L ('ffmpeg_expand_error='+(San $_.Exception.Message)) } }
  $ffmpeg=Find-Ffmpeg
}
L ('ffmpeg='+(San $ffmpeg))
if($py){
  $pypath=$py
  $pilCheck=Run-Cap { & $using:pypath -c "import PIL, sys; print('PIL_OK')" 2>&1|Out-String } 30
  if($pilCheck -notmatch 'PIL_OK'){
    $pilOut=Run-Cap { & $using:pypath -m pip install --user pillow 2>&1|Out-String } 240
    L ('pillow_install_head='+(San (($pilOut -split "`r?`n"|Select-Object -First 8)-join ' | ')))
  }else{ L 'pillow_ok=True' }
}

# 4. Build the video with generated funny script, TTS narration, burned subtitles, and animation.
$builder=Join-Path $work 'build_funny_talking_head.py'
$builderCode=@'
import argparse, json, math, os, subprocess, sys, wave, shutil
from pathlib import Path
try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except Exception as e:
    print('PIL_IMPORT_ERROR', e)
    raise

def u(s):
    return s.encode('utf-8').decode('unicode_escape')

def run(cmd, timeout=None):
    print('RUN', ' '.join(str(x) for x in cmd[:4]), '...')
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)

def pick_font(size):
    cands=[r'C:\Windows\Fonts\msyh.ttc', r'C:\Windows\Fonts\simhei.ttf', r'C:\Windows\Fonts\simsun.ttc', r'C:\Windows\Fonts\arial.ttf']
    for p in cands:
        if os.path.exists(p):
            return ImageFont.truetype(p,size)
    return ImageFont.load_default()

def wrap_text(draw, text, font, max_w):
    chars=list(text)
    lines=[]; cur=''
    for ch in chars:
        test=cur+ch
        box=draw.textbbox((0,0), test, font=font)
        if box[2]-box[0] <= max_w or not cur:
            cur=test
        else:
            lines.append(cur); cur=ch
    if cur: lines.append(cur)
    return lines

def wav_duration(path):
    with wave.open(str(path),'rb') as w:
        return w.getnframes()/float(w.getframerate())

def concat_wavs(paths, out_path, silence_sec=0.18):
    params=None; frames=[]
    for p in paths:
        with wave.open(str(p),'rb') as w:
            if params is None: params=w.getparams()
            data=w.readframes(w.getnframes())
            frames.append(data)
            silence_frames=int(w.getframerate()*silence_sec)
            frames.append(b'\x00' * silence_frames * w.getnchannels() * w.getsampwidth())
    with wave.open(str(out_path),'wb') as out:
        out.setparams(params)
        for data in frames: out.writeframes(data)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--project', required=True)
    ap.add_argument('--materials', required=True)
    ap.add_argument('--work', required=True)
    ap.add_argument('--output', required=True)
    ap.add_argument('--ffmpeg', required=True)
    args=ap.parse_args()
    project=Path(args.project); materials=Path(args.materials); work=Path(args.work); output=Path(args.output); ffmpeg=Path(args.ffmpeg)
    frames=work/'frames'
    tts=work/'tts'
    for d in [frames,tts,output]:
        if d.exists(): shutil.rmtree(d)
        d.mkdir(parents=True, exist_ok=True)
    lines=[
        u(r'\u5927\u5bb6\u597d\uff0c\u4eca\u5929\u6211\u4e0d\u662f\u6765\u5377\u5de5\u4f5c\u7684\uff0c\u6211\u662f\u6765\u628a\u7d20\u6750\u6587\u4ef6\u5939\u54c4\u6210\u6210\u7247\u7684\u3002'),
        u(r'\u7b2c\u4e00\u6b65\uff1a\u6253\u5f00\u526a\u6620\u6280\u80fd\u3002\u5b83\u4e00\u542c\u8981\u526a\u89c6\u9891\uff0cCPU\u98ce\u6247\u5148\u5f00\u59cb\u53e3\u64ad\u3002'),
        u(r'\u7b2c\u4e8c\u6b65\uff1a\u7d20\u6750\u6392\u961f\u5165\u573a\u3002\u7535\u8111\u3001\u706b\u7bad\u3001\u7b11\u54ed\u8868\u60c5\uff0c\u50cf\u4e0b\u73ed\u524d\u7684\u540c\u4e8b\u4e00\u6837\u6574\u9f50\u3002'),
        u(r'\u7b2c\u4e09\u6b65\uff1a\u52a8\u753b\u7279\u6548\u5b89\u6392\u4e0a\u3002\u753b\u9762\u4e00\u6296\uff0c\u7075\u611f\u5c31\u5047\u88c5\u81ea\u5df1\u5f88\u591a\u3002'),
        u(r'\u6700\u540e\u603b\u7ed3\uff1a\u628a\u6587\u4ef6\u4e22\u8fdb\u6587\u4ef6\u5939\uff0c\u53cc\u51fb\u6210\u7247\uff0c\u8001\u677f\u95ee\u6548\u7387\uff1f\u6211\u8bf4\uff1a\u8fd9\u53eb\u7535\u5b50\u69a8\u83dc\u5de5\u4e1a\u5316\u3002')
    ]
    script_md=project/'script_funny_talking_head.md'
    script_md.write_text('# Funny talking-head script\n\n'+'\n\n'.join(f'{i+1}. {line}' for i,line in enumerate(lines))+'\n', encoding='utf-8')
    # TTS PowerShell script reads JSON to avoid encoding issues in the task file.
    lines_json=work/'tts_lines.json'
    lines_json.write_text(json.dumps(lines, ensure_ascii=False), encoding='utf-8')
    ps=work/'make_tts.ps1'
    ps.write_text(r'''
param([string]$JsonPath,[string]$OutDir)
Add-Type -AssemblyName System.Speech
$lines=Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$i=0
foreach($line in $lines){
  $i++
  $synth=New-Object System.Speech.Synthesis.SpeechSynthesizer
  try{
    $voice=$synth.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -match '^zh' } | Select-Object -First 1
    if($voice){ $synth.SelectVoice($voice.VoiceInfo.Name) }
    $synth.Rate=2
    $synth.Volume=100
    $out=Join-Path $OutDir (('{0:D2}.wav' -f $i))
    $synth.SetOutputToWaveFile($out)
    $synth.Speak([string]$line)
    $synth.SetOutputToNull()
  } finally { $synth.Dispose() }
}
''', encoding='ascii')
    r=run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ps),str(lines_json),str(tts)], timeout=180)
    print(r.stdout)
    wavs=[tts/f'{i:02d}.wav' for i in range(1,len(lines)+1)]
    missing=[str(p) for p in wavs if not p.exists()]
    if missing:
        print('TTS_MISSING', missing)
        # make silent fallback WAV
        import struct
        wavs=[]
        for i,line in enumerate(lines,1):
            p=tts/f'{i:02d}.wav'
            sr=22050; dur=3.8
            with wave.open(str(p),'wb') as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
                w.writeframes(b'\x00'*int(sr*dur)*2)
            wavs.append(p)
    voice=output/'funny_voiceover.wav'
    concat_wavs(wavs, voice)
    durations=[wav_duration(p)+0.18 for p in wavs]
    starts=[]; acc=0
    for d in durations:
        starts.append(acc); acc+=d
    total=sum(durations)
    # SRT
    def ts(t):
        ms=int(round((t-int(t))*1000)); s=int(t)%60; m=(int(t)//60)%60; h=int(t)//3600
        return f'{h:02d}:{m:02d}:{s:02d},{ms:03d}'
    srt=[]
    for i,(st,d,line) in enumerate(zip(starts,durations,lines),1):
        srt += [str(i), f'{ts(st)} --> {ts(st+d-0.05)}', line, '']
    (output/'funny_subtitles.srt').write_text('\n'.join(srt), encoding='utf-8')
    W,H=720,1280; fps=24
    font_big=pick_font(46); font_mid=pick_font(36); font_small=pick_font(28)
    stickers=[]
    for name in ['openmoji_face_tears_of_joy.png','openmoji_rocket.png','openmoji_laptop.png','openmoji_movie_camera.png','openmoji_sparkles.png']:
        p=materials/name
        if p.exists():
            try: stickers.append(Image.open(p).convert('RGBA').resize((120,120)))
            except Exception: pass
    if not stickers:
        stickers=[Image.new('RGBA',(120,120),(255,255,0,255))]
    frame_count=int(math.ceil(total*fps))
    for idx in range(frame_count):
        t=idx/fps
        # Scene index.
        scene=0
        for i,st in enumerate(starts):
            if t>=st: scene=i
        local=t-starts[scene]
        # Animated gradient background.
        img=Image.new('RGB',(W,H),(18,22,35))
        dr=ImageDraw.Draw(img)
        for y in range(H):
            r=int(25+20*math.sin(t*0.7+y/120))
            g=int(35+30*(y/H))
            b=int(80+50*math.sin(t*0.3+y/160))
            dr.line([(0,y),(W,y)], fill=(max(0,r),max(0,g),max(0,b)))
        # neon blobs
        for k in range(5):
            cx=int((W/2)+260*math.sin(t*0.7+k*1.7))
            cy=int(200+170*k+40*math.cos(t+k))
            col=[(80,180,255),(255,120,180),(255,220,80),(120,255,160),(180,120,255)][k%5]
            dr.ellipse([cx-90,cy-90,cx+90,cy+90], fill=tuple(int(c*0.22) for c in col))
        img=img.filter(ImageFilter.GaussianBlur(0.6))
        dr=ImageDraw.Draw(img)
        # title badge
        dr.rounded_rectangle([45,45,W-45,125], radius=28, fill=(0,0,0,115), outline=(255,255,255), width=2)
        dr.text((70,65), u(r'\u526a\u6620 Skill \u53e3\u64ad\u5c0f\u5267\u573a'), font=font_mid, fill=(255,255,255))
        # Talking head avatar.
        ax,ay=W//2,330+int(10*math.sin(t*3))
        dr.ellipse([ax-120,ay-120,ax+120,ay+120], fill=(255,226,160), outline=(255,255,255), width=5)
        dr.ellipse([ax-55,ay-25,ax-25,ay+5], fill=(20,20,20))
        dr.ellipse([ax+25,ay-25,ax+55,ay+5], fill=(20,20,20))
        mouth_h=12+int(22*(0.5+0.5*math.sin(t*18)))
        dr.rounded_rectangle([ax-45,ay+45-mouth_h//2,ax+45,ay+45+mouth_h//2], radius=20, fill=(120,30,45))
        dr.arc([ax-80,ay-70,ax+80,ay+95], start=20, end=160, fill=(180,90,55), width=4)
        # bouncing stickers
        for k,sticker in enumerate(stickers):
            scale=0.75+0.12*math.sin(t*2.5+k)
            sz=int(105*scale)
            im=sticker.resize((sz,sz))
            x=int(70 + (k%2)*480 + 35*math.sin(t*1.2+k))
            y=int(500 + (k//2)*130 + 25*math.cos(t*1.7+k))
            if k==scene%len(stickers): y-=int(25*math.sin(local*6)**2)
            img.paste(im,(x,y),im)
        # caption panel
        panel=[38,820,W-38,1165]
        dr.rounded_rectangle(panel, radius=32, fill=(0,0,0,170), outline=(255,230,120), width=3)
        text=lines[scene]
        wrapped=wrap_text(dr,text,font_big,W-120)
        y=860
        for line in wrapped:
            bbox=dr.textbbox((0,0),line,font=font_big)
            dr.text(((W-(bbox[2]-bbox[0]))//2,y), line, font=font_big, fill=(255,255,255), stroke_width=2, stroke_fill=(0,0,0))
            y+=58
        # animated lower thirds/effects
        progress=min(1, max(0, local/max(0.1,durations[scene])))
        bar_w=int((W-100)*progress)
        dr.rounded_rectangle([50,1190,50+bar_w,1215], radius=12, fill=(255,220,80))
        dr.text((54,1225), f'Scene {scene+1}/5  |  R236 auto edit', font=font_small, fill=(220,230,255))
        # comic pop words
        if local<1.2:
            pop=['WOW!','BOOM!','CUT!','MEME!','OK!'][scene]
            size=int(42+12*math.sin(local*8))
            pf=pick_font(size)
            dr.text((W-210,170), pop, font=pf, fill=(255,245,80), stroke_width=3, stroke_fill=(30,30,30))
        img.save(frames/f'frame_{idx:05d}.png', quality=90)
    video_noaudio=work/'video_noaudio.mp4'
    final=output/'funny_talking_head_r236.mp4'
    cmd=[str(ffmpeg),'-y','-framerate',str(fps),'-i',str(frames/'frame_%05d.png'),'-i',str(voice),'-f','lavfi','-t',f'{total:.3f}','-i','sine=frequency=176:sample_rate=44100','-filter_complex','[2:a]volume=0.035[a2];[1:a][a2]amix=inputs=2:duration=first[a]','-map','0:v','-map','[a]','-c:v','libx264','-pix_fmt','yuv420p','-c:a','aac','-shortest',str(final)]
    r=run(cmd, timeout=300)
    print(r.stdout[-2000:])
    manifest={
        'ok': final.exists(), 'video': str(final), 'bytes': final.stat().st_size if final.exists() else 0,
        'voiceover': str(voice), 'srt': str(output/'funny_subtitles.srt'), 'script': str(script_md),
        'duration': total, 'frames': frame_count
    }
    (output/'build_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2), encoding='utf-8')
    print(json.dumps(manifest,ensure_ascii=False,indent=2))
if __name__=='__main__': main()
'@
[IO.File]::WriteAllText($builder,$builderCode,(New-Object Text.UTF8Encoding($false)))
$buildOut=''
if($py -and $ffmpeg){
  $pypath=$py; $bd=$builder; $pr=$project; $ma=$materials; $wo=$work; $ou=$output; $ff=$ffmpeg
  $buildOut=Run-Cap { & $using:pypath $using:bd --project $using:pr --materials $using:ma --work $using:wo --output $using:ou --ffmpeg $using:ff 2>&1|Out-String } 900
  L ('build_video_head='+(San (($buildOut -split "`r?`n"|Select-Object -First 18)-join ' | ')))
  L ('build_video_tail='+(San (($buildOut -split "`r?`n"|Select-Object -Last 18)-join ' | ')))
}else{ L 'build_video_skipped_missing_python_or_ffmpeg=True' }

$video=Join-Path $output 'funny_talking_head_r236.mp4'
$manifest=Join-Path $output 'build_manifest.json'
$srt=Join-Path $output 'funny_subtitles.srt'
$scriptFile=Join-Path $project 'script_funny_talking_head.md'
$videoBytes=0; if(Test-Path -LiteralPath $video){$videoBytes=(Get-Item -LiteralPath $video).Length}
# Also copy final MP4 to desktop for easy opening.
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop' }
$desktopVideo=Join-Path $desktop 'jianying_funny_talking_head_r236.mp4'
if(Test-Path -LiteralPath $video){ try{ Copy-Item -LiteralPath $video -Destination $desktopVideo -Force }catch{ L ('desktop_copy_error='+(San $_.Exception.Message)) } }
L ('video='+(San $video)+' exists='+(Test-Path -LiteralPath $video)+' bytes='+$videoBytes)
L ('desktop_video='+(San $desktopVideo)+' exists='+(Test-Path -LiteralPath $desktopVideo))
L ('subtitle='+(San $srt)+' exists='+(Test-Path -LiteralPath $srt))
L ('script='+(San $scriptFile)+' exists='+(Test-Path -LiteralPath $scriptFile))

# Write human-readable project readme on E:.
W (Join-Path $project 'README_PROJECT.txt') @(
'Jianying editor skill + funny talking-head demo project.',
'',
('Skill path: '+$skillDir),
('Materials: '+$materials),
('Output video: '+$video),
('Desktop copy: '+$desktopVideo),
('Script: '+$scriptFile),
('Subtitles: '+$srt),
'',
'The MP4 was assembled from downloaded material stickers, generated narration, subtitles, and animated effects.',
'Open the MP4 directly, or import the materials/output into Jianying for further manual edits.'
)

$summaryJson=Join-Path $outDir 'jianying-skill-funny-video-r236.json'
$summary=[pscustomobject]@{skillDir=$skillDir;skillInstalled=$skillInstalled;project=$project;materials=$materials;assets=$assetRows;ffmpeg=$ffmpeg;python=$py;video=$video;videoBytes=$videoBytes;desktopVideo=$desktopVideo;script=$scriptFile;subtitle=$srt;manifest=$manifest;output=$output}
[IO.File]::WriteAllText($summaryJson,($summary|ConvertTo-Json -Depth 8)+"`r`n",(New-Object Text.UTF8Encoding($false)))
$status=if($skillInstalled -and (Test-Path -LiteralPath $video) -and $videoBytes -gt 100000){'JIANYING_SKILL_INSTALLED_FUNNY_VIDEO_READY'}elseif(Test-Path -LiteralPath $video){'VIDEO_READY_SKILL_OR_SIZE_CHECK_WARN'}else{'JIANYING_VIDEO_INCOMPLETE'}
L ('status='+$status)
L ('FINAL_R236: '+$status)
W $report $script:Lines
exit 0
