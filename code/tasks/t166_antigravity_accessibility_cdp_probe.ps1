# t166_antigravity_accessibility_cdp_probe.ps1 - round 209.
# Relaunch Antigravity with Electron accessibility/CDP flags and probe whether
# its UI can be controlled by UIA or Chrome DevTools Protocol. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function Invoke-Curl([string[]]$CurlArgs) { try { $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce @CurlArgs 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message } }
function Invoke-Wcu([string]$Backend,[string]$Action,[object]$Payload,[int]$TimeoutMs=60000){
    $json=($Payload|ConvertTo-Json -Depth 30 -Compress)
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $psi.Arguments='-STA -NoProfile -ExecutionPolicy Bypass -File "' + $Backend + '" -Action ' + $Action
    $psi.UseShellExecute=$false; $psi.RedirectStandardInput=$true; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
    $psi.StandardOutputEncoding=[Text.Encoding]::UTF8; $psi.StandardErrorEncoding=[Text.Encoding]::UTF8
    $p=[Diagnostics.Process]::Start($psi); $p.StandardInput.Write($json); $p.StandardInput.Close()
    if(-not $p.WaitForExit($TimeoutMs)){ try{$p.Kill()}catch{}; return @{ok=$false;error='TIMEOUT'} }
    $out=$p.StandardOutput.ReadToEnd().Trim(); $err=$p.StandardError.ReadToEnd().Trim(); if($err){ L ('wcu_stderr_' + $Action + '=' + (San (($err -split "`r?`n")[-1]))) }
    try{ return ($out|ConvertFrom-Json) }catch{ return @{ok=$false;raw=$out;parseError=$_.Exception.Message} }
}
function CountTypes($node, [hashtable]$h){ if($null -eq $node){return}; $t=[string]$node.controlType; if($t){ if(-not $h.ContainsKey($t)){$h[$t]=0}; $h[$t]++ }; foreach($c in @($node.children)){ CountTypes $c $h } }
function CollectCandidates($node, [System.Collections.ArrayList]$rows){ if($null -eq $node -or $rows.Count -ge 120){return}; $name=[string]$node.name; $type=[string]$node.controlType; $cls=[string]$node.className; if(($name -match 'chat|agent|message|ask|prompt|composer|input|send|new|mcp|tool|model') -or ($type -match 'Edit|Document|Button|Text|Pane')){ [void]$rows.Add([ordered]@{id=$node.id; depth=$node.depth; type=$type; name=$name; class=$cls; box=$node.boundingBox}) }; foreach($c in @($node.children)){ CollectCandidates $c $rows } }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'ANTIGRAVITY_ACCESSIBILITY_CDP_PROBE_R209.md'
L '--- task t166: Antigravity accessibility/CDP probe ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
New-Item -ItemType Directory -Force -Path $reports | Out-Null
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$backend=Join-Path $lab 'github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
L ('antigravity_exe_exists=' + (Test-Path -LiteralPath $agExe))
L ('wcu_backend_exists=' + (Test-Path -LiteralPath $backend))
L ('bridge_18088=' + (Wait-Port 18088 2))
if(Test-Path -LiteralPath $agExe){
    try{ foreach($n in @('language_server','Antigravity')){ taskkill /f /im ($n+'.exe') 2>&1|Out-Null } }catch{}
    Start-Sleep -Seconds 2
    $args=@('--force-renderer-accessibility','--remote-debugging-port=9223')
    try{ Start-Process -FilePath $agExe -ArgumentList $args; L ('antigravity_relaunch_flags=' + ($args -join ' ')) }catch{ L ('antigravity_relaunch_WARN=' + (San $_.Exception.Message)) }
    Start-Sleep -Seconds 10
}
$cdpListen=Wait-Port 9223 5
L ('cdp_9223_listening=' + $cdpListen)
if($cdpListen){
    $ver=Invoke-Curl -CurlArgs @('-sS','--max-time','5','http://127.0.0.1:9223/json/version')
    $lst=Invoke-Curl -CurlArgs @('-sS','--max-time','5','http://127.0.0.1:9223/json/list')
    [IO.File]::WriteAllText((Join-Path $reports 'antigravity-cdp-version-r209.json'), $ver + "`r`n", (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $reports 'antigravity-cdp-list-r209.json'), $lst + "`r`n", (New-Object Text.UTF8Encoding($false)))
    L ('cdp_version_path=' + (San (Join-Path $reports 'antigravity-cdp-version-r209.json')))
    try{ $vj=$ver|ConvertFrom-Json; L ('cdp_browser=' + (San ([string]$vj.Browser)) + ' protocol=' + (San ([string]$vj.'Protocol-Version'))) }catch{ L ('cdp_version_raw=' + (San $ver)) }
    try{ $lj=@($lst|ConvertFrom-Json); L ('cdp_targets=' + $lj.Count); foreach($t in ($lj|Select-Object -First 10)){ L ('cdp_target type=' + (San ([string]$t.type)) + ' title=' + (San ([string]$t.title)) + ' url=' + (San ([string]$t.url))) } }catch{ L ('cdp_list_raw=' + (San $lst)) }
}
$wins=@(Get-Process -Name Antigravity -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object -First 8)
L ('antigravity_window_count=' + $wins.Count)
$targetTitle='Antigravity'
if($wins.Count -gt 0){ $targetTitle=$wins[0].MainWindowTitle }
foreach($w in $wins){ L ('antigravity_window=' + (San $w.MainWindowTitle) + ' pid=' + $w.Id) }
if(Test-Path -LiteralPath $backend){
    foreach($view in @('control','raw','content')){
        $tree=Invoke-Wcu $backend 'tree' ([pscustomobject]@{ scope='active_window'; windowTitle=$targetTitle; activate=$true; viewMode=$view; includeOffscreen=$true; maxDepth=14; maxNodes=1500; detailLevel='full' }) 90000
        $path=Join-Path $reports ('antigravity-uia-' + $view + '-r209.json')
        try{ [IO.File]::WriteAllText($path,(($tree|ConvertTo-Json -Depth 40)+"`r`n"),(New-Object Text.UTF8Encoding($false))) }catch{}
        $counts=@{}; try{ CountTypes $tree.tree $counts }catch{}
        $pairs=@($counts.GetEnumerator()|Sort-Object Value -Descending|Select-Object -First 12|ForEach-Object{ $_.Key + '=' + $_.Value })
        $cands=New-Object System.Collections.ArrayList; try{ CollectCandidates $tree.tree $cands }catch{}
        L ('uia_' + $view + '_ok=' + $tree.ok + ' nodes=' + $tree.nodeCount + ' candidates=' + $cands.Count + ' types=' + (($pairs) -join ','))
        foreach($c in ($cands|Select-Object -First 40)){ L ('uia_' + $view + '| id=' + (San ([string]$c.id)) + ' d=' + $c.depth + ' type=' + (San ([string]$c.type)) + ' name=' + (San ([string]$c.name)) + ' class=' + (San ([string]$c.class))) }
        L ('uia_' + $view + '_path=' + (San $path))
    }
}
$summary=@('# Antigravity accessibility/CDP probe r209','',('CDP 9223 listening: ' + $cdpListen),('Target title: ' + $targetTitle),'UIA JSON files are under E:\0mcp-agv-arena-optimized\reports.','If raw/control UIA still only exposes the title bar, CDP or OCR/vision fallback is required for Antigravity UI conversations.')
W (Join-Path $reports 'antigravity-probe-summary-r209.md') $summary
try{ Copy-Item -LiteralPath (Join-Path $reports 'antigravity-probe-summary-r209.md') -Destination (Join-Path $outDir 'antigravity-probe-summary-r209.md') -Force }catch{}
if($cdpListen){ L 'FINAL_R209: ANTIGRAVITY_CDP_AVAILABLE_AND_UIA_PROBED' } else { L 'FINAL_R209: UIA_PROBED_CDP_NOT_AVAILABLE' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t166 done ---'
exit 0
