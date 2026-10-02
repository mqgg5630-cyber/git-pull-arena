# t160_wcu_button_app_proof.ps1 - round 203.
# Clean proof that the cloned GitHub windows-computer-use backend can operate
# a visible Windows desktop app: activate window, click a button, verify file.
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
$report=Join-Path $outDir 'WCU_BUTTON_APP_PROOF_R203.md'
L '--- task t160: windows-computer-use button app proof ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$labRoot=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$toolsDir=Join-Path $labRoot 'tools'
$smokeDir=Join-Path $labRoot 'smoke'
New-Item -ItemType Directory -Force -Path $toolsDir,$smokeDir | Out-Null
$backend=Join-Path $labRoot 'github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
$appScript=Join-Path $toolsDir 'arena_wcu_button_app.ps1'
$resultFile=Join-Path $smokeDir 'wcu_button_app_result.txt'
$appLines=@'
param([string]$OutFile,[string]$Marker)
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Arena WCU Button App'
$form.Width = 520
$form.Height = 240
$form.StartPosition = 'CenterScreen'
$label = New-Object System.Windows.Forms.Label
$label.Text = 'Click the button to write the marker to a lab file.'
$label.Left = 30; $label.Top = 30; $label.Width = 450
$button = New-Object System.Windows.Forms.Button
$button.Name = 'arena_write_marker_button'
$button.Text = 'Write Marker'
$button.Left = 30; $button.Top = 85; $button.Width = 180; $button.Height = 46
$button.Add_Click({ [IO.File]::WriteAllText($OutFile, $Marker, (New-Object Text.UTF8Encoding($false))); $form.Close() })
$form.Controls.Add($label)
$form.Controls.Add($button)
[void]$form.ShowDialog()
'@ -split "`r?`n"
W $appScript $appLines
L ('button_app_written=' + (San $appScript))
L ('wcu_backend_exists=' + (Test-Path -LiteralPath $backend))
if(-not (Test-Path -LiteralPath $backend)){ L 'FINAL_WCU_BUTTON: NO_BACKEND'; W $report $script:Lines; exit 0 }
try { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue } catch { }
$marker='WCU_BUTTON_CLICKED_BY_ARENA_' + (Get-Date -Format 'HHmmss')
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$p=$null
try { $p=Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$appScript,'-OutFile',$resultFile,'-Marker',$marker) -PassThru; L ('button_app_started_pid=' + $p.Id) } catch { L ('button_app_start_WARN=' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 3
$health=Invoke-Wcu $backend 'health' ([pscustomobject]@{})
L ('wcu_health_ok=' + $health.ok + ' platform=' + (San ([string]$health.platform)))
$act=Invoke-Wcu $backend 'activate_window' ([pscustomobject]@{ windowTitle='Arena WCU Button App' })
L ('wcu_activate_ok=' + $act.ok + $(if($act.error){' error=' + (San ([string]$act.error))}else{''}))
$bb=$null
try{ $bb=$act.window.boundingBox }catch{}
$clickOk=$false
if($bb){
    L ('window_box=' + $bb.x + ',' + $bb.y + ' ' + $bb.width + 'x' + $bb.height)
    $cx=[int]($bb.x + 125); $cy=[int]($bb.y + 135)
    $clk=Invoke-Wcu $backend 'click' ([pscustomobject]@{ x=$cx; y=$cy; button='left' })
    L ('wcu_click_button_ok=' + $clk.ok + ' x=' + $cx + ' y=' + $cy + $(if($clk.error){' error=' + (San ([string]$clk.error))}else{''}))
    $clickOk=[bool]$clk.ok
} else { L 'button_click_skipped=no_window_box' }
Start-Sleep -Seconds 2
$resultText=''
try{ if(Test-Path -LiteralPath $resultFile){ $resultText=Get-Content -LiteralPath $resultFile -Raw -ErrorAction SilentlyContinue } }catch{}
$markerPresent=[bool]($resultText -match [regex]::Escape($marker))
L ('result_file=' + (San $resultFile))
L ('result_marker_present=' + $markerPresent)
try { if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; L 'button_app_force_closed=True' } } catch { }
if($health.ok -and $act.ok -and $clickOk -and $markerPresent){ L 'FINAL_WCU_BUTTON: OK_GITHUB_PROJECT_CLICKED_DESKTOP_APP' }
else { L 'FINAL_WCU_BUTTON: PARTIAL_CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t160 done ---'
exit 0
