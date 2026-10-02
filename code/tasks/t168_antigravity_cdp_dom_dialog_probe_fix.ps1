# t168_antigravity_cdp_dom_dialog_probe_fix.ps1 - round 211.
# Fix the round 210 Node ESM issue by using a CommonJS .cjs probe and run a
# more robust CDP DOM/action pass against Antigravity. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[REDACTED-GUID]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
    [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}
function Wait-Port([int]$port, [int]$sec) {
    $deadline=(Get-Date).AddSeconds($sec)
    while((Get-Date)-lt $deadline){
        try{
            $c=New-Object Net.Sockets.TcpClient
            $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null)
            if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true }
            $c.Close()
        }catch{}
        Start-Sleep -Milliseconds 300
    }
    return $false
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'ANTIGRAVITY_CDP_DOM_DIALOG_PROBE_R211.md'
L '--- task t168: Antigravity CDP DOM/dialog probe fix ---'
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
    $cdp=Wait-Port 9223 10
}
L ('cdp_9223_listening=' + $cdp)
$nodeScript=Join-Path $suite 'antigravity-cdp-dom-probe-r211.cjs'
$domJson=Join-Path $reports 'antigravity-cdp-dom-r211.json'
$marker='ARENA_AGV_DIALOG_PROBE_R211_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$prompt='Reply exactly: ' + $marker
$js=@'
const fs = require('fs');
const out = process.argv[2];
const marker = process.argv[3];
const promptText = process.argv[4];
const WS = globalThis.WebSocket;
function short(s,n=180){ s = String(s ?? ''); return s.length > n ? s.slice(0,n) + '...' : s; }
function sleep(ms){ return new Promise(r => setTimeout(r, ms)); }
async function getJson(url){ const r = await fetch(url); return await r.json(); }
function redact(s){ return String(s ?? '').replace(/[A-Za-z0-9+/_=-]{20,}/g,'[REDACTED]').replace(/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/g,'[REDACTED-GUID]'); }
function connect(wsUrl){
  return new Promise((resolve,reject)=>{
    const ws = new WS(wsUrl);
    let id = 0; const pending = new Map();
    ws.onmessage = ev => { const msg = JSON.parse(ev.data); if(msg.id && pending.has(msg.id)){ const p=pending.get(msg.id); pending.delete(msg.id); if(msg.error) p.reject(new Error(JSON.stringify(msg.error))); else p.resolve(msg.result); } };
    ws.onopen = () => {
      const send = (method, params={}) => new Promise((resolve,reject)=>{ const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params})); });
      resolve({ws,send});
    };
    ws.onerror = reject;
  });
}
async function key(send,key,code,vk,modifiers=0){
  await send('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers});
  await send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers});
}
async function enter(send,modifiers=0){ await key(send,'Enter','Enter',13,modifiers); }
async function probe(send,label){
  const expr = `(() => {
    const terms = /chat|agent|message|ask|prompt|composer|input|send|new chat|inline|quick|command|textbox|textarea|mcp|tool|plan|edit/i;
    const skip = /codicon|icon|monaco-icon/i;
    function safe(v){ try { return String(v || '').slice(0,220); } catch(e){ return ''; } }
    function rectOf(e){ try { const r=e.getBoundingClientRect(); return {x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height)}; } catch(err){ return {x:0,y:0,w:0,h:0}; } }
    function styleOf(e){ try { const cs=getComputedStyle(e); return {display:cs.display,visibility:cs.visibility,opacity:cs.opacity}; } catch(err){ return {display:'',visibility:'',opacity:''}; } }
    function visible(e){ const r=rectOf(e); const s=styleOf(e); return r.w>0 && r.h>0 && s.display!=='none' && s.visibility!=='hidden' && s.opacity!=='0'; }
    function textOf(e){ return safe(e.innerText || e.textContent || e.value || e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.getAttribute('title') || ''); }
    const els=[];
    function walk(root, depth){
      if(!root || depth>5) return;
      let nodes=[]; try { nodes = Array.from(root.querySelectorAll('*')); } catch(e) { return; }
      for(const e of nodes){
        els.push(e);
        try { if(e.shadowRoot) walk(e.shadowRoot, depth+1); } catch(err) {}
        try { if(e.tagName==='IFRAME' && e.contentDocument) walk(e.contentDocument, depth+1); } catch(err) {}
      }
    }
    walk(document,0);
    function score(e){
      const tag=e.tagName||''; const role=e.getAttribute('role')||''; const aria=e.getAttribute('aria-label')||''; const ph=e.getAttribute('placeholder')||''; const id=e.id||''; const cls=String(e.className||''); const title=e.getAttribute('title')||''; const txt=textOf(e);
      const hay=(tag+' '+role+' '+aria+' '+ph+' '+id+' '+cls+' '+title+' '+txt).toLowerCase();
      let s=0;
      if(tag==='TEXTAREA') s+=70; if(tag==='INPUT') s+=55; if(e.isContentEditable) s+=60; if(/textbox|searchbox|textarea/.test(role)) s+=55;
      if(/monaco-editor|inputarea|interactive-input|chat-input|composer|prompt-input/.test(hay)) s+=45;
      if(/chat|agent|message|ask|prompt|composer|inline/.test(hay)) s+=35;
      if(/send|submit/.test(hay) && /button|a|div|span/.test(tag.toLowerCase()+' '+role)) s+=20;
      if(/command|quick-input|quickinput/.test(hay)) s+=20;
      const r=rectOf(e); if(r.w>80) s+=8; if(r.h>15) s+=8; if(r.y>250) s+=4;
      if(e.disabled || e.getAttribute('aria-disabled')==='true') s-=80;
      if(skip.test(hay)) s-=20;
      return s;
    }
    const candidates = els.map((e,i)=>{
      const r=rectOf(e); const st=styleOf(e); const tag=e.tagName||''; const role=e.getAttribute('role')||''; const txt=textOf(e); const hay=(tag+' '+role+' '+(e.getAttribute('aria-label')||'')+' '+(e.getAttribute('placeholder')||'')+' '+(e.id||'')+' '+String(e.className||'')+' '+txt);
      return {idx:i, tag, role, type:e.getAttribute('type')||'', aria:safe(e.getAttribute('aria-label')||''), placeholder:safe(e.getAttribute('placeholder')||''), title:safe(e.getAttribute('title')||''), id:safe(e.id||''), cls:safe(String(e.className||'')), text:safe(txt), contentEditable:!!e.isContentEditable, visible:visible(e), score:score(e), rect:r, display:st.display, visibility:st.visibility};
    }).filter(c => c.score>20 || (c.visible && terms.test([c.tag,c.role,c.aria,c.placeholder,c.title,c.id,c.cls,c.text].join(' ')))).sort((a,b)=>b.score-a.score).slice(0,220);
    const inputCandidates = candidates.filter(c => c.score>=55 || c.tag==='TEXTAREA' || c.tag==='INPUT' || c.contentEditable || /textbox|searchbox|textarea/.test(c.role) || /chat|agent|message|ask|prompt|composer|inputarea|interactive-input/.test((c.aria+' '+c.placeholder+' '+c.title+' '+c.id+' '+c.cls+' '+c.text).toLowerCase())).slice(0,80);
    return {label:${JSON.stringify(label)}, title:document.title, url:location.href, ready:document.readyState, bodyLen:(document.body?.innerText||'').length, bodyTail:(document.body?.innerText||'').slice(-3000), candidates, inputCandidates};
  })()`;
  const ev = await send('Runtime.evaluate',{expression:expr,returnByValue:true,awaitPromise:true});
  return ev.result.value;
}
async function focusBestInput(send, promptText){
  const expr = `(() => {
    const promptText = ${JSON.stringify(promptText)};
    function rectOf(e){ try { const r=e.getBoundingClientRect(); return {x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height)}; } catch(err){ return {x:0,y:0,w:0,h:0}; } }
    function visible(e){ try { const r=e.getBoundingClientRect(); const cs=getComputedStyle(e); return r.width>=0 && r.height>=0 && cs.display!=='none' && cs.visibility!=='hidden' && cs.opacity!=='0'; } catch(err){ return false; } }
    function txt(e){ try { return (e.innerText || e.textContent || e.value || e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.getAttribute('title') || '').trim(); } catch(err){ return ''; } }
    const els=[]; function walk(root,depth){ if(!root || depth>5) return; let nodes=[]; try{ nodes=Array.from(root.querySelectorAll('*')); }catch(e){return;} for(const e of nodes){ els.push(e); try{ if(e.shadowRoot) walk(e.shadowRoot,depth+1); }catch(err){} try{ if(e.tagName==='IFRAME' && e.contentDocument) walk(e.contentDocument,depth+1); }catch(err){} } }
    walk(document,0);
    function score(e){ const tag=e.tagName||''; const role=e.getAttribute('role')||''; const aria=e.getAttribute('aria-label')||''; const ph=e.getAttribute('placeholder')||''; const id=e.id||''; const cls=String(e.className||''); const title=e.getAttribute('title')||''; const hay=(tag+' '+role+' '+aria+' '+ph+' '+id+' '+cls+' '+title+' '+txt(e)).toLowerCase(); let s=0; if(tag==='TEXTAREA')s+=80; if(tag==='INPUT')s+=60; if(e.isContentEditable)s+=70; if(/textbox|searchbox|textarea/.test(role))s+=65; if(/monaco-editor|inputarea|interactive-input|chat-input|composer|prompt-input/.test(hay))s+=55; if(/chat|agent|message|ask|prompt|composer|inline/.test(hay))s+=45; if(/command|quick-input|quickinput/.test(hay))s+=15; const r=rectOf(e); if(r.w>80)s+=8; if(r.h>15)s+=8; if(r.y>250)s+=4; if(e.disabled || e.getAttribute('aria-disabled')==='true' || e.readOnly)s-=80; if(!visible(e))s-=12; return s; }
    function innerEditable(e){ return e.matches && (e.matches('textarea,input,[contenteditable="true"],[role="textbox"],.inputarea,.monaco-editor textarea')) ? e : (e.querySelector && e.querySelector('textarea,input,[contenteditable="true"],[role="textbox"],.inputarea,.monaco-editor textarea')) || e; }
    const ranked = els.filter(e => score(e)>45).sort((a,b)=>score(b)-score(a));
    for(const raw of ranked.slice(0,30)){
      const e = innerEditable(raw);
      try {
        e.scrollIntoView({block:'center',inline:'center'});
        if(e.click) e.click();
        if(e.focus) e.focus();
        if(e.tagName==='TEXTAREA' || e.tagName==='INPUT'){
          const proto = e.tagName==='TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
          const desc = Object.getOwnPropertyDescriptor(proto,'value');
          if(desc && desc.set) desc.set.call(e, ''); else e.value='';
          e.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'deleteContentBackward',data:null}));
        } else if(e.isContentEditable){
          e.textContent='';
          e.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'deleteContentBackward',data:null}));
        }
        const r=rectOf(e);
        return {ok:true, tag:e.tagName, role:e.getAttribute('role')||'', aria:e.getAttribute('aria-label')||'', placeholder:e.getAttribute('placeholder')||'', id:e.id||'', cls:String(e.className||'').slice(0,160), text:txt(e).slice(0,160), score:score(raw), rect:r};
      } catch(err) { }
    }
    return {ok:false, reason:'no-ranked-input', rankedCount:ranked.length};
  })()`;
  const res = await send('Runtime.evaluate',{expression:expr,returnByValue:true,awaitPromise:true});
  const value = res.result.value || {ok:false};
  if(value.ok){
    await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Control',code:'ControlLeft',windowsVirtualKeyCode:17,nativeVirtualKeyCode:17,modifiers:2});
    await key(send,'A','KeyA',65,2);
    await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Control',code:'ControlLeft',windowsVirtualKeyCode:17,nativeVirtualKeyCode:17,modifiers:0});
    await key(send,'Backspace','Backspace',8,0);
    await send('Input.insertText',{text:promptText});
  }
  return value;
}
async function clickSendOrEnter(send){
  const expr = `(() => {
    function rectOf(e){ const r=e.getBoundingClientRect(); return {x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height)}; }
    function visible(e){ try{ const r=e.getBoundingClientRect(); const cs=getComputedStyle(e); return r.width>2 && r.height>2 && cs.display!=='none' && cs.visibility!=='hidden' && cs.opacity!=='0'; }catch(err){return false;} }
    function label(e){ return (e.innerText || e.textContent || e.getAttribute('aria-label') || e.getAttribute('title') || e.id || e.className || '').toString().trim(); }
    const all=[]; function walk(root,depth){ if(!root || depth>5)return; let nodes=[]; try{nodes=Array.from(root.querySelectorAll('*'));}catch(e){return;} for(const e of nodes){ all.push(e); try{if(e.shadowRoot)walk(e.shadowRoot,depth+1);}catch(err){} try{if(e.tagName==='IFRAME'&&e.contentDocument)walk(e.contentDocument,depth+1);}catch(err){} } }
    walk(document,0);
    const buttons=all.filter(e => visible(e) && (e.tagName==='BUTTON' || /button/.test(e.getAttribute('role')||'') || /codicon-send|send|submit/.test(String(e.className||'').toLowerCase()))).map(e => ({e, lab:label(e), hay:(label(e)+' '+(e.getAttribute('aria-label')||'')+' '+(e.getAttribute('title')||'')+' '+String(e.className||'')).toLowerCase(), rect:rectOf(e)}));
    const b = buttons.find(x => /send|submit/.test(x.hay) && !/disabled/.test(x.hay));
    if(b){ b.e.scrollIntoView({block:'center',inline:'center'}); b.e.click(); return {clicked:true, label:b.lab.slice(0,160), rect:b.rect}; }
    return {clicked:false, buttonCount:buttons.length, first:buttons.slice(0,8).map(x=>({label:x.lab.slice(0,80),rect:x.rect}))};
  })()`;
  const res = await send('Runtime.evaluate',{expression:expr,returnByValue:true,awaitPromise:true});
  const v = res.result.value || {clicked:false};
  if(!v.clicked){
    await enter(send,0);
    await sleep(500);
    await enter(send,2);
    v.enterFallback = true;
  }
  return v;
}
async function clickAgentOrChat(send){
  const expr = `(() => {
    function rectOf(e){ const r=e.getBoundingClientRect(); return {x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height)}; }
    function visible(e){ try{ const r=e.getBoundingClientRect(); const cs=getComputedStyle(e); return r.width>2 && r.height>2 && cs.display!=='none' && cs.visibility!=='hidden' && cs.opacity!=='0'; }catch(err){return false;} }
    function label(e){ return (e.innerText || e.textContent || e.getAttribute('aria-label') || e.getAttribute('title') || e.id || e.className || '').toString().trim(); }
    const all=[]; function walk(root,depth){ if(!root || depth>5)return; let nodes=[]; try{nodes=Array.from(root.querySelectorAll('*'));}catch(e){return;} for(const e of nodes){ all.push(e); try{if(e.shadowRoot)walk(e.shadowRoot,depth+1);}catch(err){} try{if(e.tagName==='IFRAME'&&e.contentDocument)walk(e.contentDocument,depth+1);}catch(err){} } }
    walk(document,0);
    const hit=all.filter(e => visible(e)).map(e => ({e, lab:label(e), hay:(label(e)+' '+(e.getAttribute('aria-label')||'')+' '+(e.getAttribute('title')||'')+' '+String(e.className||'')+' '+(e.id||'')).toLowerCase(), rect:rectOf(e)})).find(x => /\b(agent|chat|ask)\b/.test(x.hay) && !/settings|github|terminal/.test(x.hay));
    if(hit){ hit.e.scrollIntoView({block:'center',inline:'center'}); hit.e.click(); return {clicked:true,label:hit.lab.slice(0,160),rect:hit.rect}; }
    return {clicked:false};
  })()`;
  const res = await send('Runtime.evaluate',{expression:expr,returnByValue:true,awaitPromise:true});
  return res.result.value || {clicked:false};
}
async function attempt(send,result,phase){
  const f = await focusBestInput(send,promptText);
  result.actions.push({phase, focus:f});
  if(!f.ok) return false;
  await sleep(800);
  const submit = await clickSendOrEnter(send);
  result.actions[result.actions.length-1].submit = submit;
  result.action.attempted = true;
  result.action.submitted = true;
  result.action.focus = f;
  result.action.submit = submit;
  await sleep(60000);
  const chk = await send('Runtime.evaluate',{expression:`(() => { const body=(document.body?.innerText||''); const inputs=Array.from(document.querySelectorAll('textarea,input,[contenteditable="true"],[role="textbox"]')).map(e=>e.value||e.innerText||e.textContent||'').join('\n'); return {found:body.includes(${JSON.stringify(marker)}), inputStillHas:inputs.includes(${JSON.stringify(marker)}), tail:body.slice(-5000)}; })()`,returnByValue:true,awaitPromise:true});
  result.action.markerFound = !!chk.result.value?.found;
  result.action.inputStillHas = !!chk.result.value?.inputStillHas;
  result.action.tail = short(chk.result.value?.tail || '', 1500);
  return true;
}
async function main(){
  if(!WS) throw new Error('No global WebSocket in this Node runtime');
  const targets = await getJson('http://127.0.0.1:9223/json/list');
  const target = targets.find(t => t.type === 'page' && /Antigravity/i.test(t.title || '') && t.webSocketDebuggerUrl) || targets.find(t => t.type === 'page' && t.webSocketDebuggerUrl);
  const result = { ok:false, marker, promptText, targetSummary: targets.map(t => ({type:t.type,title:short(t.title,100),url:short(t.url,160)})), selectedTarget: target ? {title:target.title,url:target.url,type:target.type} : null, probes:[], actions:[], action:{attempted:false,submitted:false,markerFound:false,inputStillHas:null} };
  if(!target){ fs.writeFileSync(out, JSON.stringify(result,null,2)); return; }
  const {ws,send} = await connect(target.webSocketDebuggerUrl);
  await send('Runtime.enable'); await send('DOM.enable'); await send('Page.enable').catch(()=>{}); await send('Page.bringToFront').catch(()=>{});
  result.ok = true;
  result.probes.push(await probe(send,'initial'));
  let done = await attempt(send,result,'initial');
  if(!done){
    result.openAgentClick = await clickAgentOrChat(send);
    await sleep(3500);
    result.probes.push(await probe(send,'after-click-agent-chat'));
    done = await attempt(send,result,'after-click-agent-chat');
  }
  if(!done){
    await key(send,'F1','F1',112,0);
    await sleep(900);
    await send('Input.insertText',{text:'New Chat'}).catch(()=>{});
    await sleep(400);
    await enter(send,0);
    await sleep(4500);
    result.probes.push(await probe(send,'after-f1-new-chat'));
    done = await attempt(send,result,'after-f1-new-chat');
  }
  if(!done){
    await key(send,'I','KeyI',73,2);
    await sleep(3000);
    result.probes.push(await probe(send,'after-ctrl-i'));
    done = await attempt(send,result,'after-ctrl-i');
  }
  try{ ws.close(); }catch{}
  result.finalProbe = result.probes[result.probes.length-1] || null;
  result.candidates = (result.finalProbe?.candidates || []).slice(0,80).map(c => ({...c, text:redact(c.text), aria:redact(c.aria), placeholder:redact(c.placeholder), title:redact(c.title), id:redact(c.id), cls:redact(c.cls)}));
  result.inputCandidates = (result.finalProbe?.inputCandidates || []).slice(0,40).map(c => ({...c, text:redact(c.text), aria:redact(c.aria), placeholder:redact(c.placeholder), title:redact(c.title), id:redact(c.id), cls:redact(c.cls)}));
  fs.writeFileSync(out, JSON.stringify(result,null,2));
}
main().catch(e => { fs.writeFileSync(out, JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1; });
'@
[IO.File]::WriteAllText($nodeScript,$js,(New-Object Text.UTF8Encoding($false)))
L ('node_probe_script=' + (San $nodeScript))
if($cdp -and (Get-Command node -ErrorAction SilentlyContinue)){
    $ns=$nodeScript; $dj=$domJson; $mk=$marker; $pt=$prompt
    $job=Start-Job -ScriptBlock { node $using:ns $using:dj $using:mk $using:pt 2>&1 | Out-String }
    if(Wait-Job $job -Timeout 240){
        $nodeOut=(Receive-Job $job | Out-String).Trim()
        L ('node_probe_exit=completed')
        foreach($ln in (($nodeOut -split "`r?`n")|Select-Object -First 80)){ if($ln.Trim()){ L ('node| ' + (San $ln)) } }
    } else {
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        L 'node_probe_TIMEOUT=240s'
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
} else {
    L 'node_probe_skipped=no_cdp_or_node'
}
L ('dom_probe_json=' + (San $domJson))
$summaryLines=@('# Antigravity CDP DOM/dialog probe r211','',('DOM JSON: ' + $domJson),('Marker: ' + $marker),'')
$final='CHECK_REPORT'
if(Test-Path -LiteralPath $domJson){
    try{
        $j=Get-Content -LiteralPath $domJson -Raw -Encoding UTF8 | ConvertFrom-Json
        $probeCount=@($j.probes).Count
        $candCount=@($j.candidates).Count
        $inputCount=@($j.inputCandidates).Count
        L ('dom_ok=' + $j.ok + ' probes=' + $probeCount + ' candidates=' + $candCount + ' inputs=' + $inputCount + ' action_attempted=' + $j.action.attempted + ' submitted=' + $j.action.submitted + ' markerFound=' + $j.action.markerFound + ' inputStillHas=' + $j.action.inputStillHas)
        if($j.selectedTarget){ L ('target=' + (San ($j.selectedTarget.title + ' ' + $j.selectedTarget.url))) }
        foreach($a in @($j.actions)){ L ('action| phase=' + (San ([string]$a.phase)) + ' focus_ok=' + $a.focus.ok + ' focus_tag=' + (San ([string]$a.focus.tag)) + ' focus_role=' + (San ([string]$a.focus.role)) + ' submitted=' + ($null -ne $a.submit)) }
        foreach($c in @($j.inputCandidates|Select-Object -First 20)){
            L ('input| score=' + $c.score + ' tag=' + (San ([string]$c.tag)) + ' role=' + (San ([string]$c.role)) + ' aria=' + (San ([string]$c.aria)) + ' placeholder=' + (San ([string]$c.placeholder)) + ' text=' + (San ([string]$c.text)) + ' rect=' + $c.rect.x + ',' + $c.rect.y + ',' + $c.rect.w + 'x' + $c.rect.h + ' visible=' + $c.visible)
        }
        foreach($c in @($j.candidates|Select-Object -First 30)){
            L ('cand| score=' + $c.score + ' tag=' + (San ([string]$c.tag)) + ' role=' + (San ([string]$c.role)) + ' aria=' + (San ([string]$c.aria)) + ' text=' + (San ([string]$c.text)) + ' rect=' + $c.rect.x + ',' + $c.rect.y + ',' + $c.rect.w + 'x' + $c.rect.h + ' visible=' + $c.visible)
        }
        if($j.action.submitted -and $j.action.markerFound){ $final='ANTIGRAVITY_DIALOG_SUBMITTED_MARKER_VISIBLE_CDP' }
        elseif($j.action.attempted){ $final='ANTIGRAVITY_DIALOG_INPUT_ATTEMPTED_CDP' }
        elseif($j.ok){ $final='ANTIGRAVITY_DOM_PROBED_CDP' }
        $summaryLines += ('Final: ' + $final)
        $summaryLines += ('Submitted: ' + $j.action.submitted)
        $summaryLines += ('Marker visible in Antigravity DOM: ' + $j.action.markerFound)
        $summaryLines += ('Input still has marker after submit wait: ' + $j.action.inputStillHas)
        $summaryLines += ('Candidate count copied to repo report: ' + $candCount)
        $summaryLines += ''
        $summaryLines += 'Top input candidates are summarized in the repo report. Full DOM probe JSON stays on E drive.'
    }catch{
        L ('dom_parse_WARN=' + (San $_.Exception.Message))
        $summaryLines += ('Final: ' + $final)
        $summaryLines += ('Parse warning: ' + (San $_.Exception.Message))
    }
} else {
    $summaryLines += ('Final: ' + $final)
    $summaryLines += 'No DOM JSON was produced.'
}
$summaryPath=Join-Path $reports 'antigravity-cdp-dialog-summary-r211.md'
W $summaryPath $summaryLines
try{ Copy-Item -LiteralPath $summaryPath -Destination (Join-Path $outDir 'antigravity-cdp-dialog-summary-r211.md') -Force }catch{}
L ('summary_path=' + (San $summaryPath))
L ('FINAL_R211: ' + $final)
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t168 done ---'
exit 0
