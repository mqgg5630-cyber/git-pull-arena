# t165_antigravity_ui_probe_suite.ps1 - round 208.
# Build an E:-only multi-backend computer-use suite, test low-level SendInput
# on a lab GUI, then probe Antigravity's UI for a safe chat/input path.
# ASCII-only; no secrets or chat contents are printed.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Run-Capped([string]$Name, [scriptblock]$Block, [int]$TimeoutSec) {
    L ('RUN_START=' + $Name)
    $job=Start-Job -ScriptBlock $Block
    if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; L ('RUN_TIMEOUT=' + $Name); return @{ok=$false;text='TIMEOUT'} }
    $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
    foreach($ln in (($txt -split "`r?`n") | Select-Object -First 120)){ if($ln.Trim()){ L ('RUN_OUT|' + $Name + '| ' + (San $ln)) } }
    return @{ok=$true;text=$txt}
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'ANTIGRAVITY_UI_PROBE_SUITE_R208.md'
L '--- task t165: Antigravity UI probe and computer-use suite ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$lab='E:\0mcp-agv-arena-optimized'
$suite=Join-Path $lab 'computer-use-suite'
$tools=Join-Path $lab 'tools'
$smoke=Join-Path $lab 'smoke'
$reports=Join-Path $lab 'reports'
foreach($d in @($suite,$tools,$smoke,$reports)){ New-Item -ItemType Directory -Force -Path $d | Out-Null }
L ('lab=' + $lab + ' exists=' + (Test-Path -LiteralPath $lab))
L ('bridge_18088=' + (Wait-Port 18088 2))

# E:-only low-level controller. It complements GitHub windows-computer-use by
# using SendInput for apps where SendKeys is blocked.
$lite=Join-Path $suite 'Invoke-ComputerUseLite.ps1'
$liteLines=@'
param([string]$Action='health',[string]$Title='',[int]$X=0,[int]$Y=0,[string]$Text='',[string]$OutFile='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName WindowsBase
if(-not ('ArenaInputLite' -as [type])){
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ArenaInputLite {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd,int nCmdShow);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int X,int Y);
 [DllImport("user32.dll")] public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
 [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public InputUnion U; }
 [StructLayout(LayoutKind.Explicit)] public struct InputUnion { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
 [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
 [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
 public const uint INPUT_MOUSE=0; public const uint INPUT_KEYBOARD=1; public const uint KEYEVENTF_KEYUP=0x0002; public const uint KEYEVENTF_UNICODE=0x0004;
 public const uint MOUSEEVENTF_LEFTDOWN=0x0002; public const uint MOUSEEVENTF_LEFTUP=0x0004;
 public static void SendUnicode(string s){ foreach(char ch in s){ INPUT down=new INPUT(); down.type=INPUT_KEYBOARD; down.U.ki.wScan=ch; down.U.ki.dwFlags=KEYEVENTF_UNICODE; INPUT up=new INPUT(); up.type=INPUT_KEYBOARD; up.U.ki.wScan=ch; up.U.ki.dwFlags=KEYEVENTF_UNICODE|KEYEVENTF_KEYUP; INPUT[] arr=new INPUT[]{down,up}; SendInput(2,arr,Marshal.SizeOf(typeof(INPUT))); } }
 public static void SendVk(ushort vk){ INPUT d=new INPUT(); d.type=INPUT_KEYBOARD; d.U.ki.wVk=vk; INPUT u=new INPUT(); u.type=INPUT_KEYBOARD; u.U.ki.wVk=vk; u.U.ki.dwFlags=KEYEVENTF_KEYUP; INPUT[] arr=new INPUT[]{d,u}; SendInput(2,arr,Marshal.SizeOf(typeof(INPUT))); }
 public static void Click(){ INPUT d=new INPUT(); d.type=INPUT_MOUSE; d.U.mi.dwFlags=MOUSEEVENTF_LEFTDOWN; INPUT u=new INPUT(); u.type=INPUT_MOUSE; u.U.mi.dwFlags=MOUSEEVENTF_LEFTUP; INPUT[] arr=new INPUT[]{d,u}; SendInput(2,arr,Marshal.SizeOf(typeof(INPUT))); }
}
"@
}
function J([object]$o){ $o | ConvertTo-Json -Depth 12 -Compress }
function FindWin([string]$t){ $root=[System.Windows.Automation.AutomationElement]::RootElement; $kids=$root.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition); for($i=0;$i -lt $kids.Count;$i++){ $el=$kids.Item($i); $name=''; try{$name=$el.Current.Name}catch{}; if($name -and $name.IndexOf($t,[StringComparison]::OrdinalIgnoreCase) -ge 0){ return $el } }; return $null }
function RectObj($el){ try{$r=$el.Current.BoundingRectangle; return [ordered]@{x=[int]$r.X;y=[int]$r.Y;width=[int]$r.Width;height=[int]$r.Height;centerX=[int]($r.X+$r.Width/2);centerY=[int]($r.Y+$r.Height/2)}}catch{return $null} }
function Activate($el){ try{$hwnd=$el.Current.NativeWindowHandle; if($hwnd){$ptr=[IntPtr]([int64]$hwnd); [ArenaInputLite]::ShowWindow($ptr,9)|Out-Null; Start-Sleep -Milliseconds 100; [ArenaInputLite]::SetForegroundWindow($ptr)|Out-Null; Start-Sleep -Milliseconds 200}}catch{} }
function WalkSummary($el,[int]$depth,[int]$max,[System.Collections.ArrayList]$rows){ if($null -eq $el -or $rows.Count -ge 220 -or $depth -gt $max){return}; $ct='';$name='';$cls=''; try{$ct=$el.Current.ControlType.ProgrammaticName -replace '^ControlType\.',''}catch{}; try{$name=$el.Current.Name}catch{}; try{$cls=$el.Current.ClassName}catch{}; if($name -or $ct){ [void]$rows.Add([ordered]@{depth=$depth; type=$ct; name=($name.Substring(0,[Math]::Min(80,$name.Length))); class=$cls; rect=(RectObj $el)}) }; try{$kids=$el.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition); for($i=0;$i -lt $kids.Count;$i++){ WalkSummary $kids.Item($i) ($depth+1) $max $rows }}catch{} }
switch($Action){
 'health' { J ([ordered]@{ok=$true; backend='SendInput+UIA'; actions=@('health','activate','click','send-text','enter','summary')}) }
 'activate' { $w=FindWin $Title; if($w){Activate $w; J ([ordered]@{ok=$true; title=$Title; rect=(RectObj $w)})} else {J ([ordered]@{ok=$false; error='window not found'; title=$Title})} }
 'click' { [ArenaInputLite]::SetCursorPos($X,$Y)|Out-Null; Start-Sleep -Milliseconds 60; [ArenaInputLite]::Click(); J ([ordered]@{ok=$true;x=$X;y=$Y}) }
 'send-text' { [ArenaInputLite]::SendUnicode($Text); J ([ordered]@{ok=$true;length=$Text.Length}) }
 'enter' { [ArenaInputLite]::SendVk(13); J ([ordered]@{ok=$true;key='Enter'}) }
 'summary' { $w=FindWin $Title; if($w){Activate $w; $rows=New-Object System.Collections.ArrayList; WalkSummary $w 0 8 $rows; J ([ordered]@{ok=$true;title=$Title; count=$rows.Count; rows=@($rows)})} else {J ([ordered]@{ok=$false; error='window not found'; title=$Title})} }
 default { J ([ordered]@{ok=$false; error='unknown action'}) }
}
'@ -split "`r?`n"
W $lite $liteLines
L ('lite_controller=' + (San $lite))

# Test low-level SendInput on a lab-owned GUI app.
$inputApp=Join-Path $tools 'arena_sendinput_test_app.ps1'
$inputResult=Join-Path $smoke 'sendinput_test_result.txt'
$appLines=@'
param([string]$OutFile)
$ErrorActionPreference='Continue'
Add-Type -AssemblyName System.Windows.Forms
$form=New-Object Windows.Forms.Form
$form.Text='Arena SendInput Test App'
$form.Width=520; $form.Height=260; $form.StartPosition='CenterScreen'
$text=New-Object Windows.Forms.TextBox
$text.Left=30; $text.Top=40; $text.Width=430; $text.Height=40
$btn=New-Object Windows.Forms.Button
$btn.Text='Save Input'; $btn.Left=30; $btn.Top=100; $btn.Width=140; $btn.Height=42
$btn.Add_Click({ [IO.File]::WriteAllText($OutFile,$text.Text,(New-Object Text.UTF8Encoding($false))); $form.Close() })
$form.Controls.Add($text); $form.Controls.Add($btn)
[void]$form.ShowDialog()
'@ -split "`r?`n"
W $inputApp $appLines
try{Remove-Item -LiteralPath $inputResult -Force -ErrorAction SilentlyContinue}catch{}
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$p=Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$inputApp,'-OutFile',$inputResult) -PassThru
Start-Sleep -Seconds 2
$marker='SENDINPUT_OK_' + (Get-Date -Format 'HHmmss')
$actJson=(& $psExe -NoProfile -ExecutionPolicy Bypass -File $lite -Action activate -Title 'Arena SendInput Test App' 2>&1 | Out-String).Trim(); L ('sendinput_app_activate=' + (San $actJson))
try{$act=$actJson|ConvertFrom-Json; $bb=$act.rect}catch{$bb=$null}
if($bb){
    $x=[int]($bb.x+120); $y=[int]($bb.y+70); & $psExe -NoProfile -ExecutionPolicy Bypass -File $lite -Action click -X $x -Y $y | Out-Null; Start-Sleep -Milliseconds 300
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $lite -Action send-text -Text $marker | Out-Null; Start-Sleep -Milliseconds 500
    $bx=[int]($bb.x+90); $by=[int]($bb.y+130); & $psExe -NoProfile -ExecutionPolicy Bypass -File $lite -Action click -X $bx -Y $by | Out-Null
}
Start-Sleep -Seconds 2
try{ if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }catch{}
$txt=''; try{ if(Test-Path $inputResult){$txt=Get-Content -LiteralPath $inputResult -Raw} }catch{}
L ('sendinput_smoke_result_file=' + (San $inputResult))
L ('sendinput_smoke_marker_present=' + [bool]($txt -match [regex]::Escape($marker)))

# Antigravity UI probe: relaunch/activate and collect a safe structural summary.
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
L ('antigravity_exe_exists=' + (Test-Path -LiteralPath $agExe))
if(Test-Path -LiteralPath $agExe){
    if(@(Get-Process -Name Antigravity -ErrorAction SilentlyContinue).Count -eq 0){ try{Start-Process $agExe; Start-Sleep -Seconds 6; L 'antigravity_started=True'}catch{L('antigravity_start_WARN='+(San $_.Exception.Message))} }
}
$wins=@(Get-Process -Name Antigravity -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object -First 8)
L ('antigravity_window_count=' + $wins.Count)
foreach($w in $wins){ L ('antigravity_window=' + (San $w.MainWindowTitle) + ' pid=' + $w.Id) }
$targetTitle='Antigravity'
if($wins.Count -gt 0){ $targetTitle=$wins[0].MainWindowTitle }
$sumPath=Join-Path $reports 'antigravity-ui-summary-r208.json'
$sumText=(& $psExe -NoProfile -ExecutionPolicy Bypass -File $lite -Action summary -Title $targetTitle 2>&1 | Out-String).Trim()
[IO.File]::WriteAllText($sumPath,$sumText + "`r`n",(New-Object Text.UTF8Encoding($false)))
L ('antigravity_ui_summary_path=' + (San $sumPath))
try{
    $sum=$sumText|ConvertFrom-Json
    L ('antigravity_summary_ok=' + $sum.ok + ' count=' + $sum.count)
    $interesting=@($sum.rows | Where-Object { ($_.name -match 'chat|agent|message|ask|prompt|composer|input|send|new') -or ($_.type -match 'Edit|Document|Button') } | Select-Object -First 60)
    L ('antigravity_interesting_count=' + $interesting.Count)
    foreach($it in $interesting){ L ('ag_ui| d=' + $it.depth + ' type=' + (San ([string]$it.type)) + ' name=' + (San ([string]$it.name)) + ' class=' + (San ([string]$it.class))) }
}catch{ L ('antigravity_summary_parse_WARN=' + (San $_.Exception.Message)) }

$readme=@(
'# Computer-use suite on E drive',
'',
'Root: E:\0mcp-agv-arena-optimized\computer-use-suite',
'',
'Backends:',
'- GitHub windows-computer-use MCP: E:\0mcp-agv-arena-optimized\github\windows-computer-use\plugins\windows-computer-use\mcp\server.mjs',
'- Windows-MCP clone: E:\0mcp-agv-arena-optimized\github\Windows-MCP',
'- Lite SendInput+UIA fallback: Invoke-ComputerUseLite.ps1',
'',
'Use strategy:',
'1. Prefer app-specific wrappers in software-ops.',
'2. Use windows-computer-use for UIA tree/find/invoke/screenshot.',
'3. Use Lite SendInput only for foreground, user-visible text/click flows.',
'4. Use pywinauto when UIA IDs are stable.',
'',
'Antigravity probe report: E:\0mcp-agv-arena-optimized\reports\antigravity-ui-summary-r208.json'
)
W (Join-Path $suite 'README.md') $readme

if([bool]($txt -match [regex]::Escape($marker))){ L 'FINAL_R208: SENDINPUT_BACKEND_OK_AND_ANTIGRAVITY_UI_PROBED' } else { L 'FINAL_R208: ANTIGRAVITY_UI_PROBED_SENDINPUT_CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t165 done ---'
exit 0
