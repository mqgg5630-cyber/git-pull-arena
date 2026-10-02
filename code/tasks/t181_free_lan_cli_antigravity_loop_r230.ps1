# t181_free_lan_cli_antigravity_loop_r230.ps1 - round 230.
# Free LAN phone file-share guide plus Antigravity CLI/CDP polling attempt.
# ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function Curl-Text([string]$Url,[int]$Sec){ try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -k -L --max-time $Sec -sS $Url 2>&1|Out-String).Trim() }catch{ return $_.Exception.Message } }
function Wait-Port([int]$port,[int]$sec){ $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(300)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 250}; return $false }
function FInfo([string]$p){ if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return [pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')} }; return [pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''} }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$phoneRoot=Join-Path $lab 'phone-share'
$agvRoot=Join-Path $lab 'antigravity-tests\agv_cli_loop_r230'
foreach($d in @($reports,$phoneRoot,$agvRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$report=Join-Path $outDir 'FREE_LAN_ANTIGRAVITY_CLI_LOOP_R230.md'
L '# R230 free LAN file share + Antigravity CLI/CDP loop'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))

# 1. Free phone alternatives: same-WiFi LAN HTTP share, no VPN needed.
$port=18089
[IO.File]::WriteAllText((Join-Path $phoneRoot 'index.html'),'<title>Arena LAN Phone Share R230</title><h1>Arena LAN Phone Share R230</h1><p>Same WiFi: open one of the http://LAN-IP:18089/ URLs. This folder only.</p>',(New-Object Text.UTF8Encoding($false)))
$pidFile=Join-Path $phoneRoot 'phone_share_python.pid'
if(Test-Path -LiteralPath $pidFile){ try{ Stop-Process -Id ([int](Get-Content -LiteralPath $pidFile -Raw)) -Force -ErrorAction SilentlyContinue }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
if($py){ try{ $p=Start-Process -FilePath $py -ArgumentList @('-m','http.server',[string]$port,'--bind','0.0.0.0','--directory',$phoneRoot) -PassThru -WindowStyle Hidden; [IO.File]::WriteAllText($pidFile,[string]$p.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('lan_http_pid='+$p.Id) }catch{ L ('lan_http_start_ERR='+(San $_.Exception.Message)) } }
$fw=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 profile=any 2>&1|Out-String } 30
$ips=@()
try{
  $ips=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.|100\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' -and $_.IPAddress -ne '0.0.0.0' } | Select-Object -ExpandProperty IPAddress -Unique)
}catch{
  $raw=ipconfig | Out-String
  $ips=@([regex]::Matches($raw,'IPv4[^:]*:\s*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notmatch '^(127\.|169\.254\.|100\.)' } | Select-Object -Unique)
}
$lanUrls=@(); foreach($ip in $ips){ $lanUrls += ('http://'+$ip+':'+$port+'/') }
$lanResults=@(); foreach($u in $lanUrls){ $lanResults += [pscustomobject]@{url=$u; ok=((Curl-Text $u 5) -match 'Arena LAN Phone Share R230')} }
foreach($r in $lanResults){ L ('lan_url='+$r.url+' ok='+$r.ok) }
W (Join-Path $outDir 'free-phone-file-share-lan-r230.md') (@('# Free same-WiFi phone file access r230','','Share root: '+$phoneRoot,'','Open from phone while phone and PC are on the same Wi-Fi:') + ($lanUrls | ForEach-Object { '- '+$_ }) + @('','This is free and does not require Tailscale. If the phone shows Cloudflare, you are still opening a proxy/HTTPS URL, not this LAN URL. Type http:// exactly.'))

# 2. Prepare an Illustrator runner for Antigravity to execute.
$runner=Join-Path $agvRoot 'run_illustrator_cli_loop_r230.ps1'
$outAi=Join-Path $agvRoot 'agv_cli_loop_figure_r230.ai'
$outPng=Join-Path $agvRoot 'agv_cli_loop_figure_r230.png'
$outDone=Join-Path $agvRoot 'agv_cli_loop_done_r230.txt'
$outInvoke=Join-Path $agvRoot 'agv_cli_loop_invoked_r230.txt'
$outLog=Join-Path $agvRoot 'agv_cli_loop_runner_r230.log'
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone,$outInvoke,$outLog -Force -ErrorAction SilentlyContinue }catch{}
$runnerText=@'
param()
$ErrorActionPreference='Continue'
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
$script:Lines=@()
$root='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_cli_loop_r230'
$outAi=Join-Path $root 'agv_cli_loop_figure_r230.ai'
$outPng=Join-Path $root 'agv_cli_loop_figure_r230.png'
$outDone=Join-Path $root 'agv_cli_loop_done_r230.txt'
$outLog=Join-Path $root 'agv_cli_loop_runner_r230.log'
$outJsx=Join-Path $root 'agv_cli_loop_illustrator_r230.jsx'
New-Item -ItemType Directory -Force -Path $root|Out-Null
L '# runner r230 requested through Antigravity CLI/CDP loop'
L ('time='+(Get-Date).ToString('s'))
$aiExe=$null
foreach($base in @('E:\','D:\','C:\Program Files','C:\Program Files (x86)')){ if(Test-Path -LiteralPath $base){ try{ $f=Get-ChildItem -LiteralPath $base -Recurse -Filter Illustrator.exe -File -ErrorAction SilentlyContinue|Select-Object -First 1; if($f){$aiExe=$f.FullName; break} }catch{} } }
L ('illustrator_exe='+$aiExe)
if(-not $aiExe){ L 'FINAL: NO_ILLUSTRATOR'; W $outLog $script:Lines; exit 2 }
$jsx=@"
(function(){
 function rgb(r,g,b){var c=new RGBColor(); c.red=r; c.green=g; c.blue=b; return c;}
 function text(doc,s,x,y,z,c){var f=doc.textFrames.add(); f.contents=s; f.position=[x,y]; f.textRange.characterAttributes.size=z; f.textRange.characterAttributes.fillColor=c; return f;}
 function rect(doc,top,left,w,h,fill,stroke){var p=doc.pathItems.rectangle(top,left,w,h); p.filled=true; p.fillColor=fill; p.stroked=true; p.strokeColor=stroke; p.strokeWidth=3; return p;}
 var root='E:/0mcp-agv-arena-optimized/antigravity-tests/agv_cli_loop_r230/'; var done=new File(root+'agv_cli_loop_done_r230.txt'); var stat=new File(root+'jsx_status_r230.txt');
 try{ var doc=app.documents.add(DocumentColorSpace.RGB,1000,620); rect(doc,620,0,1000,620,rgb(255,255,255),rgb(255,255,255)); rect(doc,545,80,840,420,rgb(248,250,252),rgb(15,23,42));
 var xs=[190,450,710]; var fills=[[219,234,254],[220,252,231],[254,243,199]]; var strokes=[[37,99,235],[22,163,74],[245,158,11]]; for(var i=0;i<3;i++){ var c=doc.pathItems.ellipse(395,xs[i],120,120); c.filled=true; c.fillColor=rgb(fills[i][0],fills[i][1],fills[i][2]); c.stroked=true; c.strokeColor=rgb(strokes[i][0],strokes[i][1],strokes[i][2]); c.strokeWidth=5; }
 var l1=doc.pathItems.add(); l1.setEntirePath([[310,335],[450,335]]); l1.stroked=true; l1.strokeWidth=8; l1.strokeColor=rgb(100,116,139); l1.filled=false; var l2=doc.pathItems.add(); l2.setEntirePath([[570,335],[710,335]]); l2.stroked=true; l2.strokeWidth=8; l2.strokeColor=rgb(100,116,139); l2.filled=false;
 text(doc,'Antigravity CLI/CDP -> Illustrator R230',120,205,34,rgb(15,23,42)); text(doc,'Generated only if Antigravity executed the runner.',120,160,23,rgb(71,85,105)); text(doc,'ARENA_AGV_CLI_LOOP_ILLUSTRATOR_R230',120,115,20,rgb(37,99,235)); text(doc,'Input',215,340,30,rgb(30,41,59)); text(doc,'Model',475,340,30,rgb(30,41,59)); text(doc,'Figure',735,340,30,rgb(30,41,59));
 var ai=new File(root+'agv_cli_loop_figure_r230.ai'); var opt=new IllustratorSaveOptions(); try{opt.compatibility=Compatibility.ILLUSTRATOR17;}catch(e){} doc.saveAs(ai,opt); var png=new File(root+'agv_cli_loop_figure_r230.png'); var po=new ExportOptionsPNG24(); po.antiAliasing=true; po.transparency=false; po.horizontalScale=100; po.verticalScale=100; doc.exportFile(png,ExportType.PNG24,po); try{doc.close(SaveOptions.DONOTSAVECHANGES);}catch(e){} done.encoding='UTF-8'; done.open('w'); done.write('OK R230 '+(new Date()).toString()); done.close(); stat.open('w'); stat.write('OK'); stat.close(); }catch(e){stat.open('w'); stat.write('ERR '+e.message+' line '+e.line); stat.close();}
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
$st=Join-Path $root 'jsx_status_r230.txt'; if(Test-Path -LiteralPath $st){ L ('jsx_status='+(Get-Content -LiteralPath $st -Raw)) }
if($aiOk -and $pngOk -and $doneOk){ L 'FINAL: OK_ILLUSTRATOR_OUTPUTS' } else { L 'FINAL: FAIL_OUTPUTS' }
W $outLog $script:Lines
if($aiOk -and $pngOk -and $doneOk){exit 0}else{exit 3}
'@
[IO.File]::WriteAllText($runner,$runnerText,(New-Object Text.UTF8Encoding($false)))
$marker='ARENA_AGV_CLI_LOOP_R230_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$cmdLine='cmd.exe /c echo '+$marker+' > "'+$outInvoke+'" && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'+$runner+'"'
$prompt='Execute this local Windows command with Antigravity tools or terminal. Do not just describe it. Command: '+$cmdLine+' . Keep working until these outputs exist: '+$outAi+' and '+$outPng+' . End with marker '+$marker
L ('agv_runner='+(San $runner))

# 3. Scan Antigravity CLI candidates and test help.
$cands=New-Object System.Collections.Generic.List[string]
$base=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity'
foreach($pat in @('bin\*.cmd','bin\*.exe','*.cmd','*.exe','resources\app\bin\*.cmd','resources\app\bin\*.exe')){ try{ Get-ChildItem -LiteralPath $base -Filter (Split-Path -Leaf $pat) -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'antigravity|ag|cli|code' } | ForEach-Object { $cands.Add($_.FullName) } }catch{} }
foreach($name in @('antigravity','antigravity.cmd','ag','ag.cmd')){ $w=Run-Cap { where.exe $using:name 2>&1|Out-String } 10; foreach($line in ($w -split "`r?`n")){ if($line.Trim() -and (Test-Path -LiteralPath $line.Trim())){ $cands.Add($line.Trim()) } } }
$cands=@($cands | Sort-Object -Unique)
$cliRows=@()
foreach($c in $cands){
  $cc=$c
  $help=Run-Cap { & $using:cc --help 2>&1|Out-String } 25
  $cliRows += [pscustomobject]@{path=$c;help=(($help -split "`r?`n"|Select-Object -First 20)-join "`n")}
  L ('cli_candidate='+(San $c)+' help_head='+(San (($help -split "`r?`n"|Select-Object -First 3)-join ' | ')))
}
$cliJson=Join-Path $reports 'antigravity-cli-scan-r230.json'
[IO.File]::WriteAllText($cliJson,($cliRows|ConvertTo-Json -Depth 5)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $cliJson -Destination (Join-Path $outDir 'antigravity-cli-scan-r230.json') -Force }catch{}

# Try a conservative set of CLI prompt forms only for .cmd/.exe candidates whose help suggests automation.
$cliAttempts=@()
foreach($row in $cliRows){
  $h=[string]$row.help; if($h -notmatch 'chat|agent|prompt|ask|run|command|help'){ continue }
  $c=[string]$row.path
  $forms=@(
    @('--prompt',$prompt),
    @('chat',$prompt),
    @('agent',$prompt),
    @('run',$prompt)
  )
  foreach($f in $forms){
    if((Test-Path -LiteralPath $outDone) -or ((Test-Path -LiteralPath $outAi) -and (Test-Path -LiteralPath $outPng))){ break }
    $arg1=$f[0]; $arg2=$f[1]; $cc=$c
    $o=Run-Cap { & $using:cc $using:arg1 $using:arg2 2>&1|Out-String } 60
    $cliAttempts += [pscustomobject]@{path=$c;form=$arg1;out=(($o -split "`r?`n"|Select-Object -First 20)-join "`n")}
    L ('cli_attempt path='+(San $c)+' form='+$arg1+' out='+(San (($o -split "`r?`n"|Select-Object -First 4)-join ' | ')))
  }
}
$cliAttemptJson=Join-Path $reports 'antigravity-cli-attempts-r230.json'
[IO.File]::WriteAllText($cliAttemptJson,($cliAttempts|ConvertTo-Json -Depth 5)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $cliAttemptJson -Destination (Join-Path $outDir 'antigravity-cli-attempts-r230.json') -Force }catch{}

# 4. CDP fallback: scan ports, submit prompt, and poll approval buttons.
$nodeScript=Join-Path $agvRoot 'agv_cdp_loop_r230.cjs'
$nodeCode=@'
const fs=require('fs'); const out=process.argv[2], mode=process.argv[3], text=process.argv[4]||'', marker=process.argv[5]||'', port=process.argv[6]||'9223'; const WS=globalThis.WebSocket;
async function getJson(u){const r=await fetch(u); return await r.json();}
function connect(url){return new Promise((resolve,reject)=>{const ws=new WS(url); let id=0; const pending=new Map(); ws.onmessage=ev=>{const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){const p=pending.get(m.id); pending.delete(m.id); m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);}}; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=reject;});}
async function key(send,key,code,vk,mods=0){await send('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers:mods}); await new Promise(r=>setTimeout(r,30)); await send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers:mods});}
async function main(){const res={ok:false,mode,marker,port}; const targets=await getJson(`http://127.0.0.1:${port}/json/list`); const target=targets.find(t=>(t.title||'').includes('Antigravity')&&t.webSocketDebuggerUrl)||targets.find(t=>t.webSocketDebuggerUrl); res.targets=targets.map(t=>({title:t.title,url:t.url,type:t.type})); if(!target){fs.writeFileSync(out,JSON.stringify(res,null,2)); return;} const {ws,send}=await connect(target.webSocketDebuggerUrl); await send('Runtime.enable'); await send('Page.bringToFront').catch(()=>{}); await new Promise(r=>setTimeout(r,500)); if(mode==='submit'){const f=await send('Runtime.evaluate',{expression:`(() => { const e=document.querySelector('[aria-label="Message input"]')||document.querySelector('[role="combobox"][aria-label*="Message"]')||document.querySelector('[contenteditable=true]')||document.querySelector('textarea,input,[role=textbox]'); if(!e)return {ok:false}; e.scrollIntoView({block:'center'}); e.click(); e.focus(); if(e.isContentEditable){e.textContent=''; e.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'deleteContentBackward'}));} else {e.value=''; e.dispatchEvent(new Event('input',{bubbles:true}));} return {ok:true,tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||''}; })()`,returnByValue:true,awaitPromise:true}); res.focus=f.result.value; if(res.focus&&res.focus.ok){await key(send,'A','KeyA',65,2); await key(send,'Backspace','Backspace',8,0); await send('Input.insertText',{text}); res.inserted=true;}}
 const re = mode==='submit' ? /send message|send|submit|run|continue|allow|approve|yes/i : /run|allow|approve|continue|yes|trust|execute|open|install/i;
 const expr=`(() => { function all(root){let a=[]; try{a.push(...root.querySelectorAll('button,[role=button]')); for(const e of root.querySelectorAll('*')){ if(e.shadowRoot)a.push(...all(e.shadowRoot)); }}catch(e){} return a;} const re=${re.toString()}; const btns=all(document).map((e,i)=>{const r=e.getBoundingClientRect(); const label=((e.getAttribute('aria-label')||'')+' '+(e.innerText||e.textContent||'')).trim(); return {e,i,label,disabled:!!e.disabled,visible:r.width>0&&r.height>0};}); const hits=btns.filter(b=>b.visible&&!b.disabled&&re.test(b.label)); let clicked=[]; for(const b of hits.slice(0,5)){try{b.e.click(); clicked.push({i:b.i,label:b.label.slice(0,160)});}catch(e){}} return {clicked,buttons:btns.map(b=>({i:b.i,label:b.label.slice(0,120),disabled:b.disabled,visible:b.visible})).slice(0,80),tail:(document.body.innerText||'').slice(-5000)}; })()`;
 const ck=await send('Runtime.evaluate',{expression:expr,returnByValue:true,awaitPromise:true}); res.click=ck.result.value; if(mode==='submit'&&(!res.click.clicked||res.click.clicked.length===0)){await key(send,'Enter','Enter',13,0); await new Promise(r=>setTimeout(r,300)); await key(send,'Enter','Enter',13,2); res.enter=true;} const body=await send('Runtime.evaluate',{expression:`(() => ({title:document.title,marker:(document.body.innerText||'').includes(${JSON.stringify(marker)}),tail:(document.body.innerText||'').slice(-5000)}))()`,returnByValue:true,awaitPromise:true}); res.body=body.result.value; res.ok=true; try{ws.close();}catch{} fs.writeFileSync(out,JSON.stringify(res,null,2));}
main().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($nodeScript,$nodeCode,(New-Object Text.UTF8Encoding($false)))
$cdpPorts=@()
foreach($pnum in @(9223,9222,9224,9225,9226,9227,9228,9229,9230,9231,9232,9233,9234,9235)){ $txt=Curl-Text ('http://127.0.0.1:'+$pnum+'/json/list') 2; if($txt -match 'webSocketDebuggerUrl'){ $cdpPorts += $pnum } }
if($cdpPorts.Count -eq 0){
  $agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
  if(Test-Path -LiteralPath $agExe){ try{ Start-Process -FilePath $agExe -ArgumentList @('--force-renderer-accessibility','--remote-debugging-port=9223')|Out-Null; Start-Sleep -Seconds 12 }catch{} }
  $txt=Curl-Text 'http://127.0.0.1:9223/json/list' 5; if($txt -match 'webSocketDebuggerUrl'){ $cdpPorts += 9223 }
}
L ('cdp_ports='+(($cdpPorts|ForEach-Object{[string]$_}) -join ','))
$cdpJson=Join-Path $reports 'antigravity-cdp-loop-r230.json'
if($cdpPorts.Count -gt 0 -and(Get-Command node -ErrorAction SilentlyContinue)){
  $cp=[string]$cdpPorts[0]; $ns=$nodeScript; $cj=$cdpJson; $pt=$prompt; $mk=$marker
  $sub=Run-Cap { node $using:ns $using:cj submit $using:pt $using:mk $using:cp 2>&1|Out-String } 90
  L ('cdp_submit_out='+(San (($sub -split "`r?`n"|Select-Object -First 6)-join ' | ')))
}
$deadline=(Get-Date).AddSeconds(900)
$iter=0
while((Get-Date)-lt $deadline){
  $iter++
  if((Test-Path -LiteralPath $outDone) -or ((Test-Path -LiteralPath $outAi) -and (Test-Path -LiteralPath $outPng))){ break }
  if($cdpPorts.Count -gt 0 -and(Get-Command node -ErrorAction SilentlyContinue)){
    $cp=[string]$cdpPorts[0]; $ns=$nodeScript; $aj=Join-Path $reports 'antigravity-cdp-loop-approve-r230.json'; $mk=$marker
    $ap=Run-Cap { node $using:ns $using:aj approve '' $using:mk $using:cp 2>&1|Out-String } 45
    if(($iter % 10)-eq 0){ L ('approve_iter_'+$iter+'='+(San (($ap -split "`r?`n"|Select-Object -First 5)-join ' | '))) }
  }
  Start-Sleep -Seconds 10
}
$invoke=FInfo $outInvoke; $ai=FInfo $outAi; $png=FInfo $outPng; $done=FInfo $outDone
$ok=$invoke.exists -and $ai.exists -and $png.exists -and $done.exists -and ($ai.bytes -gt 1000) -and ($png.bytes -gt 1000)
L ('antigravity_marker='+$marker)
L ('antigravity_invoked='+$invoke.exists)
L ('antigravity_outputs ok='+$ok+' ai='+$ai.exists+'/'+$ai.bytes+' png='+$png.exists+'/'+$png.bytes+' done='+$done.exists)
if(Test-Path -LiteralPath $outLog){ foreach($line in (Get-Content -LiteralPath $outLog -Tail 40 -ErrorAction SilentlyContinue)){ if($line.Trim()){ L ('runner_log|'+(San $line)) } } } else { L 'runner_log_missing=True' }
$summaryJson=Join-Path $reports 'antigravity-cli-cdp-loop-summary-r230.json'
[IO.File]::WriteAllText($summaryJson,([pscustomobject]@{ok=$ok;marker=$marker;invoke=$invoke;ai=$ai;png=$png;done=$done;runner=$runner;log=$outLog;lanUrls=$lanResults;cliCandidates=$cliRows;cliAttempts=$cliAttempts;cdpPorts=$cdpPorts}|ConvertTo-Json -Depth 8)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $summaryJson -Destination (Join-Path $outDir 'antigravity-cli-cdp-loop-summary-r230.json') -Force; if(Test-Path -LiteralPath $cdpJson){ Copy-Item -LiteralPath $cdpJson -Destination (Join-Path $outDir 'antigravity-cdp-loop-r230.json') -Force } }catch{}
$statusAgv=if($ok){'ANTIGRAVITY_CLI_OR_CDP_ILLUSTRATOR_GENERATED'}else{'ANTIGRAVITY_CLI_OR_CDP_ILLUSTRATOR_NOT_PROVEN'}
$statusPhone=if(($lanResults|Where-Object{$_.ok}).Count -gt 0){'FREE_LAN_PHONE_SHARE_OK'}else{'FREE_LAN_PHONE_SHARE_NOT_PROVEN'}
L ('status_antigravity='+$statusAgv)
L ('status_phone='+$statusPhone)
L ('FINAL_R230: '+$statusAgv+'_'+$statusPhone)
W $report $script:Lines
W (Join-Path $outDir 'free-lan-antigravity-cli-summary-r230.md') (@('# R230 summary','',('Antigravity status: '+$statusAgv),('AI: '+$outAi),('PNG: '+$outPng),('Invoke marker: '+$outInvoke),'',('Free LAN phone-share status: '+$statusPhone),'Open one of these on phone while same Wi-Fi:') + ($lanUrls|ForEach-Object{'- '+$_}) + @('','Free alternatives: same-WiFi HTTP share, Syncthing, LocalSend, ZeroTier, self-hosted WireGuard.'))
exit 0
