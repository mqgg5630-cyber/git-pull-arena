# t171_desktop_computer_use_audit_fix.ps1 - round 214.
# Stage E-drive computer-use project zips to the desktop and rerun the fixed
# desktop capability audit; then generate the final combined checklist.
# ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=]{32,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[REDACTED-GUID]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; $enc=New-Object System.Text.UTF8Encoding -ArgumentList $false; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", $enc) }
function Run-Capped([string]$Name,[scriptblock]$Block,[int]$TimeoutSec) { L ('RUN_START=' + $Name); $job=Start-Job -ScriptBlock $Block; if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; L ('RUN_TIMEOUT=' + $Name); return @{ok=$false;text='TIMEOUT'} }; $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; foreach($ln in (($txt -split "`r?`n") | Select-Object -First 60)){ if($ln.Trim()){ L ('RUN_OUT|' + $Name + '| ' + (San $ln)) } }; return @{ok=$true;text=$txt} }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'COMPUTER_USE_CAPABILITY_DESKTOP_FIX_R214.md'
$final=Join-Path $outDir 'COMPUTER_USE_CAPABILITY_FINAL_R214.md'
L '# Desktop computer-use audit fix r214'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$lab='E:\0mcp-agv-arena-optimized'
$github=Join-Path $lab 'github'
$desktop='100.84.137.117'
$duser='BNI'
$sshBase=@('-o','BatchMode=yes','-o','ConnectTimeout=15','-o','StrictHostKeyChecking=accept-new')
$fshare='\\' + $desktop + '\F$'
$stageUnc=$fshare + '\fig1_rebuild\cu_r214'
$stageRemote='F:\fig1_rebuild\cu_r214'

$netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if($LASTEXITCODE -ne 0){ L ('Fshare_unreachable=' + (San $netOut)); L 'FINAL_R214: DESKTOP_FSHARE_UNREACHABLE'; W $report $script:Lines; exit 0 }
try{
    New-Item -ItemType Directory -Force -Path $stageUnc | Out-Null
    $deskScript=Join-Path $repo 'code\tasks\desk_computer_use_capability_audit_r214.ps1'
    Copy-Item -LiteralPath $deskScript -Destination ($fshare + '\fig1_rebuild\desk_computer_use_capability_audit_r214.ps1') -Force
    L 'desktop_script_staged=OK'
    $projects=@(
        @{name='windows-computer-use';src=(Join-Path $github 'windows-computer-use');zip=($stageUnc + '\windows-computer-use.zip')},
        @{name='Windows-MCP';src=(Join-Path $github 'Windows-MCP');zip=($stageUnc + '\Windows-MCP.zip')},
        @{name='pywinauto-mcp';src=(Join-Path $github 'pywinauto-mcp');zip=($stageUnc + '\pywinauto-mcp.zip')}
    )
    foreach($p in $projects){
        if(Test-Path -LiteralPath $p.src){
            try{
                Remove-Item -LiteralPath $p.zip -Force -ErrorAction SilentlyContinue
                $srcWild=Join-Path $p.src '*'
                $zip=$p.zip
                $rr=Run-Capped ('zip_' + $p.name) { Compress-Archive -Path $using:srcWild -DestinationPath $using:zip -Force 2>&1 | Out-String } 420
                L ('zip_project=' + $p.name + ' ok=' + $rr.ok + ' exists=' + (Test-Path -LiteralPath $p.zip))
            }catch{ L ('zip_project_FAIL=' + $p.name + ' err=' + (San $_.Exception.Message)) }
        } else { L ('zip_project_SKIP=' + $p.name + ' local_missing=' + (San $p.src)) }
    }
}catch{ L ('stage_FAIL=' + (San $_.Exception.Message)) }
finally{ & net use $fshare /delete 2>&1 | Out-Null }

$desktopStatus='NOT_RUN'
$job=Start-Job -ScriptBlock { param($o,$u,$h) & ssh @o ($u + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_computer_use_capability_audit_r214.ps1' 2>&1 | Out-String } -ArgumentList $sshBase,$duser,$desktop
if(-not (Wait-Job $job -Timeout 1100)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; $desktopStatus='TIMEOUT'; L 'desktop_audit_TIMEOUT=1100s' }
else{
    $dout=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; $desktopStatus='RAN'
    foreach($ln in (($dout -split "`r?`n") | Select-Object -First 260)){ $x=San $ln; if($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +'){ L ('desktop| ' + $x) } }
}

$netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
$deskReport=Join-Path $outDir 'computer-use-capability-audit-desktop-r214.md'
$deskJson=Join-Path $outDir 'computer-use-capability-audit-desktop-r214.json'
if($LASTEXITCODE -eq 0){
    try{
        $src=$fshare + '\fig1_rebuild\computer-use-capability-audit-desktop-r214.md'
        $srcj=$fshare + '\fig1_rebuild\computer-use-capability-audit-desktop-r214.json'
        if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $deskReport -Force; L 'desktop_report_collected=True' } else { L 'desktop_report_collected=False' }
        if(Test-Path -LiteralPath $srcj){ Copy-Item -LiteralPath $srcj -Destination $deskJson -Force; L 'desktop_json_collected=True' } else { L 'desktop_json_collected=False' }
    }catch{ L ('collect_WARN=' + (San $_.Exception.Message)) }
    finally{ & net use $fshare /delete 2>&1 | Out-Null }
} else { L ('collect_Fshare_WARN=' + (San $netOut)) }

$combined=@()
$combined += '# Computer-use capability final checklist r214'
$combined += ''
$combined += 'All new computer-use project installs and reports are kept under E:\0mcp-agv-arena-optimized on each Windows machine.'
$combined += ''
$combined += '## Key paths'
$combined += ''
$combined += '- Laptop final/local report: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.md'
$combined += '- Laptop final/local JSON: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.json'
$combined += '- Laptop combined repo report: results/mcp_agv_lab/COMPUTER_USE_CAPABILITY_AUDIT_R213.md'
$combined += '- Desktop final report: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.md'
$combined += '- Desktop final JSON: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r214.json'
$combined += '- Desktop repo copy: results/mcp_agv_lab/computer-use-capability-audit-desktop-r214.md'
$combined += ''
$combined += '## Interpretation'
$combined += ''
$combined += '- Antigravity CLI is useful for launching/opening files or workspaces from a terminal.'
$combined += '- Antigravity chat/agent dialog control is still better via CDP/Electron DOM; r212 proved real message insertion and submit.'
$combined += '- windows-computer-use gives reliable UIA find/invoke on ordinary Windows controls; r213 proved it again on an E-drive WinForms app.'
$combined += '- software-ops wrappers and COM are best for app-specific status/control such as WPS, v2rayN/xray, GreenVPN, and Illustrator detection.'
$combined += ''
if(Test-Path -LiteralPath (Join-Path $outDir 'COMPUTER_USE_CAPABILITY_AUDIT_R213.md')){
    $combined += '## Laptop r213 summary'
    $combined += ''
    $combined += (Get-Content -LiteralPath (Join-Path $outDir 'COMPUTER_USE_CAPABILITY_AUDIT_R213.md') -Encoding UTF8 | Select-Object -First 90)
    $combined += ''
}
if(Test-Path -LiteralPath $deskReport){
    $combined += '## Desktop r214 summary'
    $combined += ''
    $combined += (Get-Content -LiteralPath $deskReport -Encoding UTF8 | Select-Object -First 220)
    $combined += ''
} else {
    $combined += '## Desktop r214 summary'
    $combined += ''
    $combined += ('Desktop audit did not produce a collected report; status=' + $desktopStatus)
}
$combined += ''
$combined += ('Desktop status: ' + $desktopStatus)
$combined += 'FINAL_R214: COMPUTER_USE_CAPABILITY_FINAL_CHECKLIST_READY'
W $final $combined
L ('final_checklist=' + (San $final))
L ('FINAL_R214: COMPUTER_USE_CAPABILITY_FINAL_CHECKLIST_READY desktop_status=' + $desktopStatus)
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t171 done ---'
exit 0
