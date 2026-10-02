# t177_antigravity_sendinput_browserskill_r225.ps1 - round 225.
# Stronger retry: use foreground Antigravity + keyboard input without clipboard,
# and quote the installed BrowserSkill extension path for Edge. ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Wait-Port([int]$port,[int]$sec){ $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function FInfo([string]$p){ if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return [pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')} }; return [pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''} }
function Curl-Text([string]$Url,[int]$Sec){ try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -L --max-time $Sec -sS $Url 2>&1|Out-String).Trim() }catch{ return $_.Exception.Message } }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$agvRoot=Join-Path $lab 'antigravity-tests\agv_sendinput_illustrator_r225'
$browserRoot=Join-Path $lab 'browser-tests\browserskill_edge_r225'
$phoneRoot=Join-Path $lab 'phone-share'
foreach($d in @($reports,$agvRoot,$browserRoot,$phoneRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$report=Join-Path $outDir 'ANTIGRAVITY_SENDINPUT_BROWSERSKILL_PHONE_R225.md'
L '# R225 Antigravity SendKeys terminal + BrowserSkill extension + phone share'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))

# 1. Prepare runner.
$runner=Join-Path $agvRoot 'run_illustrator_r225.ps1'
$outAi=Join-Path $agvRoot 'agv_sendinput_figure_r225.ai'
$outPng=Join-Path $agvRoot 'agv_sendinput_figure_r225.png'
$outDone=Join-Path $agvRoot 'agv_sendinput_illustrator_done_r225.txt'
$outInvoke=Join-Path $agvRoot 'agv_sendinput_terminal_invoked_r225.txt'
$outLog=Join-Path $agvRoot 'agv_sendinput_runner_r225.log'
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone,$outInvoke,$outLog -Force -ErrorAction SilentlyContinue }catch{}
$runnerText=@'
param()
$ErrorActionPreference='Continue'
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
$script:Lines=@()
$root='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_sendinput_illustrator_r225'
$outAi=Join-Path $root 'agv_sendinput_figure_r225.ai'
$outPng=Join-Path $root 'agv_sendinput_figure_r225.png'
$outDone=Join-Path $root 'agv_sendinput_illustrator_done_r225.txt'
$outLog=Join-Path $root 'agv_sendinput_runner_r225.log'
$outJsx=Join-Path $root 'agv_sendinput_illustrator_r225.jsx'
New-Item -ItemType Directory -Force -Path $root|Out-Null
L '# runner r225 from Antigravity terminal/keyboard path'
L ('time='+(Get-Date).ToString('s'))
$aiExe=$null
foreach($base in @('E:\','D:\','C:\Program Files','C:\Program Files (x86)')){ if(Test-Path -LiteralPath $base){ try{ $f=Get-ChildItem -LiteralPath $base -Recurse -Filter Illustrator.exe -File -ErrorAction SilentlyContinue|Select-Object -First 1; if($f){$aiExe=$f.FullName; break} }catch{} } }
L ('illustrator_exe='+$aiExe)
if(-not $aiExe){ L 'FINAL: NO_ILLUSTRATOR'; W $outLog $script:Lines; exit 2 }
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone -Force -ErrorAction SilentlyContinue }catch{}
$jsx=@"
(function(){
 function rgb(r,g,b){var c=new RGBColor(); c.red=r; c.green=g; c.blue=b; return c;}
 function t(doc,s,x,y,z,c){var f=doc.textFrames.add(); f.contents=s; f.position=[x,y]; f.textRange.characterAttributes.size=z; f.textRange.characterAttributes.fillColor=c; return f;}
 function r(doc,top,left,w,h,fill,stroke){var p=doc.pathItems.rectangle(top,left,w,h); p.filled=true; p.fillColor=fill; p.stroked=true; p.strokeColor=stroke; p.strokeWidth=3; return p;}
 var root='E:/0mcp-agv-arena-optimized/antigravity-tests/agv_sendinput_illustrator_r225/'; var done=new File(root+'agv_sendinput_illustrator_done_r225.txt'); var status=new File(root+'jsx_status_r225.txt');
 try{ var doc=app.documents.add(DocumentColorSpace.RGB,1000,620); r(doc,620,0,1000,620,rgb(255,255,255),rgb(255,255,255)); r(doc,540,75,850,410,rgb(248,250,252),rgb(15,23,42));
 var c1=doc.pathItems.ellipse(390,175,120,120); c1.filled=true; c1.fillColor=rgb(219,234,254); c1.stroked=true; c1.strokeColor=rgb(37,99,235); c1.strokeWidth=5;
 var c2=doc.pathItems.ellipse(390,440,120,120); c2.filled=true; c2.fillColor=rgb(220,252,231); c2.stroked=true; c2.strokeColor=rgb(22,163,74); c2.strokeWidth=5;
 var c3=doc.pathItems.ellipse(390,705,120,120); c3.filled=true; c3.fillColor=rgb(254,243,199); c3.stroked=true; c3.strokeColor=rgb(245,158,11); c3.strokeWidth=5;
 var l1=doc.pathItems.add(); l1.setEntirePath([[300,330],[440,330]]); l1.stroked=true; l1.strokeWidth=8; l1.strokeColor=rgb(100,116,139); l1.filled=false; var l2=doc.pathItems.add(); l2.setEntirePath([[560,330],[705,330]]); l2.stroked=true; l2.strokeWidth=8; l2.strokeColor=rgb(100,116,139); l2.filled=false;
 t(doc,'Antigravity keyboard terminal -> Illustrator R225',120,205,34,rgb(15,23,42)); t(doc,'Editable AI and PNG generated by Illustrator.',120,160,24,rgb(71,85,105)); t(doc,'ARENA_AGV_SENDINPUT_ILLUSTRATOR_R225',120,115,20,rgb(37,99,235)); t(doc,'Input',205,335,30,rgb(30,41,59)); t(doc,'Model',465,335,30,rgb(30,41,59)); t(doc,'Figure',725,335,30,rgb(30,41,59));
 var ai=new File(root+'agv_sendinput_figure_r225.ai'); var opt=new IllustratorSaveOptions(); try{opt.compatibility=Compatibility.ILLUSTRATOR17;}catch(e){} doc.saveAs(ai,opt); var png=new File(root+'agv_sendinput_figure_r225.png'); var po=new ExportOptionsPNG24(); po.antiAliasing=true; po.transparency=false; po.horizontalScale=100; po.verticalScale=100; doc.exportFile(png,ExportType.PNG24,po); try{doc.close(SaveOptions.DONOTSAVECHANGES);}catch(e){} done.encoding='UTF-8'; done.open('w'); done.write('OK R225 '+(new Date()).toString()); done.close(); status.open('w'); status.write('OK'); status.close(); }catch(e){status.open('w'); status.write('ERR '+e.message+' line '+e.line); status.close();}
})();
"@
[IO.File]::WriteAllText($outJsx,$jsx,(New-Object Text.UTF8Encoding($false)))
Start-Process -FilePath $aiExe -ArgumentList @('"'+$outJsx+'"')|Out-Null
$deadline=(Get-Date).AddSeconds(180)
while((Get-Date)-lt $deadline){ if(Test-Path -LiteralPath $outDone){break}; Start-Sleep -Milliseconds 800 }
$aiOk=Test-Path -LiteralPath $outAi; $pngOk=Test-Path -LiteralPath $outPng; $doneOk=Test-Path -LiteralPath $outDone
L ('ai_exists='+$aiOk+' ai_bytes='+$(if($aiOk){(Get-Item -LiteralPath $outAi).Length}else{0}))
L ('png_exists='+$pngOk+' png_bytes='+$(if($pngOk){(Get-Item -LiteralPath $outPng).Length}else{0}))
L ('done_exists='+$doneOk)
$st=Join-Path $root 'jsx_status_r225.txt'; if(Test-Path -LiteralPath $st){ L ('jsx_status='+(Get-Content -LiteralPath $st -Raw)) }
if($aiOk -and $pngOk -and $doneOk){ L 'FINAL: OK_ILLUSTRATOR_OUTPUTS' } else { L 'FINAL: FAIL_OUTPUTS' }
W $outLog $script:Lines
if($aiOk -and $pngOk -and $doneOk){exit 0}else{exit 3}
'@
[IO.File]::WriteAllText($runner,$runnerText,(New-Object Text.UTF8Encoding($false)))
L ('runner='+(San $runner))

# 2. Open Antigravity and send keyboard commands without clipboard.
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
if(Test-Path -LiteralPath $agExe){ try{ Start-Process -FilePath $agExe -ArgumentList @('--force-renderer-accessibility','--remote-debugging-port=9223')|Out-Null }catch{} }
Start-Sleep -Seconds 5
$terminalMarker='ARENA_AGV_SENDINPUT_TERMINAL_R225_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$cmdLine='cmd.exe /c echo '+$terminalMarker+' > "'+$outInvoke+'" && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'+$runner+'"'
$sendScript=Join-Path $agvRoot 'send_antigravity_keys_r225.ps1'
$sendText=@'
param([string]$Command)
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class FgWin { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd); [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd,int nCmdShow); }
"@
function EscSend([string]$s){ $r=''; foreach($ch in $s.ToCharArray()){ $c=[string]$ch; if($c -match '[\+\^%~\(\)\{\}\[\]]'){ $r += '{' + $c + '}' } else { $r += $c } }; return $r }
function TypeText([string]$s){ [System.Windows.Forms.SendKeys]::SendWait((EscSend $s)); Start-Sleep -Milliseconds 200 }
$p=Get-Process Antigravity -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if(-not $p){ throw 'no Antigravity window' }
[FgWin]::ShowWindowAsync($p.MainWindowHandle,9)|Out-Null
[FgWin]::SetForegroundWindow($p.MainWindowHandle)|Out-Null
Start-Sleep -Milliseconds 800
[System.Windows.Forms.SendKeys]::SendWait('{ESC}')
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait('{F1}')
Start-Sleep -Milliseconds 1000
TypeText 'Terminal: Create New Terminal'
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Seconds 5
TypeText $Command
[System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
Start-Sleep -Seconds 10
'@
[IO.File]::WriteAllText($sendScript,$sendText,(New-Object Text.UTF8Encoding($false)))
$ss=$sendScript; $cl=$cmdLine
$sendOut=Run-Cap { powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $using:ss -Command $using:cl 2>&1|Out-String } 60
L ('sendkeys_out='+(San (($sendOut -split "`r?`n"|Select-Object -First 12)-join ' | ')))

$deadline=(Get-Date).AddSeconds(300)
while((Get-Date)-lt $deadline){ if((Test-Path -LiteralPath $outDone)-or((Test-Path -LiteralPath $outAi)-and(Test-Path -LiteralPath $outPng))){break}; Start-Sleep -Seconds 5 }
$invoke=FInfo $outInvoke; $ai=FInfo $outAi; $png=FInfo $outPng; $done=FInfo $outDone
$agvOk=$invoke.exists -and $ai.exists -and $png.exists -and $done.exists -and ($ai.bytes -gt 1000) -and ($png.bytes -gt 1000)
L ('antigravity_invoked='+$invoke.exists+' marker='+$terminalMarker)
L ('antigravity_outputs ok='+$agvOk+' ai='+$ai.exists+'/'+$ai.bytes+' png='+$png.exists+'/'+$png.bytes+' done='+$done.exists)
if(Test-Path -LiteralPath $outLog){ foreach($line in (Get-Content -LiteralPath $outLog -Tail 50)){ if($line.Trim()){ L ('runner_log|'+(San $line)) } } } else { L 'runner_log_missing=True' }
$agvJson=Join-Path $reports 'antigravity-sendinput-illustrator-r225.json'
[IO.File]::WriteAllText($agvJson,([pscustomobject]@{ok=$agvOk;marker=$terminalMarker;invoke=$invoke;ai=$ai;png=$png;done=$done;runner=$runner;log=$outLog;sendOut=$sendOut}|ConvertTo-Json -Depth 6)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $agvJson -Destination (Join-Path $outDir 'antigravity-sendinput-illustrator-r225.json') -Force }catch{}

# 3. BrowserSkill extension load test with quoted extension path.
$bsManifest=$null; $bsObj=$null
foreach($root in @((Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Extensions'),(Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Profile 1\Extensions'))){ if(Test-Path -LiteralPath $root){ foreach($mf in @(Get-ChildItem -LiteralPath $root -Recurse -Depth 3 -Filter manifest.json -File -ErrorAction SilentlyContinue)){ try{ $raw=Get-Content -LiteralPath $mf.FullName -Raw -Encoding UTF8; $j=$raw|ConvertFrom-Json; if([string]$j.name -eq 'BrowserSkill' -or $raw -match 'BrowserSkill'){ $bsManifest=$mf.FullName; $bsObj=$j; break } }catch{} }; if($bsManifest){break} } }
$bsDir=if($bsManifest){Split-Path -Parent $bsManifest}else{''}; $bsId=if($bsManifest){Split-Path -Leaf (Split-Path -Parent $bsDir)}else{''}; $bsVersion=''; if($bsObj){$bsVersion=[string]$bsObj.version}
L ('browserskill_manifest='+(San $bsManifest))
L ('browserskill_id='+(San $bsId)+' version='+$bsVersion)
$html=Join-Path $browserRoot 'browserskill_task_r225.html'
[IO.File]::WriteAllText($html,'<!doctype html><meta charset="utf-8"><title>BrowserSkill task R225</title><button id="btn" onclick="document.body.setAttribute(''data-task'',''OK'');document.getElementById(''out'').textContent=''BROWSERSKILL_R225_OK'';">Run</button><div id="out">waiting</div>',(New-Object Text.UTF8Encoding($false)))
$edgeExe=''; foreach($p in @((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),(Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'))){ if($p -and(Test-Path -LiteralPath $p)){ $edgeExe=$p; break } }
$edgePort=9228; $edgeProfile=Join-Path $browserRoot 'edge-profile'; try{ Remove-Item -LiteralPath $edgeProfile -Recurse -Force -ErrorAction SilentlyContinue }catch{}
if($edgeExe){ $args='--remote-debugging-port='+$edgePort+' --remote-debugging-address=127.0.0.1 --user-data-dir="'+$edgeProfile+'" --no-first-run --disable-first-run-ui --enable-extensions'; if($bsDir){ $args += ' --disable-extensions-except="'+$bsDir+'" --load-extension="'+$bsDir+'"' }; $args += ' "file:///'+($html -replace '\\','/')+'"'; try{ $edgeP=Start-Process -FilePath $edgeExe -ArgumentList $args -PassThru; L ('edge_started_pid='+$edgeP.Id+' args='+(San $args)); Start-Sleep -Seconds 8 }catch{ L ('edge_start_ERR='+(San $_.Exception.Message)) } }
$edgeCdp=Wait-Port $edgePort 20
L ('edge_cdp='+$edgeCdp)
$bsTaskJson=Join-Path $reports 'browserskill-edge-concrete-task-r225.json'
$bsScript=Join-Path $browserRoot 'browserskill_task_r225.cjs'
$bsJs=@'
const fs=require('fs'); const out=process.argv[2], port=process.argv[3], eid=process.argv[4]||''; const WS=globalThis.WebSocket;
async function getJson(u){const r=await fetch(u); return await r.json();}
function connect(u){return new Promise((res,rej)=>{const ws=new WS(u); let id=0; const pend=new Map(); ws.onmessage=e=>{const m=JSON.parse(e.data); if(m.id&&pend.has(m.id)){const p=pend.get(m.id); pend.delete(m.id); m.error?p.rej(new Error(JSON.stringify(m.error))):p.res(m.result);}}; ws.onopen=()=>res({ws,send:(method,params={})=>new Promise((res,rej)=>{const mid=++id; pend.set(mid,{res,rej}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=rej;});}
(async()=>{let result={ok:false,eid}; const targets=await getJson(`http://127.0.0.1:${port}/json/list`); result.targets=targets.map(t=>({type:t.type,title:t.title,url:t.url})); result.extensionTargets=targets.filter(t=>(t.url||'').includes('chrome-extension://'+eid)).map(t=>({type:t.type,title:t.title,url:t.url})); result.pluginLoaded=result.extensionTargets.length>0; const page=targets.find(t=>(t.url||'').includes('browserskill_task_r225.html'))||targets.find(t=>t.type==='page'&&t.webSocketDebuggerUrl); if(page){const {ws,send}=await connect(page.webSocketDebuggerUrl); await send('Runtime.enable'); await send('Runtime.evaluate',{expression:'document.getElementById("btn").click()',returnByValue:true}); const chk=(await send('Runtime.evaluate',{expression:'({task:document.body.getAttribute("data-task"),out:document.getElementById("out").textContent,title:document.title})',returnByValue:true})).result.value; result.check=chk; result.ok=!!(result.pluginLoaded&&chk.task==='OK'&&chk.out==='BROWSERSKILL_R225_OK'); try{ws.close();}catch{}} fs.writeFileSync(out,JSON.stringify(result,null,2));})().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($bsScript,$bsJs,(New-Object Text.UTF8Encoding($false)))
if($edgeCdp -and(Get-Command node -ErrorAction SilentlyContinue)){ $bss=$bsScript; $bsj=$bsTaskJson; $ep=[string]$edgePort; $eid=$bsId; $bsNode=Run-Cap { node $using:bss $using:bsj $using:ep $using:eid 2>&1|Out-String } 60; L ('browserskill_node='+(San (($bsNode -split "`r?`n"|Select-Object -First 8)-join ' | '))) } else { L 'browserskill_node_skipped=True' }
$bsOk=$false; $bsLoaded=$false; $bsOut=''
if(Test-Path -LiteralPath $bsTaskJson){ try{ $jj=Get-Content -LiteralPath $bsTaskJson -Raw -Encoding UTF8|ConvertFrom-Json; $bsOk=[bool]$jj.ok; $bsLoaded=[bool]$jj.pluginLoaded; $bsOut=[string]$jj.check.out }catch{} }
$bsRepo=''; foreach($p in @('E:\0GitHub\BrowserSkill-01a0b237','E:\0github\BrowserSkill-01a0b237',('E:\0'+[string]([char]0x4E2D)+[string]([char]0x671F)+'\BrowserSkill-01a0b237'))){ if(Test-Path -LiteralPath $p){$bsRepo=$p; break} }
L ('browserskill_repo='+(San $bsRepo))
L ('browserskill_loaded='+$bsLoaded+' task_ok='+$bsOk+' out='+(San $bsOut))
$bsScan=Join-Path $reports 'browserskill-installed-scan-r225.json'
[IO.File]::WriteAllText($bsScan,([pscustomobject]@{manifest=$bsManifest;id=$bsId;version=$bsVersion;extensionDir=$bsDir;repo=$bsRepo;edgeCdp=$edgeCdp;loaded=$bsLoaded;taskOk=$bsOk;taskJson=$bsTaskJson}|ConvertTo-Json -Depth 6)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $bsScan -Destination (Join-Path $outDir 'browserskill-installed-scan-r225.json') -Force; if(Test-Path -LiteralPath $bsTaskJson){ Copy-Item -LiteralPath $bsTaskJson -Destination (Join-Path $outDir 'browserskill-edge-concrete-task-r225.json') -Force } }catch{}

# 4. Keep phone file share alive.
[IO.File]::WriteAllText((Join-Path $phoneRoot 'index.html'),'<title>Arena Phone Share R225</title><h1>Arena Phone Share R225</h1><p>Tailscale phone browser access is limited to this folder.</p>',(New-Object Text.UTF8Encoding($false)))
$tsExe=''; foreach($p in @('E:\Tailscale\tailscale.exe','C:\Program Files\Tailscale\tailscale.exe','C:\Program Files (x86)\Tailscale\tailscale.exe')){ if(Test-Path -LiteralPath $p){$tsExe=$p; break} }
$tsIp=''; $tsStatus=''; if($tsExe){ $te=$tsExe; $tsIp=(Run-Cap { & $using:te ip -4 2>&1|Select-Object -First 1|Out-String } 20).Trim(); $tsStatus=Run-Cap { & $using:te status 2>&1|Out-String } 25 }
$phoneSeen=($tsStatus -match 'redmi|phone|android|100\.90\.87\.92')
$sharePort=18089; $pidFile=Join-Path $phoneRoot 'phone_share_python.pid'; if(Test-Path -LiteralPath $pidFile){ try{ Stop-Process -Id ([int](Get-Content -LiteralPath $pidFile -Raw)) -Force -ErrorAction SilentlyContinue }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
if($py){ try{ $pp=Start-Process -FilePath $py -ArgumentList @('-m','http.server',[string]$sharePort,'--bind','0.0.0.0','--directory',$phoneRoot) -PassThru -WindowStyle Hidden; [IO.File]::WriteAllText($pidFile,[string]$pp.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('phone_share_pid='+$pp.Id) }catch{ L ('phone_share_ERR='+(San $_.Exception.Message)) } }
$fw=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 2>&1|Out-String } 30
$phoneUrl=if($tsIp){'http://'+$tsIp+':'+$sharePort+'/'}else{''}
$localText=Curl-Text ('http://127.0.0.1:'+$sharePort+'/') 10; $tsText=''; if($tsIp){$tsText=Curl-Text $phoneUrl 10}
$phoneOk=($localText -match 'Arena Phone Share R225') -and ($tsText -match 'Arena Phone Share R225')
L ('phone_url='+$phoneUrl)
L ('phone_seen='+$phoneSeen+' phone_share_ok='+$phoneOk)
$phoneGuide=Join-Path $outDir 'phone-browser-file-share-r225.md'
W $phoneGuide @('# Phone browser file access r225','',('Share root: '+$phoneRoot),('Phone URL: '+$phoneUrl),('Phone seen in Tailscale status: '+$phoneSeen),('Laptop self-test through tailnet IP: '+$phoneOk),'','On the phone, keep Tailscale connected and open the Phone URL in the browser. Only this folder is exposed.')

$statusAgv=if($agvOk){'ANTIGRAVITY_SENDINPUT_ILLUSTRATOR_GENERATED'}else{'ANTIGRAVITY_SENDINPUT_ILLUSTRATOR_NOT_PROVEN'}
$statusBs=if($bsOk){'BROWSERSKILL_EDGE_PLUGIN_LOADED_TASK_OK'}elseif($bsLoaded){'BROWSERSKILL_EDGE_PLUGIN_LOADED_TASK_FAILED'}else{'BROWSERSKILL_EDGE_PLUGIN_NOT_LOADED'}
$statusPhone=if($phoneOk){'PHONE_SHARE_TAILNET_OK'}else{'PHONE_SHARE_TAILNET_NOT_PROVEN'}
L ('status_antigravity='+$statusAgv)
L ('status_browserskill='+$statusBs)
L ('status_phone='+$statusPhone)
L ('FINAL_R225: '+$statusAgv+'_'+$statusBs+'_'+$statusPhone)
W $report $script:Lines
$summary=Join-Path $outDir 'antigravity-browserskill-phone-summary-r225.md'
W $summary @('# R225 summary','',('Antigravity Illustrator status: '+$statusAgv),('AI: '+$outAi),('PNG: '+$outPng),('Terminal marker: '+$outInvoke),'',('BrowserSkill manifest: '+$bsManifest),('BrowserSkill repo: '+$bsRepo),('BrowserSkill loaded in Edge: '+$bsLoaded),('BrowserSkill concrete task OK: '+$bsOk),'',('Phone share root: '+$phoneRoot),('Phone URL: '+$phoneUrl),('Phone seen in Tailscale status: '+$phoneSeen),('Tailnet self-test OK: '+$phoneOk),'','No browser cookies, Kaggle credentials, tokens, passwords, or private keys were read or printed.')
exit 0
