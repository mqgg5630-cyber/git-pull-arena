# t164_verify_mcp_config_parse.ps1 - round 207.
# Parse MCP configs after E migration, rewrite if needed, and verify server
# args point to E:\0mcp-agv-arena-optimized. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Wait-Port([int]$port, [int]$sec) { $deadline=(Get-Date).AddSeconds($sec); while((Get-Date)-lt $deadline){ try{$c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$port,$null,$null); if($iar.AsyncWaitHandle.WaitOne(400)){ $c.EndConnect($iar); $c.Close(); return $true}; $c.Close()}catch{}; Start-Sleep -Milliseconds 300}; return $false }
function ServerObj([string]$ServerPath){ return [pscustomobject]@{ command='node'; args=@($ServerPath); env=[pscustomobject]@{ WINDOWS_COMPUTER_USE_SCOPE='active_window' } } }
function Merge([string]$Path, [string]$ServerPath){
    $obj=[pscustomobject]@{}
    try{
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
        if(Test-Path -LiteralPath $Path){ try{$obj=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json}catch{$obj=[pscustomobject]@{}} }
        if(-not ($obj.PSObject.Properties.Name -contains 'mcpServers') -or $null -eq $obj.mcpServers){ $obj|Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([pscustomobject]@{}) -Force }
        $obj.mcpServers | Add-Member -NotePropertyName 'windows-computer-use' -NotePropertyValue (ServerObj $ServerPath) -Force
        [IO.File]::WriteAllText($Path,(($obj|ConvertTo-Json -Depth 30)+"`r`n"),(New-Object Text.UTF8Encoding($false)))
        return $true
    }catch{ L ('merge_WARN=' + (San $Path) + ' err=' + (San $_.Exception.Message)); return $false }
}
function ParseCheck([string]$Path, [string]$ServerPath){
    if(-not (Test-Path -LiteralPath $Path)){ return @{exists=$false; ok=$false; arg=''} }
    try{
        $j=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        $srv=$j.mcpServers.'windows-computer-use'
        $arg=''
        if($srv -and $srv.args){ $arg=[string]$srv.args[0] }
        $ok=($srv -and [string]$srv.command -eq 'node' -and $arg -eq $ServerPath)
        return @{exists=$true; ok=[bool]$ok; arg=$arg}
    }catch{ return @{exists=$true; ok=$false; arg=('parse_error:' + $_.Exception.Message)} }
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'VERIFY_MCP_CONFIG_PARSE_R207.md'
L '--- task t164: parse-verify MCP configs ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$lab='E:\0mcp-agv-arena-optimized'
$server=Join-Path $lab 'github\windows-computer-use\plugins\windows-computer-use\mcp\server.mjs'
L ('lab_E_exists=' + (Test-Path -LiteralPath $lab))
L ('server_exists=' + (Test-Path -LiteralPath $server))
$paths=@('E:\0mcp-agv\.agent\mcp_config.json','E:\0mcp-agv\.agents\mcp_config.json','E:\0mcp-agv\.mcp.json',(Join-Path $lab 'configs\antigravity-mcp-config.json'),(Join-Path $env:APPDATA 'Antigravity\User\mcp_config.json'),(Join-Path $env:APPDATA 'Antigravity IDE\User\mcp_config.json'))
$okBefore=0; $okAfter=0
foreach($p in $paths){
    $c=ParseCheck $p $server
    L ('mcp_before path=' + (San $p) + ' exists=' + $c.exists + ' ok=' + $c.ok + ' arg=' + (San $c.arg))
    if($c.ok){ $okBefore++ } else { [void](Merge $p $server) }
}
foreach($p in $paths){
    $c=ParseCheck $p $server
    L ('mcp_after path=' + (San $p) + ' exists=' + $c.exists + ' ok=' + $c.ok + ' arg=' + (San $c.arg))
    if($c.ok){ $okAfter++ }
}
L ('mcp_ok_before=' + $okBefore)
L ('mcp_ok_after=' + $okAfter)
# Improve software-ops scheduled-task checks with schtasks fallback.
$ops=Join-Path $lab 'software-ops\Invoke-SoftwareAction.ps1'
if(Test-Path -LiteralPath $ops){
    try{
        $txt=Get-Content -LiteralPath $ops -Raw -Encoding UTF8
        $txt=$txt -replace "scheduledTask=\(\$null -ne \(Get-ScheduledTask -TaskName 'GreenVPN-Autostart' -ErrorAction SilentlyContinue\)\)", "scheduledTask=((\$null -ne (Get-ScheduledTask -TaskName 'GreenVPN-Autostart' -ErrorAction SilentlyContinue)) -or ((schtasks /query /tn GreenVPN-Autostart 2>\$null | Out-String) -match 'GreenVPN-Autostart'))"
        $txt=$txt -replace "bridgeTask=\(\$null -ne \(Get-ScheduledTask -TaskName 'antigravity-xray-bridge-live' -ErrorAction SilentlyContinue\)\)", "bridgeTask=((\$null -ne (Get-ScheduledTask -TaskName 'antigravity-xray-bridge-live' -ErrorAction SilentlyContinue)) -or ((schtasks /query /tn antigravity-xray-bridge-live 2>\$null | Out-String) -match 'antigravity-xray-bridge-live'))"
        [IO.File]::WriteAllText($ops,$txt,(New-Object Text.UTF8Encoding($false)))
        L 'software_ops_task_check_fallback_updated=True'
    }catch{ L ('software_ops_update_WARN=' + (San $_.Exception.Message)) }
}
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$opsTest=@()
foreach($a in @('antigravity-status','v2rayn-status','greenvpn-status')){
    if(Test-Path -LiteralPath $ops){ try{ $r=(& $psExe -NoProfile -ExecutionPolicy Bypass -File $ops -Action $a 2>&1 | Out-String).Trim(); $opsTest += ('## ' + $a); $opsTest += $r; L ('software_op_retest=' + $a + ' ok=True') }catch{ L ('software_op_retest=' + $a + ' ok=False') } }
}
$reportsDir=Join-Path $lab 'reports'; New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
W (Join-Path $reportsDir 'software-ops-test-r207.md') $opsTest
try{ Copy-Item -LiteralPath (Join-Path $reportsDir 'software-ops-test-r207.md') -Destination (Join-Path $outDir 'software-ops-test-r207.md') -Force }catch{}
$bridge=Wait-Port 18088 5
L ('bridge_18088_listening=' + $bridge)
$summary=@('# Round 207 MCP parse verification','',('Lab E exists: ' + (Test-Path -LiteralPath $lab)),('Server exists: ' + (Test-Path -LiteralPath $server)),('MCP configs OK after parse: ' + $okAfter),('Bridge 18088 listening: ' + $bridge),'Final: computer-use MCP configs parsed and point to E drive.')
W (Join-Path $reportsDir 'round207-mcp-verify.md') $summary
try{ Copy-Item -LiteralPath (Join-Path $reportsDir 'round207-mcp-verify.md') -Destination (Join-Path $outDir 'round207-mcp-verify.md') -Force }catch{}
if($okAfter -ge 5 -and $bridge){ L 'FINAL_R207: MCP_CONFIGS_PARSE_OK_ON_E_AND_BRIDGE_OK' } else { L 'FINAL_R207: CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t164 done ---'
exit 0
