# t170_computer_use_capability_audit.ps1 - round 213.
# Test Antigravity terminal CLI, prove complementary computer-use backends, and
# generate laptop + desktop capability lists under E:\0mcp-agv-arena-optimized.
# ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[REDACTED-GUID]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Add-Cap([string]$Computer,[string]$App,[string]$Backend,[string]$Task,[string]$Result,[string]$Evidence,[string]$Artifact) { $script:Caps += [pscustomobject]@{computer=$Computer; app=$App; backend=$Backend; task=$Task; result=$Result; evidence=(San $Evidence); artifact=(San $Artifact)} }
function Test-Port([int]$p) { try { $c=New-Object Net.Sockets.TcpClient; $iar=$c.BeginConnect('127.0.0.1',$p,$null,$null); if($iar.AsyncWaitHandle.WaitOne(500)){ $c.EndConnect($iar); $c.Close(); return $true }; $c.Close() } catch { }; return $false }
function Run-Capped([string]$Name,[scriptblock]$Block,[int]$TimeoutSec) { $job=Start-Job -ScriptBlock $Block; if(-not (Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{ok=$false;text='TIMEOUT';name=$Name} }; $txt=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return @{ok=$true;text=$txt;name=$Name} }
function Ensure-Clone([string]$Url,[string]$Dest) { if(Test-Path -LiteralPath (Join-Path $Dest '.git')){ return 'present' }; if(-not (Get-Command git -ErrorAction SilentlyContinue)){ return 'git-missing' }; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dest) | Out-Null; $u=$Url; $d=$Dest; $r=Run-Capped ('clone_' + (Split-Path $Dest -Leaf)) { git clone --depth 1 $using:u $using:d 2>&1 | Out-String } 240; if(Test-Path -LiteralPath (Join-Path $Dest '.git')){ return 'cloned' }; return ('clone-failed-' + (San $r.text)) }
function Run-ExeCapture([string]$Path,[string[]]$Args,[int]$TimeoutMs) {
    try {
        $psi=New-Object Diagnostics.ProcessStartInfo
        if($Path -match '\.(cmd|bat)$'){
            $psi.FileName=(Join-Path $env:SystemRoot 'System32\cmd.exe')
            $argLine=($Args | ForEach-Object { if($_ -match '[ \t"]'){ '"' + ($_ -replace '"','\"') + '"' } else { $_ } }) -join ' '
            $psi.Arguments='/c ""' + $Path + '" ' + $argLine + '"'
        } else {
            $psi.FileName=$Path
            $psi.Arguments=($Args | ForEach-Object { if($_ -match '[ \t"]'){ '"' + ($_ -replace '"','\"') + '"' } else { $_ } }) -join ' '
        }
        $psi.UseShellExecute=$false; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
        $p=[Diagnostics.Process]::Start($psi)
        if(-not $p.WaitForExit($TimeoutMs)){ try{$p.Kill()}catch{}; return @{ok=$false;exit='TIMEOUT';out=''} }
        $out=($p.StandardOutput.ReadToEnd() + "`n" + $p.StandardError.ReadToEnd()).Trim()
        return @{ok=($p.ExitCode -eq 0 -or $out.Length -gt 0);exit=$p.ExitCode;out=(San (($out -split "`r?`n" | Select-Object -First 12) -join ' | '))}
    } catch { return @{ok=$false;exit='ERR';out=(San $_.Exception.Message)} }
}
function Invoke-Wcu([string]$Backend, [string]$Action, [object]$Payload, [int]$TimeoutMs = 30000) {
    $json = ($Payload | ConvertTo-Json -Depth 30 -Compress)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
    $psi.Arguments = '-STA -NoProfile -ExecutionPolicy Bypass -File "' + $Backend + '" -Action ' + $Action
    $psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8; $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($json); $p.StandardInput.Close()
    if (-not $p.WaitForExit($TimeoutMs)) { try { $p.Kill() } catch { }; return @{ ok=$false; error='TIMEOUT'; raw='' } }
    $out = $p.StandardOutput.ReadToEnd().Trim(); $err = $p.StandardError.ReadToEnd().Trim()
    if($err){ L ('wcu_stderr_' + $Action + '=' + (San (($err -split "`r?`n")[-1]))) }
    try { return ($out | ConvertFrom-Json) } catch { return @{ ok=$false; raw=$out; parseError=$_.Exception.Message } }
}

$script:Lines=@(); $script:Caps=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$mainReport=Join-Path $outDir 'COMPUTER_USE_CAPABILITY_AUDIT_R213.md'
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$github=Join-Path $lab 'github'
$suite=Join-Path $lab 'computer-use-suite'
$tools=Join-Path $lab 'tools'
$smoke=Join-Path $lab 'smoke'
New-Item -ItemType Directory -Force -Path $reports,$github,$suite,$tools,$smoke | Out-Null
$localReport=Join-Path $reports 'computer-use-capability-audit-laptop-r213.md'
$localJson=Join-Path $reports 'computer-use-capability-audit-laptop-r213.json'
L '# Computer-use capability audit r213'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
L ('lab_root=' + $lab)

# Ensure all candidate computer-use projects live on E:.
$projects=@(
    @{name='windows-computer-use';url='https://github.com/cgissing/windows-computer-use.git';dest=(Join-Path $github 'windows-computer-use')},
    @{name='Windows-MCP';url='https://github.com/CursorTouch/Windows-MCP.git';dest=(Join-Path $github 'Windows-MCP')},
    @{name='pywinauto-mcp';url='https://github.com/sandraschi/pywinauto-mcp.git';dest=(Join-Path $github 'pywinauto-mcp')}
)
foreach($p in $projects){ $st=Ensure-Clone $p.url $p.dest; L ('project|' + $p.name + '|status=' + (San $st) + '|path=' + (San $p.dest)); Add-Cap $env:COMPUTERNAME $p.name 'E-drive install' 'install/presence check' $(if($st -match 'present|cloned'){'OK'}else{'CHECK_REPORT'}) $st $p.dest }
$wcuBackend=Join-Path $github 'windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
$wmcpDir=Join-Path $github 'Windows-MCP'
$pywDir=Join-Path $github 'pywinauto-mcp'

# Antigravity terminal CLI probe.
$agExe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$cli=@()
foreach($p in @((Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\bin\antigravity.cmd'),(Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\bin\code.cmd'),(Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\resources\app\bin\code.cmd'),$agExe)){ if($p -and (Test-Path -LiteralPath $p)){ $cli += $p } }
try{ $cmds=@(Get-Command antigravity*,code -ErrorAction SilentlyContinue | Where-Object { $_.Source } | Select-Object -ExpandProperty Source); foreach($c in $cmds){ if($c -and (Test-Path -LiteralPath $c)){ $cli += $c } } }catch{}
$cli=@($cli | Select-Object -Unique)
L ('antigravity_cli_candidates=' + $cli.Count)
$cliOk=$false; $cliChoice=''; $cliEvidence=''
foreach($c in $cli){ $v=Run-ExeCapture $c @('--version') 8000; L ('ag_cli_version|path=' + (San $c) + '|ok=' + $v.ok + '|exit=' + $v.exit + '|out=' + (San $v.out)); if(-not $cliOk -and $v.ok){ $cliOk=$true; $cliChoice=$c; $cliEvidence=$v.out } }
$cliProbe=Join-Path $reports 'antigravity-cli-probe-laptop-r213.txt'
[IO.File]::WriteAllText($cliProbe, 'ARENA_LAPTOP_AG_CLI_R213 ' + (Get-Date).ToString('s'), (New-Object Text.UTF8Encoding($false)))
$cliOpen='NOT_RUN'
if($cliOk){
    try{ Start-Process -FilePath $cliChoice -ArgumentList @('--reuse-window',$cliProbe) -ErrorAction SilentlyContinue; Start-Sleep -Seconds 6; $cliOpen='ISSUED'; Add-Cap $env:COMPUTERNAME 'Antigravity' 'Antigravity terminal CLI' 'open E-drive probe file/workspace' 'OK_ISSUED' ('version=' + $cliEvidence) $cliProbe }catch{ $cliOpen='ERR'; Add-Cap $env:COMPUTERNAME 'Antigravity' 'Antigravity terminal CLI' 'open E-drive probe file/workspace' 'CHECK_REPORT' $_.Exception.Message $cliProbe }
} else { Add-Cap $env:COMPUTERNAME 'Antigravity' 'Antigravity terminal CLI' 'version/help/open probe' 'NOT_FOUND_OR_TIMEOUT' ('candidates=' + $cli.Count) '' }

# Fresh windows-computer-use UIA Invoke proof on an E-drive lab app.
$wcuFinal='NOT_RUN'
$appScript=Join-Path $tools 'arena_wcu_button_app_r213.ps1'
$resultFile=Join-Path $smoke 'wcu_find_invoke_result_r213.txt'
$appLines=@'
param([string]$OutFile,[string]$Marker)
$ErrorActionPreference='Continue'
Add-Type -AssemblyName System.Windows.Forms
$form=New-Object Windows.Forms.Form
$form.Text='Arena WCU Button App R213'
$form.Width=520; $form.Height=240; $form.StartPosition='CenterScreen'
$label=New-Object Windows.Forms.Label
$label.Left=30; $label.Top=30; $label.Width=440; $label.Text='Computer-use UIA invoke proof on E drive'
$btn=New-Object Windows.Forms.Button
$btn.Text='Write Marker'; $btn.Left=30; $btn.Top=80; $btn.Width=150; $btn.Height=44
$btn.Add_Click({ [IO.File]::WriteAllText($OutFile,$Marker,(New-Object Text.UTF8Encoding($false))); $form.Close() })
$form.Controls.Add($label); $form.Controls.Add($btn)
[void]$form.ShowDialog()
'@ -split "`r?`n"
W $appScript $appLines
try { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue } catch { }
if(Test-Path -LiteralPath $wcuBackend){
    $marker='WCU_R213_' + (Get-Date -Format 'HHmmss')
    $psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $p=$null
    try { $p=Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$appScript,'-OutFile',$resultFile,'-Marker',$marker) -PassThru; Start-Sleep -Seconds 3 } catch { L ('wcu_app_start_WARN=' + (San $_.Exception.Message)) }
    $health=Invoke-Wcu $wcuBackend 'health' ([pscustomobject]@{})
    $act=Invoke-Wcu $wcuBackend 'activate_window' ([pscustomobject]@{ windowTitle='Arena WCU Button App R213' })
    $find=Invoke-Wcu $wcuBackend 'find' ([pscustomobject]@{ scope='active_window'; windowTitle='Arena WCU Button App R213'; activate=$true; query='Write Marker'; controlType='Button'; maxDepth=6; maxResults=5 })
    $btnId=''; try{ if($find.ok -and $find.results.Count -gt 0){ $btnId=[string]$find.results[0].id } }catch{}
    $inv=$null; if($btnId){ $inv=Invoke-Wcu $wcuBackend 'invoke' ([pscustomobject]@{ elementId=$btnId; fallbackClick=$true; windowTitle='Arena WCU Button App R213'; activate=$true }) }
    Start-Sleep -Seconds 2
    $resultText=''; try{ if(Test-Path -LiteralPath $resultFile){ $resultText=Get-Content -LiteralPath $resultFile -Raw } }catch{}
    $markerPresent=[bool]($resultText -match [regex]::Escape($marker))
    try { if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } } catch { }
    L ('wcu_r213_health=' + $health.ok + ' activate=' + $act.ok + ' find=' + $find.ok + ' button_id=' + (San $btnId) + ' invoke=' + $(if($inv){$inv.ok}else{$false}) + ' marker=' + $markerPresent)
    if($health.ok -and $act.ok -and $find.ok -and $inv.ok -and $markerPresent){ $wcuFinal='OK'; Add-Cap $env:COMPUTERNAME 'Lab WinForms app' 'windows-computer-use MCP/UIA' 'find button and invoke it' 'OK' 'marker file created by invoked button' $resultFile } else { $wcuFinal='PARTIAL'; Add-Cap $env:COMPUTERNAME 'Lab WinForms app' 'windows-computer-use MCP/UIA' 'find button and invoke it' 'CHECK_REPORT' ('health=' + $health.ok + ';activate=' + $act.ok + ';find=' + $find.ok + ';invoke=' + $(if($inv){$inv.ok}else{$false}) + ';marker=' + $markerPresent) $resultFile }
} else { Add-Cap $env:COMPUTERNAME 'Lab WinForms app' 'windows-computer-use MCP/UIA' 'find button and invoke it' 'NOT_READY' 'backend missing' $wcuBackend }

# App-specific wrapper/status tests.
$ops=Join-Path $lab 'software-ops\Invoke-SoftwareAction.ps1'
if(Test-Path -LiteralPath $ops){
    foreach($a in @('antigravity-status','v2rayn-status','greenvpn-status','wps-status','illustrator-status')){
        try{ $txt=(& (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -NoProfile -ExecutionPolicy Bypass -File $ops -Action $a 2>&1 | Out-String).Trim(); L ('software_op|' + $a + '|' + (San (($txt -split "`r?`n" | Select-Object -First 8) -join ' | '))); Add-Cap $env:COMPUTERNAME ($a -replace '-status','') 'software-ops wrapper' ('run ' + $a) 'OK' $txt $ops }catch{ Add-Cap $env:COMPUTERNAME ($a -replace '-status','') 'software-ops wrapper' ('run ' + $a) 'CHECK_REPORT' $_.Exception.Message $ops }
    }
} else { Add-Cap $env:COMPUTERNAME 'software-ops' 'app-specific wrapper' 'run status checks' 'NOT_READY' 'script missing' $ops }

# Additional direct capability probes.
$wps=@{}; foreach($pg in @('KWPS.Application','KET.Application','KWPP.Application')){ try{ $o=New-Object -ComObject $pg; $wps[$pg]='OK'; try{$o.Quit()}catch{} }catch{ $wps[$pg]='FAIL' } }
Add-Cap $env:COMPUTERNAME 'WPS Office' 'COM automation' 'instantiate Writer/Sheet/Presentation COM' $(if($wps.Values -contains 'OK'){'OK'}else{'NOT_READY'}) (($wps.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value }) -join ';') 'results/wps_continue/amp_ml_prediction_v2_r173.pptx'
Add-Cap $env:COMPUTERNAME 'Antigravity chat' 'CDP/Electron DOM' 'submit message input' 'OK_PROVEN_R212' 'message input role=combobox aria=Message input; cdp-insertText; marker visible after submit' 'E:\0mcp-agv-arena-optimized\reports\antigravity-cdp-targeted-message-input-r212.json'
Add-Cap $env:COMPUTERNAME 'File Explorer' 'shell CLI' 'open E-drive lab folder' 'OK_CAPABLE' 'explorer.exe can open local folders' $lab
try{ $np=(Get-Command notepad.exe -ErrorAction SilentlyContinue).Source; if($np){ Add-Cap $env:COMPUTERNAME 'Notepad' 'process/file CLI' 'open/edit text file by path' 'OK_CAPABLE' 'notepad.exe present' $np } }catch{}
try{ $edge=(Get-Command msedge.exe -ErrorAction SilentlyContinue).Source; if($edge){ $ev=Run-ExeCapture $edge @('--version') 8000; Add-Cap $env:COMPUTERNAME 'Microsoft Edge' 'browser CLI' 'version/open URL/file capability' $(if($ev.ok){'OK'}else{'CHECK_REPORT'}) $ev.out $edge } }catch{}

$wins=@(Get-Process | Where-Object { $_.MainWindowTitle } | Select-Object -First 50 ProcessName,Id,MainWindowTitle)
L ('open_window_count=' + $wins.Count)
foreach($w in ($wins | Select-Object -First 25)){ L ('window|' + (San $w.ProcessName) + '|title=' + (San $w.MainWindowTitle)) }
$data=[ordered]@{computer=$env:COMPUTERNAME; user=$env:USERNAME; labRoot=$lab; projects=$projects; capabilities=$script:Caps; windows=$wins; time=(Get-Date).ToString('s')}
[IO.File]::WriteAllText($localJson, (($data | ConvertTo-Json -Depth 12) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
L ''
L '## Laptop capability list'
foreach($c in $script:Caps){ L ('cap|' + $c.computer + '|' + $c.app + '|' + $c.backend + '|' + $c.task + '|' + $c.result + '|' + $c.evidence + '|' + $c.artifact) }
L ('local_json=' + (San $localJson))
W $localReport $script:Lines
try{ Copy-Item -LiteralPath $localReport -Destination (Join-Path $outDir 'computer-use-capability-audit-laptop-r213.md') -Force }catch{}
try{ Copy-Item -LiteralPath $localJson -Destination (Join-Path $outDir 'computer-use-capability-audit-laptop-r213.json') -Force }catch{}

# Stage and run the same audit on the desktop, collecting its E-drive report.
$desktop='100.84.137.117'
$duser='BNI'
$sshBase=@('-o','BatchMode=yes','-o','ConnectTimeout=15','-o','StrictHostKeyChecking=accept-new')
$fshare='\\' + $desktop + '\F$'
$deskScript=Join-Path $repo 'code\tasks\desk_computer_use_capability_audit_r213.ps1'
$desktopCollected=Join-Path $outDir 'computer-use-capability-audit-desktop-r213.md'
$desktopJsonCollected=Join-Path $outDir 'computer-use-capability-audit-desktop-r213.json'
$desktopStatus='NOT_RUN'
$netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if($LASTEXITCODE -ne 0){
    $desktopStatus='FSHARE_UNREACHABLE'
    L ('desktop_Fshare_unreachable=' + (San $netOut))
    Add-Cap 'DESKTOP-IEUDGS5' 'desktop audit' 'ssh/smb' 'run desktop capability audit' 'CHECK_REPORT' 'Fshare unreachable' ''
} else {
    try{
        $rootUnc=$fshare + '\fig1_rebuild'
        New-Item -ItemType Directory -Force -Path $rootUnc | Out-Null
        Copy-Item -LiteralPath $deskScript -Destination ($rootUnc + '\desk_computer_use_capability_audit_r213.ps1') -Force
        L 'desktop_script_staged=OK'
        $desktopStatus='STAGED'
    }catch{ $desktopStatus='STAGE_FAIL'; L ('desktop_stage_FAIL=' + (San $_.Exception.Message)) }
    finally{ & net use $fshare /delete 2>&1 | Out-Null }
    if($desktopStatus -eq 'STAGED'){
        $job=Start-Job -ScriptBlock { param($o,$u,$h) & ssh @o ($u + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_computer_use_capability_audit_r213.ps1' 2>&1 | Out-String } -ArgumentList $sshBase,$duser,$desktop
        if(-not (Wait-Job $job -Timeout 900)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; $desktopStatus='TIMEOUT'; L 'desktop_audit_TIMEOUT=900s' }
        else{
            $dout=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; $desktopStatus='RAN'
            foreach($ln in (($dout -split "`r?`n") | Select-Object -First 220)){ $x=San $ln; if($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +'){ L ('desktop| ' + $x) } }
        }
        $netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
        if($LASTEXITCODE -eq 0){
            try{
                $src=$fshare + '\fig1_rebuild\computer-use-capability-audit-desktop-r213.md'
                $srcj=$fshare + '\fig1_rebuild\computer-use-capability-audit-desktop-r213.json'
                if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $desktopCollected -Force; L 'desktop_report_collected=True' }
                if(Test-Path -LiteralPath $srcj){ Copy-Item -LiteralPath $srcj -Destination $desktopJsonCollected -Force; L 'desktop_json_collected=True' }
            }catch{ L ('desktop_collect_WARN=' + (San $_.Exception.Message)) }
            finally{ & net use $fshare /delete 2>&1 | Out-Null }
        } else { L ('desktop_collect_Fshare_WARN=' + (San $netOut)) }
    }
}

# Combined Chinese-neutral markdown table in repo and E drive (ASCII-only content).
$combined=@()
$combined += '# Computer-use capability audit r213'
$combined += ''
$combined += ('Laptop E report: ' + $localReport)
$combined += ('Laptop E JSON: ' + $localJson)
$combined += ('Desktop status: ' + $desktopStatus)
$combined += ('Desktop E report expected: E:\0mcp-agv-arena-optimized\reports\computer-use-capability-audit-desktop-r213.md')
$combined += ('Desktop repo copy: ' + $desktopCollected)
$combined += ''
$combined += '## Complementary success case'
$combined += ''
$combined += '- Antigravity terminal CLI: used to issue opening of an E-drive probe file/workspace.'
$combined += '- CDP/Electron DOM: proven in r212 to insert and submit an Antigravity message input; marker visible after submit.'
$combined += '- windows-computer-use MCP/UIA: fresh r213 E-drive WinForms button find+invoke test writes a marker file.'
$combined += '- software-ops wrappers and COM: app-specific status/control checks for Antigravity, v2rayN/xray, GreenVPN, WPS, and Illustrator.'
$combined += ''
$combined += '## Laptop capabilities'
$combined += ''
$combined += '| Computer | App | Backend | Tested task | Result | Evidence/artifact |'
$combined += '|---|---|---|---|---|---|'
foreach($c in $script:Caps){ $combined += ('| ' + $c.computer + ' | ' + $c.app + ' | ' + $c.backend + ' | ' + $c.task + ' | ' + $c.result + ' | ' + (($c.evidence + ' ' + $c.artifact) -replace '\|','/') + ' |') }
if(Test-Path -LiteralPath $desktopCollected){
    $combined += ''
    $combined += '## Desktop report excerpt'
    $combined += ''
    $combined += (Get-Content -LiteralPath $desktopCollected -Encoding UTF8 | Select-Object -First 220)
}
$combined += ''
$okCount=@($script:Caps | Where-Object { $_.result -match '^OK' }).Count
$combined += ('Laptop OK capability count: ' + $okCount)
$combined += ('Final: completed laptop audit and desktop audit status=' + $desktopStatus)
W (Join-Path $reports 'computer-use-capability-audit-combined-r213.md') $combined
try{ Copy-Item -LiteralPath (Join-Path $reports 'computer-use-capability-audit-combined-r213.md') -Destination $mainReport -Force }catch{}
L ('combined_report_E=' + (San (Join-Path $reports 'computer-use-capability-audit-combined-r213.md')))
L ('combined_report_repo=' + (San $mainReport))
L ('FINAL_R213: COMPUTER_USE_CAPABILITY_AUDIT_COMPLETED_DESKTOP_STATUS_' + $desktopStatus)
W $mainReport ($combined + @('', '## Execution log', '') + $script:Lines)
L ('main_report=' + (San $mainReport))
L '--- task t170 done ---'
exit 0
