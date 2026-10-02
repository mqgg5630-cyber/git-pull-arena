# t169_antigravity_cdp_targeted_message_input.ps1 - round 212.
# Target Antigravity's visible "Message input" combobox found in r211, prove
# real text insertion before submitting, and save the result paths. ASCII-only.

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
$report=Join-Path $outDir 'ANTIGRAVITY_CDP_TARGETED_MESSAGE_INPUT_R212.md'
L '--- task t169: Antigravity CDP targeted message input ---'
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
$nodeScript=Join-Path $suite 'antigravity-cdp-targeted-message-input-r212.cjs'
$jsonPath=Join-Path $reports 'antigravity-cdp-targeted-message-input-r212.json'
$marker='ARENA_AGV_TARGETED_INPUT_R212_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$prompt='Reply exactly with this marker and no extra words: ' + $marker
$js=@'
const fs = require('fs');
const out = process.argv[2];
const marker = process.argv[3];
const promptText = process.argv[4];
const WS = globalThis.WebSocket;
function sleep(ms){ return new Promise(r => setTimeout(r, ms)); }
async function getJson(url){ const r = await fetch(url); return await r.json(); }
function short(s,n=500){ s=String(s??''); return s.length>n ? s.slice(0,n)+'...' : s; }
function redact(s){ return String(s??'').replace(/[A-Za-z0-9+/_=-]{20,}/g,'[REDACTED]').replace(/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/g,'[REDACTED-GUID]'); }
function connect(wsUrl){
  return new Promise((resolve,reject)=>{
    const ws = new WS(wsUrl); let id=0; const pending=new Map();
    ws.onmessage = ev => { const msg=JSON.parse(ev.data); if(msg.id && pending.has(msg.id)){ const p=pending.get(msg.id); pending.delete(msg.id); if(msg.error) p.reject(new Error(JSON.stringify(msg.error))); else p.resolve(msg.result); } };
    ws.onopen = () => resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{ const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params})); })});
    ws.onerror = reject;
  });
}
async function key(send,key,code,vk,modifiers=0){
  await send('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers});
  await send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers});
}
async function mouseClick(send,x,y){
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x,y,button:'none'}).catch(()=>{});
  await send('Input.dispatchMouseEvent',{type:'mousePressed',x,y,button:'left',clickCount:1});
  await send('Input.dispatchMouseEvent',{type:'mouseReleased',x,y,button:'left',clickCount:1});
}
async function evalVal(send,expression){ const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true}); return r.result.value; }
const inspectExpr = `(() => {
  function rectOf(e){ try{ const r=e.getBoundingClientRect(); return {x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height),cx:Math.round(r.x+r.width/2),cy:Math.round(r.y+r.height/2)}; }catch(err){ return null; } }
  function label(e){ try{ return (e.innerText || e.textContent || e.value || e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.getAttribute('title') || '').toString(); }catch(err){ return ''; } }
  function visible(e){ try{ const r=e.getBoundingClientRect(); const cs=getComputedStyle(e); return r.width>2 && r.height>2 && cs.display!=='none' && cs.visibility!=='hidden' && cs.opacity!=='0'; }catch(err){ return false; } }
  const bases = Array.from(document.querySelectorAll('[aria-label="Message input"], [role="combobox"][aria-label*="Message"], [aria-label*="Ask anything"], [placeholder*="Ask"], [placeholder*="Message"], [contenteditable], textarea, input, [role="textbox"]'));
  function describe(e, idx){ return {idx, tag:e.tagName, role:e.getAttribute('role')||'', aria:e.getAttribute('aria-label')||'', placeholder:e.getAttribute('placeholder')||'', contentEditable:e.getAttribute('contenteditable')||'', isContentEditable:!!e.isContentEditable, id:e.id||'', cls:String(e.className||'').slice(0,220), text:label(e).slice(0,260), rect:rectOf(e), visible:visible(e), outerHTML:String(e.outerHTML||'').slice(0,1400)}; }
  const described = bases.map(describe);
  const primary = bases.find(e => (e.getAttribute('aria-label')||'') === 'Message input') || bases.find(e => /ask|message/i.test(label(e)+' '+(e.getAttribute('aria-label')||'')+' '+(e.getAttribute('placeholder')||''))) || bases[0] || null;
  let children=[];
  if(primary){ children=Array.from(primary.querySelectorAll('[contenteditable],textarea,input,[role="textbox"],div,span,p,br')).slice(0,80).map(describe); }
  return {title:document.title,url:location.href,bodyHasMarker:(document.body?.innerText||'').includes(${JSON.stringify(marker)}),bodyTail:(document.body?.innerText||'').slice(-3000),primary: primary ? describe(primary, -1) : null, bases:described.slice(0,80), children};
})()`;
function readExpr(label){ return `(() => {
  const marker=${JSON.stringify(marker)};
  function txt(e){ try { return (e.value || e.innerText || e.textContent || '').toString(); } catch(err){ return ''; } }
  function deepActive(){ let a=document.activeElement; try{ while(a && a.shadowRoot && a.shadowRoot.activeElement) a=a.shadowRoot.activeElement; }catch(err){} return a; }
  const primary = document.querySelector('[aria-label="Message input"]') || document.querySelector('[role="combobox"][aria-label*="Message"]') || document.querySelector('[contenteditable],textarea,input,[role="textbox"]');
  const edits = Array.from(document.querySelectorAll('[contenteditable],textarea,input,[role="textbox"],[aria-label="Message input"],[role="combobox"]')).map((e,i)=>({i,tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||'',contentEditable:e.getAttribute('contenteditable')||'',text:txt(e).slice(0,600),hasMarker:txt(e).includes(marker)})).filter(x => x.text || x.aria || x.role);
  const body=(document.body?.innerText||'');
  const a=deepActive();
  return {label:${JSON.stringify(label)}, bodyHasMarker:body.includes(marker), bodyTail:body.slice(-3500), primaryText: primary ? txt(primary).slice(0,1000) : '', primaryHasMarker: primary ? txt(primary).includes(marker) : false, active: a ? {tag:a.tagName,role:a.getAttribute('role')||'',aria:a.getAttribute('aria-label')||'',contentEditable:a.getAttribute('contenteditable')||'',text:txt(a).slice(0,300)} : null, edits};
})()`; }
async function targetRect(send){
  const v = await evalVal(send, `(() => { const e=document.querySelector('[aria-label="Message input"]') || document.querySelector('[role="combobox"][aria-label*="Message"]') || document.querySelector('[contenteditable],textarea,input,[role="textbox"]'); if(!e)return null; const r=e.getBoundingClientRect(); return {x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height),cx:Math.round(r.x+r.width/2),cy:Math.round(r.y+r.height/2),tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||''}; })()`);
  return v;
}
async function focusRuntime(send){
  return await evalVal(send, `(() => {
    const e=document.querySelector('[aria-label="Message input"]') || document.querySelector('[role="combobox"][aria-label*="Message"]') || document.querySelector('[contenteditable],textarea,input,[role="textbox"]');
    if(!e)return {ok:false,reason:'not-found'};
    try{e.scrollIntoView({block:'center',inline:'center'});}catch(err){}
    try{e.click();}catch(err){}
    try{e.focus();}catch(err){}
    return {ok:true,tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||'',contentEditable:e.getAttribute('contenteditable')||'',isContentEditable:!!e.isContentEditable};
  })()`);
}
async function clearFocused(send){
  await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Control',code:'ControlLeft',windowsVirtualKeyCode:17,nativeVirtualKeyCode:17,modifiers:2}).catch(()=>{});
  await key(send,'A','KeyA',65,2).catch(()=>{});
  await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Control',code:'ControlLeft',windowsVirtualKeyCode:17,nativeVirtualKeyCode:17,modifiers:0}).catch(()=>{});
  await key(send,'Backspace','Backspace',8,0).catch(()=>{});
}
async function insertStrategy(send,name){
  if(name==='cdp-insertText'){
    await clearFocused(send);
    await send('Input.insertText',{text:promptText});
    return {ok:true};
  }
  if(name==='execCommand'){
    return await evalVal(send, `(() => { const t=${JSON.stringify(promptText)}; let ok=false; try{ ok=document.execCommand('insertText', false, t); }catch(err){ return {ok:false,error:String(err)}; } return {ok}; })()`);
  }
  if(name==='contenteditable-events'){
    return await evalVal(send, `(() => {
      const t=${JSON.stringify(promptText)};
      const e=document.querySelector('[aria-label="Message input"]') || document.querySelector('[role="combobox"][aria-label*="Message"]') || document.querySelector('[contenteditable],textarea,input,[role="textbox"]');
      if(!e)return {ok:false,reason:'not-found'};
      try{e.focus();}catch(err){}
      const target=(e.matches && e.matches('textarea,input,[contenteditable],[role="textbox"]')) ? e : (e.querySelector && e.querySelector('[contenteditable],textarea,input,[role="textbox"]')) || e;
      try{
        if(target.tagName==='TEXTAREA' || target.tagName==='INPUT'){
          const proto = target.tagName==='TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
          const desc = Object.getOwnPropertyDescriptor(proto,'value');
          if(desc && desc.set) desc.set.call(target,t); else target.value=t;
        } else {
          target.textContent=t;
        }
        target.dispatchEvent(new InputEvent('beforeinput',{bubbles:true,cancelable:true,inputType:'insertText',data:t}));
        target.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:t}));
        target.dispatchEvent(new Event('change',{bubbles:true}));
        return {ok:true,tag:target.tagName,role:target.getAttribute('role')||'',contentEditable:target.getAttribute('contenteditable')||'',text:(target.value||target.innerText||target.textContent||'').slice(0,300)};
      }catch(err){ return {ok:false,error:String(err)}; }
    })()`);
  }
  if(name==='paste-event'){
    return await evalVal(send, `(() => {
      const t=${JSON.stringify(promptText)};
      const e=document.querySelector('[aria-label="Message input"]') || document.querySelector('[role="combobox"][aria-label*="Message"]') || document.querySelector('[contenteditable],textarea,input,[role="textbox"]');
      if(!e)return {ok:false,reason:'not-found'};
      try{e.focus();}catch(err){}
      try{
        const dt = new DataTransfer(); dt.setData('text/plain', t);
        const ev = new ClipboardEvent('paste', {bubbles:true,cancelable:true,clipboardData:dt});
        const dispatched=e.dispatchEvent(ev);
        return {ok:true,dispatched,defaultPrevented:ev.defaultPrevented};
      }catch(err){ return {ok:false,error:String(err)}; }
    })()`);
  }
  return {ok:false,reason:'unknown'};
}
async function clickSendOrSubmit(send){
  const click = await evalVal(send, `(() => {
    function vis(e){ try{ const r=e.getBoundingClientRect(); const cs=getComputedStyle(e); return r.width>2 && r.height>2 && cs.display!=='none' && cs.visibility!=='hidden' && cs.opacity!=='0'; }catch(err){return false;} }
    function lab(e){ return (e.innerText || e.textContent || e.getAttribute('aria-label') || e.getAttribute('title') || e.id || e.className || '').toString(); }
    const buttons=Array.from(document.querySelectorAll('button,[role="button"],a')).filter(vis).map(e=>({e,hay:(lab(e)+' '+(e.getAttribute('aria-label')||'')+' '+(e.getAttribute('title')||'')+' '+String(e.className||'')).toLowerCase(),label:lab(e)}));
    const b=buttons.find(x => /send|submit/.test(x.hay) && !/disabled/.test(x.hay));
    if(b){ try{b.e.click();}catch(err){return {clicked:false,error:String(err),label:b.label.slice(0,200)}}; return {clicked:true,label:b.label.slice(0,200)}; }
    return {clicked:false,buttons:buttons.slice(0,12).map(x=>x.label.slice(0,100))};
  })()`);
  if(!click.clicked){
    await key(send,'Enter','Enter',13,0);
    await sleep(500);
    await key(send,'Enter','Enter',13,2);
    click.enterFallback=true;
  }
  return click;
}
async function main(){
  if(!WS) throw new Error('No global WebSocket in Node');
  const targets=await getJson('http://127.0.0.1:9223/json/list');
  const target=targets.find(t => t.type==='page' && /Antigravity/i.test(t.title||'') && t.webSocketDebuggerUrl) || targets.find(t => t.type==='page' && t.webSocketDebuggerUrl);
  const result={ok:false,marker,promptText,targetSummary:targets.map(t=>({type:t.type,title:t.title,url:t.url})),selectedTarget:target?{type:target.type,title:target.title,url:target.url}:null,steps:[],inserted:false,submitted:false,markerAfterSubmit:false,inputStillHasAfterSubmit:null};
  if(!target){ fs.writeFileSync(out,JSON.stringify(result,null,2)); return; }
  const {ws,send}=await connect(target.webSocketDebuggerUrl);
  await send('Runtime.enable'); await send('DOM.enable'); await send('Page.enable').catch(()=>{}); await send('Page.bringToFront').catch(()=>{});
  result.ok=true;
  result.inspect=await evalVal(send,inspectExpr);
  let rect=await targetRect(send); result.targetRect=rect;
  if(rect && Number.isFinite(rect.cx)){ await mouseClick(send,rect.cx,rect.cy); await sleep(700); }
  result.focusRuntime=await focusRuntime(send);
  const strategies=['cdp-insertText','execCommand','contenteditable-events','paste-event'];
  for(const name of strategies){
    const before=await evalVal(send,readExpr('before-'+name));
    const res=await insertStrategy(send,name);
    await sleep(900);
    const after=await evalVal(send,readExpr('after-'+name));
    result.steps.push({name,before:{bodyHasMarker:before.bodyHasMarker,primaryHasMarker:before.primaryHasMarker,active:before.active},res,after:{bodyHasMarker:after.bodyHasMarker,primaryHasMarker:after.primaryHasMarker,primaryText:short(after.primaryText,500),active:after.active,edits:after.edits.slice(0,20)}});
    if(after.bodyHasMarker || after.primaryHasMarker || after.edits.some(e => e.hasMarker)) { result.inserted=true; result.insertedBy=name; break; }
    if(rect && Number.isFinite(rect.cx)){ await mouseClick(send,rect.cx,rect.cy); await sleep(400); }
  }
  result.preSubmitRead=await evalVal(send,readExpr('pre-submit'));
  if(result.inserted){
    result.submitResult=await clickSendOrSubmit(send);
    result.submitted=true;
    await sleep(90000);
    const post=await evalVal(send,readExpr('post-submit-90s'));
    result.postSubmitRead={bodyHasMarker:post.bodyHasMarker,primaryHasMarker:post.primaryHasMarker,inputStillHas:post.edits.some(e => e.hasMarker),bodyTail:short(redact(post.bodyTail),2000),active:post.active,edits:post.edits.slice(0,20)};
    result.markerAfterSubmit=!!post.bodyHasMarker;
    result.inputStillHasAfterSubmit=!!result.postSubmitRead.inputStillHas;
  }
  try{ ws.close(); }catch{}
  if(result.inspect){
    result.inspect.bodyTail=short(redact(result.inspect.bodyTail),1500);
    if(result.inspect.primary){ result.inspect.primary.outerHTML=short(redact(result.inspect.primary.outerHTML),900); result.inspect.primary.text=short(redact(result.inspect.primary.text),260); }
    result.inspect.bases=(result.inspect.bases||[]).slice(0,30).map(x=>({...x,outerHTML:short(redact(x.outerHTML),500),text:short(redact(x.text),220),aria:short(redact(x.aria),220),placeholder:short(redact(x.placeholder),220),cls:short(redact(x.cls),220)}));
    result.inspect.children=(result.inspect.children||[]).slice(0,40).map(x=>({...x,outerHTML:short(redact(x.outerHTML),400),text:short(redact(x.text),220),aria:short(redact(x.aria),220),placeholder:short(redact(x.placeholder),220),cls:short(redact(x.cls),220)}));
  }
  fs.writeFileSync(out,JSON.stringify(result,null,2));
}
main().catch(e => { fs.writeFileSync(out, JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1; });
'@
[IO.File]::WriteAllText($nodeScript,$js,(New-Object Text.UTF8Encoding($false)))
L ('node_script=' + (San $nodeScript))
if($cdp -and (Get-Command node -ErrorAction SilentlyContinue)){
    $ns=$nodeScript; $jp=$jsonPath; $mk=$marker; $pt=$prompt
    $job=Start-Job -ScriptBlock { node $using:ns $using:jp $using:mk $using:pt 2>&1 | Out-String }
    if(Wait-Job $job -Timeout 260){
        $nodeOut=(Receive-Job $job | Out-String).Trim()
        L 'node_exit=completed'
        foreach($ln in (($nodeOut -split "`r?`n")|Select-Object -First 80)){ if($ln.Trim()){ L ('node| ' + (San $ln)) } }
    } else {
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        L 'node_TIMEOUT=260s'
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
} else {
    L 'node_skipped=no_cdp_or_node'
}
L ('json_path=' + (San $jsonPath))
$summary=@('# Antigravity CDP targeted message input r212','',('JSON: ' + $jsonPath),('Marker: ' + $marker),'')
$final='CHECK_REPORT'
if(Test-Path -LiteralPath $jsonPath){
    try{
        $j=Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        L ('ok=' + $j.ok + ' inserted=' + $j.inserted + ' insertedBy=' + (San ([string]$j.insertedBy)) + ' submitted=' + $j.submitted + ' markerAfterSubmit=' + $j.markerAfterSubmit + ' inputStillHasAfterSubmit=' + $j.inputStillHasAfterSubmit)
        if($j.selectedTarget){ L ('target=' + (San ($j.selectedTarget.title + ' ' + $j.selectedTarget.url))) }
        if($j.targetRect){ L ('target_rect=' + $j.targetRect.x + ',' + $j.targetRect.y + ',' + $j.targetRect.w + 'x' + $j.targetRect.h + ' tag=' + (San ([string]$j.targetRect.tag)) + ' role=' + (San ([string]$j.targetRect.role)) + ' aria=' + (San ([string]$j.targetRect.aria))) }
        if($j.inspect.primary){ L ('primary=' + (San ($j.inspect.primary.tag + ' role=' + $j.inspect.primary.role + ' aria=' + $j.inspect.primary.aria + ' contentEditable=' + $j.inspect.primary.contentEditable + ' isCE=' + $j.inspect.primary.isContentEditable + ' text=' + $j.inspect.primary.text))) }
        foreach($s in @($j.steps)){
            L ('step| ' + (San ([string]$s.name)) + ' after_body=' + $s.after.bodyHasMarker + ' after_primary=' + $s.after.primaryHasMarker + ' res=' + (San (($s.res | ConvertTo-Json -Compress -Depth 4))))
        }
        foreach($b in @($j.inspect.bases|Select-Object -First 15)){
            L ('base| tag=' + (San ([string]$b.tag)) + ' role=' + (San ([string]$b.role)) + ' aria=' + (San ([string]$b.aria)) + ' ce=' + (San ([string]$b.contentEditable)) + ' isCE=' + $b.isContentEditable + ' text=' + (San ([string]$b.text)) + ' rect=' + $b.rect.x + ',' + $b.rect.y + ',' + $b.rect.w + 'x' + $b.rect.h + ' visible=' + $b.visible)
        }
        foreach($ch in @($j.inspect.children|Select-Object -First 20)){
            L ('child| tag=' + (San ([string]$ch.tag)) + ' role=' + (San ([string]$ch.role)) + ' aria=' + (San ([string]$ch.aria)) + ' ce=' + (San ([string]$ch.contentEditable)) + ' isCE=' + $ch.isContentEditable + ' text=' + (San ([string]$ch.text)) + ' rect=' + $ch.rect.x + ',' + $ch.rect.y + ',' + $ch.rect.w + 'x' + $ch.rect.h + ' visible=' + $ch.visible)
        }
        if($j.inserted -and $j.submitted -and $j.markerAfterSubmit){ $final='ANTIGRAVITY_MESSAGE_INSERTED_SUBMITTED_MARKER_VISIBLE' }
        elseif($j.inserted -and $j.submitted){ $final='ANTIGRAVITY_MESSAGE_INSERTED_AND_SUBMITTED_NOT_VISIBLE_AFTER_WAIT' }
        elseif($j.inserted){ $final='ANTIGRAVITY_MESSAGE_INSERTED_NOT_SUBMITTED' }
        elseif($j.ok){ $final='ANTIGRAVITY_MESSAGE_INPUT_TARGETED_NOT_INSERTED' }
        $summary += ('Final: ' + $final)
        $summary += ('Inserted: ' + $j.inserted)
        $summary += ('Inserted by: ' + $j.insertedBy)
        $summary += ('Submitted: ' + $j.submitted)
        $summary += ('Marker visible after submit: ' + $j.markerAfterSubmit)
        $summary += ('Input still has marker after submit wait: ' + $j.inputStillHasAfterSubmit)
        $summary += 'Full targeted probe JSON remains on E drive.'
    }catch{
        L ('parse_WARN=' + (San $_.Exception.Message))
        $summary += ('Final: ' + $final)
        $summary += ('Parse warning: ' + (San $_.Exception.Message))
    }
} else {
    $summary += ('Final: ' + $final)
    $summary += 'No JSON produced.'
}
$summaryPath=Join-Path $reports 'antigravity-cdp-targeted-message-input-summary-r212.md'
W $summaryPath $summary
try{ Copy-Item -LiteralPath $summaryPath -Destination (Join-Path $outDir 'antigravity-cdp-targeted-message-input-summary-r212.md') -Force }catch{}
L ('summary_path=' + (San $summaryPath))
L ('FINAL_R212: ' + $final)
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t169 done ---'
exit 0
