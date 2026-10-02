# t175_antigravity_illustrator_browser_phone_share.ps1 - round 221.
# Laptop-only: ask Antigravity to run Illustrator/cell_su7 directly, search the
# user's Tencent/browser skill locations, test a concrete Edge browser task, and
# publish a safe Tailscale phone file-share URL. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{24,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[REDACTED-GUID]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec) { $job=Start-Job -ScriptBlock $Block; if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function File-Info([string]$p) { if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return ([pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')}) } return ([pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''}) }
function Curl-Text([string]$Url,[int]$Sec) { try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -L --max-time $Sec -sS $Url 2>&1 | Out-String).Trim() }catch{ return $_.Exception.Message } }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'ANTIGRAVITY_ILLUSTRATOR_BROWSER_PHONE_SHARE_R221.md'
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$agvRoot='E:\0mcp-agv'
$testRoot=Join-Path $lab 'antigravity-tests\agv_illustrator_direct_r221'
$browserRoot=Join-Path $lab 'browser-tests\edge_task_r221'
$phoneRoot=Join-Path $lab 'phone-share'
foreach($d in @($reports,$testRoot,$browserRoot,$phoneRoot)){ New-Item -ItemType Directory -Force -Path $d | Out-Null }
L '# Antigravity Illustrator direct + Tencent/browser skill + phone share r221'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
L 'scope=laptop_only'

# 1. Prepare a runner that Antigravity must execute to prove direct Illustrator control.
$runner=Join-Path $testRoot 'run_illustrator_direct_r221.ps1'
$fixture=Join-Path $testRoot 'direct_fixture_r221.svg'
$outAi=Join-Path $testRoot 'antigravity_direct_figure_r221.ai'
$outPng=Join-Path $testRoot 'antigravity_direct_figure_r221.png'
$outLog=Join-Path $testRoot 'direct_runner_r221.log'
$outDone=Join-Path $testRoot 'direct_runner_done_r221.txt'
$fixtureSvg=@'
<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="620" viewBox="0 0 1000 620">
<rect width="1000" height="620" fill="#ffffff"/>
<rect x="80" y="90" width="840" height="440" rx="28" fill="#f8fafc" stroke="#0f172a" stroke-width="3"/>
<circle cx="245" cy="250" r="70" fill="#dbeafe" stroke="#2563eb" stroke-width="5"/>
<circle cx="500" cy="250" r="70" fill="#dcfce7" stroke="#16a34a" stroke-width="5"/>
<circle cx="755" cy="250" r="70" fill="#fef3c7" stroke="#f59e0b" stroke-width="5"/>
<path d="M315 250 H430" stroke="#64748b" stroke-width="7" fill="none"/>
<path d="M570 250 H685" stroke="#64748b" stroke-width="7" fill="none"/>
<text x="178" y="255" font-size="34" font-family="Arial">Input</text>
<text x="438" y="255" font-size="34" font-family="Arial">Model</text>
<text x="695" y="255" font-size="34" font-family="Arial">Figure</text>
<text x="140" y="420" font-size="32" font-family="Arial">AGV Illustrator direct R221</text>
<text x="140" y="465" font-size="24" font-family="Arial">Generated only if Antigravity runs the provided cell_su7/Illustrator script.</text>
</svg>
'@
[IO.File]::WriteAllText($fixture,$fixtureSvg,(New-Object Text.UTF8Encoding($false)))
$runnerLines=@'
param()
$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
$script:Lines=@()
$root='E:\0mcp-agv-arena-optimized\antigravity-tests\agv_illustrator_direct_r221'
$fixture=Join-Path $root 'direct_fixture_r221.svg'
$outAi=Join-Path $root 'antigravity_direct_figure_r221.ai'
$outPng=Join-Path $root 'antigravity_direct_figure_r221.png'
$done=Join-Path $root 'direct_runner_done_r221.txt'
$log=Join-Path $root 'direct_runner_r221.log'
L '# Antigravity direct Illustrator runner r221'
L ('time=' + (Get-Date).ToString('s'))
$aiExe=$null
foreach($base in @('E:\','D:\','C:\Program Files','C:\Program Files (x86)')){ if(Test-Path $base){ try{ foreach($d in @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Illustrator' })){ $cand=Join-Path $d.FullName 'Support Files\Contents\Windows\Illustrator.exe'; if(Test-Path -LiteralPath $cand){ $aiExe=$cand; break } }; if($aiExe){break} }catch{} } }
L ('illustrator=' + (San $aiExe))
$skillScripts=Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\skills\cell_su7\scripts'
$lct=Join-Path $skillScripts 'run_cell_lct.ps1'
L ('cell_su7_runner=' + (San $lct) + ' exists=' + (Test-Path -LiteralPath $lct))
if(-not $aiExe -or -not (Test-Path -LiteralPath $lct) -or -not (Test-Path -LiteralPath $fixture)){ L 'FINAL: MISSING_PREREQ'; W $log $script:Lines; exit 2 }
try{ Stop-Process -Name Illustrator -Force -ErrorAction SilentlyContinue }catch{}
Start-Sleep -Seconds 3
$mkdoc=Join-Path $root 'mkdoc_r221.result'
$mkjsx=Join-Path $root 'mkdoc_r221.jsx'
Remove-Item -LiteralPath $mkdoc -Force -ErrorAction SilentlyContinue
[IO.File]::WriteAllText($mkjsx,'(function(){try{app.documents.add(DocumentColorSpace.RGB,1200,800);var f=new File("E:/0mcp-agv-arena-optimized/antigravity-tests/agv_illustrator_direct_r221/mkdoc_r221.result");f.encoding="UTF-8";f.open("w");f.write("OK|docs="+app.documents.length);f.close();}catch(e){var g=new File("E:/0mcp-agv-arena-optimized/antigravity-tests/agv_illustrator_direct_r221/mkdoc_r221.result");g.encoding="UTF-8";g.open("w");g.write("ERR|"+e.message);g.close();}})();',(New-Object Text.UTF8Encoding($false)))
Start-Process -FilePath $aiExe -ArgumentList @('"' + $mkjsx + '"')
$deadline=(Get-Date).AddSeconds(150)
while((Get-Date)-lt $deadline){ if(Test-Path -LiteralPath $mkdoc){break}; Start-Sleep -Milliseconds 700 }
$mk=''; if(Test-Path -LiteralPath $mkdoc){$mk=Get-Content -LiteralPath $mkdoc -Raw}
L ('mkdoc=' + (San $mk))
if($mk -notmatch 'OK\|docs=1'){ L 'FINAL: MKDOC_FAIL'; W $log $script:Lines; exit 2 }
$work=Join-Path $root 'live-cache'
$runLog=Join-Path $root 'cell_su7_run.log'
$errLog=Join-Path $root 'cell_su7_err.log'
Remove-Item -LiteralPath $outAi,$outPng,$done,$runLog,$errLog -Force -ErrorAction SilentlyContinue
$args=@('-NoProfile','-ExecutionPolicy','Bypass','-File','"'+$lct+'"','-InputSvg','"'+$fixture+'"','-WorkDir','"'+$work+'"','-OutputAi','"'+$outAi+'"','-OutputPng','"'+$outPng+'"','-Placement','center','-MaxWidthFraction','0.8','-MaxHeightFraction','0.8','-MinBatchSize','5','-MaxBatchSize','80')
$p=Start-Process -FilePath 'powershell.exe' -ArgumentList ($args -join ' ') -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $runLog -RedirectStandardError $errLog
L ('runner_exit=' + $p.ExitCode)
if(Test-Path -LiteralPath $runLog){ foreach($line in (Get-Content -LiteralPath $runLog -Tail 8)){ if($line.Trim()){ L ('run|' + (San $line)) } } }
if(Test-Path -LiteralPath $errLog){ foreach($line in (Get-Content -LiteralPath $errLog -Tail 5)){ if($line.Trim()){ L ('err|' + (San $line)) } } }
$ok=(Test-Path -LiteralPath $outAi) -and (Test-Path -LiteralPath $outPng) -and ($p.ExitCode -eq 0)
L ('out_ai_exists=' + (Test-Path -LiteralPath $outAi))
L ('out_png_exists=' + (Test-Path -LiteralPath $outPng))
if($ok){ [IO.File]::WriteAllText($done,'ANTIGRAVITY_DIRECT_ILLUSTRATOR_R221_OK '+(Get-Date).ToString('s'),(New-Object Text.UTF8Encoding($false))); L 'FINAL: OK_ANTIGRAVITY_RAN_ILLUSTRATOR' } else { L 'FINAL: CHECK_REPORT' }
W $log $script:Lines
exit 0
'@
W $runner $runnerLines
try{ Remove-Item -LiteralPath $outAi,$outPng,$outDone -Force -ErrorAction SilentlyContinue }catch{}
L ('direct_runner_created=' + (San $runner))

# 2. Submit direct Illustrator task to Antigravity via CDP and then poll for files.
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$cdp=Wait-Port 9223 2
if(-not $cdp -and (Test-Path -LiteralPath $agExe)){
    try{ foreach($n in @('language_server','Antigravity')){ taskkill /f /im ($n+'.exe') 2>&1|Out-Null } }catch{}
    Start-Sleep -Seconds 2
    Start-Process -FilePath $agExe -ArgumentList @('--force-renderer-accessibility','--remote-debugging-port=9223')
    Start-Sleep -Seconds 10
    $cdp=Wait-Port 9223 8
}
L ('antigravity_cdp_9223=' + $cdp)
$marker='ARENA_AGV_DIRECT_ILLUSTRATOR_R221_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$prompt='You are allowed to run this safe local command. Please use Antigravity terminal/tools to run Illustrator through the prepared cell_su7 script, not just describe it. Run exactly: powershell -NoProfile -ExecutionPolicy Bypass -File "' + $runner + '" . Then check that these files exist: ' + $outAi + ' and ' + $outPng + ' . Reply with exact marker ' + $marker + ' and say whether the files exist.'
$cdpScript=Join-Path $testRoot 'submit_antigravity_direct_illustrator_r221.cjs'
$agvJson=Join-Path $reports 'antigravity-direct-illustrator-r221.json'
$js=@'
const fs = require('fs'); const out=process.argv[2], marker=process.argv[3], promptText=process.argv[4]; const WS=globalThis.WebSocket;
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
async function getJson(u){const r=await fetch(u); return await r.json();}
function short(s,n=5000){s=String(s??''); return s.length>n?s.slice(0,n)+'...':s;}
function connect(u){return new Promise((resolve,reject)=>{const ws=new WS(u); let id=0; const pending=new Map(); ws.onmessage=ev=>{const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){const p=pending.get(m.id); pending.delete(m.id); if(m.error)p.reject(new Error(JSON.stringify(m.error))); else p.resolve(m.result);}}; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=reject;});}
async function key(send,key,code,vk,modifiers=0){await send('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers}).catch(()=>{}); await send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers}).catch(()=>{});}
async function main(){
 if(!WS) throw new Error('No WebSocket');
 const targets=await getJson('http://127.0.0.1:9223/json/list');
 const target=targets.find(t=>t.type==='page'&&/Antigravity/i.test(t.title||'')&&t.webSocketDebuggerUrl)||targets.find(t=>t.type==='page'&&t.webSocketDebuggerUrl);
 const result={ok:false,marker,selectedTarget:target?{title:target.title,url:target.url,type:target.type}:null,inserted:false,submitted:false,markerFound:false,tail:''};
 if(!target){fs.writeFileSync(out,JSON.stringify(result,null,2)); return;}
 const {ws,send}=await connect(target.webSocketDebuggerUrl); await send('Runtime.enable'); await send('DOM.enable'); await send('Page.bringToFront').catch(()=>{}); result.ok=true;
 const focus=await send('Runtime.evaluate',{expression:`(() => { const e=document.querySelector('[aria-label="Message input"]') || document.querySelector('[role="combobox"][aria-label*="Message"]') || document.querySelector('[contenteditable],textarea,input,[role="textbox"]'); if(!e)return {ok:false}; e.scrollIntoView({block:'center'}); e.click(); e.focus(); try{ if(e.isContentEditable){ e.textContent=''; e.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'deleteContentBackward'})); } }catch(err){} return {ok:true,tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||''}; })()`,returnByValue:true,awaitPromise:true});
 result.focus=focus.result.value;
 if(result.focus&&result.focus.ok){await key(send,'A','KeyA',65,2); await key(send,'Backspace','Backspace',8,0); await send('Input.insertText',{text:promptText}); result.inserted=true; await key(send,'Enter','Enter',13,0); await sleep(700); await key(send,'Enter','Enter',13,2); result.submitted=true; await sleep(15000); const chk=await send('Runtime.evaluate',{expression:`(() => { const body=document.body?.innerText||''; return {found:body.includes(${JSON.stringify(marker)}), tail:body.slice(-10000)}; })()`,returnByValue:true,awaitPromise:true}); result.markerFound=!!chk.result.value?.found; result.tail=short(chk.result.value?.tail||'',5000);}
 try{ws.close();}catch{} fs.writeFileSync(out,JSON.stringify(result,null,2));
}
main().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($cdpScript,$js,(New-Object Text.UTF8Encoding($false)))
$nodeOut='SKIPPED'
if($cdp -and (Get-Command node -ErrorAction SilentlyContinue)){
    $ns=$cdpScript; $oj=$agvJson; $mk=$marker; $pt=$prompt
    $nodeOut=Run-Cap { node $using:ns $using:oj $using:mk $using:pt 2>&1 | Out-String } 80
}
L ('antigravity_submit_node=' + (San (($nodeOut -split "`r?`n" | Select-Object -First 10) -join ' | ')))
$pollDeadline=(Get-Date).AddSeconds(720)
while((Get-Date) -lt $pollDeadline){ if((Test-Path -LiteralPath $outDone) -or ((Test-Path -LiteralPath $outAi) -and (Test-Path -LiteralPath $outPng))){ break }; Start-Sleep -Seconds 10 }
$aiInfo=File-Info $outAi; $pngInfo=File-Info $outPng; $doneInfo=File-Info $outDone
L ('direct_result ai_exists=' + $aiInfo.exists + ' ai_bytes=' + $aiInfo.bytes + ' png_exists=' + $pngInfo.exists + ' png_bytes=' + $pngInfo.bytes + ' done=' + $doneInfo.exists)
if(Test-Path -LiteralPath $outLog){ foreach($line in (Get-Content -LiteralPath $outLog -Tail 40 -ErrorAction SilentlyContinue)){ if($line.Trim()){ L ('direct_log|' + (San $line)) } } } else { L 'direct_log_missing=True' }
try{ Copy-Item -LiteralPath $agvJson -Destination (Join-Path $outDir 'antigravity-direct-illustrator-r221.json') -Force -ErrorAction SilentlyContinue }catch{}

# 3. Search Tencent/browser skill locations and Edge extensions.
$midtermRoot=('E:\0' + [string]([char]0x4E2D) + [string]([char]0x671F))
$cnPlugin=([string]([char]0x63D2) + [string]([char]0x4EF6))
$cnTencent=([string]([char]0x817E) + [string]([char]0x8BAF))
$scanPattern='Tencent|tencent|browser|playwright|selenium|edge|mcp|' + [regex]::Escape($cnPlugin)
$scanRoots=@('E:\0GitHub','E:\0github',$midtermRoot,'E:\0mcp-agv','E:\0mcp-agv-arena-optimized')
$hits=@()
foreach($root in $scanRoots){ if(Test-Path -LiteralPath $root){
    try{
        $hits += @(Get-ChildItem -LiteralPath $root -Recurse -Depth 7 -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match $scanPattern -or $_.Name -match $scanPattern } | Select-Object -First 180 FullName,Length,LastWriteTime)
        $hits += @(Get-ChildItem -LiteralPath $root -Recurse -Depth 5 -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match $scanPattern -or $_.Name -match $scanPattern } | Select-Object -First 80 FullName,Length,LastWriteTime)
    }catch{ L ('scan_WARN=' + (San $root) + ' err=' + (San $_.Exception.Message)) }
}}
$hits=@($hits | Sort-Object FullName -Unique)
L ('browser_tencent_hit_count=' + $hits.Count)
foreach($h in ($hits | Select-Object -First 80)){ L ('browser_tencent_hit|' + (San $h.FullName)) }
$edgeExtRows=@()
$edgeRoots=@((Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Default\Extensions'),(Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\Profile 1\Extensions'))
foreach($er in $edgeRoots){ if(Test-Path -LiteralPath $er){
    try{ foreach($mf in @(Get-ChildItem -LiteralPath $er -Recurse -Depth 3 -Filter manifest.json -File -ErrorAction SilentlyContinue | Select-Object -First 80)){
        $raw=Get-Content -LiteralPath $mf.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $name=''; $ver=''; try{ $j=$raw|ConvertFrom-Json; $name=[string]$j.name; $ver=[string]$j.version }catch{}
        $edgeExtRows += [pscustomobject]@{manifest=$mf.FullName;name=$name;version=$ver;tencent=([bool]($raw -match ('Tencent|tencent|' + [regex]::Escape($cnTencent))))}
    }}catch{}
}}
L ('edge_extension_manifest_count=' + $edgeExtRows.Count)
foreach($e in ($edgeExtRows | Sort-Object tencent -Descending | Select-Object -First 50)){ L ('edge_ext|tencent=' + $e.tencent + '|name=' + (San $e.name) + '|ver=' + (San $e.version) + '|manifest=' + (San $e.manifest)) }
$browserScanJson=Join-Path $reports 'browser-tencent-edge-scan-r221.json'
[IO.File]::WriteAllText($browserScanJson, ([pscustomobject]@{hits=$hits;edgeExtensions=$edgeExtRows} | ConvertTo-Json -Depth 8) + "`r`n", (New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $browserScanJson -Destination (Join-Path $outDir 'browser-tencent-edge-scan-r221.json') -Force }catch{}

# 4. Concrete Edge browser-control task with local HTML. This tests browser automation safely.
$html=Join-Path $browserRoot 'edge_browser_task_r221.html'
$edgeJson=Join-Path $reports 'edge-browser-task-r221.json'
$htmlText=@'
<!doctype html><meta charset="utf-8"><title>Arena Edge Browser Task R221</title>
<h1 id="title">Arena Edge Browser Task R221</h1>
<button id="btn" onclick="document.body.setAttribute('data-clicked','yes');document.getElementById('out').textContent='EDGE_BROWSER_TASK_R221_OK';">Click me</button>
<div id="out">pending</div>
'@
[IO.File]::WriteAllText($html,$htmlText,(New-Object Text.UTF8Encoding($false)))
$edgeExe=''
foreach($p in @((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),(Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'))){ if($p -and (Test-Path -LiteralPath $p)){ $edgeExe=$p; break } }
if(-not $edgeExe){ try{ $cmd=Get-Command msedge.exe -ErrorAction SilentlyContinue; if($cmd){$edgeExe=$cmd.Source} }catch{} }
$edgePort=9224
$edgeProfile=Join-Path $browserRoot 'edge-cdp-profile'
if($edgeExe){ try{ Start-Process -FilePath $edgeExe -ArgumentList @('--remote-debugging-port='+$edgePort,'--user-data-dir='+$edgeProfile,'--no-first-run','--disable-first-run-ui',('file:///' + ($html -replace '\\','/'))) | Out-Null; Start-Sleep -Seconds 4 }catch{ L ('edge_start_WARN=' + (San $_.Exception.Message)) } }
$edgeCdp=Wait-Port $edgePort 10
L ('edge_cdp=' + $edgeCdp + ' edge_exe=' + (San $edgeExe))
$edgeScript=Join-Path $browserRoot 'edge_browser_task_r221.cjs'
$edgeJs=@'
const fs=require('fs'); const out=process.argv[2]; const port=process.argv[3]; const WS=globalThis.WebSocket;
async function getJson(u){const r=await fetch(u); return await r.json();}
function connect(u){return new Promise((resolve,reject)=>{const ws=new WS(u); let id=0; const pending=new Map(); ws.onmessage=ev=>{const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){const p=pending.get(m.id); pending.delete(m.id); if(m.error)p.reject(new Error(JSON.stringify(m.error))); else p.resolve(m.result);}}; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=reject;});}
async function main(){const targets=await getJson(`http://127.0.0.1:${port}/json/list`); const target=targets.find(t=>(t.url||'').includes('edge_browser_task_r221.html'))||targets.find(t=>t.webSocketDebuggerUrl); const result={ok:false,target:target?{title:target.title,url:target.url}:null}; if(!target){fs.writeFileSync(out,JSON.stringify(result,null,2));return;} const {ws,send}=await connect(target.webSocketDebuggerUrl); await send('Runtime.enable'); result.title=(await send('Runtime.evaluate',{expression:'document.title',returnByValue:true})).result.value; await send('Runtime.evaluate',{expression:'document.getElementById("btn").click()',returnByValue:true}); const chk=(await send('Runtime.evaluate',{expression:'({clicked:document.body.getAttribute("data-clicked"),out:document.getElementById("out").textContent})',returnByValue:true})).result.value; result.ok=(chk.clicked==='yes'&&chk.out==='EDGE_BROWSER_TASK_R221_OK'); result.check=chk; try{ws.close();}catch{} fs.writeFileSync(out,JSON.stringify(result,null,2));}
main().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($edgeScript,$edgeJs,(New-Object Text.UTF8Encoding($false)))
if($edgeCdp -and (Get-Command node -ErrorAction SilentlyContinue)){ $es=$edgeScript; $ej=$edgeJson; $ep=[string]$edgePort; $edgeNode=Run-Cap { node $using:es $using:ej $using:ep 2>&1 | Out-String } 45; L ('edge_task_node=' + (San $edgeNode)) } else { L 'edge_task_skipped=no_edge_cdp_or_node' }
$edgeOk=$false
if(Test-Path -LiteralPath $edgeJson){ try{ $ejj=Get-Content -LiteralPath $edgeJson -Raw -Encoding UTF8 | ConvertFrom-Json; $edgeOk=[bool]$ejj.ok; L ('edge_task_ok=' + $edgeOk + ' title=' + (San ([string]$ejj.title)) + ' out=' + (San ([string]$ejj.check.out))) }catch{ L ('edge_task_parse_WARN=' + (San $_.Exception.Message)) } }
try{ Copy-Item -LiteralPath $edgeJson -Destination (Join-Path $outDir 'edge-browser-task-r221.json') -Force -ErrorAction SilentlyContinue }catch{}

# 5. Safe phone browser share over Tailscale.
$shareReadme=Join-Path $phoneRoot 'README_PHONE_SHARE_R221.txt'
$shareIndex=Join-Path $phoneRoot 'index.html'
[IO.File]::WriteAllText($shareReadme, "Arena phone share R221`r`nThis folder is intentionally limited. Copy files here to open them from your phone browser over Tailscale.`r`n", (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($shareIndex, '<!doctype html><meta charset="utf-8"><title>Arena Phone Share R221</title><h1>Arena Phone Share R221</h1><p>If you can read this on your phone, Tailscale browser file access works.</p><p><a href="README_PHONE_SHARE_R221.txt">README_PHONE_SHARE_R221.txt</a></p>', (New-Object Text.UTF8Encoding($false)))
$tsExe=''
foreach($p in @('E:\Tailscale\tailscale.exe','C:\Program Files\Tailscale\tailscale.exe','C:\Program Files (x86)\Tailscale\tailscale.exe')){ if(Test-Path -LiteralPath $p){ $tsExe=$p; break } }
if(-not $tsExe){ try{ $cmd=Get-Command tailscale -ErrorAction SilentlyContinue; if($cmd){$tsExe=$cmd.Source} }catch{} }
$tsIp=''
if($tsExe){ $t=$tsExe; $tsIp=(Run-Cap { & $using:t ip -4 2>&1 | Select-Object -First 1 | Out-String } 20).Trim() }
$sharePort=18089
$pidFile=Join-Path $phoneRoot 'phone_share_python.pid'
if(Test-Path -LiteralPath $pidFile){ try{ $old=[int](Get-Content -LiteralPath $pidFile -Raw); Stop-Process -Id $old -Force -ErrorAction SilentlyContinue }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
if($py){
    $args=@('-m','http.server',[string]$sharePort,'--bind','0.0.0.0','--directory',$phoneRoot)
    try{ $p=Start-Process -FilePath $py -ArgumentList $args -PassThru -WindowStyle Hidden; [IO.File]::WriteAllText($pidFile,[string]$p.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('phone_share_started_pid=' + $p.Id) }catch{ L ('phone_share_start_WARN=' + (San $_.Exception.Message)) }
}else{ L 'phone_share_no_python=True' }
$fwOut=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 2>&1 | Out-String } 30
L ('firewall_rule_result=' + (San (($fwOut -split "`r?`n" | Select-Object -First 8) -join ' | ')))
$localText=Curl-Text ('http://127.0.0.1:' + $sharePort + '/') 10
$tsText=''
if($tsIp){ $tsText=Curl-Text ('http://' + $tsIp + ':' + $sharePort + '/') 10 }
$shareOk=($localText -match 'Arena Phone Share R221') -and ($tsText -match 'Arena Phone Share R221')
$phoneUrl=if($tsIp){ 'http://' + $tsIp + ':' + $sharePort + '/' }else{ '' }
L ('phone_share_url=' + $phoneUrl)
L ('phone_share_local_ok=' + [bool]($localText -match 'Arena Phone Share R221') + ' tailscale_ok=' + [bool]($tsText -match 'Arena Phone Share R221'))
$phoneGuide=@(
'# Phone browser file access r221',
'',
('Share root: ' + $phoneRoot),
('Phone URL: ' + $phoneUrl),
'',
'Open the Phone URL in your phone browser while Tailscale is connected. Only files copied into this share folder are exposed.',
'Do not expose the whole drive unless you really intend to. For private transfer, copy selected files into the share root, then open them from the phone.',
'',
'If the URL does not open on the phone: keep laptop awake, check Tailscale is connected on phone, confirm the firewall rule, and retry the URL.'
)
W (Join-Path $reports 'phone-browser-file-share-r221.md') $phoneGuide

# 6. Summary.
$directFinal=if($aiInfo.exists -and $pngInfo.exists -and $doneInfo.exists){'ANTIGRAVITY_DIRECT_ILLUSTRATOR_FILES_CREATED'}elseif($aiInfo.exists -and $pngInfo.exists){'ILLUSTRATOR_FILES_CREATED_NO_DONE_MARKER'}else{'ANTIGRAVITY_DIRECT_ILLUSTRATOR_NOT_PROVEN'}
$summary=@(
'# R221 summary',
'',
('Antigravity direct Illustrator: ' + $directFinal),
('AI: ' + $outAi),
('PNG: ' + $outPng),
('Antigravity JSON: ' + $agvJson),
'',
('Tencent/browser scan JSON: ' + $browserScanJson),
('Edge browser task JSON: ' + $edgeJson),
('Edge browser concrete task OK: ' + $edgeOk),
'',
('Phone share root: ' + $phoneRoot),
('Phone share URL: ' + $phoneUrl),
('Phone share reachable via tailnet IP from laptop: ' + $shareOk),
('Phone guide: ' + (Join-Path $reports 'phone-browser-file-share-r221.md')),
'',
'Note: browser/Kaggle credentials, cookies, passwords, and tokens were not read or printed.'
)
W (Join-Path $reports 'antigravity-illustrator-browser-phone-share-summary-r221.md') $summary
foreach($p in @((Join-Path $reports 'antigravity-illustrator-browser-phone-share-summary-r221.md'),(Join-Path $reports 'phone-browser-file-share-r221.md'),$browserScanJson,$edgeJson,$agvJson)){ try{ if(Test-Path -LiteralPath $p){ Copy-Item -LiteralPath $p -Destination (Join-Path $outDir (Split-Path $p -Leaf)) -Force } }catch{} }
foreach($line in $summary){ L $line }
L ('FINAL_R221: ' + $directFinal + '_EDGE_' + $edgeOk + '_PHONE_SHARE_' + $shareOk)
W $report $script:Lines
L ('main_report=' + (San $report))
exit 0
