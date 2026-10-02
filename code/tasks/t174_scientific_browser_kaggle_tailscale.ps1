# t174_scientific_browser_kaggle_tailscale.ps1 - round 220.
# Laptop-only probes: Antigravity test for prior scientific drawing skills,
# browser/Kaggle/WSL login readiness, and Tailscale phone/HPC/desktop guide.
# ASCII-only. No passwords/tokens/cookies are read or printed.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{24,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[REDACTED-GUID]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec) { $job=Start-Job -ScriptBlock $Block; if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function Get-FileInfoSafe([string]$Path) { if(Test-Path -LiteralPath $Path){ $f=Get-Item -LiteralPath $Path; return [pscustomobject]@{exists=$true;path=$Path;bytes=$f.Length} } return [pscustomobject]@{exists=$false;path=$Path;bytes=0} }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'SCIENTIFIC_BROWSER_KAGGLE_TAILSCALE_R220.md'
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$agvRoot='E:\0mcp-agv'
New-Item -ItemType Directory -Force -Path $reports | Out-Null
L '# Scientific drawing, browser/Kaggle, and Tailscale probes r220'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
L 'scope=laptop_only_no_desktop_resume_data'

# 1. Prior drawing skills comparison from real machine artifacts.
$drawRows=@()
$drawRows += [pscustomobject]@{skill='cell-lct';historicalRound='r103 smoke';runner='C:\Users\<user>\.codex\skills\cell-lct\scripts\run_cell_lct.ps1';result='PASS';evidence='2 text frames + 4 paths, AI saved, PNG exported';ai='results\fig1_rebuild\test\cell-lct\test_cell-lct.ai';png='results\fig1_rebuild\test\cell-lct\test_cell-lct.png'}
$drawRows += [pscustomobject]@{skill='cell_su7';historicalRound='r104 smoke, r107 full demo';runner='C:\Users\<user>\.codex\skills\cell_su7\scripts\run_cell_lct.ps1';result='PASS';evidence='2 text frames + 4 paths smoke; full demo launched';ai='results\fig1_rebuild\test\cell_su7\test_cell_su7.ai';png='results\fig1_rebuild\test\cell_su7\test_cell_su7.png'}
$drawRows += [pscustomobject]@{skill='vector-editable-figure';historicalRound='r219 sample';runner='E:\0mcp-agv-arena-optimized\agents-skills\skills\vector-editable-figure\SKILL.md';result='PASS';evidence='editable SVG sample generated';ai='';png='E:\0mcp-agv-arena-optimized\resume-samples\research_vector_editable_figure_r219.svg'}
foreach($r in $drawRows){
    $aiPath=if($r.ai -and $r.ai -match '^results'){ Join-Path $repo $r.ai } else { $r.ai }
    $pngPath=if($r.png -and $r.png -match '^results'){ Join-Path $repo $r.png } else { $r.png }
    $aiInfo=Get-FileInfoSafe $aiPath; $pngInfo=Get-FileInfoSafe $pngPath
    L ('draw_skill|' + $r.skill + '|round=' + $r.historicalRound + '|result=' + $r.result + '|ai_exists=' + $aiInfo.exists + '|ai_bytes=' + $aiInfo.bytes + '|image_exists=' + $pngInfo.exists + '|image_bytes=' + $pngInfo.bytes + '|evidence=' + (San $r.evidence))
}
$drawJson=Join-Path $reports 'scientific-drawing-skill-compare-r220.json'
[IO.File]::WriteAllText($drawJson, (($drawRows | ConvertTo-Json -Depth 8) + "`r`n"), (New-Object Text.UTF8Encoding($false)))

# 2. Antigravity test specifically for these drawing skills.
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
$agvDir=Join-Path $lab 'antigravity-tests'
New-Item -ItemType Directory -Force -Path $agvDir | Out-Null
$marker='ARENA_AGV_DRAW_SKILL_COMPARE_R220_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$prompt='Use only the fake/public evidence listed here. Compare scientific drawing skills cell-lct, cell_su7, vector-editable-figure, nature-figure, scipilot-figure-skill, and smart-illustrator for editable SVG/AI scientific figures. Mention that historical local tests proved cell-lct and cell_su7 with Illustrator AI+PNG outputs. End with exact marker: ' + $marker
$cdpScript=Join-Path $agvDir 'antigravity-draw-skill-compare-r220.cjs'
$agvJson=Join-Path $reports 'antigravity-draw-skill-compare-r220.json'
$js=@'
const fs = require('fs'); const out=process.argv[2], marker=process.argv[3], promptText=process.argv[4]; const WS=globalThis.WebSocket;
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
async function getJson(u){const r=await fetch(u); return await r.json();}
function short(s,n=4000){s=String(s??''); return s.length>n?s.slice(0,n)+'...':s;}
function connect(u){return new Promise((resolve,reject)=>{const ws=new WS(u); let id=0; const pending=new Map(); ws.onmessage=ev=>{const m=JSON.parse(ev.data); if(m.id&&pending.has(m.id)){const p=pending.get(m.id); pending.delete(m.id); if(m.error)p.reject(new Error(JSON.stringify(m.error))); else p.resolve(m.result);}}; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params}));})}); ws.onerror=reject;});}
async function key(send,key,code,vk,modifiers=0){await send('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers}).catch(()=>{}); await send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers}).catch(()=>{});}
async function main(){
 if(!WS) throw new Error('No WebSocket');
 const targets=await getJson('http://127.0.0.1:9223/json/list');
 const target=targets.find(t=>t.type==='page'&&/Antigravity/i.test(t.title||'')&&t.webSocketDebuggerUrl)||targets.find(t=>t.type==='page'&&t.webSocketDebuggerUrl);
 const result={ok:false,marker,selectedTarget:target?{title:target.title,url:target.url,type:target.type}:null,inserted:false,submitted:false,markerFound:false,tail:''};
 if(!target){fs.writeFileSync(out,JSON.stringify(result,null,2)); return;}
 const {ws,send}=await connect(target.webSocketDebuggerUrl); await send('Runtime.enable'); await send('DOM.enable'); await send('Page.bringToFront').catch(()=>{}); result.ok=true;
 const focus=await send('Runtime.evaluate',{expression:`(() => { const e=document.querySelector('[aria-label="Message input"]') || document.querySelector('[role="combobox"][aria-label*="Message"]') || document.querySelector('[contenteditable],textarea,input,[role="textbox"]'); if(!e)return {ok:false}; e.scrollIntoView({block:'center'}); e.click(); e.focus(); return {ok:true,tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||''}; })()`,returnByValue:true,awaitPromise:true});
 result.focus=focus.result.value;
 if(result.focus&&result.focus.ok){await key(send,'A','KeyA',65,2); await key(send,'Backspace','Backspace',8,0); await send('Input.insertText',{text:promptText}); result.inserted=true; await key(send,'Enter','Enter',13,0); await sleep(700); await key(send,'Enter','Enter',13,2); result.submitted=true; await sleep(90000); const chk=await send('Runtime.evaluate',{expression:`(() => { const body=document.body?.innerText||''; return {found:body.includes(${JSON.stringify(marker)}), tail:body.slice(-10000)}; })()`,returnByValue:true,awaitPromise:true}); result.markerFound=!!chk.result.value?.found; result.tail=short(chk.result.value?.tail||'',4000);}
 try{ws.close();}catch{} fs.writeFileSync(out,JSON.stringify(result,null,2));
}
main().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($cdpScript,$js,(New-Object Text.UTF8Encoding($false)))
$nodeOut='SKIP'
if($cdp -and (Get-Command node -ErrorAction SilentlyContinue)){
    $ns=$cdpScript; $oj=$agvJson; $mk=$marker; $pt=$prompt
    $nodeOut=Run-Cap { node $using:ns $using:oj $using:mk $using:pt 2>&1 | Out-String } 160
}
L ('antigravity_draw_node_out=' + (San (($nodeOut -split "`r?`n" | Select-Object -First 8) -join ' | ')))
$agvFinal='CHECK_REPORT'
if(Test-Path -LiteralPath $agvJson){ try{ $j=Get-Content -LiteralPath $agvJson -Raw -Encoding UTF8 | ConvertFrom-Json; L ('antigravity_draw_result ok=' + $j.ok + ' inserted=' + $j.inserted + ' submitted=' + $j.submitted + ' markerFound=' + $j.markerFound); if($j.submitted -and $j.markerFound){$agvFinal='ANTIGRAVITY_DRAW_SKILL_COMPARE_MARKER_FOUND'} elseif($j.submitted){$agvFinal='ANTIGRAVITY_DRAW_SKILL_COMPARE_SUBMITTED'} }catch{ L ('antigravity_draw_parse_WARN=' + (San $_.Exception.Message)) } }

# 3. Browser-control skills and Kaggle CLI/WSL readiness. No credentials printed.
$browserHits=@()
foreach($root in @($agvRoot,$lab)){ if(Test-Path -LiteralPath $root){
    try{ $browserHits += @(Get-ChildItem -LiteralPath $root -Recurse -Depth 6 -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'browser|playwright|selenium|chrome|edge' -or $_.Name -match 'browser|playwright|selenium|chrome|edge' } | Select-Object -First 80 FullName,Length) }catch{}
}}
L ('browser_skill_hit_count=' + $browserHits.Count)
foreach($b in ($browserHits | Select-Object -First 40)){ L ('browser_hit|' + (San $b.FullName)) }
$browserJson=Join-Path $reports 'browser-skill-kaggle-probe-r220.json'

$kaggleRows=@()
$kgCmd=$null; try{ $kgCmd=Get-Command kaggle -ErrorAction SilentlyContinue }catch{}
$kgToken=Join-Path $env:USERPROFILE '.kaggle\kaggle.json'
$kgOut=''
if($kgCmd){ $kgOut=Run-Cap { kaggle datasets list -s mnist 2>&1 | Select-Object -First 25 | Out-String } 45 }
$kaggleRows += [pscustomobject]@{scope='windows';kaggleCommand=[bool]$kgCmd;kagglePath=$(if($kgCmd){$kgCmd.Source}else{''});tokenFileExists=(Test-Path -LiteralPath $kgToken);testOutput=(San $kgOut)}
$wslOut=''; $wslKaggle=''; $wslToken=''; $wslList=''
$wslCmd=$null; try{ $wslCmd=Get-Command wsl.exe -ErrorAction SilentlyContinue }catch{}
if($wslCmd){
    $wslOut=Run-Cap { wsl.exe -l -v 2>&1 | Out-String } 30
    $wslKaggle=Run-Cap { wsl.exe bash -lc 'command -v kaggle || true' 2>&1 | Out-String } 30
    $wslToken=Run-Cap { wsl.exe bash -lc 'if [ -f "$HOME/.kaggle/kaggle.json" ]; then echo token_file_exists=true; else echo token_file_exists=false; fi' 2>&1 | Out-String } 30
    $wslList=Run-Cap { wsl.exe bash -lc 'if command -v kaggle >/dev/null 2>&1; then kaggle datasets list -s mnist 2>&1 | head -25; else echo kaggle_command_missing; fi' 2>&1 | Out-String } 60
}
$kaggleRows += [pscustomobject]@{scope='wsl';wslCommand=[bool]$wslCmd;distros=(San $wslOut);kagglePath=(San $wslKaggle);tokenStatus=(San $wslToken);testOutput=(San $wslList)}
[IO.File]::WriteAllText($browserJson, ([pscustomobject]@{browserHits=$browserHits;kaggle=$kaggleRows} | ConvertTo-Json -Depth 8) + "`r`n", (New-Object Text.UTF8Encoding($false)))
foreach($k in $kaggleRows){ L ('kaggle_probe|' + $k.scope + '|cmd=' + $k.kaggleCommand + '|tokenOrStatus=' + (San ([string]$(if($k.scope -eq 'windows'){$k.tokenFileExists}else{$k.tokenStatus}))) + '|out=' + (San ([string]$k.testOutput))) }
L ('wsl_distros=' + (San $wslOut))

# 4. Tailscale probes and phone guide.
$tsCandidates=@('E:\Tailscale\tailscale.exe','C:\Program Files\Tailscale\tailscale.exe','C:\Program Files (x86)\Tailscale\tailscale.exe')
$tsExe=''
foreach($c in $tsCandidates){ if(Test-Path -LiteralPath $c){ $tsExe=$c; break } }
if(-not $tsExe){ try{ $cmd=Get-Command tailscale -ErrorAction SilentlyContinue; if($cmd){$tsExe=$cmd.Source} }catch{} }
L ('tailscale_exe=' + (San $tsExe))
$tsIp=''; $tsStatus=''; $tsDesktopPing=''; $hpcProbe=''
if($tsExe){
    $t=$tsExe
    $tsIp=Run-Cap { & $using:t ip -4 2>&1 | Out-String } 20
    $tsStatus=Run-Cap { & $using:t status 2>&1 | Select-Object -First 80 | Out-String } 30
    $tsDesktopPing=Run-Cap { & $using:t ping 100.84.137.117 2>&1 | Out-String } 35
    $hpcProbe=Run-Cap { Test-NetConnection 10.10.5.210 -Port 22 -InformationLevel Detailed 2>&1 | Out-String } 35
}
L ('tailscale_ip4=' + (San $tsIp))
L ('tailscale_status_head=' + (San (($tsStatus -split "`r?`n" | Select-Object -First 20) -join ' | ')))
L ('tailscale_ping_desktop=' + (San (($tsDesktopPing -split "`r?`n" | Select-Object -First 20) -join ' | ')))
L ('hpc_ssh_probe=' + (San (($hpcProbe -split "`r?`n" | Select-Object -First 20) -join ' | ')))
$tsJson=Join-Path $reports 'tailscale-phone-hpc-probe-r220.json'
[IO.File]::WriteAllText($tsJson, ([pscustomobject]@{tailscaleExe=$tsExe;ip4=(San $tsIp);statusHead=(San $tsStatus);desktopPing=(San $tsDesktopPing);hpcSshProbe=(San $hpcProbe)} | ConvertTo-Json -Depth 8) + "`r`n", (New-Object Text.UTF8Encoding($false)))
$guide=@(
'# Phone Tailscale guide r220',
'',
'Goal: phone can reach laptop, desktop, and HPC through the same tailnet.',
'',
'1. Install Tailscale on iOS/Android and sign in with the same tailnet account.',
'2. In https://login.tailscale.com/admin/machines, approve the phone if approval is required.',
'3. Keep MagicDNS enabled. Use the Tailscale app to confirm the phone shows online.',
'4. Laptop tailnet: run tailscale status and tailscale ip -4 on the laptop. This task recorded the current status in tailscale-phone-hpc-probe-r220.json.',
'5. Desktop access: use the desktop tailnet IP 100.84.137.117. For RDP from phone, use Microsoft Remote Desktop to 100.84.137.117. For SSH, use Termius/Blink/JuiceSSH if sshd is enabled.',
'6. HPC access: historical route is 10.10.5.210/32. A subnet router must advertise this route and the admin console must approve it. Then phone SSH apps can connect to ssh user@10.10.5.210.',
'7. If HPC does not work from phone, check: route approved in admin console, subnet router online, ACL permits phone -> 10.10.5.210:22, and phone Tailscale is connected.',
'8. For stable devices, optionally disable key expiry in the admin console for laptop/desktop/HPC route machines.',
'',
'Notes: mobile OS background limits may prevent other machines from reliably initiating long inbound sessions to the phone, but the phone can initiate sessions to desktop/HPC when Tailscale is connected.'
)
W (Join-Path $reports 'phone-tailscale-desktop-hpc-guide-r220.md') $guide

# 5. Combined summary.
$summary=@(
'# R220 summary',
'',
('Drawing compare JSON: ' + $drawJson),
('Antigravity drawing test JSON: ' + $agvJson),
('Browser/Kaggle probe JSON: ' + $browserJson),
('Tailscale probe JSON: ' + $tsJson),
('Phone guide: ' + (Join-Path $reports 'phone-tailscale-desktop-hpc-guide-r220.md')),
'',
('Antigravity drawing final: ' + $agvFinal),
'',
'Kaggle note: existing CLI/browser sessions can be used, but passwords, cookies, and API tokens were not read or printed.',
'Tailscale note: phone setup requires signing in on the phone and approving subnet routes in the admin console if HPC access is desired.'
)
W (Join-Path $reports 'scientific-browser-kaggle-tailscale-summary-r220.md') $summary
foreach($p in @($drawJson,$agvJson,$browserJson,$tsJson,(Join-Path $reports 'phone-tailscale-desktop-hpc-guide-r220.md'),(Join-Path $reports 'scientific-browser-kaggle-tailscale-summary-r220.md'))){ try{ Copy-Item -LiteralPath $p -Destination (Join-Path $outDir (Split-Path $p -Leaf)) -Force }catch{} }
foreach($line in $summary){ L $line }
L ('FINAL_R220: SCIENTIFIC_BROWSER_KAGGLE_TAILSCALE_DONE_' + $agvFinal)
W $report $script:Lines
L ('main_report=' + (San $report))
exit 0
