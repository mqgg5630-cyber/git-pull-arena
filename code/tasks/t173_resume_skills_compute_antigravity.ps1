# t173_resume_skills_compute_antigravity.ps1 - round 219.
# Laptop-only: install resume/research/vector/cloud-compute skills on E:, create
# privacy-safe sample resume artifacts, probe Colab/Kaggle reachability, and ask
# Antigravity to run a fake-data capability test. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{24,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[REDACTED-GUID]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Test-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Curl-Probe([string]$Name,[string]$Url) {
    $ce=Join-Path $env:SystemRoot 'System32\curl.exe'
    $fmt='HTTP=%{http_code} time=%{time_total} speed=%{speed_download} url=%{url_effective}'
    try { $txt=(& $ce -L -sS -o NUL --max-time 20 -w $fmt $Url 2>&1 | Out-String).Trim(); return [pscustomobject]@{name=$Name;url=$Url;ok=$true;text=(San $txt)} } catch { return [pscustomobject]@{name=$Name;url=$Url;ok=$false;text=(San $_.Exception.Message)} }
}
function Run-NodeCdp([string]$Script,[string]$OutJson,[string]$Marker,[string]$Prompt,[int]$TimeoutSec) {
    if(-not (Get-Command node -ErrorAction SilentlyContinue)){ return 'NO_NODE' }
    $ns=$Script; $oj=$OutJson; $mk=$Marker; $pt=$Prompt
    $job=Start-Job -ScriptBlock { node $using:ns $using:oj $using:mk $using:pt 2>&1 | Out-String }
    if(Wait-Job $job -Timeout $TimeoutSec){ $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
    Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT'
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$mainReport=Join-Path $outDir 'RESUME_SKILLS_COMPUTE_AGV_R219.md'
L '# Resume skills, compute bridge, and Antigravity capability test r219'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
L 'privacy_scope=laptop_only_no_desktop_resume_test'
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$resumeRoot=Join-Path $lab 'resume-samples'
$computeRoot=Join-Path $lab 'compute-bridge'
$skillsRoot=Join-Path $lab 'agents-skills\skills'
$catalogRoot=Join-Path $lab 'agents-skills'
$agvTestRoot=Join-Path $lab 'antigravity-tests'
foreach($d in @($lab,$reports,$resumeRoot,$computeRoot,$skillsRoot,$agvTestRoot)){ New-Item -ItemType Directory -Force -Path $d | Out-Null }
L ('lab_root=' + $lab)

# 1. Install small wrapper skills on E drive.
$skillDefs=@{
 'resume-cv-builder'=@('# Resume CV Builder Skill','','Purpose: create privacy-safe resumes from user-approved data or fictional samples.','Outputs: Markdown, HTML, editable DOCX, and optional SVG infographic.','Privacy: do not send real personal data to cloud tools unless the user explicitly asks.');
 'cloud-compute-bridge'=@('# Cloud Compute Bridge Skill','','Purpose: connect authorized Colab/Kaggle notebooks with local project files through user-controlled upload/download or API tokens stored outside Git.','Limits: free tiers have quotas, idle timeouts, TOS restrictions, and no guaranteed GPU.','Never store Kaggle tokens, Google cookies, or notebook credentials in Git or public logs.');
 'research-skill-router'=@('# Research Skill Router','','Purpose: route tasks to literature search, citation audit, data cleaning, reproducible report, and figure-generation skills discovered from E:\0mcp-agv.');
 'vector-editable-figure'=@('# Vector Editable Figure Skill','','Purpose: generate SVG-first scientific diagrams that can be edited in Illustrator, Inkscape, WPS, or a browser.','Use SVG as source of truth; export PNG/PDF only as derived artifacts.')
}
foreach($name in $skillDefs.Keys){ $dir=Join-Path $skillsRoot $name; New-Item -ItemType Directory -Force -Path $dir | Out-Null; W (Join-Path $dir 'SKILL.md') $skillDefs[$name]; L ('skill_installed=' + (San $dir)) }

# 2. Search existing skill catalog for resume/research/vector capabilities.
$indexPath=Join-Path $catalogRoot 'skills-index.json'
$hits=@()
if(Test-Path -LiteralPath $indexPath){
    try{
        $idx=Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach($it in @($idx)){
            $hay=([string]$it.name + ' ' + [string]$it.category + ' ' + [string]$it.relative + ' ' + [string]$it.source).ToLowerInvariant()
            if($hay -match 'resume|cv|curriculum|academic|research|citation|paper|thesis|cnki|reference|data|figure|svg|vector|illustrator|diagram|plot'){
                $kind='general'
                if($hay -match 'resume|cv|curriculum'){ $kind='resume' }
                elseif($hay -match 'svg|vector|illustrator|figure|diagram|plot'){ $kind='vector-figure' }
                elseif($hay -match 'academic|research|citation|paper|thesis|cnki|reference|data'){ $kind='research' }
                $hits += [pscustomobject]@{kind=$kind;name=$it.name;category=$it.category;relative=$it.relative;source=$it.source}
            }
        }
    }catch{ L ('skill_index_parse_WARN=' + (San $_.Exception.Message)) }
}
$hitsJson=Join-Path $reports 'resume-research-vector-skill-hits-r219.json'
[IO.File]::WriteAllText($hitsJson, (($hits | ConvertTo-Json -Depth 8) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
L ('skill_hits_count=' + $hits.Count)
foreach($h in ($hits | Select-Object -First 60)){ L ('skill_hit|' + $h.kind + '|' + (San ([string]$h.name)) + '|' + (San ([string]$h.category)) + '|' + (San ([string]$h.relative))) }

# 3. Generate privacy-safe sample resume artifacts on the laptop only.
$py=''
try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
if(-not $py){ try{ $cmd=Get-Command py -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{} }
$gen=Join-Path $repo 'code\tasks\resume_artifacts_generator_r219.py'
L ('python_cmd=' + (San $py))
L ('resume_generator=' + (San $gen) + ' exists=' + (Test-Path -LiteralPath $gen))
$resumeManifestText=''
if($py -and (Test-Path -LiteralPath $gen)){
    try{
        if((Split-Path -Leaf $py) -ieq 'py.exe'){ $resumeManifestText=(& $py -3 $gen --out $resumeRoot 2>&1 | Out-String).Trim() }
        else{ $resumeManifestText=(& $py $gen --out $resumeRoot 2>&1 | Out-String).Trim() }
        L ('resume_generator_out=' + (San $resumeManifestText))
    }catch{ L ('resume_generator_WARN=' + (San $_.Exception.Message)) }
}else{ L 'resume_generator_skipped=no_python_or_script' }
$resumeFiles=@('sample_resume_privacy_safe_r219.md','sample_resume_privacy_safe_r219.html','sample_resume_privacy_safe_r219.docx','sample_resume_vector_editable_r219.svg','research_vector_editable_figure_r219.svg','resume_artifacts_manifest_r219.json') | ForEach-Object { Join-Path $resumeRoot $_ }
foreach($rf in $resumeFiles){ L ('resume_artifact=' + (San $rf) + ' exists=' + (Test-Path -LiteralPath $rf)) }

# 4. Cloud compute bridge docs and network probes. No credentials are used.
$computeReadme=@(
'# Colab and Kaggle compute bridge',
'',
'Purpose: use free Colab/Kaggle resources with explicit user account authorization.',
'',
'Safe modes:',
'1. Manual notebook upload/download for public or non-sensitive projects.',
'2. Kaggle API with kaggle.json stored only under the user profile, never in Git.',
'3. Google Drive/Colab notebooks for GPU experiments where data can be uploaded safely.',
'',
'Limits: free tiers have quotas, idle timeouts, changing GPU availability, and TOS restrictions. Do not use them for private secrets unless you explicitly approve the transfer.',
'',
'Native/local network can be faster for browser/API downloads and for moving large files between local apps; cloud GPU helps when compute is the bottleneck, not when data transfer dominates.'
)
W (Join-Path $computeRoot 'README.md') $computeReadme
$kaggleSetup=@(
'# Kaggle CLI setup template',
'',
'1. Create a Kaggle API token from your Kaggle account settings.',
'2. Save it locally only at %USERPROFILE%\.kaggle\kaggle.json.',
'3. Do not commit or paste the token into chat/logs.',
'4. Test with: kaggle datasets list -s example',
'',
'This task did not request or store any token.'
)
W (Join-Path $computeRoot 'kaggle_cli_setup.md') $kaggleSetup
$nb='{"cells":[{"cell_type":"markdown","metadata":{},"source":["# Colab bridge template\\n","Upload non-sensitive project data or mount Drive after explicit approval.\\n"]},{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["# Example: check GPU and Python environment\\n","import sys, platform\\n","print(sys.version)\\n","print(platform.platform())\\n"]}],"metadata":{"kernelspec":{"display_name":"Python 3","language":"python","name":"python3"}},"nbformat":4,"nbformat_minor":5}'
[IO.File]::WriteAllText((Join-Path $computeRoot 'colab_bridge_template.ipynb'), $nb, (New-Object Text.UTF8Encoding($false)))
$probes=@()
foreach($item in @(
    @{n='colab';u='https://colab.research.google.com/'},
    @{n='kaggle';u='https://www.kaggle.com/'},
    @{n='kaggle_api';u='https://www.kaggle.com/api/v1/datasets/list?search=mnist'},
    @{n='google_storage';u='https://storage.googleapis.com/'}) ){
    $probes += Curl-Probe $item.n $item.u
}
$probeJson=Join-Path $reports 'colab-kaggle-connectivity-r219.json'
[IO.File]::WriteAllText($probeJson, (($probes | ConvertTo-Json -Depth 6) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
foreach($p in $probes){ L ('compute_probe|' + $p.name + '|ok=' + $p.ok + '|' + (San $p.text)) }

# 5. Antigravity capability test using fake data only.
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$cdp=Test-Port 9223 2
if(-not $cdp -and (Test-Path -LiteralPath $agExe)){
    try{ foreach($n in @('language_server','Antigravity')){ taskkill /f /im ($n+'.exe') 2>&1|Out-Null } }catch{}
    Start-Sleep -Seconds 2
    Start-Process -FilePath $agExe -ArgumentList @('--force-renderer-accessibility','--remote-debugging-port=9223')
    Start-Sleep -Seconds 10
    $cdp=Test-Port 9223 8
}
L ('antigravity_cdp_9223=' + $cdp)
$marker='ARENA_AGV_RESUME_SKILL_R219_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$prompt='Use only fictional data. In Chinese, produce a concise resume-improvement and research/vector-skills test note for a fake research data analyst resume. End with this exact marker: ' + $marker
$cdpScript=Join-Path $agvTestRoot 'antigravity-resume-skill-test-r219.cjs'
$agvJson=Join-Path $reports 'antigravity-resume-skill-test-r219.json'
$cdpJs=@'
const fs = require('fs');
const out = process.argv[2]; const marker = process.argv[3]; const promptText = process.argv[4]; const WS = globalThis.WebSocket;
function sleep(ms){ return new Promise(r=>setTimeout(r,ms)); }
async function getJson(url){ const r=await fetch(url); return await r.json(); }
function short(s,n=2400){ s=String(s??''); return s.length>n?s.slice(0,n)+'...':s; }
function connect(url){ return new Promise((resolve,reject)=>{ const ws=new WS(url); let id=0; const pending=new Map(); ws.onmessage=ev=>{ const msg=JSON.parse(ev.data); if(msg.id&&pending.has(msg.id)){ const p=pending.get(msg.id); pending.delete(msg.id); if(msg.error)p.reject(new Error(JSON.stringify(msg.error))); else p.resolve(msg.result); } }; ws.onopen=()=>resolve({ws,send:(method,params={})=>new Promise((resolve,reject)=>{ const mid=++id; pending.set(mid,{resolve,reject}); ws.send(JSON.stringify({id:mid,method,params})); })}); ws.onerror=reject; }); }
async function key(send,key,code,vk,modifiers=0){ await send('Input.dispatchKeyEvent',{type:'keyDown',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers}).catch(()=>{}); await send('Input.dispatchKeyEvent',{type:'keyUp',key,code,windowsVirtualKeyCode:vk,nativeVirtualKeyCode:vk,modifiers}).catch(()=>{}); }
async function main(){
 if(!WS) throw new Error('No WebSocket');
 const targets=await getJson('http://127.0.0.1:9223/json/list');
 const target=targets.find(t=>t.type==='page'&&/Antigravity/i.test(t.title||'')&&t.webSocketDebuggerUrl)||targets.find(t=>t.type==='page'&&t.webSocketDebuggerUrl);
 const result={ok:false,marker,promptText,selectedTarget:target?{title:target.title,url:target.url,type:target.type}:null,inserted:false,submitted:false,markerFound:false,tail:''};
 if(!target){ fs.writeFileSync(out,JSON.stringify(result,null,2)); return; }
 const {ws,send}=await connect(target.webSocketDebuggerUrl); await send('Runtime.enable'); await send('DOM.enable'); await send('Page.bringToFront').catch(()=>{}); result.ok=true;
 const focus=await send('Runtime.evaluate',{expression:`(() => { const e=document.querySelector('[aria-label="Message input"]') || document.querySelector('[role="combobox"][aria-label*="Message"]') || document.querySelector('[contenteditable],textarea,input,[role="textbox"]'); if(!e)return {ok:false}; e.scrollIntoView({block:'center'}); e.click(); e.focus(); const r=e.getBoundingClientRect(); return {ok:true,tag:e.tagName,role:e.getAttribute('role')||'',aria:e.getAttribute('aria-label')||'',rect:{x:r.x,y:r.y,w:r.width,h:r.height}}; })()`,returnByValue:true,awaitPromise:true});
 result.focus=focus.result.value;
 if(result.focus&&result.focus.ok){ await key(send,'A','KeyA',65,2); await key(send,'Backspace','Backspace',8,0); await send('Input.insertText',{text:promptText}); result.inserted=true; await key(send,'Enter','Enter',13,0); await sleep(700); await key(send,'Enter','Enter',13,2); result.submitted=true; await sleep(90000); const chk=await send('Runtime.evaluate',{expression:`(() => { const body=document.body?.innerText||''; return {found:body.includes(${JSON.stringify(marker)}), tail:body.slice(-8000)}; })()`,returnByValue:true,awaitPromise:true}); result.markerFound=!!chk.result.value?.found; result.tail=short(chk.result.value?.tail||'',3000); }
 try{ws.close();}catch{} fs.writeFileSync(out,JSON.stringify(result,null,2));
}
main().catch(e=>{fs.writeFileSync(out,JSON.stringify({ok:false,error:String(e.stack||e)},null,2)); process.exitCode=1;});
'@
[IO.File]::WriteAllText($cdpScript,$cdpJs,(New-Object Text.UTF8Encoding($false)))
$nodeOut=''
if($cdp){ $nodeOut=Run-NodeCdp $cdpScript $agvJson $marker $prompt 150 } else { $nodeOut='SKIPPED_NO_CDP' }
L ('antigravity_node_out=' + (San (($nodeOut -split "`r?`n" | Select-Object -First 12) -join ' | ')))
$agvSummary=@('# Antigravity resume/skills capability test r219','',('JSON: ' + $agvJson),('Marker: ' + $marker),'Fake data only; no real resume personal data was sent.')
$agvFinal='CHECK_REPORT'
if(Test-Path -LiteralPath $agvJson){
    try{ $j=Get-Content -LiteralPath $agvJson -Raw -Encoding UTF8 | ConvertFrom-Json; L ('antigravity_result ok=' + $j.ok + ' inserted=' + $j.inserted + ' submitted=' + $j.submitted + ' markerFound=' + $j.markerFound); $agvSummary += ('Inserted: ' + $j.inserted); $agvSummary += ('Submitted: ' + $j.submitted); $agvSummary += ('Marker found in DOM: ' + $j.markerFound); if($j.submitted -and $j.markerFound){ $agvFinal='ANTIGRAVITY_FAKE_RESUME_SKILL_RESPONSE_MARKER_FOUND' } elseif($j.submitted){ $agvFinal='ANTIGRAVITY_FAKE_RESUME_SKILL_PROMPT_SUBMITTED' } }catch{ L ('antigravity_json_parse_WARN=' + (San $_.Exception.Message)) }
}
W (Join-Path $reports 'antigravity-resume-skill-test-summary-r219.md') $agvSummary
try{ Copy-Item -LiteralPath (Join-Path $reports 'antigravity-resume-skill-test-summary-r219.md') -Destination (Join-Path $outDir 'antigravity-resume-skill-test-summary-r219.md') -Force }catch{}
try{ Copy-Item -LiteralPath $hitsJson -Destination (Join-Path $outDir 'resume-research-vector-skill-hits-r219.json') -Force }catch{}
try{ Copy-Item -LiteralPath $probeJson -Destination (Join-Path $outDir 'colab-kaggle-connectivity-r219.json') -Force }catch{}

# 6. Summary report.
$summary=@(
'# Resume skills / compute bridge / Antigravity r219',
'',
'Privacy: laptop-only for resume artifacts; desktop was not used for this resume task.',
'',
('Lab root: ' + $lab),
('Resume artifacts root: ' + $resumeRoot),
('Compute bridge root: ' + $computeRoot),
('Skill hits JSON: ' + $hitsJson),
('Colab/Kaggle probe JSON: ' + $probeJson),
('Antigravity test JSON: ' + $agvJson),
'',
'## Installed wrapper skills',
'- resume-cv-builder',
'- cloud-compute-bridge',
'- research-skill-router',
'- vector-editable-figure',
'',
'## Resume artifacts',
('- Markdown: ' + (Join-Path $resumeRoot 'sample_resume_privacy_safe_r219.md')),
('- HTML: ' + (Join-Path $resumeRoot 'sample_resume_privacy_safe_r219.html')),
('- DOCX: ' + (Join-Path $resumeRoot 'sample_resume_privacy_safe_r219.docx')),
('- Resume SVG: ' + (Join-Path $resumeRoot 'sample_resume_vector_editable_r219.svg')),
('- Research vector SVG: ' + (Join-Path $resumeRoot 'research_vector_editable_figure_r219.svg')),
'',
'## Antigravity test final',
$agvFinal,
'',
'## Notes',
'- Colab/Kaggle can be connected through authorized notebooks/API tokens, but no credentials were requested or stored.',
'- Native/local network is useful for fast browser/API downloads and moving local files; cloud GPU is useful when compute is the bottleneck.'
)
W (Join-Path $reports 'resume-skills-compute-antigravity-summary-r219.md') $summary
try{ Copy-Item -LiteralPath (Join-Path $reports 'resume-skills-compute-antigravity-summary-r219.md') -Destination (Join-Path $outDir 'resume-skills-compute-antigravity-summary-r219.md') -Force }catch{}
foreach($line in $summary){ L $line }
L ('FINAL_R219: RESUME_SKILLS_COMPUTE_AGV_DONE_' + $agvFinal)
W $mainReport $script:Lines
L ('main_report=' + (San $mainReport))
exit 0
