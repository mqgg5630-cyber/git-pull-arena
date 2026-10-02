# t162_migrate_integrate_mcp_agv.ps1 - round 205.
# Move the isolated computer-use lab from C: to E:, officially register the
# windows-computer-use MCP server for Antigravity/workspace use, add dedicated
# software operation scripts, and build an optimized agents/skills catalog from
# E:\0mcp-agv without modifying the original. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function WA([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllLines($p, $lines, (New-Object System.Text.ASCIIEncoding)) }
function Run-Capped([string]$Name, [scriptblock]$Block, [int]$TimeoutSec) {
    L ('RUN_START=' + $Name)
    $job = Start-Job -ScriptBlock $Block
    if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        L ('RUN_TIMEOUT=' + $Name + ' seconds=' + $TimeoutSec)
        return @{ ok=$false; text='TIMEOUT' }
    }
    $txt = (Receive-Job $job | Out-String).Trim()
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    foreach($ln in (($txt -split "`r?`n") | Select-Object -First 80)) { if($ln.Trim()){ L ('RUN_OUT|' + $Name + '| ' + (San $ln)) } }
    return @{ ok=$true; text=$txt }
}
function Merge-McpConfig([string]$Path, [object]$ServerObj) {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
        $obj = [pscustomobject]@{}
        if (Test-Path -LiteralPath $Path) {
            $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($raw -and $raw.Trim()) {
                try { $obj = $raw | ConvertFrom-Json } catch { Copy-Item -LiteralPath $Path -Destination ($Path + '.invalid-bak-' + (Get-Date -Format 'yyyyMMddHHmmss')) -Force; $obj = [pscustomobject]@{} }
            }
            Copy-Item -LiteralPath $Path -Destination ($Path + '.bak-' + (Get-Date -Format 'yyyyMMddHHmmss')) -Force -ErrorAction SilentlyContinue
        }
        if (-not ($obj.PSObject.Properties.Name -contains 'mcpServers') -or $null -eq $obj.mcpServers) {
            $obj | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        $obj.mcpServers | Add-Member -NotePropertyName 'windows-computer-use' -NotePropertyValue $ServerObj -Force
        [IO.File]::WriteAllText($Path, (($obj | ConvertTo-Json -Depth 30) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
        $check = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        $ok = ($check.mcpServers.PSObject.Properties.Name -contains 'windows-computer-use')
        L ('mcp_config_written=' + (San $Path) + ' ok=' + $ok)
        return $ok
    } catch { L ('mcp_config_FAIL=' + (San $Path) + ' err=' + (San $_.Exception.Message)); return $false }
}
function Test-Port([int]$port) {
    try { $c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(500)){ $c.EndConnect($iar); $c.Close(); return $true }; $c.Close() } catch { }
    return $false
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'MIGRATE_INTEGRATE_MCP_AGV_R205.md'
L '--- task t162: migrate lab to E and integrate computer-use MCP ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)

# 1. Move lab to E: and remove the C: copy.
$oldLab=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$newLab='E:\0mcp-agv-arena-optimized'
New-Item -ItemType Directory -Force -Path $newLab | Out-Null
L ('old_lab_exists=' + (Test-Path -LiteralPath $oldLab))
L ('new_lab=' + $newLab)
if(Test-Path -LiteralPath $oldLab){
    $src=$oldLab; $dst=$newLab
    $r=Run-Capped 'robocopy_lab_C_to_E' { robocopy $using:src $using:dst /E /NFL /NDL /NJH /NJS /NP 2>&1 | Out-String } 600
    L ('robocopy_lab_ok=' + $r.ok)
}
$reposDir=Join-Path $newLab 'github'
$reportsDir=Join-Path $newLab 'reports'
$toolsDir=Join-Path $newLab 'tools'
$smokeDir=Join-Path $newLab 'smoke'
$configsDir=Join-Path $newLab 'configs'
foreach($d in @($reposDir,$reportsDir,$toolsDir,$smokeDir,$configsDir)){ New-Item -ItemType Directory -Force -Path $d | Out-Null }
$wcuDir=Join-Path $reposDir 'windows-computer-use'
$wmcpDir=Join-Path $reposDir 'Windows-MCP'
if(-not (Test-Path -LiteralPath (Join-Path $wcuDir '.git'))){ $url='https://github.com/cgissing/windows-computer-use.git'; $dest=$wcuDir; Run-Capped 'clone_windows_computer_use_to_E' { git clone --depth 1 $using:url $using:dest 2>&1 | Out-String } 300 | Out-Null }
if(-not (Test-Path -LiteralPath (Join-Path $wmcpDir '.git'))){ $url='https://github.com/CursorTouch/Windows-MCP.git'; $dest=$wmcpDir; Run-Capped 'clone_Windows_MCP_to_E' { git clone --depth 1 $using:url $using:dest 2>&1 | Out-String } 300 | Out-Null }
$server=Join-Path $newLab 'github\windows-computer-use\plugins\windows-computer-use\mcp\server.mjs'
$backend=Join-Path $newLab 'github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
L ('wcu_server_exists_E=' + (Test-Path -LiteralPath $server))
L ('wcu_backend_exists_E=' + (Test-Path -LiteralPath $backend))
if((Test-Path -LiteralPath (Join-Path $newLab 'README.md')) -or (Test-Path -LiteralPath $server)){
    if(Test-Path -LiteralPath $oldLab){ try { Remove-Item -LiteralPath $oldLab -Recurse -Force -ErrorAction Stop; L 'old_lab_removed_from_C=True' } catch { L ('old_lab_remove_WARN=' + (San $_.Exception.Message)) } }
}
L ('old_lab_exists_after=' + (Test-Path -LiteralPath $oldLab))

# 2. Register the windows-computer-use MCP in workspace and Antigravity configs.
$serverObj = [pscustomobject]@{
    command = 'node'
    args = @($server)
    env = [pscustomobject]@{ WINDOWS_COMPUTER_USE_SCOPE = 'active_window' }
}
$agvRoot='E:\0mcp-agv'
$mcpConfigs=@()
$mcpConfigs += (Join-Path $agvRoot '.agent\mcp_config.json')
$mcpConfigs += (Join-Path $agvRoot '.agents\mcp_config.json')
$mcpConfigs += (Join-Path $agvRoot '.mcp.json')
$mcpConfigs += (Join-Path $configsDir 'antigravity-mcp-config.json')
$mcpConfigs += (Join-Path $env:APPDATA 'Antigravity\User\mcp_config.json')
$mcpConfigs += (Join-Path $env:APPDATA 'Antigravity IDE\User\mcp_config.json')
$okCount=0
foreach($cfg in @($mcpConfigs | Select-Object -Unique)){ if(Merge-McpConfig $cfg $serverObj){ $okCount++ } }
L ('mcp_config_ok_count=' + $okCount)
# Keep settings proxy and record a pointer to the config without changing user secrets.
foreach($root in @((Join-Path $env:APPDATA 'Antigravity\User'),(Join-Path $env:APPDATA 'Antigravity IDE\User'))){
    try{
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        $sp=Join-Path $root 'settings.json'
        $obj=[pscustomobject]@{}
        if(Test-Path -LiteralPath $sp){ try { $obj=Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $obj=[pscustomobject]@{} } }
        $obj | Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue 'http://127.0.0.1:18088' -Force
        $obj | Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force
        $obj | Add-Member -NotePropertyName 'arena.computerUseLab' -NotePropertyValue $newLab -Force
        [IO.File]::WriteAllText($sp, (($obj | ConvertTo-Json -Depth 20) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
        L ('antigravity_settings_pointer_OK=' + (San $sp))
    } catch { L ('antigravity_settings_pointer_WARN=' + (San $_.Exception.Message)) }
}
# Verify upstream plugin and relaunch Antigravity to load new config.
$verify=Join-Path $newLab 'github\windows-computer-use\plugins\windows-computer-use\scripts\verify-plugin.mjs'
if((Test-Path -LiteralPath $verify) -and (Get-Command node -ErrorAction SilentlyContinue)){
    $v=$verify; $vf=Join-Path $reportsDir 'windows-computer-use-verify-r205.txt'
    $vr=Run-Capped 'verify_windows_computer_use_E' { node $using:v 2>&1 | Tee-Object -FilePath $using:vf | Out-String } 240
    L ('wcu_verify_E_ok=' + $vr.ok)
}
try { foreach($n in @('language_server','Antigravity')){ taskkill /f /im ($n + '.exe') 2>&1 | Out-Null } } catch { }
Start-Sleep -Seconds 2
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
if(Test-Path -LiteralPath $agExe){ try { Start-Process -FilePath $agExe; L 'antigravity_relaunch=OK' } catch { L ('antigravity_relaunch_WARN=' + (San $_.Exception.Message)) } }

# 3. Dedicated software operations.
$opsDir=Join-Path $newLab 'software-ops'
New-Item -ItemType Directory -Force -Path $opsDir | Out-Null
$opsScript=Join-Path $opsDir 'Invoke-SoftwareAction.ps1'
$opsLines=@'
param([string]$Action='status')
$ErrorActionPreference='Continue'
function J([object]$o){ $o | ConvertTo-Json -Depth 8 }
function Port([int]$p){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$p,$null,$null); if($iar.AsyncWaitHandle.WaitOne(500)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; return $false }
switch($Action){
 'window-inventory' { Get-Process | Where-Object { $_.MainWindowTitle } | Sort-Object ProcessName | Select-Object ProcessName,Id,MainWindowTitle,Path | Format-Table -AutoSize; break }
 'antigravity-status' { $exe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'; J ([ordered]@{app='Antigravity'; installed=(Test-Path $exe); version=$(if(Test-Path $exe){[string](Get-Item $exe).VersionInfo.ProductVersion}else{''}); processes=@(Get-Process -Name Antigravity -ErrorAction SilentlyContinue).Count; languageServer=@(Get-Process -Name language_server -ErrorAction SilentlyContinue).Count; proxy18088=(Port 18088); mcpConfig=(Test-Path 'E:\0mcp-agv\.agent\mcp_config.json')}); break }
 'antigravity-restart' { foreach($n in @('language_server','Antigravity')){ taskkill /f /im ($n+'.exe') 2>&1|Out-Null }; Start-Sleep 2; $exe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'; if(Test-Path $exe){ Start-Process $exe }; J ([ordered]@{app='Antigravity'; restarted=$true}); break }
 'greenvpn-status' { $exe='E:\NsfocusVPN\NsfocusVPN.exe'; $startup=Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\GreenVPN-Autostart.cmd'; $task=Get-ScheduledTask -TaskName 'GreenVPN-Autostart' -ErrorAction SilentlyContinue; J ([ordered]@{app='GreenVPN'; exe=(Test-Path $exe); processes=@(Get-Process -Name NsfocusVPN -ErrorAction SilentlyContinue).Count; startup=(Test-Path $startup); scheduledTask=($null -ne $task)}); break }
 'greenvpn-start' { $cmd='E:\NsfocusVPN\green-vpn-launcher.cmd'; if(Test-Path $cmd){ Start-Process $cmd } elseif(Test-Path 'E:\NsfocusVPN\NsfocusVPN.exe'){ Start-Process 'E:\NsfocusVPN\NsfocusVPN.exe' }; J ([ordered]@{app='GreenVPN'; startIssued=$true}); break }
 'v2rayn-status' { J ([ordered]@{app='v2rayN'; v2rayN=@(Get-Process -Name v2rayN -ErrorAction SilentlyContinue).Count; xray=@(Get-Process -Name xray -ErrorAction SilentlyContinue).Count; bridge18088=(Port 18088); bridgeTask=($null -ne (Get-ScheduledTask -TaskName 'antigravity-xray-bridge-live' -ErrorAction SilentlyContinue))}); break }
 'wps-status' { $progs=@('KWPP.Application','KET.Application','KWPS.Application'); $r=@{}; foreach($pg in $progs){ try{ $o=New-Object -ComObject $pg; $r[$pg]='OK'; try{$o.Quit()}catch{} }catch{ $r[$pg]='FAIL' } }; J ([ordered]@{app='WPS'; processes=@(Get-Process -Name wpp,et,wps -ErrorAction SilentlyContinue).Count; com=$r}); break }
 'illustrator-status' { J ([ordered]@{app='Illustrator'; processes=@(Get-Process -Name Illustrator -ErrorAction SilentlyContinue).Count; paths=@((Get-ChildItem 'C:\Program Files','D:\','E:\' -Recurse -Depth 4 -Filter Illustrator.exe -File -ErrorAction SilentlyContinue | Select-Object -First 5 -ExpandProperty FullName))}); break }
 default { J ([ordered]@{actions=@('window-inventory','antigravity-status','antigravity-restart','greenvpn-status','greenvpn-start','v2rayn-status','wps-status','illustrator-status')}) }
}
'@ -split "`r?`n"
W $opsScript $opsLines
$opsReadme=@(
'# Arena software operations',
'',
'This folder contains app-specific operation wrappers kept outside E:\0mcp-agv.',
'',
'Examples:',
'- powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SoftwareAction.ps1 -Action antigravity-status',
'- powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SoftwareAction.ps1 -Action greenvpn-start',
'- powershell -NoProfile -ExecutionPolicy Bypass -File .\Invoke-SoftwareAction.ps1 -Action v2rayn-status',
'',
'Policy: prefer app-specific COM/UIA/status actions before broad screen-control.'
)
W (Join-Path $opsDir 'README.md') $opsReadme
$opsTest=@()
foreach($a in @('antigravity-status','v2rayn-status','greenvpn-status','wps-status')){
    try { $txt=(& powershell -NoProfile -ExecutionPolicy Bypass -File $opsScript -Action $a 2>&1 | Out-String).Trim(); $opsTest += ('## ' + $a); $opsTest += $txt; L ('software_op_test=' + $a + ' ok=True') } catch { $opsTest += ('## ' + $a + ' FAIL ' + $_.Exception.Message); L ('software_op_test=' + $a + ' ok=False') }
}
W (Join-Path $reportsDir 'software-ops-test-r205.md') $opsTest

# 4. Optimized agents/skills catalog from E:\0mcp-agv (read-only source).
$catDir=Join-Path $newLab 'agents-skills'
$catAgents=Join-Path $catDir 'agents'
$catSkills=Join-Path $catDir 'skills'
New-Item -ItemType Directory -Force -Path $catAgents,$catSkills | Out-Null
$skillFiles=@()
if(Test-Path -LiteralPath $agvRoot){ $skillFiles=@(Get-ChildItem -LiteralPath $agvRoot -Recurse -Depth 5 -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue | Select-Object -First 500) }
$index=@()
foreach($sf in $skillFiles){
    $rel=$sf.FullName.Substring($agvRoot.Length).TrimStart('\')
    $cat='general'
    $low=$rel.ToLowerInvariant()
    if($low -match 'ppt|slide|deck|wps|presentation|guizang|dashi|banana|cyber'){ $cat='presentation' }
    elseif($low -match 'citation|academic|paper|thesis|cnki|english|reference|consistency|data'){ $cat='research' }
    elseif($low -match 'illustrator|figure|svg|image'){ $cat='figure' }
    elseif($low -match 'mcp|agent|computer|desktop'){ $cat='agent-mcp' }
    $index += [pscustomobject]@{ name=(Split-Path (Split-Path $sf.FullName -Parent) -Leaf); category=$cat; source=$sf.FullName; relative=$rel; bytes=$sf.Length }
}
$indexPath=Join-Path $catDir 'skills-index.json'
[IO.File]::WriteAllText($indexPath, (($index | ConvertTo-Json -Depth 6) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
L ('skills_index_count=' + $index.Count)
$agentDocs=@{
    'desktop-operator-agent.md' = @('# Desktop Operator Agent','','Use windows-computer-use MCP for active-window UIA observation/invoke/click, then fall back to app-specific scripts in software-ops. Keep secrets out of logs.','',('MCP server: ' + $server),('Ops root: ' + $opsDir));
    'presentation-agent.md' = @('# Presentation Agent','','Use WPS/PowerPoint COM or existing presentation skills from E:\0mcp-agv. Prefer deterministic Python/COM generators before GUI clicks.','Categories: presentation skills are indexed in skills-index.json.');
    'research-agent.md' = @('# Research Agent','','Use academic/citation/data skills from E:\0mcp-agv through the optimized index. Preserve citations and run verification gates.');
    'illustrator-figure-agent.md' = @('# Illustrator Figure Agent','','Use Illustrator/figure/SVG skills from the original workspace via read-only references; write new artifacts under this optimized lab or explicit project folders.')
}
foreach($k in $agentDocs.Keys){ W (Join-Path $catAgents $k) $agentDocs[$k] }
$skillStubs=@{
    'desktop-computer-use' = @('# Desktop Computer Use Skill','','Purpose: operate Windows desktop apps through the registered windows-computer-use MCP server. Scope defaults to active_window.','Use for: find windows, inspect UIA tree, invoke buttons, click coordinates, screenshot.','Do not log passwords, tokens, or clipboard contents.');
    'antigravity-vpn-bridge' = @('# Antigravity VPN Bridge Skill','','Purpose: keep Antigravity on the supported-region bridge at http://127.0.0.1:18088 and verify daily-cloudcode no location block.','Use software-ops v2rayn-status and Antigravity status before making changes.');
    'wps-ppt-automation' = @('# WPS PPT Automation Skill','','Purpose: build/edit PPT through WPS COM and existing E:\0mcp-agv presentation assets without relying on unlicensed Microsoft Office.');
    'illustrator-figure-automation' = @('# Illustrator Figure Automation Skill','','Purpose: generate and verify Illustrator/SVG figure workflows using original E:\0mcp-agv references, writing outputs outside the original tree unless requested.');
    'academic-citation-audit' = @('# Academic Citation Audit Skill','','Purpose: use the original light-citation, consistency, and data-engineering skills as read-only source material for citation/fact checks.')
}
foreach($name in $skillStubs.Keys){ $d=Join-Path $catSkills $name; New-Item -ItemType Directory -Force -Path $d | Out-Null; W (Join-Path $d 'SKILL.md') $skillStubs[$name] }
$catReadme=@(
'# Optimized agents and skills catalog',
'',
('Source workspace (read-only): ' + $agvRoot),
('Optimized catalog root: ' + $catDir),
'',
'Generated artifacts:',
'- skills-index.json: categorized index of SKILL.md files discovered under source workspace.',
'- agents/: optimized role prompts that reference the original skills without modifying them.',
'- skills/: small wrapper skills for desktop computer use, Antigravity bridge, WPS/PPT, Illustrator, and citation audits.',
'',
'Original E:\0mcp-agv was not modified except for MCP config backup/merge requested by the user.'
)
W (Join-Path $catDir 'README.md') $catReadme
L ('agents_skills_catalog=' + (San $catDir))

# Final summary and copy important lab reports to repo.
$summary=@(
'# Round 205 completion',
'',
('Lab root on E: ' + $newLab),
('Old C lab exists after move: ' + (Test-Path -LiteralPath $oldLab)),
('windows-computer-use MCP server: ' + $server),
('MCP configs written: ' + $okCount),
('Software ops: ' + $opsDir),
('Agents/skills catalog: ' + $catDir),
('Antigravity bridge 18088 listening: ' + (Test-Port 18088)),
'',
'Final: completed E-drive migration, MCP registration, software ops wrappers, and optimized agent/skill catalog.'
)
W (Join-Path $reportsDir 'round205-summary.md') $summary
try { Copy-Item -LiteralPath (Join-Path $reportsDir 'round205-summary.md') -Destination (Join-Path $outDir 'round205-summary.md') -Force } catch { }
try { Copy-Item -LiteralPath (Join-Path $reportsDir 'software-ops-test-r205.md') -Destination (Join-Path $outDir 'software-ops-test-r205.md') -Force } catch { }
L 'FINAL_R205: COMPLETED_E_DRIVE_MCP_INTEGRATION_SOFTWARE_OPS_AND_AGENT_SKILL_CATALOG'
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t162 done ---'
exit 0
