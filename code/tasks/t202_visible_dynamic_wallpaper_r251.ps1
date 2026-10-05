# t202_visible_dynamic_wallpaper_r251.ps1 - round 251.
# Make the wallpaper visibly dynamic on the actual desktop, not only by CLI exit code.
# Creates a persistent desktop-hosted animated wallpaper and verifies it by screen diff.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s-replace '[A-Za-z0-9+/_=-]{48,}','[REDACTED]'}catch{}; return $s }
function TailText([string]$s,[int]$n){ if($null -eq $s){return ''}; return (($s -split "`r?`n" | Select-Object -Last $n) -join ' | ') }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function WriteUtf8([string]$p,[string]$txt){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,$txt,(New-Object Text.UTF8Encoding($false))) }
function W([string]$p,[string[]]$lines){ WriteUtf8 $p (($lines -join "`r`n")+"`r`n") }
function Run-ExeArgs([string]$Exe,[string[]]$Args,[int]$TimeoutSec){
  if(-not $Exe -or -not(Test-Path -LiteralPath $Exe)){ return @{code=127;text='missing exe'} }
  $job=Start-Job -ScriptBlock { param($e,$a); & $e @a 2>&1 | Out-String; $c=$LASTEXITCODE; if($null -eq $c){$c=0}; Write-Output ('===EXITCODE:'+[string]$c) } -ArgumentList $Exe,$Args
  if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{code=-1;text='TIMEOUT'} }
  $txt=(Receive-Job $job 2>&1 | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
  $code=0; if($txt -match '===EXITCODE:(-?\d+)'){ $code=[int]$Matches[1]; $txt=($txt -replace '===EXITCODE:-?\d+\s*','').Trim() }
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
function Stop-OldHosts([string]$Needle){
  $stopped=0
  try{
    $ps=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($Needle) }
    foreach($p in $ps){ try{ Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue; $stopped++ }catch{} }
  }catch{}
  return $stopped
}
function Capture-Screen([string]$Path){
  try{
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $b=[System.Windows.Forms.SystemInformation]::VirtualScreen
    if($b.Width -le 0 -or $b.Height -le 0){ return @{ok=$false;err='bad screen bounds';path=$Path;width=0;height=0} }
    $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size)
    $bmp.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    return @{ok=(Test-Path -LiteralPath $Path);err='';path=$Path;width=$b.Width;height=$b.Height;left=$b.Left;top=$b.Top}
  }catch{ return @{ok=$false;err=(San $_.Exception.Message);path=$Path;width=0;height=0} }
}
function Compare-Images([string]$A,[string]$B){
  try{
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $ia=[System.Drawing.Bitmap]::FromFile($A); $ib=[System.Drawing.Bitmap]::FromFile($B)
    $w=[Math]::Min($ia.Width,$ib.Width); $h=[Math]::Min($ia.Height,$ib.Height)
    $step=[Math]::Max(4,[int]([Math]::Min($w,$h)/240))
    $samples=0; $changed=0; [int64]$total=0
    for($y=0;$y -lt $h;$y+=$step){ for($x=0;$x -lt $w;$x+=$step){ $ca=$ia.GetPixel($x,$y); $cb=$ib.GetPixel($x,$y); $d=[Math]::Abs([int]$ca.R-[int]$cb.R)+[Math]::Abs([int]$ca.G-[int]$cb.G)+[Math]::Abs([int]$ca.B-[int]$cb.B); $total += $d; $samples++; if($d -gt 30){$changed++} } }
    $ia.Dispose(); $ib.Dispose()
    $ratio=0.0; $avg=0.0; if($samples -gt 0){$ratio=[double]$changed/[double]$samples; $avg=[double]$total/[double]$samples}
    return @{ok=$true;samples=$samples;changed=$changed;ratio=$ratio;avgDiff=$avg;step=$step;width=$w;height=$h}
  }catch{ return @{ok=$false;err=(San $_.Exception.Message);samples=0;changed=0;ratio=0.0;avgDiff=0.0} }
}
function Tidy-Desktop([string]$Desktop,[string]$OrgRoot){
  New-Item -ItemType Directory -Force -Path $OrgRoot|Out-Null
  foreach($c in @('01-Apps-Shortcuts','03-Video-Creation','04-Images-ID-Photos','05-Documents','06-Archives-Installers','07-Old-Folders','08-Misc','09-Anime-Wallpapers')){ New-Item -ItemType Directory -Force -Path (Join-Path $OrgRoot $c)|Out-Null }
  $keep=@('desktop.ini','OpenSpeedy.lnk','OpenSpeedy.bat','OpenSpeedy','DeskBox-Cute-Desktop-Organizer','DeskBox Cute.lnk','Auto Tidy Desktop.lnk','Cute Anime Dynamic R247.lnk','Cute Anime Live Project R247.lnk','R247 Cute Dynamic Wallpaper Paths.lnk','Cute Anime Dynamic Wallpaper START.lnk','Cute Anime Dynamic Wallpaper STOP.lnk','Cute Anime Dynamic Wallpaper Folder.lnk','R251 Visible Dynamic Wallpaper Report.lnk')
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
$report=Join-Path $outDir 'R251_VISIBLE_DYNAMIC_WALLPAPER.md'; $jsonReport=Join-Path $outDir 'r251-visible-dynamic-wallpaper.json'
$lab='E:\0mcp-agv-arena-optimized'
$root=Join-Path $lab 'wallpapers\cute-anime-live-r251'
$hostDir=Join-Path $root 'visible-host'
$proofDir=Join-Path $root 'proof'
foreach($d in @($root,$hostDir,$proofDir)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$desktop=[Environment]::GetFolderPath('Desktop'); if(-not $desktop -or -not(Test-Path -LiteralPath $desktop)){ $desktop=Join-Path $env:USERPROFILE 'Desktop'; New-Item -ItemType Directory -Force -Path $desktop|Out-Null }
$asset=Join-Path $repo 'deliverable\assets\cute_anime_live_wallpaper_r247.png'
$bg=Join-Path $hostDir 'background.png'
if(Test-Path -LiteralPath $asset){ Copy-Item -LiteralPath $asset -Destination $bg -Force }
L '# R251 visible dynamic desktop wallpaper'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('diagnosis=previous rounds trusted Lively exit/process; this round verifies actual visible desktop pixels over time')
L ('desktop_dir='+$desktop)
L ('host_dir='+$hostDir)
L ('background='+$bg+' exists='+(Test-Path -LiteralPath $bg))

$hostScript=Join-Path $hostDir 'CuteAnimeDynamicWallpaperHost.ps1'
$hostLog=Join-Path $hostDir 'CuteAnimeDynamicWallpaperHost.log'
$hostCode=@'
$ErrorActionPreference='Continue'
$HostDir=Split-Path -Parent $MyInvocation.MyCommand.Path
$ImagePath=Join-Path $HostDir 'background.png'
$LogPath=Join-Path $HostDir 'CuteAnimeDynamicWallpaperHost.log'
function Log($m){ try{ Add-Content -LiteralPath $LogPath -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')+' '+$m) -Encoding UTF8 }catch{} }
try{
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$pinvoke=@"
using System;
using System.Runtime.InteropServices;
public class Win32WallpaperApi {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
  [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string className, string windowName);
  [DllImport("user32.dll", SetLastError=true)] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
  [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
  [DllImport("user32.dll", SetLastError=true)] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
}
"@
Add-Type $pinvoke
$render=@"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Windows.Forms;
public class CuteAnimeWallpaperForm : Form {
  private Image bg;
  private Timer timer;
  private double t;
  private Random rand = new Random(251);
  private Particle[] ps;
  private struct Particle { public float x; public float y; public float s; public float z; public int k; public float p; }
  public CuteAnimeWallpaperForm(string imagePath, Rectangle bounds) {
    this.FormBorderStyle = FormBorderStyle.None;
    this.StartPosition = FormStartPosition.Manual;
    this.Bounds = bounds;
    this.ShowInTaskbar = false;
    this.BackColor = Color.FromArgb(10,10,32);
    this.DoubleBuffered = true;
    if(File.Exists(imagePath)) bg = Image.FromFile(imagePath);
    ps = new Particle[260];
    for(int i=0;i<ps.Length;i++){
      ps[i].x=(float)rand.NextDouble(); ps[i].y=(float)rand.NextDouble(); ps[i].s=(float)(0.35+rand.NextDouble()*1.9); ps[i].z=(float)(2+rand.NextDouble()*18); ps[i].k=i%3; ps[i].p=(float)(rand.NextDouble()*6.2831853);
    }
    timer = new Timer(); timer.Interval = 25; timer.Tick += (s,e)=>{ t += 0.025; this.Invalidate(); }; timer.Start();
  }
  protected override CreateParams CreateParams { get { CreateParams cp = base.CreateParams; cp.ExStyle |= 0x00000080; return cp; } }
  protected override void OnPaint(PaintEventArgs e) {
    Graphics g=e.Graphics; g.SmoothingMode=SmoothingMode.AntiAlias; g.InterpolationMode=InterpolationMode.HighQualityBicubic;
    int W=this.ClientSize.Width; int H=this.ClientSize.Height;
    using(LinearGradientBrush b=new LinearGradientBrush(new Rectangle(0,0,W,H), Color.FromArgb(255,20,12,55), Color.FromArgb(255,255,120,205), 35f)) g.FillRectangle(b,0,0,W,H);
    if(bg!=null){
      float scale=Math.Max((float)W/bg.Width,(float)H/bg.Height)*(1.055f+(float)(0.025*Math.Sin(t*0.45)));
      float bw=bg.Width*scale, bh=bg.Height*scale;
      float x=(W-bw)/2f+(float)(Math.Sin(t*0.22)*26.0); float y=(H-bh)/2f+(float)(Math.Cos(t*0.18)*16.0);
      g.DrawImage(bg,x,y,bw,bh);
    }
    using(LinearGradientBrush veil=new LinearGradientBrush(new Rectangle(0,0,W,H), Color.FromArgb(42,255,150,220), Color.FromArgb(38,95,225,255), 115f)) g.FillRectangle(veil,0,0,W,H);
    using(SolidBrush aur1=new SolidBrush(Color.FromArgb(70,255,110,205))) g.FillEllipse(aur1,(int)(W*.07+Math.Sin(t*.55)*80),(int)(H*.08+Math.Cos(t*.4)*45),(int)(W*.42),(int)(H*.34));
    using(SolidBrush aur2=new SolidBrush(Color.FromArgb(55,80,230,255))) g.FillEllipse(aur2,(int)(W*.55+Math.Cos(t*.38)*90),(int)(H*.08+Math.Sin(t*.5)*50),(int)(W*.36),(int)(H*.36));
    for(int i=0;i<ps.Length;i++){
      Particle p=ps[i]; float x=0,y=0;
      if(p.k==0){
        x=(float)(((p.x*W)+(Math.Sin(t*p.s+p.p)*95)+(t*48*p.s))%(W+90))-45; y=(float)(((p.y*H)+(t*85*p.s))%(H+80))-40;
        GraphicsState st=g.Save(); g.TranslateTransform(x,y); g.RotateTransform((float)((t*120*p.s+p.p*60)%360));
        using(SolidBrush br=new SolidBrush(Color.FromArgb(185,255,160,220))) g.FillEllipse(br,-p.z*.55f,-p.z*.28f,p.z*1.1f,p.z*.56f); g.Restore(st);
      } else if(p.k==1){
        x=(float)(((p.x*W)+(t*34*p.s))%(W+180))-90; y=(float)(((p.y*H)+(t*470*p.s))%(H+90))-45;
        using(Pen pen=new Pen(Color.FromArgb(105,185,238,255),1.6f)) g.DrawLine(pen,x,y,x-22,y+58);
      } else {
        x=(float)(((p.x*W)+(Math.Cos(t*.75*p.s+p.p)*32))%W); y=(float)(((p.y*H)+(Math.Sin(t*.9*p.s+p.p)*28))%H);
        int a=(int)(95+120*Math.Abs(Math.Sin(t*1.9*p.s+p.p))); float r=(float)(1.5+p.z*.22*Math.Abs(Math.Sin(t*p.s+p.p)));
        using(SolidBrush br=new SolidBrush(Color.FromArgb(a,255,255,255))) g.FillEllipse(br,x-r,y-r,r*2,r*2);
      }
    }
    float cx=W*.84f+(float)Math.Sin(t*1.4)*22f; float cy=H*.78f+(float)Math.Cos(t*1.7)*28f; float cr=Math.Min(W,H)*.055f;
    using(SolidBrush glow=new SolidBrush(Color.FromArgb(65,255,115,220))) g.FillEllipse(glow,cx-cr*2.6f,cy-cr*2.2f,cr*5.2f,cr*4.4f);
    using(SolidBrush body=new SolidBrush(Color.FromArgb(225,255,235,252))) g.FillEllipse(body,cx-cr,cy-cr*.72f,cr*2f,cr*1.44f);
    using(SolidBrush ear=new SolidBrush(Color.FromArgb(220,255,225,248))){ PointF[] l={new PointF(cx-cr*.74f,cy-cr*.48f),new PointF(cx-cr*.34f,cy-cr*1.38f),new PointF(cx-cr*.05f,cy-cr*.48f)}; PointF[] r={new PointF(cx+cr*.05f,cy-cr*.48f),new PointF(cx+cr*.36f,cy-cr*1.38f),new PointF(cx+cr*.74f,cy-cr*.48f)}; g.FillPolygon(ear,l); g.FillPolygon(ear,r); }
    using(Pen line=new Pen(Color.FromArgb(200,255,110,205),3f)) { g.DrawArc(line,cx-cr*.45f,cy-cr*.15f,cr*.34f,cr*.3f,0,180); g.DrawArc(line,cx+cr*.12f,cy-cr*.15f,cr*.34f,cr*.3f,0,180); }
    using(SolidBrush panel=new SolidBrush(Color.FromArgb(52,255,255,255))) g.FillRoundedRectangle(panel,new RectangleF(W*.06f,H*.80f,W*.56f,H*.12f),34f);
  }
}
public static class RoundRectExt {
  public static void FillRoundedRectangle(this Graphics g, Brush brush, RectangleF rect, float radius) {
    using(GraphicsPath path=new GraphicsPath()) { float d=radius*2; path.AddArc(rect.X,rect.Y,d,d,180,90); path.AddArc(rect.Right-d,rect.Y,d,d,270,90); path.AddArc(rect.Right-d,rect.Bottom-d,d,d,0,90); path.AddArc(rect.X,rect.Bottom-d,d,d,90,90); path.CloseFigure(); g.FillPath(brush,path); }
  }
}
"@
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition $render
function Get-WallpaperParent {
  $prog=[Win32WallpaperApi]::FindWindow('Progman',$null)
  $res=[IntPtr]::Zero
  [Win32WallpaperApi]::SendMessageTimeout($prog,0x052C,[IntPtr]::Zero,[IntPtr]::Zero,0,1000,[ref]$res)|Out-Null
  Start-Sleep -Milliseconds 500
  $script:ww=[IntPtr]::Zero
  $cb=[Win32WallpaperApi+EnumWindowsProc]{ param($top,$lp)
    $def=[Win32WallpaperApi]::FindWindowEx($top,[IntPtr]::Zero,'SHELLDLL_DefView',$null)
    if($def -ne [IntPtr]::Zero){ $next=[Win32WallpaperApi]::FindWindowEx([IntPtr]::Zero,$top,'WorkerW',$null); if($next -ne [IntPtr]::Zero){ $script:ww=$next } }
    return $true
  }
  [Win32WallpaperApi]::EnumWindows($cb,[IntPtr]::Zero)|Out-Null
  if($script:ww -ne [IntPtr]::Zero){ return $script:ww }
  return $prog
}
[System.Windows.Forms.Application]::EnableVisualStyles()
$bounds=[System.Windows.Forms.SystemInformation]::VirtualScreen
$form=New-Object CuteAnimeWallpaperForm($ImagePath,$bounds)
$form.Add_Shown({ param($sender,$eventArgs)
  try{
    $parent=Get-WallpaperParent
    Log ('parent_handle='+$parent.ToString())
    [Win32WallpaperApi]::SetParent($sender.Handle,$parent)|Out-Null
    [Win32WallpaperApi]::MoveWindow($sender.Handle,$bounds.Left,$bounds.Top,$bounds.Width,$bounds.Height,$true)|Out-Null
  }catch{ Log ('shown_error='+$_.Exception.Message) }
})
Log ('start bounds='+$bounds.ToString()+' image_exists='+(Test-Path -LiteralPath $ImagePath))
[System.Windows.Forms.Application]::Run($form)
}catch{ Log ('fatal='+$_.Exception.ToString()) }
'@
WriteUtf8 $hostScript $hostCode
L ('host_script='+$hostScript+' exists='+(Test-Path -LiteralPath $hostScript))

$startBat=Join-Path $hostDir 'Start-CuteAnimeDynamicWallpaper.bat'
$stopBat=Join-Path $hostDir 'Stop-CuteAnimeDynamicWallpaper.bat'
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$startContent="@echo off`r`nstart ""CuteAnimeDynamicWallpaper"" /min ""$psExe"" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$hostScript""`r`n"
$stopCmd="Get-CimInstance Win32_Process | Where-Object { `$_.CommandLine -like '*CuteAnimeDynamicWallpaperHost.ps1*' } | ForEach-Object { Stop-Process -Id `$_.ProcessId -Force }"
$stopContent="@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -Command ""$stopCmd""`r`n"
WriteUtf8 $startBat $startContent
WriteUtf8 $stopBat $stopContent
L ('start_bat='+$startBat+' exists='+(Test-Path -LiteralPath $startBat))
L ('stop_bat='+$stopBat+' exists='+(Test-Path -LiteralPath $stopBat))

# Stop possible overlays/wallpapers, then start our visible host.
$lively='C:\Program Files\Lively Wallpaper\Lively.exe'
$livelyCloseOk=$false
if(Test-Path -LiteralPath $lively){
  $r=Run-ExeArgs $lively ([string[]]@('closewp','--monitor','-1')) 120
  $livelyCloseOk=($r.code -eq 0)
  L ('lively_closewp_all_exit='+$r.code)
  L ('lively_closewp_all_tail='+(TailText (San $r.text) 4))
}
$stopped=Stop-OldHosts 'CuteAnimeDynamicWallpaperHost.ps1'
L ('old_host_processes_stopped='+$stopped)
try{
  Start-Process -FilePath $psExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$hostScript) -WindowStyle Hidden -WorkingDirectory $hostDir | Out-Null
  $startOk=$true
}catch{ $startOk=$false; L ('host_start_error='+(San $_.Exception.Message)) }
L ('host_start_invoked='+$startOk)
Start-Sleep -Seconds 5
$hostProcs=@(); try{ $hostProcs=Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.Contains('CuteAnimeDynamicWallpaperHost.ps1') } }catch{}
L ('host_process_count='+(@($hostProcs).Count))
foreach($p in @($hostProcs|Select-Object -First 6)){ L ('host_process='+$p.Name+' pid='+$p.ProcessId) }
if(Test-Path -LiteralPath $hostLog){ L ('host_log_tail='+(TailText (Get-Content -LiteralPath $hostLog -Raw -ErrorAction SilentlyContinue) 8)) }

try{ $sh=New-Object -ComObject Shell.Application; $sh.MinimizeAll(); Start-Sleep -Seconds 2 }catch{ L ('minimize_error='+(San $_.Exception.Message)) }
$shotA=Join-Path $proofDir 'visible_desktop_frame_a.png'
$shotB=Join-Path $proofDir 'visible_desktop_frame_b.png'
$c1=Capture-Screen $shotA
Start-Sleep -Seconds 3
$c2=Capture-Screen $shotB
$diff=@{ok=$false;ratio=0.0;avgDiff=0.0;changed=0;samples=0;err='not compared'}
if($c1.ok -and $c2.ok){ $diff=Compare-Images $shotA $shotB }
L ('screen_capture_a_ok='+$c1.ok+' path='+$shotA+' width='+$c1.width+' height='+$c1.height+' err='+$c1.err)
L ('screen_capture_b_ok='+$c2.ok+' path='+$shotB+' width='+$c2.width+' height='+$c2.height+' err='+$c2.err)
L ('screen_diff_ok='+$diff.ok)
L ('screen_diff_samples='+$diff.samples)
L ('screen_diff_changed='+$diff.changed)
L ('screen_diff_ratio='+('{0:N6}' -f [double]$diff.ratio))
L ('screen_diff_avg='+('{0:N3}' -f [double]$diff.avgDiff))
$visibleDynamic=($diff.ok -and ([double]$diff.ratio -gt 0.003 -or [double]$diff.avgDiff -gt 1.2))
L ('visible_dynamic_screen_proof='+$visibleDynamic)

$startup=[Environment]::GetFolderPath('Startup')
$startupLink=''
if($startup -and (Test-Path -LiteralPath $startup)){
  $startupLink=Join-Path $startup 'Cute Anime Dynamic Wallpaper R251.lnk'
  New-Link $startupLink $psExe ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$hostScript+'"') $hostDir '' 'Start cute anime dynamic wallpaper at login'|Out-Null
}
L ('startup_link='+$startupLink+' exists='+($startupLink -and (Test-Path -LiteralPath $startupLink)))
New-Link (Join-Path $desktop 'Cute Anime Dynamic Wallpaper START.lnk') $startBat '' $hostDir '' 'Start cute anime dynamic wallpaper'|Out-Null
New-Link (Join-Path $desktop 'Cute Anime Dynamic Wallpaper STOP.lnk') $stopBat '' $hostDir '' 'Stop cute anime dynamic wallpaper'|Out-Null
New-Link (Join-Path $desktop 'Cute Anime Dynamic Wallpaper Folder.lnk') 'explorer.exe' ('"'+$hostDir+'"') $hostDir '' 'Open dynamic wallpaper folder'|Out-Null
New-Link (Join-Path $desktop 'R251 Visible Dynamic Wallpaper Report.lnk') 'explorer.exe' ('"'+$root+'"') $root '' 'Open wallpaper proof folder'|Out-Null
$org=Join-Path $desktop 'DeskBox-Cute-Desktop-Organizer'
$wallFolder=Join-Path $org '09-Anime-Wallpapers'; New-Item -ItemType Directory -Force -Path $wallFolder|Out-Null
$deskCopy=Join-Path $wallFolder 'Cute-Anime-Dynamic-R251-Visible-Host'
if(Test-Path -LiteralPath $deskCopy){ Remove-Item -LiteralPath $deskCopy -Recurse -Force -ErrorAction SilentlyContinue }
Copy-Item -LiteralPath $hostDir -Destination $deskCopy -Recurse -Force -ErrorAction SilentlyContinue
$tidy=Tidy-Desktop $desktop $org
L ('desktop_host_copy='+$deskCopy+' exists='+(Test-Path -LiteralPath $deskCopy))
L ('desktop_tidy_manifest='+$tidy.manifest)
L ('desktop_tidy_moved_count='+$tidy.moved)
L ('desktop_tidy_done='+(Test-Path -LiteralPath $tidy.manifest))

$ready=((@($hostProcs).Count -gt 0) -and $visibleDynamic -and (Test-Path -LiteralPath $tidy.manifest) -and (Test-Path -LiteralPath $hostScript))
L ('visible_host_running='+(@($hostProcs).Count -gt 0))
L ('desktop_tidy_ok='+(Test-Path -LiteralPath $tidy.manifest))
L ('R251_VISIBLE_DYNAMIC_WALLPAPER_READY='+$ready)
$summary=[pscustomobject]@{ready=$ready;diagnosis='Previous checks used Lively exit/process; R251 uses screen diff proof.';hostDir=$hostDir;hostScript=$hostScript;startBat=$startBat;stopBat=$stopBat;background=$bg;hostProcessCount=@($hostProcs).Count;screenFrameA=$shotA;screenFrameB=$shotB;screenDiffRatio=[double]$diff.ratio;screenDiffAvg=[double]$diff.avgDiff;visibleDynamicScreenProof=$visibleDynamic;livelyCloseAllOk=$livelyCloseOk;startupLink=$startupLink;desktopHostCopy=$deskCopy;desktopOrganizer=$org;tidyManifest=$tidy.manifest}
WriteUtf8 $jsonReport (($summary|ConvertTo-Json -Depth 8)+"`r`n")
W $report $script:Lines
if(-not $ready){ exit 6 }
exit 0
