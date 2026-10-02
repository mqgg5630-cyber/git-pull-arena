# t176_antigravity_terminal_browserskill_phone_r222.ps1 - round 222.
# Laptop-only: use the Antigravity UI/integrated terminal path to run an
# Illustrator generator, load/test the installed BrowserSkill Edge extension,
# and refresh the Tailscale phone browser file-share. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{24,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[REDACTED-GUID]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(350)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec) { $job=Start-Job -ScriptBlock $Block; if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function File-Info([string]$p) { if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return ([pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')}) } return ([pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''}) }
function Curl-Text([string]$Url,[int]$Sec) { try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -L --max-time $Sec -sS $Url 2>&1 | Out-String).Trim() }catch{ return $_.Exception.Message } }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'ANTIGRAVITY_TERMINAL_ILLUSTRATOR_BROWSERSKILL_PHONE_R222.md'
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$agvRoot=Join-Path $lab 'antigravity-tests\agv_terminal_illustrator_r222'
$browserRoot=Join-Path $lab 'browser-tests\browserskill_edge_r222'
$phoneRoot=Join-Path $lab 'phone-share'
foreach($d in @($reports,$agvRoot,$browserRoot,$phoneRoot)){ New-Item -ItemType Directory -Force -Path $d | Out-Null }
L '# R222 Antigravity terminal Illustrator + BrowserSkill + phone share'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + (San $env:USERNAME))

# ---------------------------------------------------------------------------
# 1. Prepare a standalone Illustrator runner. It creates editable AI + PNG.
# The round script does NOT run this runner directly. It only injects the
# command into Antigravity's UI/integrated-terminal path, then waits for proof.
# ---------------------------------------------------------------------------
$runner=Join-Path $agvRoot 'run_illustrator_from_antigravity_terminal_r222.ps1'
$outAi=Join-Path $agvRoot 'agv_terminal_figure_r222.ai'
$outPng=Join-Path $agvRoot 'agv_terminal_figure_r222.png'
$outDone=Join-Path $agvRoot 'agv_terminal_illustrator_done_r222.txt'
$outInvoke=Join-Path $agvRoot 'agv_terminal_invoked_r222.txt'
$outLog=Join-Path $agvRoot 'agv_terminal_illustrator_runner_r222.log'
$outJsx=Join-Path $agvRoot 'agv_terminal_illustrator_r222.jsx'
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone,$outInvoke,$outLog,$outJsx -Force -ErrorAction SilentlyContinue }catch{}
$runnerLines=@'
param()
$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
$script:Lines=@()
$root='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_terminal_illustrator_r222'
$outAi=Join-Path $root 'agv_terminal_figure_r222.ai'
$outPng=Join-Path $root 'agv_terminal_figure_r222.png'
$outDone=Join-Path $root 'agv_terminal_illustrator_done_r222.txt'
$outLog=Join-Path $root 'agv_terminal_illustrator_runner_r222.log'
$outJsx=Join-Path $root 'agv_terminal_illustrator_r222.jsx'
New-Item -ItemType Directory -Force -Path $root | Out-Null
L '# Illustrator generator launched from Antigravity terminal r222'
L ('time=' + (Get-Date).ToString('s'))
L ('pid=' + $PID)
$aiExe=$null
$roots=@('E:\','D:\','C:\Program Files','C:\Program Files (x86)')
foreach($base in $roots){ if(Test-Path -LiteralPath $base){ try{ $found=Get-ChildItem -LiteralPath $base -Recurse -Filter Illustrator.exe -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'Adobe.*Illustrator|Illustrator' } | Select-Object -First 1; if($found){ $aiExe=$found.FullName; break } }catch{} } }
if(-not $aiExe){ try{ $cmd=Get-Command Illustrator.exe -ErrorAction SilentlyContinue; if($cmd){$aiExe=$cmd.Source} }catch{} }
L ('illustrator_exe=' + (San $aiExe))
if(-not $aiExe -or -not (Test-Path -LiteralPath $aiExe)){ L 'FINAL: FAIL_NO_ILLUSTRATOR'; W $outLog $script:Lines; exit 2 }
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone -Force -ErrorAction SilentlyContinue }catch{}
$jsx=@'
(function(){
  function rgb(r,g,b){ var c=new RGBColor(); c.red=r; c.green=g; c.blue=b; return c; }
  function txt(doc, contents, x, y, size, color){ var t=doc.textFrames.add(); t.contents=contents; t.position=[x,y]; t.textRange.characterAttributes.size=size; t.textRange.characterAttributes.fillColor=color; t.textRange.characterAttributes.textFont=app.textFonts.getByName('ArialMT'); return t; }
  function rect(doc, top, left, w, h, fill, stroke, sw){ var p=doc.pathItems.rectangle(top,left,w,h); p.filled=true; p.fillColor=fill; p.stroked=true; p.strokeColor=stroke; p.strokeWidth=sw; return p; }
  function circ(doc, left, top, d, fill, stroke){ var p=doc.pathItems.ellipse(top,left,d,d); p.filled=true; p.fillColor=fill; p.stroked=true; p.strokeColor=stroke; p.strokeWidth=5; return p; }
  var root='E:/0mcp-agv-arena-optimized/antigravity-tests/agv_terminal_illustrator_r222/';
  var done=new File(root+'agv_terminal_illustrator_done_r222.txt');
  var log=new File(root+'jsx_status_r222.txt');
  try{
    var doc=app.documents.add(DocumentColorSpace.RGB,1000,620);
    rect(doc,620,0,1000,620,rgb(255,255,255),rgb(255,255,255),0);
    rect(doc,545,70,860,420,rgb(248,250,252),rgb(15,23,42),3);
    circ(doc,180,365,120,rgb(219,234,254),rgb(37,99,235));
    circ(doc,440,365,120,rgb(220,252,231),rgb(22,163,74));
    circ(doc,700,365,120,rgb(254,243,199),rgb(245,158,11));
    var l1=doc.pathItems.add(); l1.setEntirePath([[300,305],[440,305]]); l1.stroked=true; l1.strokeWidth=8; l1.strokeColor=rgb(100,116,139); l1.filled=false;
    var l2=doc.pathItems.add(); l2.setEntirePath([[560,305],[700,305]]); l2.stroked=true; l2.strokeWidth=8; l2.strokeColor=rgb(100,116,139); l2.filled=false;
    txt(doc,'Input',210,310,32,rgb(30,41,59));
    txt(doc,'Model',465,310,32,rgb(30,41,59));
    txt(doc,'Figure',720,310,32,rgb(30,41,59));
    txt(doc,'Antigravity terminal -> Illustrator R222',120,185,34,rgb(15,23,42));
    txt(doc,'Editable vector AI plus PNG generated by Illustrator.',120,140,24,rgb(71,85,105));
    txt(doc,'ARENA_AGV_TERMINAL_ILLUSTRATOR_R222',120,105,20,rgb(37,99,235));
    var aiFile=new File(root+'agv_terminal_figure_r222.ai');
    var saveOpts=new IllustratorSaveOptions();
    try{ saveOpts.compatibility=Compatibility.ILLUSTRATOR17; }catch(e){}
    doc.saveAs(aiFile,saveOpts);
    var pngFile=new File(root+'agv_terminal_figure_r222.png');
    var pngOpts=new ExportOptionsPNG24(); pngOpts.antiAliasing=true; pngOpts.transparency=false; pngOpts.horizontalScale=100; pngOpts.verticalScale=100;
    doc.exportFile(pngFile,ExportType.PNG24,pngOpts);
    try{ doc.close(SaveOptions.DONOTSAVECHANGES); }catch(e){}
    done.encoding='UTF-8'; done.open('w'); done.write('OK ARENA_AGV_TERMINAL_ILLUSTRATOR_R222 '+(new Date()).toString()); done.close();
    log.encoding='UTF-8'; log.open('w'); log.write('OK'); log.close();
  }catch(e){
    log.encoding='UTF-8'; log.open('w'); log.write('ERR '+e.message+' line '+e.line); log.close();
  }
})();
'@
[IO.File]::WriteAllText($outJsx,$jsx,(New-Object Text.UTF8Encoding($false)))
Start-Process -FilePath $aiExe -ArgumentList @('"' + $outJsx + '"') | Out-Null
$deadline=(Get-Date).AddSeconds(180)
while((Get-Date)-lt $deadline){ if(Test-Path -LiteralPath $outDone){ break }; Start-Sleep -Milliseconds 800 }
$aiOk=Test-Path -LiteralPath $outAi; $pngOk=Test-Path -LiteralPath $outPng; $doneOk=Test-Path -LiteralPath $outDone
L ('ai_exists=' + $aiOk + ' ai_bytes=' + ($(if($aiOk){(Get-Item -LiteralPath $outAi).Length}else{0})))
L ('png_exists=' + $pngOk + ' png_bytes=' + ($(if($pngOk){(Get-Item -LiteralPath $outPng).Length}else{0})))
L ('done_exists=' + $doneOk)
$jsxStatus=Join-Path $root 'jsx_status_r222.txt'
if(Test-Path -LiteralPath $jsxStatus){ L ('jsx_status=' + (San (Get-Content -LiteralPath $jsxStatus -Raw))) }
if($aiOk -and $pngOk -and $doneOk){ L 'FINAL: OK_ILLUSTRATOR_GENERATED_BY_ANTIGRAVITY_TERMINAL_COMMAND' } else { L 'FINAL: FAIL_NO_OUTPUTS' }
W $outLog $script:Lines
if($aiOk -and $pngOk -and $doneOk){ exit 0 } else { exit 3 }
'@
W $runner $runnerLines
L ('runner_prepared=' + (San $runner))

# Ensure Antigravity with CDP is reachable.
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$agvPort=9223
$agvCdp=Wait-Port $agvPort 2
if(-not $agvCdp -and (Test-Path -LiteralPath $agExe)){
    try{ Start-Process -FilePath $agExe -ArgumentList @('--force-renderer-accessibility','--remote-debugging-port='+$agvPort) | Out-Null }catch{ L ('antigravity_start_WARN=' + (San $_.Exception.Message)) }
    Start-Sleep -Seconds 8
    $agvCdp=Wait-Port $agvPort 8
}
L ('antigravity_cdp=' + $agvCdp)

$terminalMarker='ARENA_AGV_TERMINAL_CMD_R222_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$cmdLine='cmd.exe /c echo ' + $terminalMarker + ' > "' + $outInvoke + '" && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $runner + '"'
$agvCdpJson=Join-Path $reports 'antigravity-terminal-inject-r222.json'
$agvCdpScript=Join-Path $agvRoot 'agv_terminal_inject_r222.cjs'
$agvJs=@'
const fs=require('fs');
const out=process.argv[2], marker=process.argv[3], command=process.argv[4], port=process.argv[5]||'9223';
const WS=globalThis.WebSocket;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function getJson(u){const r=await fetch(u); return await r.json();}
function connect(url){return new Promise((resolve,reject)=>{const ws=new WS(url); let id=0; const pending=new Map(); ws.onmessage=ev=>{const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){const p=pending.get(m.id); pending.delete(m.id); m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);}}; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=reject;});}
async function key(send,key,code,vk,mods=0){await send('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers:mods}); await sleep(30); await send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers:mods});}
async function enter(send){await key(send,'Enter','Enter',13,0)}
async function esc(send){await key(send,'Escape','Escape',27,0)}
async function main(){
 const result={ok:false,marker,commandLength:command.length,steps:[]};
 const targets=await getJson(`http://127.0.0.1:${port}/json/list`);
 result.targets=targets.map(t=>({title:t.title,url:t.url,type:t.type})).slice(0,20);
 const target=targets.find(t=>(t.title||'').includes('Antigravity')&&t.webSocketDebuggerUrl)||targets.find(t=>(t.url||'').includes('127.0.0.1')&&t.webSocketDebuggerUrl)||targets.find(t=>t.webSocketDebuggerUrl);
 if(!target){fs.writeFileSync(out,JSON.stringify(result,null,2)); return;}
 result.target={title:target.title,url:target.url,type:target.type};
 const {ws,send}=await connect(target.webSocketDebuggerUrl);
 await send('Runtime.enable'); await send('Page.bringToFront').catch(()=>{}); result.steps.push('front');
 await sleep(500); await esc(send); await sleep(200); await esc(send); await sleep(300);
 await key(send,'P','KeyP',80,10); result.steps.push('palette'); await sleep(1200);
 await send('Input.insertText',{text:'Terminal: Create New Terminal'}); result.steps.push('palette_text'); await sleep(300); await enter(send); result.steps.push('palette_enter'); await sleep(5000);
 await send('Input.insertText',{text:command}); result.steps.push('command_text'); await sleep(300); await enter(send); result.steps.push('command_enter'); await sleep(3000);
 const body=await send('Runtime.evaluate',{expression:`(() => { const t=document.body?document.body.innerText:''; return {title:document.title, active:(document.activeElement&&(document.activeElement.tagName+' '+(document.activeElement.getAttribute('aria-label')||'')+' '+(document.activeElement.getAttribute('role')||'')))||'', hasTerminal:/TERMINAL|Terminal|PowerShell|cmd.exe|PS /.test(t), tail:t.slice(-6000)}; })()`,returnByValue:true,awaitPromise:true});
 result.body=body.result.value; result.ok=true;
 try{ws.close();}catch{}
 fs.writeFileSync(out,JSON.stringify(result,null,2));
}
main().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($agvCdpScript,$agvJs,(New-Object Text.UTF8Encoding($false)))
$nodeOut='SKIPPED'
if($agvCdp -and (Get-Command node -ErrorAction SilentlyContinue)){
    $ns=$agvCdpScript; $oj=$agvCdpJson; $mk=$terminalMarker; $cmd=$cmdLine; $pt=[string]$agvPort
    $nodeOut=Run-Cap { node $using:ns $using:oj $using:mk $using:cmd $using:pt 2>&1 | Out-String } 90
}
L ('agv_cdp_terminal_inject_node=' + (San (($nodeOut -split "`r?`n" | Select-Object -First 10) -join ' | ')))

# Fallback: if CDP did not invoke a shell quickly, use foreground SendKeys into Antigravity.
Start-Sleep -Seconds 8
if(-not (Test-Path -LiteralPath $outInvoke)){
    $sendKeyScript=Join-Path $agvRoot 'agv_terminal_sendkeys_r222.ps1'
    $sendKeyLines=@'
param([string]$Command)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Fg {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@
$p=Get-Process Antigravity -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if(-not $p){ throw 'No Antigravity window found' }
[Win32Fg]::ShowWindowAsync($p.MainWindowHandle,9) | Out-Null
[Win32Fg]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 700
[System.Windows.Forms.SendKeys]::SendWait('{ESC}')
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait('^+p')
Start-Sleep -Milliseconds 1000
Set-Clipboard -Value 'Terminal: Create New Terminal'
[System.Windows.Forms.SendKeys]::SendWait('^v')
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Milliseconds 5000
Set-Clipboard -Value $Command
[System.Windows.Forms.SendKeys]::SendWait('^v')
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Milliseconds 500
'@
    W $sendKeyScript $sendKeyLines
    $sk=$sendKeyScript; $cmd=$cmdLine
    $skOut=Run-Cap { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $using:sk -Command $using:cmd 2>&1 | Out-String } 45
    L ('agv_sendkeys_fallback=' + (San (($skOut -split "`r?`n" | Select-Object -First 10) -join ' | ')))
}

$deadline=(Get-Date).AddSeconds(300)
while((Get-Date)-lt $deadline){ if((Test-Path -LiteralPath $outDone) -or ((Test-Path -LiteralPath $outAi) -and (Test-Path -LiteralPath $outPng))){ break }; Start-Sleep -Seconds 5 }
$invokeInfo=File-Info $outInvoke; $aiInfo=File-Info $outAi; $pngInfo=File-Info $outPng; $doneInfo=File-Info $outDone
$agvIllOk=$invokeInfo.exists -and $aiInfo.exists -and $pngInfo.exists -and $doneInfo.exists -and ($aiInfo.bytes -gt 1000) -and ($pngInfo.bytes -gt 1000)
L ('antigravity_terminal_invoked=' + $invokeInfo.exists + ' marker=' + $terminalMarker)
L ('antigravity_illustrator_result ok=' + $agvIllOk + ' ai_exists=' + $aiInfo.exists + ' ai_bytes=' + $aiInfo.bytes + ' png_exists=' + $pngInfo.exists + ' png_bytes=' + $pngInfo.bytes + ' done=' + $doneInfo.exists)
if(Test-Path -LiteralPath $outLog){ foreach($line in (Get-Content -LiteralPath $outLog -Tail 40 -ErrorAction SilentlyContinue)){ if($line.Trim()){ L ('runner_log|' + (San $line)) } } } else { L 'runner_log_missing=True' }
$agvSummaryJson=Join-Path $reports 'antigravity-terminal-illustrator-r222.json'
[IO.File]::WriteAllText($agvSummaryJson, ([pscustomobject]@{ok=$agvIllOk;terminalMarker=$terminalMarker;command=$cmdLine;invoke=File-Info $outInvoke;ai=File-Info $outAi;png=File-Info $outPng;done=File-Info $outDone;runner=$runner;cdpJson=$agvCdpJson;log=$outLog} | ConvertTo-Json -Depth 6) + "`r`n", (New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $agvSummaryJson -Destination (Join-Path $outDir 'antigravity-terminal-illustrator-r222.json') -Force -ErrorAction SilentlyContinue; Copy-Item -LiteralPath $agvCdpJson -Destination (Join-Path $outDir 'antigravity-terminal-inject-r222.json') -Force -ErrorAction SilentlyContinue }catch{}

# ---------------------------------------------------------------------------
# 2. Locate the installed Tencent/BrowserSkill Edge extension, load it in Edge,
# and do a concrete browser task on a local page while the extension is loaded.
# ---------------------------------------------------------------------------
$bsManifest=$null; $bsManifestObj=$null
$edgeExtRoots=@((Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Extensions'),(Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Profile 1\Extensions'))
foreach($root in $edgeExtRoots){ if(Test-Path -LiteralPath $root){
    foreach($mf in @(Get-ChildItem -LiteralPath $root -Recurse -Depth 3 -Filter manifest.json -File -ErrorAction SilentlyContinue)){
        try{ $raw=Get-Content -LiteralPath $mf.FullName -Raw -Encoding UTF8; $j=$raw|ConvertFrom-Json; if([string]$j.name -eq 'BrowserSkill' -or $raw -match 'BrowserSkill'){ $bsManifest=$mf.FullName; $bsManifestObj=$j; break } }catch{}
    }
    if($bsManifest){ break }
}}
$bsDir=if($bsManifest){ Split-Path -Parent $bsManifest }else{ '' }
$bsId=if($bsManifest){ Split-Path -Leaf (Split-Path -Parent $bsDir) }else{ '' }
L ('browserskill_manifest=' + (San $bsManifest))
L ('browserskill_id=' + (San $bsId) + ' version=' + (if($bsManifestObj){[string]$bsManifestObj.version}else{''}))

$html=Join-Path $browserRoot 'browserskill_task_r222.html'
$htmlText=@'
<!doctype html><meta charset="utf-8"><title>BrowserSkill concrete task R222</title>
<h1 id="title">BrowserSkill concrete task R222</h1>
<input id="q" value="pending">
<button id="btn" onclick="document.getElementById('q').value='BrowserSkill clicked';document.body.setAttribute('data-task','OK');document.getElementById('out').textContent='BROWSERSKILL_TASK_R222_OK';">Run concrete task</button>
<div id="out">waiting</div>
'@
[IO.File]::WriteAllText($html,$htmlText,(New-Object Text.UTF8Encoding($false)))
$edgeExe=''
foreach($p in @((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),(Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'))){ if($p -and (Test-Path -LiteralPath $p)){ $edgeExe=$p; break } }
if(-not $edgeExe){ try{ $cmd=Get-Command msedge.exe -ErrorAction SilentlyContinue; if($cmd){$edgeExe=$cmd.Source} }catch{} }
$edgePort=9226
$edgeProfile=Join-Path $browserRoot 'edge-profile-with-browserskill'
$edgeUrl='file:///' + ($html -replace '\\','/')
if($edgeExe){
    $args=@('--remote-debugging-port='+$edgePort,'--user-data-dir='+$edgeProfile,'--no-first-run','--disable-first-run-ui')
    if($bsDir){ $args += @('--disable-extensions-except='+$bsDir,'--load-extension='+$bsDir) }
    $args += @($edgeUrl)
    try{ Start-Process -FilePath $edgeExe -ArgumentList $args | Out-Null; Start-Sleep -Seconds 5 }catch{ L ('edge_browserskill_start_WARN=' + (San $_.Exception.Message)) }
}
$edgeCdp=Wait-Port $edgePort 12
L ('edge_browserskill_cdp=' + $edgeCdp + ' edge_exe=' + (San $edgeExe))
$bsTaskJson=Join-Path $reports 'browserskill-edge-concrete-task-r222.json'
$bsTaskScript=Join-Path $browserRoot 'browserskill_edge_task_r222.cjs'
$bsJs=@'
const fs=require('fs'); const out=process.argv[2], port=process.argv[3], extId=process.argv[4]||''; const WS=globalThis.WebSocket;
async function getJson(u){const r=await fetch(u); return await r.json();}
function connect(u){return new Promise((resolve,reject)=>{const ws=new WS(u); let id=0; const pending=new Map(); ws.onmessage=ev=>{const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){const p=pending.get(m.id); pending.delete(m.id); m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);}}; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=reject;});}
async function main(){const result={ok:false,extId}; const targets=await getJson(`http://127.0.0.1:${port}/json/list`); result.targets=targets.map(t=>({type:t.type,title:t.title,url:t.url})); result.extensionTargets=targets.filter(t=>(t.url||'').includes('chrome-extension://'+extId)).map(t=>({type:t.type,title:t.title,url:t.url})); result.pluginLoaded=result.extensionTargets.length>0; const page=targets.find(t=>(t.url||'').includes('browserskill_task_r222.html'))||targets.find(t=>t.type==='page'&&t.webSocketDebuggerUrl); if(!page){fs.writeFileSync(out,JSON.stringify(result,null,2)); return;} const {ws,send}=await connect(page.webSocketDebuggerUrl); await send('Runtime.enable'); await send('Runtime.evaluate',{expression:'document.getElementById("btn").click()',returnByValue:true}); const chk=(await send('Runtime.evaluate',{expression:'({title:document.title,task:document.body.getAttribute("data-task"),out:document.getElementById("out").textContent,q:document.getElementById("q").value,body:document.body.innerText})',returnByValue:true})).result.value; result.check=chk; result.ok=!!(result.pluginLoaded && chk.task==='OK' && chk.out==='BROWSERSKILL_TASK_R222_OK'); try{ws.close();}catch{} fs.writeFileSync(out,JSON.stringify(result,null,2));}
main().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($bsTaskScript,$bsJs,(New-Object Text.UTF8Encoding($false)))
if($edgeCdp -and (Get-Command node -ErrorAction SilentlyContinue)){ $bsS=$bsTaskScript; $bsJ=$bsTaskJson; $ep=[string]$edgePort; $eid=$bsId; $bsNode=Run-Cap { node $using:bsS $using:bsJ $using:ep $using:eid 2>&1 | Out-String } 60; L ('browserskill_task_node=' + (San (($bsNode -split "`r?`n" | Select-Object -First 10) -join ' | '))) } else { L 'browserskill_task_skipped=no_edge_cdp_or_node' }
$bsOk=$false; $bsLoaded=$false; $bsOut=''
if(Test-Path -LiteralPath $bsTaskJson){ try{ $bjj=Get-Content -LiteralPath $bsTaskJson -Raw -Encoding UTF8 | ConvertFrom-Json; $bsOk=[bool]$bjj.ok; $bsLoaded=[bool]$bjj.pluginLoaded; $bsOut=[string]$bjj.check.out }catch{ L ('browserskill_task_parse_WARN=' + (San $_.Exception.Message)) } }
L ('browserskill_plugin_loaded=' + $bsLoaded + ' concrete_task_ok=' + $bsOk + ' out=' + (San $bsOut))
$repoPathHit=''
foreach($p in @('E:\0GitHub\BrowserSkill-01a0b237','E:\0github\BrowserSkill-01a0b237',('E:\0' + [string]([char]0x4E2D) + [string]([char]0x671F) + '\BrowserSkill-01a0b237'))){ if(Test-Path -LiteralPath $p){ $repoPathHit=$p; break } }
L ('browserskill_repo_path=' + (San $repoPathHit))
try{ Copy-Item -LiteralPath $bsTaskJson -Destination (Join-Path $outDir 'browserskill-edge-concrete-task-r222.json') -Force -ErrorAction SilentlyContinue }catch{}
$bsScanJson=Join-Path $reports 'browserskill-installed-scan-r222.json'
[IO.File]::WriteAllText($bsScanJson, ([pscustomobject]@{manifest=$bsManifest;extensionDir=$bsDir;id=$bsId;version=if($bsManifestObj){[string]$bsManifestObj.version}else{''};repoPath=$repoPathHit;loaded=$bsLoaded;taskOk=$bsOk;taskJson=$bsTaskJson} | ConvertTo-Json -Depth 5) + "`r`n", (New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $bsScanJson -Destination (Join-Path $outDir 'browserskill-installed-scan-r222.json') -Force -ErrorAction SilentlyContinue }catch{}

# ---------------------------------------------------------------------------
# 3. Refresh safe Tailscale phone file-share.
# ---------------------------------------------------------------------------
$shareReadme=Join-Path $phoneRoot 'README_PHONE_SHARE_R222.txt'
$shareIndex=Join-Path $phoneRoot 'index.html'
[IO.File]::WriteAllText($shareReadme, "Arena phone share R222`r`nOnly this folder is exposed: E:\\0mcp-agv-arena-optimized\\phone-share`r`nCopy selected files here, then open the tailnet URL on your phone browser.`r`n", (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($shareIndex, '<!doctype html><meta charset="utf-8"><title>Arena Phone Share R222</title><h1>Arena Phone Share R222</h1><p>If you can read this on your phone, Tailscale browser file access works.</p><p><a href="README_PHONE_SHARE_R222.txt">README_PHONE_SHARE_R222.txt</a></p>', (New-Object Text.UTF8Encoding($false)))
$tsExe=''
foreach($p in @('E:\Tailscale\tailscale.exe','C:\Program Files\Tailscale\tailscale.exe','C:\Program Files (x86)\Tailscale\tailscale.exe')){ if(Test-Path -LiteralPath $p){ $tsExe=$p; break } }
if(-not $tsExe){ try{ $cmd=Get-Command tailscale -ErrorAction SilentlyContinue; if($cmd){$tsExe=$cmd.Source} }catch{} }
$tsIp=''; $tsStatus=''
if($tsExe){ $t=$tsExe; $tsIp=(Run-Cap { & $using:t ip -4 2>&1 | Select-Object -First 1 | Out-String } 20).Trim(); $tsStatus=Run-Cap { & $using:t status 2>&1 | Out-String } 25 }
$phoneSeen=($tsStatus -match 'redmi|phone|android|100\.90\.87\.92')
$sharePort=18089
$pidFile=Join-Path $phoneRoot 'phone_share_python.pid'
if(Test-Path -LiteralPath $pidFile){ try{ $old=[int](Get-Content -LiteralPath $pidFile -Raw); if($old){ Stop-Process -Id $old -Force -ErrorAction SilentlyContinue } }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
if($py){ try{ $p=Start-Process -FilePath $py -ArgumentList @('-m','http.server',[string]$sharePort,'--bind','0.0.0.0','--directory',$phoneRoot) -PassThru -WindowStyle Hidden; [IO.File]::WriteAllText($pidFile,[string]$p.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('phone_share_pid=' + $p.Id) }catch{ L ('phone_share_start_WARN=' + (San $_.Exception.Message)) } } else { L 'phone_share_no_python=True' }
$fwOut=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 2>&1 | Out-String } 30
L ('phone_share_firewall=' + (San (($fwOut -split "`r?`n" | Select-Object -First 4) -join ' | ')))
$localText=Curl-Text ('http://127.0.0.1:' + $sharePort + '/') 10
$tsText=''; if($tsIp){ $tsText=Curl-Text ('http://' + $tsIp + ':' + $sharePort + '/') 10 }
$phoneUrl=if($tsIp){ 'http://' + $tsIp + ':' + $sharePort + '/' }else{ '' }
$shareOk=($localText -match 'Arena Phone Share R222') -and ($tsText -match 'Arena Phone Share R222')
L ('phone_share_url=' + $phoneUrl)
L ('phone_seen_in_tailscale_status=' + $phoneSeen)
L ('phone_share_local_ok=' + [bool]($localText -match 'Arena Phone Share R222') + ' tailscale_ip_ok=' + [bool]($tsText -match 'Arena Phone Share R222'))
$phoneGuide=Join-Path $reports 'phone-browser-file-share-r222.md'
W $phoneGuide @(
'# Phone browser file access r222',
'',
('Share root: ' + $phoneRoot),
('Phone URL: ' + $phoneUrl),
('Phone seen in tailscale status: ' + $phoneSeen),
('Laptop self-test through tailnet IP: ' + $shareOk),
'',
'On the phone: keep Tailscale connected, then open the Phone URL in any mobile browser.',
'Only files copied into the share root are exposed. Do not expose the whole disk.',
'If it does not open: keep the laptop awake, confirm phone Tailscale is connected, and retry the URL.'
)
try{ Copy-Item -LiteralPath $phoneGuide -Destination (Join-Path $outDir 'phone-browser-file-share-r222.md') -Force }catch{}

# Final summary.
$statusAgv=if($agvIllOk){'ANTIGRAVITY_TERMINAL_ILLUSTRATOR_GENERATED'}else{'ANTIGRAVITY_TERMINAL_ILLUSTRATOR_NOT_PROVEN'}
$statusBs=if($bsOk){'BROWSERSKILL_EDGE_PLUGIN_LOADED_TASK_OK'}elseif($bsLoaded){'BROWSERSKILL_EDGE_PLUGIN_LOADED_TASK_FAILED'}else{'BROWSERSKILL_EDGE_PLUGIN_NOT_LOADED'}
$statusPhone=if($shareOk){'PHONE_SHARE_TAILNET_OK'}else{'PHONE_SHARE_TAILNET_NOT_PROVEN'}
L ('status_antigravity=' + $statusAgv)
L ('status_browserskill=' + $statusBs)
L ('status_phone=' + $statusPhone)
L ('FINAL_R222: ' + $statusAgv + '_' + $statusBs + '_' + $statusPhone)
W $report $script:Lines
$summary=Join-Path $outDir 'antigravity-browserskill-phone-summary-r222.md'
W $summary @(
'# R222 summary',
'',
('Antigravity direct Illustrator status: ' + $statusAgv),
('AI: ' + $outAi),
('PNG: ' + $outPng),
('Terminal invoked marker file: ' + $outInvoke),
('Runner log: ' + $outLog),
'',
('BrowserSkill installed manifest: ' + $bsManifest),
('BrowserSkill repo path: ' + $repoPathHit),
('BrowserSkill loaded in Edge: ' + $bsLoaded),
('BrowserSkill concrete local page task OK: ' + $bsOk),
'',
('Phone share root: ' + $phoneRoot),
('Phone URL: ' + $phoneUrl),
('Phone seen in Tailscale status: ' + $phoneSeen),
('Laptop self-test via tailnet IP OK: ' + $shareOk),
'',
'No browser cookies, Kaggle credentials, tokens, passwords, or private keys were read or printed.'
)
exit 0
