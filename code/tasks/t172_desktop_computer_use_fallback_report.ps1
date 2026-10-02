# t172_desktop_computer_use_fallback_report.ps1 - round 218.
# Run a desktop audit that detects whether E: exists; if E: is unavailable on
# the desktop, it records the F: fallback instead of pretending E: worked.
# ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=]{32,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Out-Lines([string]$Path,[string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; Set-Content -LiteralPath $Path -Value $Lines -Encoding UTF8 }
function Run-Capped([string]$Name,[scriptblock]$Block,[int]$TimeoutSec) { L ('RUN_START=' + $Name); $job=Start-Job -ScriptBlock $Block; if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; L ('RUN_TIMEOUT=' + $Name); return @{ok=$false;text='TIMEOUT'} }; $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; foreach($ln in (($txt -split "`r?`n") | Select-Object -First 50)){ if($ln.Trim()){ L ('RUN_OUT|' + $Name + '| ' + (San $ln)) } }; return @{ok=$true;text=$txt} }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'COMPUTER_USE_DESKTOP_FALLBACK_R218.md'
$final=Join-Path $outDir 'COMPUTER_USE_CAPABILITY_FINAL_R218.md'
L '# Desktop fallback audit r218'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$desktop='100.84.137.117'
$duser='BNI'
$sshBase=@('-o','BatchMode=yes','-o','ConnectTimeout=15','-o','StrictHostKeyChecking=accept-new')
$fshare='\\' + $desktop + '\F$'
$lab='E:\0mcp-agv-arena-optimized'
$github=Join-Path $lab 'github'
$stageUnc=$fshare + '\fig1_rebuild\cu_r214'

$netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if($LASTEXITCODE -ne 0){ L ('Fshare_unreachable=' + (San $netOut)); L 'FINAL_R218: DESKTOP_FSHARE_UNREACHABLE'; Out-Lines $report $script:Lines; exit 0 }
try{
    New-Item -ItemType Directory -Force -Path $stageUnc | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'code\tasks\desk_computer_use_capability_fallback_r218.ps1') -Destination ($fshare + '\fig1_rebuild\desk_computer_use_capability_fallback_r218.ps1') -Force
    L 'desktop_fallback_script_staged=OK'
    foreach($name in @('windows-computer-use','Windows-MCP','pywinauto-mcp')){
        $src=Join-Path $github $name
        $zip=$stageUnc + '\' + $name + '.zip'
        if((Test-Path -LiteralPath $src) -and -not (Test-Path -LiteralPath $zip)){
            $srcWild=Join-Path $src '*'
            Run-Capped ('zip_' + $name) { Compress-Archive -Path $using:srcWild -DestinationPath $using:zip -Force 2>&1 | Out-String } 420 | Out-Null
            L ('zip_created=' + $name + ' exists=' + (Test-Path -LiteralPath $zip))
        } else { L ('zip_ready=' + $name + ' exists=' + (Test-Path -LiteralPath $zip)) }
    }
}catch{ L ('stage_WARN=' + (San $_.Exception.Message)) }
finally{ & net use $fshare /delete 2>&1 | Out-Null }

$desktopStatus='NOT_RUN'
$job=Start-Job -ScriptBlock { param($o,$u,$h) & ssh @o ($u + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_computer_use_capability_fallback_r218.ps1' 2>&1 | Out-String } -ArgumentList $sshBase,$duser,$desktop
if(-not (Wait-Job $job -Timeout 900)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; $desktopStatus='TIMEOUT'; L 'desktop_fallback_TIMEOUT=900s' }
else{
    $dout=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; $desktopStatus='RAN'
    foreach($ln in (($dout -split "`r?`n") | Select-Object -First 260)){ $x=San $ln; if($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +'){ L ('desktop| ' + $x) } }
}

$deskReport=Join-Path $outDir 'computer-use-capability-audit-desktop-r218.md'
$deskJson=Join-Path $outDir 'computer-use-capability-audit-desktop-r218.json'
$netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if($LASTEXITCODE -eq 0){
    try{
        $src=$fshare + '\fig1_rebuild\computer-use-capability-audit-desktop-r218.md'
        $srcj=$fshare + '\fig1_rebuild\computer-use-capability-audit-desktop-r218.json'
        if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $deskReport -Force; L 'desktop_report_collected=True' } else { L 'desktop_report_collected=False' }
        if(Test-Path -LiteralPath $srcj){ Copy-Item -LiteralPath $srcj -Destination $deskJson -Force; L 'desktop_json_collected=True' } else { L 'desktop_json_collected=False' }
    }catch{ L ('collect_WARN=' + (San $_.Exception.Message)) }
    finally{ & net use $fshare /delete 2>&1 | Out-Null }
} else { L ('collect_Fshare_WARN=' + (San $netOut)) }

$combined=@()
$combined += '# Computer-use capability final checklist r218'
$combined += ''
$combined += 'Laptop uses E:\0mcp-agv-arena-optimized. Desktop audit now explicitly detects whether E: exists; if not, it reports the F: fallback root.'
$combined += ''
$combined += '## Key paths'
$combined += '- Laptop report: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.md'
$combined += '- Laptop JSON: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-laptop-r213.json'
$combined += '- Desktop collected report: results/mcp_agv_lab/computer-use-capability-audit-desktop-r218.md'
$combined += '- Desktop collected JSON: results/mcp_agv_lab/computer-use-capability-audit-desktop-r218.json'
$combined += ''
$combined += '## Antigravity CLI vs CDP'
$combined += '- CLI is convenient for terminal launch/open-file/open-folder operations.'
$combined += '- For actual Antigravity chat/dialog tasks, CDP/Electron DOM is the working route proven by r212.'
$combined += ''
if(Test-Path -LiteralPath (Join-Path $outDir 'COMPUTER_USE_CAPABILITY_AUDIT_R213.md')){ $combined += '## Laptop summary'; $combined += ''; $combined += (Get-Content -LiteralPath (Join-Path $outDir 'COMPUTER_USE_CAPABILITY_AUDIT_R213.md') -Encoding UTF8 | Select-Object -First 80); $combined += '' }
if(Test-Path -LiteralPath $deskReport){ $combined += '## Desktop summary'; $combined += ''; $combined += (Get-Content -LiteralPath $deskReport -Encoding UTF8 | Select-Object -First 220); $combined += '' } else { $combined += '## Desktop summary'; $combined += ('Desktop report missing; status=' + $desktopStatus) }
$combined += ('Desktop status: ' + $desktopStatus)
$combined += 'FINAL_R218: COMPUTER_USE_CAPABILITY_FINAL_CHECKLIST_READY'
Out-Lines $final $combined
L ('final_checklist=' + (San $final))
L ('FINAL_R218: COMPUTER_USE_CAPABILITY_FINAL_CHECKLIST_READY desktop_status=' + $desktopStatus)
Out-Lines $report $script:Lines
L ('main_report=' + (San $report))
exit 0
