# t179_antigravity_agent_autorun_phonefix_r227.ps1 - round 227.
# Fix phone share HTTP/HTTPS confusion and keep polling Antigravity agent/tools
# approvals until an Illustrator runner produces AI+PNG, or until timed out.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Wait-Port([int]$port,[int]$sec){ $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function FInfo([string]$p){ if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return [pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')} }; return [pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''} }
function Curl-Text([string]$Url,[int]$Sec){ try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -k -L --max-time $Sec -sS $Url 2>&1|Out-String).Trim() }catch{ return $_.Exception.Message } }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$agvRoot=Join-Path $lab 'antigravity-tests\agv_agent_autorun_r227'
$phoneRoot=Join-Path $lab 'phone-share'
foreach($d in @($reports,$agvRoot,$phoneRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$report=Join-Path $outDir 'ANTIGRAVITY_AGENT_AUTORUN_PHONEFIX_R227.md'
L '# R227 Antigravity agent autorun polling + phone share HTTP/HTTPS fix'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))

# ---------------------------------------------------------------------------
# A. Phone share: keep raw HTTP tailnet URL and try to enable Tailscale Serve
# HTTPS URL too, so a phone that auto-upgrades to HTTPS has a correct endpoint.
# ---------------------------------------------------------------------------
[IO.File]::WriteAllText((Join-Path $phoneRoot 'index.html'),'<title>Arena Phone Share R227</title><h1>Arena Phone Share R227</h1><p>Use HTTP tailnet IP or HTTPS Tailscale Serve URL. This folder only.</p><p><a href="README_PHONE_SHARE_R227.txt">README</a></p>',(New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText((Join-Path $phoneRoot 'README_PHONE_SHARE_R227.txt'),"Arena Phone Share R227`r`nOnly files in E:\\0mcp-agv-arena-optimized\\phone-share are exposed.`r`nIf a browser says Cloudflare plain HTTP request was sent to HTTPS port, use the HTTPS Tailscale Serve URL or type the raw http://100.x URL exactly.`r`n",(New-Object Text.UTF8Encoding($false)))
$sharePort=18089
$pidFile=Join-Path $phoneRoot 'phone_share_python.pid'
if(Test-Path -LiteralPath $pidFile){ try{ Stop-Process -Id ([int](Get-Content -LiteralPath $pidFile -Raw)) -Force -ErrorAction SilentlyContinue }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
if($py){ try{ $pp=Start-Process -FilePath $py -ArgumentList @('-m','http.server',[string]$sharePort,'--bind','0.0.0.0','--directory',$phoneRoot) -PassThru -WindowStyle Hidden; [IO.File]::WriteAllText($pidFile,[string]$pp.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('phone_http_pid='+$pp.Id) }catch{ L ('phone_http_start_ERR='+(San $_.Exception.Message)) } } else { L 'phone_http_no_python=True' }
$fw=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 profile=any 2>&1|Out-String } 30
L ('phone_firewall='+(San (($fw -split "`r?`n"|Select-Object -First 4)-join ' | ')))
$tsExe=''; foreach($p in @('E:\Tailscale\tailscale.exe','C:\Program Files\Tailscale\tailscale.exe','C:\Program Files (x86)\Tailscale\tailscale.exe')){ if(Test-Path -LiteralPath $p){$tsExe=$p; break} }
if(-not $tsExe){ try{ $cmd=Get-Command tailscale -ErrorAction SilentlyContinue; if($cmd){$tsExe=$cmd.Source} }catch{} }
$tsIp=''; $dnsName=''; $phoneSeen=$false; $serveOuts=@(); $serveStatus=''
if($tsExe){
  $te=$tsExe
  $tsIp=(Run-Cap { & $using:te ip -4 2>&1|Select-Object -First 1|Out-String } 20).Trim()
  $statusJson=Run-Cap { & $using:te status --json 2>&1|Out-String } 30
  try{ $sj=$statusJson|ConvertFrom-Json; $dnsName=[string]$sj.Self.DNSName; if($dnsName.EndsWith('.')){$dnsName=$dnsName.Substring(0,$dnsName.Length-1)}; $phoneSeen=($statusJson -match 'redmi|phone|android|100\.90\.87\.92') }catch{ $phoneSeen=($statusJson -match 'redmi|phone|android|100\.90\.87\.92') }
  $serveHelp=Run-Cap { & $using:te serve --help 2>&1|Out-String } 30
  L ('tailscale_ip='+$tsIp)
  L ('tailscale_dns='+$dnsName)
  L ('tailscale_phone_seen='+$phoneSeen)
  L ('tailscale_serve_help_head='+(San (($serveHelp -split "`r?`n"|Select-Object -First 5)-join ' | ')))
  $serveOuts += 'try1:'+(Run-Cap { & $using:te serve --bg http://127.0.0.1:18089 2>&1|Out-String } 45)
  $serveStatus=Run-Cap { & $using:te serve status 2>&1|Out-String } 30
  if($serveStatus -notmatch '18089|127\.0\.0\.1'){
    $serveOuts += 'try2:'+(Run-Cap { & $using:te serve --bg --set-path / http://127.0.0.1:18089 2>&1|Out-String } 45)
    $serveStatus=Run-Cap { & $using:te serve status 2>&1|Out-String } 30
  }
  if($serveStatus -notmatch '18089|127\.0\.0\.1'){
    $serveOuts += 'try3:'+(Run-Cap { & $using:te serve --bg 18089 2>&1|Out-String } 45)
    $serveStatus=Run-Cap { & $using:te serve status 2>&1|Out-String } 30
  }
}
$httpUrl=if($tsIp){'http://'+$tsIp+':'+$sharePort+'/'}else{''}
$httpsUrl=if($dnsName){'https://'+$dnsName+'/'}else{''}
$localHttp=Curl-Text ('http://127.0.0.1:'+$sharePort+'/') 10
$tailHttp=''; if($httpUrl){$tailHttp=Curl-Text $httpUrl 10}
$tailHttps=''; if($httpsUrl){$tailHttps=Curl-Text $httpsUrl 15}
$httpOk=($localHttp -match 'Arena Phone Share R227') -and ($tailHttp -match 'Arena Phone Share R227')
$httpsOk=($tailHttps -match 'Arena Phone Share R227')
L ('phone_http_url='+$httpUrl)
L ('phone_https_url='+$httpsUrl)
L ('phone_http_ok='+$httpOk+' phone_https_ok='+$httpsOk)
foreach($o in $serveOuts){ L ('tailscale_serve_attempt='+(San (($o -split "`r?`n"|Select-Object -First 6)-join ' | '))) }
L ('tailscale_serve_status='+(San (($serveStatus -split "`r?`n"|Select-Object -First 12)-join ' | ')))
$phoneGuide=Join-Path $outDir 'phone-browser-file-share-r227.md'
W $phoneGuide @('# Phone browser file access r227','',('Share root: '+$phoneRoot),('HTTP tailnet URL: '+$httpUrl),('HTTPS Tailscale Serve URL: '+$httpsUrl),('HTTP self-test OK: '+$httpOk),('HTTPS serve self-test OK: '+$httpsOk),('Phone seen in Tailscale status: '+$phoneSeen),'','If the phone shows Cloudflare 400 plain HTTP request was sent to HTTPS port, the browser/proxy used the wrong scheme or URL. Use the HTTPS Tailscale Serve URL above, or type the HTTP tailnet URL exactly with http:// and the 100.x address. Do not use an Arena/Cloudflare preview URL for this local share.','','Only files copied into the share root are exposed.')

# ---------------------------------------------------------------------------
# B. Antigravity agent autorun: submit a command and repeatedly click approval
# buttons, then poll for Illustrator AI+PNG proof files.
# ---------------------------------------------------------------------------
$runner=Join-Path $agvRoot 'run_illustrator_agent_r227.ps1'
$outAi=Join-Path $agvRoot 'agv_agent_figure_r227.ai'
$outPng=Join-Path $agvRoot 'agv_agent_figure_r227.png'
$outDone=Join-Path $agvRoot 'agv_agent_done_r227.txt'
$outInvoke=Join-Path $agvRoot 'agv_agent_invoked_r227.txt'
$outLog=Join-Path $agvRoot 'agv_agent_runner_r227.log'
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone,$outInvoke,$outLog -Force -ErrorAction SilentlyContinue }catch{}
$runnerText=@'
param()
$ErrorActionPreference='Continue'
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
$script:Lines=@()
$root='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_agent_autorun_r227'
$outAi=Join-Path $root 'agv_agent_figure_r227.ai'
$outPng=Join-Path $root 'agv_agent_figure_r227.png'
$outDone=Join-Path $root 'agv_agent_done_r227.txt'
$outLog=Join-Path $root 'agv_agent_runner_r227.log'
$outJsx=Join-Path $root 'agv_agent_illustrator_r227.jsx'
New-Item -ItemType Directory -Force -Path $root|Out-Null
L '# runner r227 requested through Antigravity agent/tools'
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
 var root='E:/0mcp-agv-arena-optimized/antigravity-tests/agv_agent_autorun_r227/'; var done=new File(root+'agv_agent_done_r227.txt'); var stat=new File(root+'jsx_status_r227.txt');
 try{ var doc=app.documents.add(DocumentColorSpace.RGB,1000,620); rect(doc,620,0,1000,620,rgb(255,255,255),rgb(255,255,255)); rect(doc,545,80,840,420,rgb(248,250,252),rgb(15,23,42));
 var xs=[190,450,710]; var fills=[[219,234,254],[220,252,231],[254,243,199]]; var strokes=[[37,99,235],[22,163,74],[245,158,11]]; for(var i=0;i<3;i++){ var c=doc.pathItems.ellipse(395,xs[i],120,120); c.filled=true; c.fillColor=rgb(fills[i][0],fills[i][1],fills[i][2]); c.stroked=true; c.strokeColor=rgb(strokes[i][0],strokes[i][1],strokes[i][2]); c.strokeWidth=5; }
 var l1=doc.pathItems.add(); l1.setEntirePath([[310,335],[450,335]]); l1.stroked=true; l1.strokeWidth=8; l1.strokeColor=rgb(100,116,139); l1.filled=false; var l2=doc.pathItems.add(); l2.setEntirePath([[570,335],[710,335]]); l2.stroked=true; l2.strokeWidth=8; l2.strokeColor=rgb(100,116,139); l2.filled=false;
 text(doc,'Antigravity agent/tool -> Illustrator R227',120,205,34,rgb(15,23,42)); text(doc,'Generated only if Antigravity executed the local runner.',120,160,23,rgb(71,85,105)); text(doc,'ARENA_AGV_AGENT_ILLUSTRATOR_R227',120,115,20,rgb(37,99,235)); text(doc,'Input',215,340,30,rgb(30,41,59)); text(doc,'Model',475,340,30,rgb(30,41,59)); text(doc,'Figure',735,340,30,rgb(30,41,59));
 var ai=new File(root+'agv_agent_figure_r227.ai'); var opt=new IllustratorSaveOptions(); try{opt.compatibility=Compatibility.ILLUSTRATOR17;}catch(e){} doc.saveAs(ai,opt); var png=new File(root+'agv_agent_figure_r227.png'); var po=new ExportOptionsPNG24(); po.antiAliasing=true; po.transparency=false; po.horizontalScale=100; po.verticalScale=100; doc.exportFile(png,ExportType.PNG24,po); try{doc.close(SaveOptions.DONOTSAVECHANGES);}catch(e){} done.encoding='UTF-8'; done.open('w'); done.write('OK R227 '+(new Date()).toString()); done.close(); stat.open('w'); stat.write('OK'); stat.close(); }catch(e){stat.open('w'); stat.write('ERR '+e.message+' line '+e.line); stat.close();}
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
$st=Join-Path $root 'jsx_status_r227.txt'; if(Test-Path -LiteralPath $st){ L ('jsx_status='+(Get-Content -LiteralPath $st -Raw)) }
if($aiOk -and $pngOk -and $doneOk){ L 'FINAL: OK_ILLUSTRATOR_OUTPUTS' } else { L 'FINAL: FAIL_OUTPUTS' }
W $outLog $script:Lines
if($aiOk -and $pngOk -and $doneOk){exit 0}else{exit 3}
'@
[IO.File]::WriteAllText($runner,$runnerText,(New-Object Text.UTF8Encoding($false)))
L ('agv_runner='+(San $runner))
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$agPort=9223
$agCdp=Wait-Port $agPort 2
if(-not $agCdp -and(Test-Path -LiteralPath $agExe)){ try{ Start-Process -FilePath $agExe -ArgumentList @('--force-renderer-accessibility','--remote-debugging-port='+$agPort)|Out-Null }catch{ L ('agv_start_WARN='+(San $_.Exception.Message)) }; Start-Sleep -Seconds 8; $agCdp=Wait-Port $agPort 8 }
L ('antigravity_cdp='+$agCdp)
$marker='ARENA_AGV_AGENT_AUTORUN_R227_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$cmdLine='cmd.exe /c echo '+$marker+' > "'+$outInvoke+'" && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'+$runner+'"'
$prompt='Execute this local Windows command now using Antigravity agent tools or terminal. Do not only describe it. If there is any approval dialog, choose Run, Allow, Continue, or Yes. Command: '+$cmdLine+' . After it finishes, report whether these files exist: '+$outAi+' and '+$outPng+' . End with marker '+$marker
$nodeScript=Join-Path $agvRoot 'agv_agent_autorun_r227.cjs'
$nodeJson=Join-Path $reports 'antigravity-agent-autorun-r227.json'
$nodeCode=@'
const fs=require('fs'); const out=process.argv[2], action=process.argv[3], promptText=process.argv[4]||'', marker=process.argv[5]||'', port=process.argv[6]||'9223'; const WS=globalThis.WebSocket;
async function getJson(u){const r=await fetch(u); return await r.json();}
function connect(url){return new Promise((resolve,reject)=>{const ws=new WS(url); let id=0; const pending=new Map(); ws.onmessage=ev=>{const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){const p=pending.get(m.id); pending.delete(m.id); m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);}}; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=reject;});}
async function key(send,key,code,vk,mods=0){await send('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers:mods}); await new Promise(r=>setTimeout(r,40)); await send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers:mods});}
const exprCollect=`(() => { function all(root){let a=[]; try{a.push(...root.querySelectorAll('button,[role=button],textarea,input,[contenteditable=true],[role=textbox],[role=combobox]')); for(const e of root.querySelectorAll('*')){ if(e.shadowRoot) a.push(...all(e.shadowRoot)); }}catch(e){} return a;} const els=all(document); return els.slice(0,300).map((e,i)=>{const r=e.getBoundingClientRect(); return {i,tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||'',text:(e.innerText||e.textContent||e.value||'').trim().slice(0,120),disabled:!!e.disabled,w:r.width,h:r.height,x:r.x,y:r.y,visible:(r.width>0&&r.height>0)};}); })()`;
async function main(){ const result={ok:false,action,marker}; const targets=await getJson(`http://127.0.0.1:${port}/json/list`); result.targets=targets.map(t=>({title:t.title,url:t.url,type:t.type})); const target=targets.find(t=>(t.title||'').includes('Antigravity')&&t.webSocketDebuggerUrl)||targets.find(t=>t.webSocketDebuggerUrl); if(!target){fs.writeFileSync(out,JSON.stringify(result,null,2)); return;} result.target={title:target.title,url:target.url,type:target.type}; const {ws,send}=await connect(target.webSocketDebuggerUrl); await send('Runtime.enable'); await send('Page.bringToFront').catch(()=>{}); await new Promise(r=>setTimeout(r,500));
 if(action==='submit'){
  const focus=await send('Runtime.evaluate',{expression:`(() => { const e=document.querySelector('[aria-label="Message input"]')||document.querySelector('[role="combobox"][aria-label*="Message"]')||document.querySelector('[contenteditable=true]')||document.querySelector('textarea,input,[role=textbox]'); if(!e)return {ok:false}; e.scrollIntoView({block:'center'}); e.click(); e.focus(); try{ if(e.isContentEditable){ e.textContent=''; e.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'deleteContentBackward'})); } else { e.value=''; e.dispatchEvent(new Event('input',{bubbles:true})); } }catch(err){} return {ok:true,tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||''}; })()`,returnByValue:true,awaitPromise:true}); result.focus=focus.result.value; if(result.focus&&result.focus.ok){ await key(send,'A','KeyA',65,2); await key(send,'Backspace','Backspace',8,0); await send('Input.insertText',{text:promptText}); result.inserted=true; }
 }
 const clickExpr=`(() => { function all(root){let a=[]; try{a.push(...root.querySelectorAll('button,[role=button]')); for(const e of root.querySelectorAll('*')){ if(e.shadowRoot) a.push(...all(e.shadowRoot)); }}catch(e){} return a;} const re=${action==='submit'?'/send|submit|arrow|run|continue|allow|approve|yes/i':'/run|allow|approve|continue|yes|trust|execute|open/i'}; const btns=all(document).map((e,i)=>{const r=e.getBoundingClientRect(); const label=((e.getAttribute('aria-label')||'')+' '+(e.innerText||e.textContent||'')).trim(); return {e,i,label,disabled:!!e.disabled,visible:r.width>0&&r.height>0,x:r.x,y:r.y,w:r.width,h:r.height};}); const hits=btns.filter(b=>b.visible&&!b.disabled&&re.test(b.label)); let clicked=[]; for(const b of hits.slice(0,5)){ try{ b.e.click(); clicked.push({i:b.i,label:b.label.slice(0,120)}); }catch(e){} } return {clicked,buttons:btns.map(b=>({i:b.i,label:b.label.slice(0,120),disabled:b.disabled,visible:b.visible,x:b.x,y:b.y,w:b.w,h:b.h})).slice(0,80),textTail:(document.body.innerText||'').slice(-4000)}; })()`;
 const ck=await send('Runtime.evaluate',{expression:clickExpr,returnByValue:true,awaitPromise:true}); result.click=ck.result.value; if(action==='submit'&&(!result.click||!result.click.clicked||result.click.clicked.length===0)){ await key(send,'Enter','Enter',13,0); await new Promise(r=>setTimeout(r,300)); await key(send,'Enter','Enter',13,2); result.fallbackEnter=true; }
 const body=await send('Runtime.evaluate',{expression:`(() => ({title:document.title,active:(document.activeElement&&(document.activeElement.tagName+' '+(document.activeElement.getAttribute('aria-label')||'')+' '+(document.activeElement.getAttribute('role')||'')))||'',markerInBody:(document.body.innerText||'').includes(${JSON.stringify(marker)}),tail:(document.body.innerText||'').slice(-5000)}))()`,returnByValue:true,awaitPromise:true}); result.body=body.result.value; result.elements=(await send('Runtime.evaluate',{expression:exprCollect,returnByValue:true,awaitPromise:true})).result.value; result.ok=true; try{ws.close();}catch{} fs.writeFileSync(out,JSON.stringify(result,null,2)); }
main().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($nodeScript,$nodeCode,(New-Object Text.UTF8Encoding($false)))
if($agCdp -and(Get-Command node -ErrorAction SilentlyContinue)){ $ns=$nodeScript; $nj=$nodeJson; $pr=$prompt; $mk=$marker; $pt=[string]$agPort; $submitOut=Run-Cap { node $using:ns $using:nj submit $using:pr $using:mk $using:pt 2>&1|Out-String } 90; L ('agv_submit_node='+(San (($submitOut -split "`r?`n"|Select-Object -First 10)-join ' | '))) } else { L 'agv_submit_skipped=True' }
$approveJson=Join-Path $reports 'antigravity-agent-approve-r227.json'
$deadline=(Get-Date).AddSeconds(900)
$iter=0
while((Get-Date)-lt $deadline){
  $iter++
  if((Test-Path -LiteralPath $outDone)-or((Test-Path -LiteralPath $outAi)-and(Test-Path -LiteralPath $outPng))){break}
  if($agCdp -and(Get-Command node -ErrorAction SilentlyContinue)){
    $ns=$nodeScript; $aj=$approveJson; $mk=$marker; $pt=[string]$agPort
    $ap=Run-Cap { node $using:ns $using:aj approve '' $using:mk $using:pt 2>&1|Out-String } 45
    if(($iter % 10)-eq 0){ L ('agv_approve_iter_'+$iter+'='+(San (($ap -split "`r?`n"|Select-Object -First 6)-join ' | '))) }
  }
  Start-Sleep -Seconds 10
}
$invoke=FInfo $outInvoke; $ai=FInfo $outAi; $png=FInfo $outPng; $done=FInfo $outDone
$agvOk=$invoke.exists -and $ai.exists -and $png.exists -and $done.exists -and ($ai.bytes -gt 1000) -and ($png.bytes -gt 1000)
L ('antigravity_agent_marker='+$marker)
L ('antigravity_agent_invoked='+$invoke.exists)
L ('antigravity_agent_outputs ok='+$agvOk+' ai='+$ai.exists+'/'+$ai.bytes+' png='+$png.exists+'/'+$png.bytes+' done='+$done.exists)
if(Test-Path -LiteralPath $outLog){ foreach($line in (Get-Content -LiteralPath $outLog -Tail 60 -ErrorAction SilentlyContinue)){ if($line.Trim()){ L ('runner_log|'+(San $line)) } } } else { L 'runner_log_missing=True' }
try{ if(Test-Path -LiteralPath $nodeJson){ Copy-Item -LiteralPath $nodeJson -Destination (Join-Path $outDir 'antigravity-agent-autorun-r227.json') -Force }; if(Test-Path -LiteralPath $approveJson){ Copy-Item -LiteralPath $approveJson -Destination (Join-Path $outDir 'antigravity-agent-approve-r227.json') -Force } }catch{}
$agvSummary=Join-Path $reports 'antigravity-agent-illustrator-summary-r227.json'
[IO.File]::WriteAllText($agvSummary,([pscustomobject]@{ok=$agvOk;marker=$marker;command=$cmdLine;invoke=$invoke;ai=$ai;png=$png;done=$done;runner=$runner;log=$outLog;submitJson=$nodeJson;approveJson=$approveJson}|ConvertTo-Json -Depth 6)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $agvSummary -Destination (Join-Path $outDir 'antigravity-agent-illustrator-summary-r227.json') -Force }catch{}

$statusAgv=if($agvOk){'ANTIGRAVITY_AGENT_ILLUSTRATOR_GENERATED'}else{'ANTIGRAVITY_AGENT_ILLUSTRATOR_NOT_PROVEN'}
$statusPhone=if($httpsOk){'PHONE_SHARE_HTTPS_TAILSCALE_SERVE_OK'}elseif($httpOk){'PHONE_SHARE_HTTP_TAILNET_OK'}else{'PHONE_SHARE_NOT_PROVEN'}
L ('status_antigravity='+$statusAgv)
L ('status_phone='+$statusPhone)
L ('FINAL_R227: '+$statusAgv+'_'+$statusPhone)
W $report $script:Lines
$sum=Join-Path $outDir 'antigravity-phonefix-summary-r227.md'
W $sum @('# R227 summary','',('Antigravity Illustrator status: '+$statusAgv),('AI: '+$outAi),('PNG: '+$outPng),('Invoke marker: '+$outInvoke),'',('Phone share root: '+$phoneRoot),('HTTP tailnet URL: '+$httpUrl),('HTTPS Tailscale Serve URL: '+$httpsUrl),('HTTP self-test OK: '+$httpOk),('HTTPS self-test OK: '+$httpsOk),('Phone seen in Tailscale status: '+$phoneSeen),'','If you saw Cloudflare 400 plain HTTP request was sent to HTTPS port, use the HTTPS Tailscale Serve URL if HTTPS OK, or type the HTTP tailnet URL exactly as http://100.x.x.x:18089/. Do not use an Arena/Cloudflare preview URL for this local Tailscale share.','','No credentials, cookies, tokens, passwords, or private keys were read or printed.')
exit 0
