# t155_wcu_winforms_control.ps1 - round 198.
# Use the cloned GitHub windows-computer-use backend to operate a safe
# lab-owned WinForms desktop app. This proves real GUI control without touching
# Antigravity's existing 0mcp-agv tasks. ASCII-only.

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
$report=Join-Path $outDir 'WCU_WINFORMS_CONTROL_R198.md'
L '--- task t155: windows-computer-use controls WinForms test app ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$labRoot=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$toolsDir=Join-Path $labRoot 'tools'
$smokeDir=Join-Path $labRoot 'smoke'
New-Item -ItemType Directory -Force -Path $toolsDir,$smokeDir | Out-Null
$wcuRoot=Join-Path $labRoot 'github\windows-computer-use\plugins\windows-computer-use'
$backend=Join-Path $wcuRoot 'scripts\windows-uia.ps1'
L ('lab_root=' + (San $labRoot))
L ('wcu_backend_exists=' + (Test-Path -LiteralPath $backend))
if(-not (Test-Path -LiteralPath $backend)){ L 'FINAL_WCU_WINFORMS: NO_BACKEND'; W $report $script:Lines; exit 0 }

# Write a tiny lab-owned desktop app. It is intentionally simple and isolated.
$appScript=Join-Path $toolsDir 'arena_wcu_test_app.ps1'
$resultFile=Join-Path $smokeDir 'wcu_winforms_result.txt'
$appLines=@'
param([string]$OutFile)
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Arena WCU Test App'
$form.Width = 620
$form.Height = 320
$form.StartPosition = 'CenterScreen'
$label = New-Object System.Windows.Forms.Label
$label.Text = 'Lab-owned GUI app for windows-computer-use smoke test'
$label.Left = 20; $label.Top = 20; $label.Width = 560
$text = New-Object System.Windows.Forms.TextBox
$text.Name = 'arena_text_box'
$text.Multiline = $true
$text.Left = 20; $text.Top = 55; $text.Width = 560; $text.Height = 140
$text.Text = 'initial text'
$button = New-Object System.Windows.Forms.Button
$button.Name = 'arena_save_button'
$button.Text = 'Save'
$button.Left = 20; $button.Top = 210; $button.Width = 120; $button.Height = 34
$button.Add_Click({ [IO.File]::WriteAllText($OutFile, $text.Text, (New-Object Text.UTF8Encoding($false))); $form.Tag = 'saved' })
$form.Controls.Add($label)
$form.Controls.Add($text)
$form.Controls.Add($button)
[void]$form.ShowDialog()
'@ -split "`r?`n"
W $appScript $appLines
L ('test_app_written=' + (San $appScript))
try { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue } catch { }
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$p=$null
try { $p=Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$appScript,'-OutFile',$resultFile) -PassThru; L ('test_app_started_pid=' + $p.Id) } catch { L ('test_app_start_WARN=' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 3

$health=Invoke-Wcu $backend 'health' ([pscustomobject]@{})
L ('wcu_health_ok=' + $health.ok + ' platform=' + (San ([string]$health.platform)))
$act=Invoke-Wcu $backend 'activate_window' ([pscustomobject]@{ windowTitle='Arena WCU Test App' })
L ('wcu_activate_window_ok=' + $act.ok)
$tree=Invoke-Wcu $backend 'tree' ([pscustomobject]@{ scope='active_window'; windowTitle='Arena WCU Test App'; activate=$true; maxDepth=5; maxNodes=120; detailLevel='full' })
L ('wcu_tree_ok=' + $tree.ok + ' nodes=' + $tree.nodeCount)
$findEdit=Invoke-Wcu $backend 'find' ([pscustomobject]@{ scope='active_window'; windowTitle='Arena WCU Test App'; activate=$true; controlType='Edit'; maxDepth=6; maxResults=5 })
$editId=$null
try { if($findEdit.ok -and $findEdit.results.Count -gt 0){ $editId=[string]$findEdit.results[0].id } } catch { }
L ('wcu_find_edit_ok=' + $findEdit.ok + ' edit_id=' + (San $editId))
$marker='WCU_WINFORMS_TYPED_BY_ARENA_' + (Get-Date -Format 'HHmmss')
$setOk=$false
if($editId){
    $set=Invoke-Wcu $backend 'set_value' ([pscustomobject]@{ elementId=$editId; value=$marker; fallbackType=$true; restoreClipboard=$true; windowTitle='Arena WCU Test App'; activate=$true })
    L ('wcu_set_value_ok=' + $set.ok + ' method=' + (San ([string]$set.method)))
    $setOk=[bool]$set.ok
} else { L 'wcu_set_value_skipped=no_edit_id' }
$findBtn=Invoke-Wcu $backend 'find' ([pscustomobject]@{ scope='active_window'; windowTitle='Arena WCU Test App'; activate=$true; query='Save'; controlType='Button'; maxDepth=6; maxResults=5 })
$btnId=$null
try { if($findBtn.ok -and $findBtn.results.Count -gt 0){ $btnId=[string]$findBtn.results[0].id } } catch { }
L ('wcu_find_save_ok=' + $findBtn.ok + ' button_id=' + (San $btnId))
$invokeOk=$false
if($btnId){
    $inv=Invoke-Wcu $backend 'invoke' ([pscustomobject]@{ elementId=$btnId; fallbackClick=$true; windowTitle='Arena WCU Test App'; activate=$true })
    L ('wcu_invoke_save_ok=' + $inv.ok + ' method=' + (San ([string]$inv.method)))
    $invokeOk=[bool]$inv.ok
} else { L 'wcu_invoke_save_skipped=no_button_id' }
Start-Sleep -Seconds 1
$resultText=''
try { if(Test-Path -LiteralPath $resultFile){ $resultText=Get-Content -LiteralPath $resultFile -Raw -ErrorAction SilentlyContinue } } catch { }
$typedPresent=[bool]($resultText -match [regex]::Escape($marker))
L ('result_file=' + (San $resultFile))
L ('result_typed_present=' + $typedPresent)
# Close the app using WCU then force-close if needed.
$cls=Invoke-Wcu $backend 'keypress' ([pscustomobject]@{ keys=@('ALT','F4'); windowTitle='Arena WCU Test App'; activate=$true })
L ('wcu_close_ok=' + $cls.ok)
Start-Sleep -Seconds 1
try { if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; L 'test_app_force_closed=True' } } catch { }

if($health.ok -and $act.ok -and $setOk -and $invokeOk -and $typedPresent){ L 'FINAL_WCU_WINFORMS: OK_GITHUB_PROJECT_OPERATED_DESKTOP_APP' }
else { L 'FINAL_WCU_WINFORMS: PARTIAL_CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t155 done ---'
exit 0
