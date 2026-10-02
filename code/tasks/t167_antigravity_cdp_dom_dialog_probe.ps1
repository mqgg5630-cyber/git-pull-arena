# t167_antigravity_cdp_dom_dialog_probe.ps1 - round 210.
# Use the Antigravity CDP endpoint to inspect DOM candidates and, only when a
# clear chat/message input is found, attempt a harmless dialog probe. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Invoke-Curl([string[]]$CurlArgs) { try { $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce @CurlArgs 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message } }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'ANTIGRAVITY_CDP_DOM_DIALOG_PROBE_R210.md'
L '--- task t167: Antigravity CDP DOM/dialog probe ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$lab='E:\0mcp-agv-arena-optimized'
$suite=Join-Path $lab 'computer-use-suite'
$reports=Join-Path $lab 'reports'
New-Item -ItemType Directory -Force -Path $suite,$reports | Out-Null
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$cdp=Wait-Port 9223 3
if(-not $cdp -and (Test-Path -LiteralPath $agExe)){
    try{ foreach($n in @('language_server','Antigravity')){ taskkill /f /im ($n+'.exe') 2>&1|Out-Null } }catch{}
    Start-Sleep -Seconds 2
    Start-Process -FilePath $agExe -ArgumentList @('--force-renderer-accessibility','--remote-debugging-port=9223')
    Start-Sleep -Seconds 10
    $cdp=Wait-Port 9223 8
}
L ('cdp_9223_listening=' + $cdp)
$nodeScript=Join-Path $suite 'antigravity-cdp-dom-probe.mjs'
$domJson=Join-Path $reports 'antigravity-cdp-dom-r210.json'
$marker='ARENA_AGV_DIALOG_PROBE_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$js=@'
const fs = require('fs');
const out = process.argv[2];
const marker = process.argv[3];
function short(s,n=160){ s = String(s ?? ''); return s.length > n ? s.slice(0,n) + '...' : s; }
async function getJson(url){ const r = await fetch(url); return await r.json(); }
function sleep(ms){ return new Promise(r => setTimeout(r, ms)); }
async function main(){
  const targets = await getJson('http://127.0.0.1:9223/json/list');
  const target = targets.find(t => t.type === 'page' && t.title === 'Antigravity' && t.webSocketDebuggerUrl) || targets.find(t => t.type === 'page' && t.webSocketDebuggerUrl);
  const result = { ok:false, marker, targetSummary: targets.map(t => ({type:t.type,title:short(t.title,100),url:short(t.url,120)})), selectedTarget: target ? {title:target.title,url:target.url,type:target.type} : null, candidates:[], inputCandidates:[], action:{attempted:false, submitted:false, markerFound:false} };
  if(!target){ fs.writeFileSync(out, JSON.stringify(result,null,2)); return; }
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  let id = 0; const pending = new Map();
  ws.onmessage = ev => { const msg = JSON.parse(ev.data); if(msg.id && pending.has(msg.id)){ const {resolve,reject}=pending.get(msg.id); pending.delete(msg.id); if(msg.error) reject(new Error(JSON.stringify(msg.error))); else resolve(msg.result); } };
  await new Promise((resolve,reject)=>{ ws.onopen=resolve; ws.onerror=reject; });
  const send = (method, params={}) => new Promise((resolve,reject)=>{ const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params})); });
  await send('Runtime.enable');
  await send('DOM.enable');
  const expr = `(() => {
    const visible = e => { const r=e.getBoundingClientRect(); const cs=getComputedStyle(e); return r.width>2 && r.height>2 && cs.display!=='none' && cs.visibility!=='hidden'; };
    const txt = e => (e.innerText || e.textContent || e.value || e.getAttribute('aria-label') || e.getAttribute('placeholder') || '').trim();
    const all = Array.from(document.querySelectorAll('*'));
    const candidates = all.filter(e => visible(e) && (['TEXTAREA','INPUT','BUTTON'].includes(e.tagName) || e.isContentEditable || /button|textbox|searchbox|textarea|menuitem|tab/i.test(e.getAttribute('role')||'') || /chat|agent|message|ask|prompt|composer|input|send|new|mcp|tool/i.test(txt(e) + ' ' + (e.className||'') + ' ' + (e.id||'')))).slice(0,250).map((e,i)=>{ const r=e.getBoundingClientRect(); return {idx:i, tag:e.tagName, role:e.getAttribute('role')||'', type:e.getAttribute('type')||'', aria:e.getAttribute('aria-label')||'', placeholder:e.getAttribute('placeholder')||'', id:e.id||'', cls:String(e.className||'').slice(0,120), text:txt(e).slice(0,180), contentEditable:!!e.isContentEditable, rect:{x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height)}} });
    const inputs = candidates.filter(c => c.tag==='TEXTAREA' || c.tag==='INPUT' || c.contentEditable || /textbox|searchbox|textarea/i.test(c.role) || /message|ask|prompt|composer|chat/i.test((c.aria+' '+c.placeholder+' '+c.text+' '+c.cls).toLowerCase()));
    return {title:document.title, url:location.href, ready:document.readyState, bodyLen:(document.body?.innerText||'').length, candidates, inputs};
  })()`;
  const eval1 = await send('Runtime.evaluate',{expression:expr,returnByValue:true,awaitPromise:true});
  Object.assign(result, { ok:true, page: eval1.result.value });
  result.candidates = (eval1.result.value?.candidates || []).slice(0,80);
  result.inputCandidates = (eval1.result.value?.inputs || []).slice(0,40);
  const strong = (eval1.result.value?.inputs || []).find(c => /message|ask|prompt|composer|chat|agent/i.test([c.aria,c.placeholder,c.text,c.cls,c.role].join(' ')) && c.rect && c.rect.w > 80 && c.rect.h > 15);
  if(strong){
    result.action.attempted = true; result.action.candidate = strong;
    const setExpr = `(() => { const marker = ${JSON.stringify('请只回复：' + marker)}; const all = Array.from(document.querySelectorAll('*')); const visible = e => { const r=e.getBoundingClientRect(); const cs=getComputedStyle(e); return r.width>2 && r.height>2 && cs.display!=='none' && cs.visibility!=='hidden'; }; const txt = e => (e.innerText || e.textContent || e.value || e.getAttribute('aria-label') || e.getAttribute('placeholder') || '').trim(); const inputs = all.filter(e => visible(e) && (e.tagName==='TEXTAREA' || e.tagName==='INPUT' || e.isContentEditable || /textbox|searchbox|textarea/i.test(e.getAttribute('role')||'') || /message|ask|prompt|composer|chat|agent/i.test((txt(e)+' '+(e.className||'')+' '+(e.getAttribute('aria-label')||'')+' '+(e.getAttribute('placeholder')||'')).toLowerCase()))); const e=inputs.find(x => { const r=x.getBoundingClientRect(); return r.width>80 && r.height>15; }); if(!e) return {ok:false, reason:'no element'}; e.focus(); if('value' in e){ const proto = e.tagName==='TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype; const desc = Object.getOwnPropertyDescriptor(proto,'value'); if(desc && desc.set) desc.set.call(e, marker); else e.value=marker; } else { e.textContent=marker; } e.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:marker})); e.dispatchEvent(new Event('change',{bubbles:true})); const r=e.getBoundingClientRect(); return {ok:true, tag:e.tagName, role:e.getAttribute('role')||'', rect:{x:r.x,y:r.y,w:r.width,h:r.height}}; })()`;
    const setRes = await send('Runtime.evaluate',{expression:setExpr,returnByValue:true,awaitPromise:true});
    result.action.setResult = setRes.result.value;
    if(setRes.result.value?.ok){
      await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Enter',code:'Enter',windowsVirtualKeyCode:13,nativeVirtualKeyCode:13});
      await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Enter',code:'Enter',windowsVirtualKeyCode:13,nativeVirtualKeyCode:13});
      result.action.submitted = true;
      await sleep(45000);
      const chk = await send('Runtime.evaluate',{expression:`(() => ({body:(document.body?.innerText||'').slice(-6000), found:(document.body?.innerText||'').includes(${JSON.stringify(marker)})}))()`,returnByValue:true,awaitPromise:true});
      result.action.markerFound = !!chk.result.value?.found;
      result.action.tailHasMarker = !!chk.result.value?.found;
    }
  }
  try{ ws.close(); }catch{}
  fs.writeFileSync(out, JSON.stringify(result,null,2));
}
main().catch(e => { fs.writeFileSync(out, JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1; });
'@
[IO.File]::WriteAllText($nodeScript,$js,(New-Object Text.UTF8Encoding($false)))
L ('node_probe_script=' + (San $nodeScript))
if($cdp -and (Get-Command node -ErrorAction SilentlyContinue)){
    $ns=$nodeScript; $dj=$domJson; $mk=$marker
    $job=Start-Job -ScriptBlock { node $using:ns $using:dj $using:mk 2>&1 | Out-String }
    if(Wait-Job $job -Timeout 120){ $nodeOut=(Receive-Job $job | Out-String).Trim(); L ('node_probe_exit=completed'); foreach($ln in (($nodeOut -split "`r?`n")|Select-Object -First 40)){ if($ln.Trim()){ L ('node| ' + (San $ln)) } } } else { Stop-Job $job -Force -ErrorAction SilentlyContinue; L 'node_probe_TIMEOUT=120s' }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
} else { L 'node_probe_skipped=no_cdp_or_node' }
L ('dom_probe_json=' + (San $domJson))
if(Test-Path -LiteralPath $domJson){
    try{
        $j=Get-Content -LiteralPath $domJson -Raw -Encoding UTF8 | ConvertFrom-Json
        L ('dom_ok=' + $j.ok + ' candidates=' + @($j.candidates).Count + ' inputs=' + @($j.inputCandidates).Count + ' action_attempted=' + $j.action.attempted + ' submitted=' + $j.action.submitted + ' markerFound=' + $j.action.markerFound)
        foreach($c in @($j.inputCandidates|Select-Object -First 20)){ L ('input| idx=' + $c.idx + ' tag=' + (San ([string]$c.tag)) + ' role=' + (San ([string]$c.role)) + ' aria=' + (San ([string]$c.aria)) + ' placeholder=' + (San ([string]$c.placeholder)) + ' text=' + (San ([string]$c.text)) + ' rect=' + $c.rect.x + ',' + $c.rect.y + ',' + $c.rect.w + 'x' + $c.rect.h) }
        foreach($c in @($j.candidates|Select-Object -First 30)){ L ('cand| idx=' + $c.idx + ' tag=' + (San ([string]$c.tag)) + ' role=' + (San ([string]$c.role)) + ' aria=' + (San ([string]$c.aria)) + ' text=' + (San ([string]$c.text)) + ' rect=' + $c.rect.x + ',' + $c.rect.y + ',' + $c.rect.w + 'x' + $c.rect.h) }
    }catch{ L ('dom_parse_WARN=' + (San $_.Exception.Message)) }
}
$summary=@('# Antigravity CDP DOM/dialog probe r210','',('DOM JSON: ' + $domJson),('Marker: ' + $marker),'If action_attempted/submitted/markerFound are true, the CDP path can operate an Antigravity chat input. Otherwise use the candidates list to make a second targeted pass.')
W (Join-Path $reports 'antigravity-cdp-dialog-summary-r210.md') $summary
try{ Copy-Item -LiteralPath (Join-Path $reports 'antigravity-cdp-dialog-summary-r210.md') -Destination (Join-Path $outDir 'antigravity-cdp-dialog-summary-r210.md') -Force }catch{}
$final='CHECK_REPORT'
try{ $jj=Get-Content -LiteralPath $domJson -Raw -Encoding UTF8 | ConvertFrom-Json; if($jj.action.submitted -and $jj.action.markerFound){$final='ANTIGRAVITY_DIALOG_SUBMITTED_AND_MARKER_VISIBLE'} elseif($jj.ok){$final='ANTIGRAVITY_DOM_PROBED'} }catch{}
L ('FINAL_R210: ' + $final)
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t167 done ---'
exit 0
