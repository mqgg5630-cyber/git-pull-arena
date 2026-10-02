# t156_wcu_coordinate_gui_control.ps1 - round 199.
# Second proof: use windows-computer-use click/type/invoke tools with a lab
# WinForms app. Coordinate focus avoids app-specific TextBox discovery issues.
# ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Invoke-Wcu([string]$Backend, [string]$Action, [object]$Payload, [int]$TimeoutMs = 30000) {
    $json = ($Payload | ConvertTo-Json -Depth 30 -Compress)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $Backend + '" -Action ' + $Action
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($json)
    $p.StandardInput.Close()
    if (-not $p.WaitForExit($TimeoutMs)) { try { $p.Kill() } catch { }; return @{ ok=$false; raw='TIMEOUT' } }
    $out = $p.StandardOutput.ReadToEnd().Trim()
    $err = $p.StandardError.ReadToEnd().Trim()
    if($err){ L ('wcu_stderr_' + $Action + '=' + (San (($err -split "`r?`n")[-1]))) }
    try { return ($out | ConvertFrom-Json) } catch { return @{ ok=$false; raw=$out; parseError=$_.Exception.Message } }
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'WCU_COORDINATE_GUI_CONTROL_R199.md'
L '--- task t156: windows-computer-use coordinate GUI control ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$labRoot=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$toolsDir=Join-Path $labRoot 'tools'
$smokeDir=Join-Path $labRoot 'smoke'
New-Item -ItemType Directory -Force -Path $toolsDir,$smokeDir | Out-Null
$backend=Join-Path $labRoot 'github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
$appScript=Join-Path $toolsDir 'arena_wcu_test_app.ps1'
$resultFile=Join-Path $smokeDir 'wcu_coordinate_result.txt'
L ('wcu_backend_exists=' + (Test-Path -LiteralPath $backend))
L ('test_app_exists=' + (Test-Path -LiteralPath $appScript))
if(-not (Test-Path -LiteralPath $backend) -or -not (Test-Path -LiteralPath $appScript)){ L 'FINAL_WCU_COORDINATE: MISSING_BACKEND_OR_APP'; W $report $script:Lines; exit 0 }
try { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue } catch { }
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$p=$null
try { $p=Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$appScript,'-OutFile',$resultFile) -PassThru; L ('test_app_started_pid=' + $p.Id) } catch { L ('test_app_start_WARN=' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 3
$health=Invoke-Wcu $backend 'health' ([pscustomobject]@{})
L ('wcu_health_ok=' + $health.ok + ' platform=' + (San ([string]$health.platform)))
$act=Invoke-Wcu $backend 'activate_window' ([pscustomobject]@{ windowTitle='Arena WCU Test App' })
L ('wcu_activate_ok=' + $act.ok)
$bb=$null
try{ $bb=$act.window.boundingBox }catch{}
if($bb){ L ('window_box=' + $bb.x + ',' + $bb.y + ' ' + $bb.width + 'x' + $bb.height) }
$clickOk=$false
$typeOk=$false
$saveOk=$false
$marker='WCU_COORDINATE_TYPED_BY_ARENA_' + (Get-Date -Format 'HHmmss')
if($bb){
    $tx=[int]($bb.x + 120)
    $ty=[int]($bb.y + 115)
    $clk=Invoke-Wcu $backend 'click' ([pscustomobject]@{ x=$tx; y=$ty; button='left' })
    L ('wcu_click_textbox_ok=' + $clk.ok + ' x=' + $tx + ' y=' + $ty)
    $clickOk=[bool]$clk.ok
    Start-Sleep -Milliseconds 300
    $sel=Invoke-Wcu $backend 'keypress' ([pscustomobject]@{ keys=@('CTRL','A') })
    L ('wcu_select_all_ok=' + $sel.ok)
    $typ=Invoke-Wcu $backend 'type_text' ([pscustomobject]@{ text=$marker; restoreClipboard=$true })
    L ('wcu_type_text_ok=' + $typ.ok + ' length=' + $typ.length)
    $typeOk=[bool]$typ.ok
    Start-Sleep -Milliseconds 500
    # Use the button if UIA can find it; otherwise click its known area.
    $findBtn=Invoke-Wcu $backend 'find' ([pscustomobject]@{ scope='active_window'; windowTitle='Arena WCU Test App'; activate=$true; query='Save'; controlType='Button'; maxDepth=6; maxResults=5 })
    $btnId=$null
    try { if($findBtn.ok -and $findBtn.results.Count -gt 0){ $btnId=[string]$findBtn.results[0].id } } catch { }
    if($btnId){
        $inv=Invoke-Wcu $backend 'invoke' ([pscustomobject]@{ elementId=$btnId; fallbackClick=$true; windowTitle='Arena WCU Test App'; activate=$true })
        L ('wcu_invoke_save_ok=' + $inv.ok + ' method=' + (San ([string]$inv.method)))
        $saveOk=[bool]$inv.ok
    } else {
        $sx=[int]($bb.x + 80); $sy=[int]($bb.y + 235)
        $sav=Invoke-Wcu $backend 'click' ([pscustomobject]@{ x=$sx; y=$sy; button='left' })
        L ('wcu_click_save_ok=' + $sav.ok + ' x=' + $sx + ' y=' + $sy)
        $saveOk=[bool]$sav.ok
    }
} else { L 'coordinate_smoke_skipped=no_window_box' }
Start-Sleep -Seconds 1
$resultText=''
try{ if(Test-Path -LiteralPath $resultFile){ $resultText=Get-Content -LiteralPath $resultFile -Raw -ErrorAction SilentlyContinue } }catch{}
$typedPresent=[bool]($resultText -match [regex]::Escape($marker))
L ('result_file=' + (San $resultFile))
L ('result_typed_present=' + $typedPresent)
$cls=Invoke-Wcu $backend 'keypress' ([pscustomobject]@{ keys=@('ALT','F4'); windowTitle='Arena WCU Test App'; activate=$true })
L ('wcu_close_ok=' + $cls.ok)
Start-Sleep -Seconds 1
try { if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; L 'test_app_force_closed=True' } } catch { }
if($health.ok -and $act.ok -and $clickOk -and $typeOk -and $saveOk -and $typedPresent){ L 'FINAL_WCU_COORDINATE: OK_PROJECT_CLICKED_TYPED_SAVED_DESKTOP_APP' }
else { L 'FINAL_WCU_COORDINATE: PARTIAL_CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t156 done ---'
exit 0
