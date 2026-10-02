# t180_antigravity_installide_tailscale_serve_r228.ps1 - round 228.
# Retry: enable Tailscale Serve with --yes, click Antigravity Install IDE,
# submit the existing Illustrator runner command, and poll approvals/outputs.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Wait-Port([int]$port,[int]$sec){ $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(350)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function FInfo([string]$p){ if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return [pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')} }; return [pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''} }
function Curl-Text([string]$Url,[int]$Sec){ try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -k -L --max-time $Sec -sS $Url 2>&1|Out-String).Trim() }catch{ return $_.Exception.Message } }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$root=Join-Path $lab 'antigravity-tests\agv_installide_r228'
$phoneRoot=Join-Path $lab 'phone-share'
foreach($d in @($reports,$root,$phoneRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$report=Join-Path $outDir 'ANTIGRAVITY_INSTALLIDE_TAILSCALE_SERVE_R228.md'
L '# R228 Antigravity Install IDE retry + Tailscale Serve fix'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))

# Phone share.
$sharePort=18089
[IO.File]::WriteAllText((Join-Path $phoneRoot 'index.html'),'<title>Arena Phone Share R228</title><h1>Arena Phone Share R228</h1><p>Use the 100.x HTTP URL exactly, or Tailscale Serve HTTPS if configured.</p>',(New-Object Text.UTF8Encoding($false)))
$pidFile=Join-Path $phoneRoot 'phone_share_python.pid'
if(Test-Path -LiteralPath $pidFile){ try{ Stop-Process -Id ([int](Get-Content -LiteralPath $pidFile -Raw)) -Force -ErrorAction SilentlyContinue }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
if($py){ try{ $pp=Start-Process -FilePath $py -ArgumentList @('-m','http.server',[string]$sharePort,'--bind','0.0.0.0','--directory',$phoneRoot) -PassThru -WindowStyle Hidden; [IO.File]::WriteAllText($pidFile,[string]$pp.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('phone_http_pid='+$pp.Id) }catch{ L ('phone_http_start_ERR='+(San $_.Exception.Message)) } }
$fw=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 profile=any 2>&1|Out-String } 30
$tsExe=''; foreach($p in @('E:\Tailscale\tailscale.exe','C:\Program Files\Tailscale\tailscale.exe','C:\Program Files (x86)\Tailscale\tailscale.exe')){ if(Test-Path -LiteralPath $p){$tsExe=$p; break} }
$tsIp=''; $dns=''; $serveOuts=@(); $serveStatus=''
if($tsExe){
  $te=$tsExe
  $tsIp=(Run-Cap { & $using:te ip -4 2>&1|Select-Object -First 1|Out-String } 20).Trim()
  $sjRaw=Run-Cap { & $using:te status --json 2>&1|Out-String } 30
  try{ $sj=$sjRaw|ConvertFrom-Json; $dns=[string]$sj.Self.DNSName; if($dns.EndsWith('.')){$dns=$dns.Substring(0,$dns.Length-1)} }catch{}
  $serveOuts += 'yes1:'+(Run-Cap { & $using:te serve --yes --bg http://127.0.0.1:18089 2>&1|Out-String } 35)
  $serveStatus=Run-Cap { & $using:te serve status 2>&1|Out-String } 20
  if($serveStatus -notmatch '18089|127\.0\.0\.1'){
    $serveOuts += 'yes2:'+(Run-Cap { & $using:te serve --yes --bg --set-path / http://127.0.0.1:18089 2>&1|Out-String } 35)
    $serveStatus=Run-Cap { & $using:te serve status 2>&1|Out-String } 20
  }
  if($serveStatus -notmatch '18089|127\.0\.0\.1'){
    $serveOuts += 'yes3:'+(Run-Cap { & $using:te serve --yes --bg 18089 2>&1|Out-String } 35)
    $serveStatus=Run-Cap { & $using:te serve status 2>&1|Out-String } 20
  }
}
$httpUrl=if($tsIp){'http://'+$tsIp+':'+$sharePort+'/'}else{''}
$httpsUrl=if($dns){'https://'+$dns+'/'}else{''}
$httpOk=$false; $httpsOk=$false
if($httpUrl){ $httpOk=((Curl-Text $httpUrl 10) -match 'Arena Phone Share R228') }
if($httpsUrl){ $httpsOk=((Curl-Text $httpsUrl 15) -match 'Arena Phone Share R228') }
L ('phone_http_url='+$httpUrl)
L ('phone_https_url='+$httpsUrl)
L ('phone_http_ok='+$httpOk+' phone_https_ok='+$httpsOk)
foreach($o in $serveOuts){ L ('serve_attempt='+(San (($o -split "`r?`n"|Select-Object -First 6)-join ' | '))) }
L ('serve_status='+(San (($serveStatus -split "`r?`n"|Select-Object -First 14)-join ' | ')))
W (Join-Path $outDir 'phone-browser-file-share-r228.md') @('# Phone browser file access r228','',('Share root: '+$phoneRoot),('HTTP URL: '+$httpUrl),('HTTPS Tailscale Serve URL: '+$httpsUrl),('HTTP self-test OK: '+$httpOk),('HTTPS self-test OK: '+$httpsOk),'','Cloudflare 400 plain HTTP request sent to HTTPS port means the phone used the wrong URL/scheme/proxy. For now use the exact HTTP URL above unless HTTPS self-test says True.')

# Antigravity retry.
$runner='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_agent_autorun_r227\run_illustrator_agent_r227.ps1'
$outAi='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_agent_autorun_r227\agv_agent_figure_r227.ai'
$outPng='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_agent_autorun_r227\agv_agent_figure_r227.png'
$outDone='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_agent_autorun_r227\agv_agent_done_r227.txt'
$outInvoke=Join-Path $root 'agv_installide_invoked_r228.txt'
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone,$outInvoke -Force -ErrorAction SilentlyContinue }catch{}
L ('runner_exists='+(Test-Path -LiteralPath $runner)+' runner='+(San $runner))
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$port=9223
$cdp=Wait-Port $port 2
if(-not $cdp -and(Test-Path -LiteralPath $agExe)){ try{ Start-Process -FilePath $agExe -ArgumentList @('--force-renderer-accessibility','--remote-debugging-port='+$port)|Out-Null }catch{}; Start-Sleep -Seconds 8; $cdp=Wait-Port $port 8 }
L ('antigravity_cdp='+$cdp)
$marker='ARENA_AGV_INSTALLIDE_R228_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$cmdLine='cmd.exe /c echo '+$marker+' > "'+$outInvoke+'" && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'+$runner+'"'
$prompt='Antigravity must execute this local Windows command with tools or terminal now. Do not just say Working. If IDE/tools are missing, install or enable the local IDE/tool integration first. Command: '+$cmdLine+' . Keep going until '+$outAi+' and '+$outPng+' exist. End with marker '+$marker
$nodeScript=Join-Path $root 'agv_installide_r228.cjs'
$nodeCode=@'
const fs=require('fs'); const out=process.argv[2], mode=process.argv[3], text=process.argv[4]||'', marker=process.argv[5]||'', port=process.argv[6]||'9223'; const WS=globalThis.WebSocket;
async function getJson(u){const r=await fetch(u); return await r.json();}
function connect(url){return new Promise((resolve,reject)=>{const ws=new WS(url); let id=0; const pending=new Map(); ws.onmessage=ev=>{const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){const p=pending.get(m.id); pending.delete(m.id); m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);}}; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=reject;});}
async function key(send,key,code,vk,mods=0){await send('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers:mods}); await new Promise(r=>setTimeout(r,40)); await send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers:mods});}
async function main(){const result={ok:false,mode,marker}; const targets=await getJson(`http://127.0.0.1:${port}/json/list`); const target=targets.find(t=>(t.title||'').includes('Antigravity')&&t.webSocketDebuggerUrl)||targets.find(t=>t.webSocketDebuggerUrl); result.targets=targets.map(t=>({title:t.title,url:t.url,type:t.type})); if(!target){fs.writeFileSync(out,JSON.stringify(result,null,2)); return;} const {ws,send}=await connect(target.webSocketDebuggerUrl); await send('Runtime.enable'); await send('Page.bringToFront').catch(()=>{}); await new Promise(r=>setTimeout(r,500));
 const clickRe = mode==='install' ? '/install ide|install|open|allow|continue|yes|trust/i' : (mode==='submit' ? '/send message|send|submit|run|continue|allow|approve|yes/i' : '/run|allow|approve|continue|yes|trust|execute|open|install/i');
 if(mode==='submit'){ const focus=await send('Runtime.evaluate',{expression:`(() => { const e=document.querySelector('[aria-label="Message input"]')||document.querySelector('[role="combobox"][aria-label*="Message"]')||document.querySelector('[contenteditable=true]')||document.querySelector('textarea,input,[role=textbox]'); if(!e)return {ok:false}; e.scrollIntoView({block:'center'}); e.click(); e.focus(); if(e.isContentEditable){e.textContent=''; e.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'deleteContentBackward'}));} else {e.value=''; e.dispatchEvent(new Event('input',{bubbles:true}));} return {ok:true,tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||''}; })()`,returnByValue:true,awaitPromise:true}); result.focus=focus.result.value; if(result.focus&&result.focus.ok){ await key(send,'A','KeyA',65,2); await key(send,'Backspace','Backspace',8,0); await send('Input.insertText',{text}); result.inserted=true; }}
 const expr=`(() => { function all(root){let a=[]; try{a.push(...root.querySelectorAll('button,[role=button]')); for(const e of root.querySelectorAll('*')){ if(e.shadowRoot)a.push(...all(e.shadowRoot)); }}catch(e){} return a;} const re=${clickRe}; const btns=all(document).map((e,i)=>{const r=e.getBoundingClientRect(); const label=((e.getAttribute('aria-label')||'')+' '+(e.innerText||e.textContent||'')).trim(); return {e,i,label,disabled:!!e.disabled,visible:r.width>0&&r.height>0,x:r.x,y:r.y,w:r.width,h:r.height};}); const hits=btns.filter(b=>b.visible&&!b.disabled&&re.test(b.label)); let clicked=[]; for(const b of hits.slice(0,4)){try{b.e.click(); clicked.push({i:b.i,label:b.label.slice(0,160)});}catch(e){}} return {clicked,buttons:btns.map(b=>({i:b.i,label:b.label.slice(0,160),disabled:b.disabled,visible:b.visible,x:b.x,y:b.y,w:b.w,h:b.h})).slice(0,100),tail:(document.body.innerText||'').slice(-6000)}; })()`;
 const ck=await send('Runtime.evaluate',{expression:expr,returnByValue:true,awaitPromise:true}); result.click=ck.result.value; if(mode==='submit'&&(!result.click.clicked||result.click.clicked.length===0)){ await key(send,'Enter','Enter',13,0); result.fallbackEnter=true; }
 const body=await send('Runtime.evaluate',{expression:`(() => ({title:document.title,active:(document.activeElement&&(document.activeElement.tagName+' '+(document.activeElement.getAttribute('aria-label')||'')+' '+(document.activeElement.getAttribute('role')||'')))||'',marker:(document.body.innerText||'').includes(${JSON.stringify(marker)}),tail:(document.body.innerText||'').slice(-6000)}))()`,returnByValue:true,awaitPromise:true}); result.body=body.result.value; result.ok=true; try{ws.close();}catch{} fs.writeFileSync(out,JSON.stringify(result,null,2));}
main().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($nodeScript,$nodeCode,(New-Object Text.UTF8Encoding($false)))
$installJson=Join-Path $reports 'antigravity-installide-click-r228.json'
$submitJson=Join-Path $reports 'antigravity-installide-submit-r228.json'
$approveJson=Join-Path $reports 'antigravity-installide-approve-r228.json'
if($cdp -and(Get-Command node -ErrorAction SilentlyContinue)){
  $ns=$nodeScript; $ij=$installJson; $mk=$marker; $pt=[string]$port
  $ins=Run-Cap { node $using:ns $using:ij install '' $using:mk $using:pt 2>&1|Out-String } 90
  L ('install_click_out='+(San (($ins -split "`r?`n"|Select-Object -First 8)-join ' | ')))
  Start-Sleep -Seconds 45
  $ns=$nodeScript; $sj=$submitJson; $pr=$prompt; $mk=$marker; $pt=[string]$port
  $sub=Run-Cap { node $using:ns $using:sj submit $using:pr $using:mk $using:pt 2>&1|Out-String } 90
  L ('submit_out='+(San (($sub -split "`r?`n"|Select-Object -First 8)-join ' | ')))
}
$deadline=(Get-Date).AddSeconds(1200)
$i=0
while((Get-Date)-lt $deadline){
  $i++
  if((Test-Path -LiteralPath $outDone)-or((Test-Path -LiteralPath $outAi)-and(Test-Path -LiteralPath $outPng))){break}
  if($cdp -and(Get-Command node -ErrorAction SilentlyContinue)){
    $ns=$nodeScript; $aj=$approveJson; $mk=$marker; $pt=[string]$port
    $ap=Run-Cap { node $using:ns $using:aj approve '' $using:mk $using:pt 2>&1|Out-String } 45
    if(($i % 10)-eq 0){ L ('approve_iter_'+$i+'='+(San (($ap -split "`r?`n"|Select-Object -First 8)-join ' | '))) }
  }
  Start-Sleep -Seconds 10
}
$invoke=FInfo $outInvoke; $ai=FInfo $outAi; $png=FInfo $outPng; $done=FInfo $outDone
$agvOk=$invoke.exists -and $ai.exists -and $png.exists -and $done.exists -and ($ai.bytes -gt 1000) -and ($png.bytes -gt 1000)
L ('antigravity_marker='+$marker)
L ('antigravity_invoked='+$invoke.exists)
L ('antigravity_outputs ok='+$agvOk+' ai='+$ai.exists+'/'+$ai.bytes+' png='+$png.exists+'/'+$png.bytes+' done='+$done.exists)
try{ foreach($f in @($installJson,$submitJson,$approveJson)){ if(Test-Path -LiteralPath $f){ Copy-Item -LiteralPath $f -Destination (Join-Path $outDir (Split-Path -Leaf $f)) -Force } } }catch{}
$sumJson=Join-Path $reports 'antigravity-installide-illustrator-summary-r228.json'
[IO.File]::WriteAllText($sumJson,([pscustomobject]@{ok=$agvOk;marker=$marker;invoke=$invoke;ai=$ai;png=$png;done=$done;runner=$runner;installJson=$installJson;submitJson=$submitJson;approveJson=$approveJson}|ConvertTo-Json -Depth 6)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $sumJson -Destination (Join-Path $outDir 'antigravity-installide-illustrator-summary-r228.json') -Force }catch{}
$statusAgv=if($agvOk){'ANTIGRAVITY_INSTALLIDE_ILLUSTRATOR_GENERATED'}else{'ANTIGRAVITY_INSTALLIDE_ILLUSTRATOR_NOT_PROVEN'}
$statusPhone=if($httpsOk){'PHONE_SHARE_HTTPS_OK'}elseif($httpOk){'PHONE_SHARE_HTTP_OK'}else{'PHONE_SHARE_NOT_PROVEN'}
L ('status_antigravity='+$statusAgv)
L ('status_phone='+$statusPhone)
L ('FINAL_R228: '+$statusAgv+'_'+$statusPhone)
W $report $script:Lines
W (Join-Path $outDir 'antigravity-installide-phone-summary-r228.md') @('# R228 summary','',('Antigravity Illustrator status: '+$statusAgv),('AI: '+$outAi),('PNG: '+$outPng),('Invoke marker: '+$outInvoke),'',('Phone HTTP URL: '+$httpUrl),('Phone HTTPS URL: '+$httpsUrl),('HTTP OK: '+$httpOk),('HTTPS OK: '+$httpsOk),'','Use exact HTTP tailnet URL if HTTPS remains false. Cloudflare 400 means wrong scheme/proxy, not this local tailnet HTTP endpoint.')
exit 0
