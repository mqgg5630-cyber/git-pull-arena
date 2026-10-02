# t161_wcu_find_invoke_button_proof.ps1 - round 204.
# Use windows-computer-use find + invoke on a lab-owned GUI button.
# ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Invoke-Wcu([string]$Backend, [string]$Action, [object]$Payload, [int]$TimeoutMs = 30000) {
    $json = ($Payload | ConvertTo-Json -Depth 30 -Compress)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
    $psi.Arguments = '-STA -NoProfile -ExecutionPolicy Bypass -File "' + $Backend + '" -Action ' + $Action
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($json)
    $p.StandardInput.Close()
    if (-not $p.WaitForExit($TimeoutMs)) { try { $p.Kill() } catch { }; return @{ ok=$false; error='TIMEOUT'; raw='' } }
    $out = $p.StandardOutput.ReadToEnd().Trim()
    $err = $p.StandardError.ReadToEnd().Trim()
    if($err){ L ('wcu_stderr_' + $Action + '=' + (San (($err -split "`r?`n")[-1]))) }
    try { return ($out | ConvertFrom-Json) } catch { return @{ ok=$false; raw=$out; parseError=$_.Exception.Message } }
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'WCU_FIND_INVOKE_BUTTON_R204.md'
L '--- task t161: windows-computer-use find+invoke proof ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$labRoot=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$toolsDir=Join-Path $labRoot 'tools'
$smokeDir=Join-Path $labRoot 'smoke'
$backend=Join-Path $labRoot 'github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
$appScript=Join-Path $toolsDir 'arena_wcu_button_app.ps1'
$resultFile=Join-Path $smokeDir 'wcu_find_invoke_result.txt'
L ('wcu_backend_exists=' + (Test-Path -LiteralPath $backend))
L ('button_app_exists=' + (Test-Path -LiteralPath $appScript))
if(-not (Test-Path -LiteralPath $backend) -or -not (Test-Path -LiteralPath $appScript)){ L 'FINAL_WCU_FIND_INVOKE: MISSING_BACKEND_OR_APP'; W $report $script:Lines; exit 0 }
try { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue } catch { }
$marker='WCU_FIND_INVOKE_BY_ARENA_' + (Get-Date -Format 'HHmmss')
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$p=$null
try { $p=Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$appScript,'-OutFile',$resultFile,'-Marker',$marker) -PassThru; L ('button_app_started_pid=' + $p.Id) } catch { L ('button_app_start_WARN=' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 3
$health=Invoke-Wcu $backend 'health' ([pscustomobject]@{})
L ('wcu_health_ok=' + $health.ok + ' platform=' + (San ([string]$health.platform)))
$act=Invoke-Wcu $backend 'activate_window' ([pscustomobject]@{ windowTitle='Arena WCU Button App' })
L ('wcu_activate_ok=' + $act.ok + $(if($act.error){' error=' + (San ([string]$act.error))}else{''}))
$find=Invoke-Wcu $backend 'find' ([pscustomobject]@{ scope='active_window'; windowTitle='Arena WCU Button App'; activate=$true; query='Write Marker'; controlType='Button'; maxDepth=6; maxResults=5 })
$btnId=''
try { if($find.ok -and $find.results.Count -gt 0){ $btnId=[string]$find.results[0].id } } catch { }
L ('wcu_find_button_ok=' + $find.ok + ' result_count=' + $(try{$find.results.Count}catch{0}) + ' button_id=' + (San $btnId) + $(if($find.error){' error=' + (San ([string]$find.error))}else{''}))
$invokeOk=$false
if($btnId){
    $inv=Invoke-Wcu $backend 'invoke' ([pscustomobject]@{ elementId=$btnId; fallbackClick=$true; windowTitle='Arena WCU Button App'; activate=$true })
    L ('wcu_invoke_button_ok=' + $inv.ok + ' method=' + (San ([string]$inv.method)) + $(if($inv.error){' error=' + (San ([string]$inv.error))}else{''}))
    $invokeOk=[bool]$inv.ok
}
Start-Sleep -Seconds 2
$resultText=''
try{ if(Test-Path -LiteralPath $resultFile){ $resultText=Get-Content -LiteralPath $resultFile -Raw -ErrorAction SilentlyContinue } }catch{}
$markerPresent=[bool]($resultText -match [regex]::Escape($marker))
L ('result_file=' + (San $resultFile))
L ('result_marker_present=' + $markerPresent)
try { if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; L 'button_app_force_closed=True' } } catch { }
if($health.ok -and $act.ok -and $find.ok -and $invokeOk -and $markerPresent){ L 'FINAL_WCU_FIND_INVOKE: OK_GITHUB_PROJECT_INVOKED_DESKTOP_APP_BUTTON' }
else { L 'FINAL_WCU_FIND_INVOKE: PARTIAL_CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t161 done ---'
exit 0
