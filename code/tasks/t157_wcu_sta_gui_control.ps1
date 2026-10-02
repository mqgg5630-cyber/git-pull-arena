# t157_wcu_sta_gui_control.ps1 - round 200.
# Run windows-computer-use backend under PowerShell -STA so Clipboard/SendKeys
# tools can operate a lab WinForms desktop app. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Invoke-WcuSta([string]$Backend, [string]$Action, [object]$Payload, [int]$TimeoutMs = 30000) {
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
$report=Join-Path $outDir 'WCU_STA_GUI_CONTROL_R200.md'
L '--- task t157: windows-computer-use STA GUI control ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$labRoot=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$toolsDir=Join-Path $labRoot 'tools'
$smokeDir=Join-Path $labRoot 'smoke'
$backend=Join-Path $labRoot 'github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
$appScript=Join-Path $toolsDir 'arena_wcu_test_app.ps1'
$resultFile=Join-Path $smokeDir 'wcu_sta_result.txt'
L ('wcu_backend_exists=' + (Test-Path -LiteralPath $backend))
L ('test_app_exists=' + (Test-Path -LiteralPath $appScript))
if(-not (Test-Path -LiteralPath $backend) -or -not (Test-Path -LiteralPath $appScript)){ L 'FINAL_WCU_STA: MISSING_BACKEND_OR_APP'; W $report $script:Lines; exit 0 }
try { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue } catch { }
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$p=$null
try { $p=Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$appScript,'-OutFile',$resultFile) -PassThru; L ('test_app_started_pid=' + $p.Id) } catch { L ('test_app_start_WARN=' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 3
$health=Invoke-WcuSta $backend 'health' ([pscustomobject]@{})
L ('wcu_health_ok=' + $health.ok + ' platform=' + (San ([string]$health.platform)))
$act=Invoke-WcuSta $backend 'activate_window' ([pscustomobject]@{ windowTitle='Arena WCU Test App' })
L ('wcu_activate_ok=' + $act.ok + $(if($act.error){' error=' + (San ([string]$act.error))}else{''}))
$bb=$null
try{ $bb=$act.window.boundingBox }catch{}
if($bb){ L ('window_box=' + $bb.x + ',' + $bb.y + ' ' + $bb.width + 'x' + $bb.height) }
$marker='WCU_STA_TYPED_BY_ARENA_' + (Get-Date -Format 'HHmmss')
$clickOk=$false; $typeOk=$false; $saveOk=$false
if($bb){
    $tx=[int]($bb.x + 120); $ty=[int]($bb.y + 115)
    $clk=Invoke-WcuSta $backend 'click' ([pscustomobject]@{ x=$tx; y=$ty; button='left' })
    L ('wcu_click_textbox_ok=' + $clk.ok + ' x=' + $tx + ' y=' + $ty + $(if($clk.error){' error=' + (San ([string]$clk.error))}else{''}))
    $clickOk=[bool]$clk.ok
    Start-Sleep -Milliseconds 400
    $sel=Invoke-WcuSta $backend 'keypress' ([pscustomobject]@{ keys=@('CTRL','A') })
    L ('wcu_select_all_ok=' + $sel.ok + $(if($sel.error){' error=' + (San ([string]$sel.error))}else{''}))
    $typ=Invoke-WcuSta $backend 'type_text' ([pscustomobject]@{ text=$marker; restoreClipboard=$true })
    L ('wcu_type_text_ok=' + $typ.ok + ' length=' + $typ.length + $(if($typ.error){' error=' + (San ([string]$typ.error))}else{''}))
    $typeOk=[bool]$typ.ok
    Start-Sleep -Milliseconds 700
    $sx=[int]($bb.x + 80); $sy=[int]($bb.y + 235)
    $sav=Invoke-WcuSta $backend 'click' ([pscustomobject]@{ x=$sx; y=$sy; button='left' })
    L ('wcu_click_save_ok=' + $sav.ok + ' x=' + $sx + ' y=' + $sy + $(if($sav.error){' error=' + (San ([string]$sav.error))}else{''}))
    $saveOk=[bool]$sav.ok
} else { L 'coordinate_smoke_skipped=no_window_box' }
Start-Sleep -Seconds 1
$resultText=''
try{ if(Test-Path -LiteralPath $resultFile){ $resultText=Get-Content -LiteralPath $resultFile -Raw -ErrorAction SilentlyContinue } }catch{}
$typedPresent=[bool]($resultText -match [regex]::Escape($marker))
L ('result_file=' + (San $resultFile))
L ('result_typed_present=' + $typedPresent)
$cls=Invoke-WcuSta $backend 'keypress' ([pscustomobject]@{ keys=@('ALT','F4'); windowTitle='Arena WCU Test App'; activate=$true })
L ('wcu_close_ok=' + $cls.ok + $(if($cls.error){' error=' + (San ([string]$cls.error))}else{''}))
Start-Sleep -Seconds 1
try { if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; L 'test_app_force_closed=True' } } catch { }
if($health.ok -and $act.ok -and $clickOk -and $typeOk -and $saveOk -and $typedPresent){ L 'FINAL_WCU_STA: OK_PROJECT_CLICKED_TYPED_SAVED_DESKTOP_APP' }
else { L 'FINAL_WCU_STA: PARTIAL_CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t157 done ---'
exit 0
