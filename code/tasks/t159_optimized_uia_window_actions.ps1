# t159_optimized_uia_window_actions.ps1 - round 202.
# Optimized UIA actions by window title: set first Edit descendant and invoke
# named Button. This avoids SendKeys and coordinate hit-test issues. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Invoke-JsonTool([string]$Tool, [string]$Action, [object]$Payload, [int]$TimeoutMs = 30000) {
    $json = ($Payload | ConvertTo-Json -Depth 30 -Compress)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
    $psi.Arguments = '-STA -NoProfile -ExecutionPolicy Bypass -File "' + $Tool + '" -Action ' + $Action
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
    if($err){ L ('tool_stderr_' + $Action + '=' + (San (($err -split "`r?`n")[-1]))) }
    try { return ($out | ConvertFrom-Json) } catch { return @{ ok=$false; raw=$out; parseError=$_.Exception.Message } }
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'OPTIMIZED_UIA_WINDOW_ACTIONS_R202.md'
L '--- task t159: optimized UIA window actions ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$labRoot=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$toolsDir=Join-Path $labRoot 'tools'
$smokeDir=Join-Path $labRoot 'smoke'
$optDir=Join-Path $labRoot 'optimized-wcu-lite'
New-Item -ItemType Directory -Force -Path $toolsDir,$smokeDir,$optDir | Out-Null
$appScript=Join-Path $toolsDir 'arena_wcu_test_app.ps1'
$resultFile=Join-Path $smokeDir 'optimized_window_actions_result.txt'
$tool=Join-Path $optDir 'windows-uia-arena-window-actions.ps1'
$toolLines=@'
param([Parameter(Mandatory=$true)][string]$Action)
$ErrorActionPreference='Stop'
[Console]::InputEncoding=[System.Text.Encoding]::UTF8
[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
function OutJson([object]$o){ $o | ConvertTo-Json -Depth 20 -Compress }
function InObj { $raw=[Console]::In.ReadToEnd(); if([string]::IsNullOrWhiteSpace($raw)){ return [pscustomobject]@{} }; return $raw | ConvertFrom-Json }
function Safe([scriptblock]$b,$d=$null){ try { return & $b } catch { return $d } }
function LoadUIA { Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; Add-Type -AssemblyName WindowsBase; if(-not ('ArenaWinNative2' -as [type])){ Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ArenaWinNative2 {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd,int nCmdShow);
}
"@ } }
function Info($el){ $ct=Safe { $el.Current.ControlType.ProgrammaticName -replace '^ControlType\.', '' } ''; return [ordered]@{ name=(Safe { $el.Current.Name } ''); automationId=(Safe { $el.Current.AutomationId } ''); className=(Safe { $el.Current.ClassName } ''); controlType=$ct; processId=(Safe { $el.Current.ProcessId } 0) } }
function FindWindow([string]$title){ $root=[System.Windows.Automation.AutomationElement]::RootElement; $kids=$root.FindAll([System.Windows.Automation.TreeScope]::Children,[System.Windows.Automation.Condition]::TrueCondition); for($i=0;$i -lt $kids.Count;$i++){ $el=$kids.Item($i); $name=Safe { $el.Current.Name } ''; if($name -and $name.IndexOf($title,[System.StringComparison]::OrdinalIgnoreCase) -ge 0){ return $el } }; throw ('no window matched ' + $title) }
function Activate($el){ $hwnd=Safe { $el.Current.NativeWindowHandle } 0; if($hwnd){ $ptr=[IntPtr]([int64]$hwnd); [ArenaWinNative2]::ShowWindow($ptr,9)|Out-Null; Start-Sleep -Milliseconds 80; [ArenaWinNative2]::SetForegroundWindow($ptr)|Out-Null; Start-Sleep -Milliseconds 150 } }
function FindFirstByType($root,[System.Windows.Automation.ControlType]$ct){ $cond=New-Object System.Windows.Automation.PropertyCondition -ArgumentList ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), $ct; return $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$cond) }
function FindButtonByName($root,[string]$name){ $condType=New-Object System.Windows.Automation.PropertyCondition -ArgumentList ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), ([System.Windows.Automation.ControlType]::Button); $buttons=$root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condType); for($i=0;$i -lt $buttons.Count;$i++){ $b=$buttons.Item($i); $bn=Safe { $b.Current.Name } ''; if($bn -and $bn.IndexOf($name,[System.StringComparison]::OrdinalIgnoreCase) -ge 0){ return $b } }; return $null }
try{
 LoadUIA; $i=InObj
 switch($Action){
  'health' { OutJson ([ordered]@{ok=$true; optimized='arena-uia-window-actions'; platform='Windows'}) }
  'set_first_edit' { $w=FindWindow([string]$i.windowTitle); Activate $w; $edit=FindFirstByType $w ([System.Windows.Automation.ControlType]::Edit); if($null -eq $edit){ throw 'no Edit descendant found' }; $pat=$null; if(-not $edit.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern,[ref]$pat)){ throw 'Edit has no ValuePattern' }; $value=[string]$i.value; $pat.SetValue($value); OutJson ([ordered]@{ok=$true; action='set_first_edit'; element=(Info $edit); length=$value.Length; method='ValuePattern'}) }
  'invoke_button' { $w=FindWindow([string]$i.windowTitle); Activate $w; $btn=FindButtonByName $w ([string]$i.name); if($null -eq $btn){ throw 'button not found' }; $pat=$null; if($btn.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern,[ref]$pat)){ $pat.Invoke(); $m='InvokePattern' } else { throw 'button has no InvokePattern' }; OutJson ([ordered]@{ok=$true; action='invoke_button'; element=(Info $btn); method=$m}) }
  default { throw ('unknown action ' + $Action) }
 }
}catch{ OutJson ([ordered]@{ok=$false; action=$Action; error=$_.Exception.Message}); exit 1 }
'@ -split "`r?`n"
W $tool $toolLines
L ('optimized_window_tool_written=' + (San $tool))
L ('test_app_exists=' + (Test-Path -LiteralPath $appScript))
if(-not (Test-Path -LiteralPath $appScript)){ L 'FINAL_OPT_UIA_WINDOW: MISSING_APP'; W $report $script:Lines; exit 0 }
try { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue } catch { }
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$p=$null
try { $p=Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$appScript,'-OutFile',$resultFile) -PassThru; L ('test_app_started_pid=' + $p.Id) } catch { L ('test_app_start_WARN=' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 3
$health=Invoke-JsonTool $tool 'health' ([pscustomobject]@{})
L ('opt_health_ok=' + $health.ok + ' name=' + (San ([string]$health.optimized)))
$marker='OPT_UIA_WINDOW_SET_BY_ARENA_' + (Get-Date -Format 'HHmmss')
$set=Invoke-JsonTool $tool 'set_first_edit' ([pscustomobject]@{ windowTitle='Arena WCU Test App'; value=$marker })
L ('opt_set_first_edit_ok=' + $set.ok + ' method=' + (San ([string]$set.method)) + ' element=' + (San ([string]$set.element.controlType)) + $(if($set.error){' error=' + (San ([string]$set.error))}else{''}))
$inv=Invoke-JsonTool $tool 'invoke_button' ([pscustomobject]@{ windowTitle='Arena WCU Test App'; name='Save' })
L ('opt_invoke_button_ok=' + $inv.ok + ' method=' + (San ([string]$inv.method)) + ' element=' + (San ([string]$inv.element.controlType)) + $(if($inv.error){' error=' + (San ([string]$inv.error))}else{''}))
Start-Sleep -Seconds 1
$resultText=''
try{ if(Test-Path -LiteralPath $resultFile){ $resultText=Get-Content -LiteralPath $resultFile -Raw -ErrorAction SilentlyContinue } }catch{}
$typedPresent=[bool]($resultText -match [regex]::Escape($marker))
L ('result_file=' + (San $resultFile))
L ('result_typed_present=' + $typedPresent)
try { if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; L 'test_app_closed=True' } } catch { }
if($health.ok -and $set.ok -and $inv.ok -and $typedPresent){ L 'FINAL_OPT_UIA_WINDOW: OK_SET_TEXT_AND_INVOKED_SAVE' }
else { L 'FINAL_OPT_UIA_WINDOW: PARTIAL_CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t159 done ---'
exit 0
