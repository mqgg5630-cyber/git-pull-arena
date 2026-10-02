# t178_antigravity_cdp_node_illustrator_r226.ps1 - round 226.
# Try to execute the Illustrator runner from inside the Antigravity Electron/CDP
# renderer context via Node child_process if Antigravity exposes one. ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Wait-Port([int]$port,[int]$sec){ $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(350)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function FInfo([string]$p){ if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return [pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')} }; return [pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''} }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$root=Join-Path $lab 'antigravity-tests\agv_cdp_node_illustrator_r226'
foreach($d in @($reports,$root)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$report=Join-Path $outDir 'ANTIGRAVITY_CDP_NODE_ILLUSTRATOR_R226.md'
L '# R226 Antigravity CDP Node child_process Illustrator test'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))

$runner=Join-Path $root 'run_illustrator_r226.ps1'
$outAi=Join-Path $root 'agv_cdp_node_figure_r226.ai'
$outPng=Join-Path $root 'agv_cdp_node_figure_r226.png'
$outDone=Join-Path $root 'agv_cdp_node_done_r226.txt'
$outInvoke=Join-Path $root 'agv_cdp_node_invoked_r226.txt'
$outLog=Join-Path $root 'agv_cdp_node_runner_r226.log'
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone,$outInvoke,$outLog -Force -ErrorAction SilentlyContinue }catch{}
$runnerText=@'
param()
$ErrorActionPreference='Continue'
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
$script:Lines=@()
$root='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_cdp_node_illustrator_r226'
$outAi=Join-Path $root 'agv_cdp_node_figure_r226.ai'
$outPng=Join-Path $root 'agv_cdp_node_figure_r226.png'
$outDone=Join-Path $root 'agv_cdp_node_done_r226.txt'
$outLog=Join-Path $root 'agv_cdp_node_runner_r226.log'
$outJsx=Join-Path $root 'agv_cdp_node_illustrator_r226.jsx'
New-Item -ItemType Directory -Force -Path $root|Out-Null
L '# runner r226 launched by Antigravity CDP Node child_process'
L ('time='+(Get-Date).ToString('s'))
$aiExe=$null
foreach($base in @('E:\','D:\','C:\Program Files','C:\Program Files (x86)')){ if(Test-Path -LiteralPath $base){ try{ $f=Get-ChildItem -LiteralPath $base -Recurse -Filter Illustrator.exe -File -ErrorAction SilentlyContinue|Select-Object -First 1; if($f){$aiExe=$f.FullName; break} }catch{} } }
L ('illustrator_exe='+$aiExe)
if(-not $aiExe){ L 'FINAL: NO_ILLUSTRATOR'; W $outLog $script:Lines; exit 2 }
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone -Force -ErrorAction SilentlyContinue }catch{}
$jsx=@"
(function(){
 function rgb(r,g,b){var c=new RGBColor(); c.red=r; c.green=g; c.blue=b; return c;}
 function text(doc,s,x,y,z,c){var f=doc.textFrames.add(); f.contents=s; f.position=[x,y]; f.textRange.characterAttributes.size=z; f.textRange.characterAttributes.fillColor=c; return f;}
 function rect(doc,top,left,w,h,fill,stroke){var p=doc.pathItems.rectangle(top,left,w,h); p.filled=true; p.fillColor=fill; p.stroked=true; p.strokeColor=stroke; p.strokeWidth=3; return p;}
 var root='E:/0mcp-agv-arena-optimized/antigravity-tests/agv_cdp_node_illustrator_r226/'; var done=new File(root+'agv_cdp_node_done_r226.txt'); var stat=new File(root+'jsx_status_r226.txt');
 try{ var doc=app.documents.add(DocumentColorSpace.RGB,1000,620); rect(doc,620,0,1000,620,rgb(255,255,255),rgb(255,255,255)); rect(doc,545,80,840,420,rgb(248,250,252),rgb(15,23,42));
 for(var i=0;i<3;i++){ var colors=[[219,234,254,37,99,235],[220,252,231,22,163,74],[254,243,199,245,158,11]][i]; var x=[190,450,710][i]; var c=doc.pathItems.ellipse(395,x,120,120); c.filled=true; c.fillColor=rgb(colors[0],colors[1],colors[2]); c.stroked=true; c.strokeColor=rgb(colors[3],colors[4],colors[5]); c.strokeWidth=5; }
 var l1=doc.pathItems.add(); l1.setEntirePath([[310,335],[450,335]]); l1.stroked=true; l1.strokeWidth=8; l1.strokeColor=rgb(100,116,139); l1.filled=false; var l2=doc.pathItems.add(); l2.setEntirePath([[570,335],[710,335]]); l2.stroked=true; l2.strokeWidth=8; l2.strokeColor=rgb(100,116,139); l2.filled=false;
 text(doc,'Antigravity CDP Node -> Illustrator R226',120,205,34,rgb(15,23,42)); text(doc,'If this exists, Antigravity executed child_process to run Illustrator.',120,160,23,rgb(71,85,105)); text(doc,'ARENA_AGV_CDP_NODE_ILLUSTRATOR_R226',120,115,20,rgb(37,99,235)); text(doc,'Input',215,340,30,rgb(30,41,59)); text(doc,'Model',475,340,30,rgb(30,41,59)); text(doc,'Figure',735,340,30,rgb(30,41,59));
 var ai=new File(root+'agv_cdp_node_figure_r226.ai'); var opt=new IllustratorSaveOptions(); try{opt.compatibility=Compatibility.ILLUSTRATOR17;}catch(e){} doc.saveAs(ai,opt); var png=new File(root+'agv_cdp_node_figure_r226.png'); var po=new ExportOptionsPNG24(); po.antiAliasing=true; po.transparency=false; po.horizontalScale=100; po.verticalScale=100; doc.exportFile(png,ExportType.PNG24,po); try{doc.close(SaveOptions.DONOTSAVECHANGES);}catch(e){} done.encoding='UTF-8'; done.open('w'); done.write('OK R226 '+(new Date()).toString()); done.close(); stat.open('w'); stat.write('OK'); stat.close(); }catch(e){stat.open('w'); stat.write('ERR '+e.message+' line '+e.line); stat.close();}
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
$st=Join-Path $root 'jsx_status_r226.txt'; if(Test-Path -LiteralPath $st){ L ('jsx_status='+(Get-Content -LiteralPath $st -Raw)) }
if($aiOk -and $pngOk -and $doneOk){ L 'FINAL: OK_ILLUSTRATOR_OUTPUTS' } else { L 'FINAL: FAIL_OUTPUTS' }
W $outLog $script:Lines
if($aiOk -and $pngOk -and $doneOk){exit 0}else{exit 3}
'@
[IO.File]::WriteAllText($runner,$runnerText,(New-Object Text.UTF8Encoding($false)))
L ('runner='+(San $runner))

# Start/connect Antigravity CDP.
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$port=9223
$cdp=Wait-Port $port 2
if(-not $cdp -and(Test-Path -LiteralPath $agExe)){ try{ Start-Process -FilePath $agExe -ArgumentList @('--force-renderer-accessibility','--remote-debugging-port='+$port)|Out-Null }catch{ L ('start_WARN='+(San $_.Exception.Message)) }; Start-Sleep -Seconds 8; $cdp=Wait-Port $port 8 }
L ('antigravity_cdp='+$cdp)
$marker='ARENA_AGV_CDP_NODE_CMD_R226_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$cdpJson=Join-Path $reports 'antigravity-cdp-node-illustrator-r226.json'
$cdpScript=Join-Path $root 'agv_cdp_node_spawn_r226.cjs'
$js=@'
const fs=require('fs'); const out=process.argv[2], marker=process.argv[3], invoke=process.argv[4], runner=process.argv[5], port=process.argv[6]||'9223'; const WS=globalThis.WebSocket;
async function getJson(u){const r=await fetch(u); return await r.json();}
function connect(url){return new Promise((resolve,reject)=>{const ws=new WS(url); let id=0; const pending=new Map(); ws.onmessage=ev=>{const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){const p=pending.get(m.id); pending.delete(m.id); m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);}}; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=reject;});}
(async()=>{const result={ok:false,marker}; const targets=await getJson(`http://127.0.0.1:${port}/json/list`); result.targets=targets.map(t=>({title:t.title,url:t.url,type:t.type})); const target=targets.find(t=>(t.title||'').includes('Antigravity')&&t.webSocketDebuggerUrl)||targets.find(t=>t.webSocketDebuggerUrl); if(!target){fs.writeFileSync(out,JSON.stringify(result,null,2)); return;} result.target={title:target.title,url:target.url,type:target.type}; const {ws,send}=await connect(target.webSocketDebuggerUrl); await send('Runtime.enable'); await send('Page.bringToFront').catch(()=>{});
 const diagExpr=`(() => { const keys=Object.keys(globalThis).filter(k=>/require|process|electron|vscode|monaco|ipc|node/i.test(k)).slice(0,200); let reqType=typeof globalThis.require; let procType=typeof globalThis.process; let ua=navigator.userAgent; return {reqType,procType,keys,ua,title:document.title}; })()`;
 const diag=await send('Runtime.evaluate',{expression:diagExpr,returnByValue:true,awaitPromise:true}); result.diag=diag.result.value;
 const spawnExpr=`(() => new Promise((resolve) => { const res={spawned:false,marker:${JSON.stringify(marker)}}; try { let reqs=[]; if(typeof globalThis.require==='function') reqs.push(globalThis.require); if(globalThis.module&&typeof globalThis.module.require==='function') reqs.push(globalThis.module.require.bind(globalThis.module)); if(globalThis.process&&globalThis.process.mainModule&&typeof globalThis.process.mainModule.require==='function') reqs.push(globalThis.process.mainModule.require.bind(globalThis.process.mainModule)); if(typeof globalThis.__non_webpack_require__==='function') reqs.push(globalThis.__non_webpack_require__); let cp=null, fsn=null, used=-1, last=''; for(let i=0;i<reqs.length;i++){ try { cp=reqs[i]('child_process'); fsn=reqs[i]('fs'); if(cp&&cp.spawn&&fsn&&fsn.writeFileSync){used=i; break;} } catch(e){ last=String(e.message||e); } } res.requireCandidates=reqs.length; res.used=used; res.lastError=last; if(used<0){ resolve(res); return; } fsn.writeFileSync(${JSON.stringify(invoke)}, ${JSON.stringify(marker)}); const child=cp.spawn('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',${JSON.stringify(runner)}],{windowsHide:true,detached:true,stdio:'ignore'}); child.unref(); res.spawned=true; res.pid=child.pid; resolve(res); } catch(e){ res.error=String(e.stack||e); resolve(res); } }))()`;
 const sp=await send('Runtime.evaluate',{expression:spawnExpr,returnByValue:true,awaitPromise:true}); result.spawn=sp.result.value; result.ok=!!result.spawn.spawned; try{ws.close();}catch{} fs.writeFileSync(out,JSON.stringify(result,null,2));})().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($cdpScript,$js,(New-Object Text.UTF8Encoding($false)))
if($cdp -and(Get-Command node -ErrorAction SilentlyContinue)){ $cs=$cdpScript; $cj=$cdpJson; $mk=$marker; $iv=$outInvoke; $rn=$runner; $pt=[string]$port; $nodeOut=Run-Cap { node $using:cs $using:cj $using:mk $using:iv $using:rn $using:pt 2>&1|Out-String } 90; L ('node_spawn_out='+(San (($nodeOut -split "`r?`n"|Select-Object -First 10)-join ' | '))) } else { L 'node_spawn_skipped=True' }
Start-Sleep -Seconds 5
$deadline=(Get-Date).AddSeconds(300)
while((Get-Date)-lt $deadline){ if((Test-Path -LiteralPath $outDone)-or((Test-Path -LiteralPath $outAi)-and(Test-Path -LiteralPath $outPng))){break}; Start-Sleep -Seconds 5 }
$invoke=FInfo $outInvoke; $ai=FInfo $outAi; $png=FInfo $outPng; $done=FInfo $outDone
$ok=$invoke.exists -and $ai.exists -and $png.exists -and $done.exists -and ($ai.bytes -gt 1000) -and ($png.bytes -gt 1000)
L ('cdp_node_invoked='+$invoke.exists+' marker='+$marker)
L ('cdp_node_outputs ok='+$ok+' ai='+$ai.exists+'/'+$ai.bytes+' png='+$png.exists+'/'+$png.bytes+' done='+$done.exists)
if(Test-Path -LiteralPath $outLog){ foreach($line in (Get-Content -LiteralPath $outLog -Tail 50)){ if($line.Trim()){ L ('runner_log|'+(San $line)) } } } else { L 'runner_log_missing=True' }
if(Test-Path -LiteralPath $cdpJson){ try{ $jj=Get-Content -LiteralPath $cdpJson -Raw -Encoding UTF8|ConvertFrom-Json; L ('cdp_spawn_ok='+[bool]$jj.ok+' requireCandidates='+$jj.spawn.requireCandidates+' used='+$jj.spawn.used+' err='+(San ([string]$jj.spawn.lastError))+' diag_req='+$jj.diag.reqType+' diag_proc='+$jj.diag.procType) }catch{ L ('cdp_json_parse_WARN='+(San $_.Exception.Message)) } }
$summaryJson=Join-Path $reports 'antigravity-cdp-node-illustrator-summary-r226.json'
[IO.File]::WriteAllText($summaryJson,([pscustomobject]@{ok=$ok;marker=$marker;invoke=$invoke;ai=$ai;png=$png;done=$done;runner=$runner;log=$outLog;cdpJson=$cdpJson}|ConvertTo-Json -Depth 6)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $summaryJson -Destination (Join-Path $outDir 'antigravity-cdp-node-illustrator-summary-r226.json') -Force; Copy-Item -LiteralPath $cdpJson -Destination (Join-Path $outDir 'antigravity-cdp-node-illustrator-r226.json') -Force -ErrorAction SilentlyContinue }catch{}
$status=if($ok){'ANTIGRAVITY_CDP_NODE_ILLUSTRATOR_GENERATED'}else{'ANTIGRAVITY_CDP_NODE_ILLUSTRATOR_NOT_PROVEN'}
L ('status_antigravity='+$status)
L ('FINAL_R226: '+$status)
W $report $script:Lines
$sum=Join-Path $outDir 'antigravity-cdp-node-illustrator-summary-r226.md'
W $sum @('# R226 summary','',('Antigravity CDP Node Illustrator status: '+$status),('AI: '+$outAi),('PNG: '+$outPng),('Invoke marker: '+$outInvoke),('Runner log: '+$outLog),('CDP JSON: '+$cdpJson),'','No credentials, cookies, tokens, passwords, or private keys were read or printed.')
exit 0
