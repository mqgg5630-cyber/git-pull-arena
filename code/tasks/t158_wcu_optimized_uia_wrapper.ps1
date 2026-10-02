# t158_wcu_optimized_uia_wrapper.ps1 - round 201.
# Build an optimized, separate UIA wrapper inspired by windows-computer-use:
# set value / invoke by screen point, avoiding SendKeys access-denied issues.
# ASCII-only.

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
$report=Join-Path $outDir 'WCU_OPTIMIZED_UIA_WRAPPER_R201.md'
L '--- task t158: optimized UIA wrapper proof ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$labRoot=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$toolsDir=Join-Path $labRoot 'tools'
$smokeDir=Join-Path $labRoot 'smoke'
$optDir=Join-Path $labRoot 'optimized-wcu-lite'
New-Item -ItemType Directory -Force -Path $toolsDir,$smokeDir,$optDir | Out-Null
$wcuBackend=Join-Path $labRoot 'github\windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
$appScript=Join-Path $toolsDir 'arena_wcu_test_app.ps1'
$resultFile=Join-Path $smokeDir 'wcu_optimized_result.txt'
$optTool=Join-Path $optDir 'windows-uia-arena-optimized.ps1'

$optLines=@'
param([Parameter(Mandatory=$true)][string]$Action)
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
function OutJson([object]$o){ $o | ConvertTo-Json -Depth 20 -Compress }
function InObj { $raw=[Console]::In.ReadToEnd(); if([string]::IsNullOrWhiteSpace($raw)){ return [pscustomobject]@{} }; return $raw | ConvertFrom-Json }
function Safe([scriptblock]$b,$d=$null){ try { return & $b } catch { return $d } }
function LoadUIA { Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; Add-Type -AssemblyName WindowsBase; Add-Type -AssemblyName System.Windows.Forms; if(-not ('ArenaUiaNative' -as [type])){ Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ArenaUiaNative {
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int X,int Y);
 [DllImport("user32.dll")] public static extern void mouse_event(int flags,int dx,int dy,int data,UIntPtr extra);
}
"@ } }
function Info($el){ $ct=Safe { $el.Current.ControlType.ProgrammaticName -replace '^ControlType\.', '' } ''; return [ordered]@{ name=(Safe { $el.Current.Name } ''); automationId=(Safe { $el.Current.AutomationId } ''); className=(Safe { $el.Current.ClassName } ''); controlType=$ct; processId=(Safe { $el.Current.ProcessId } 0) } }
try{
 LoadUIA
 $i=InObj
 switch($Action){
  'health' { OutJson ([ordered]@{ok=$true; optimized='arena-uia-lite'; platform='Windows'; powershell=$PSVersionTable.PSVersion.ToString()}) }
  'click' { $x=[int]$i.x; $y=[int]$i.y; [ArenaUiaNative]::SetCursorPos($x,$y)|Out-Null; Start-Sleep -Milliseconds 50; [ArenaUiaNative]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 30; [ArenaUiaNative]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero); OutJson ([ordered]@{ok=$true; action='click'; x=$x; y=$y}) }
  'set_value_at_point' { $x=[int]$i.x; $y=[int]$i.y; $value=[string]$i.value; $pt=New-Object Windows.Point($x,$y); $el=[System.Windows.Automation.AutomationElement]::FromPoint($pt); if($null -eq $el){ throw 'no element at point' }; $pat=$null; $method=''; if($el.TryGetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern,[ref]$pat)){ $pat.SetValue($value); $method='ValuePattern' } else { $el.SetFocus(); [System.Windows.Forms.Clipboard]::SetText($value); [System.Windows.Forms.SendKeys]::SendWait('^v'); $method='ClipboardFallback' }; $inf=Info $el; OutJson ([ordered]@{ok=$true; action='set_value_at_point'; method=$method; x=$x; y=$y; element=$inf; length=$value.Length}) }
  'invoke_at_point' { $x=[int]$i.x; $y=[int]$i.y; $pt=New-Object Windows.Point($x,$y); $el=[System.Windows.Automation.AutomationElement]::FromPoint($pt); if($null -eq $el){ throw 'no element at point' }; $pat=$null; $method=''; if($el.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern,[ref]$pat)){ $pat.Invoke(); $method='InvokePattern' } else { [ArenaUiaNative]::SetCursorPos($x,$y)|Out-Null; Start-Sleep -Milliseconds 50; [ArenaUiaNative]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 30; [ArenaUiaNative]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero); $method='ClickFallback' }; $inf=Info $el; OutJson ([ordered]@{ok=$true; action='invoke_at_point'; method=$method; x=$x; y=$y; element=$inf}) }
  default { throw ('unknown action ' + $Action) }
 }
}catch{ OutJson ([ordered]@{ok=$false; action=$Action; error=$_.Exception.Message}); exit 1 }
'@ -split "`r?`n"
W $optTool $optLines
L ('optimized_tool_written=' + (San $optTool))
L ('wcu_backend_exists=' + (Test-Path -LiteralPath $wcuBackend))
L ('test_app_exists=' + (Test-Path -LiteralPath $appScript))
if(-not (Test-Path -LiteralPath $wcuBackend) -or -not (Test-Path -LiteralPath $appScript)){ L 'FINAL_WCU_OPTIMIZED: MISSING_BACKEND_OR_APP'; W $report $script:Lines; exit 0 }
try { Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue } catch { }
$psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$p=$null
try { $p=Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$appScript,'-OutFile',$resultFile) -PassThru; L ('test_app_started_pid=' + $p.Id) } catch { L ('test_app_start_WARN=' + (San $_.Exception.Message)) }
Start-Sleep -Seconds 3
$health=Invoke-JsonTool $optTool 'health' ([pscustomobject]@{})
L ('opt_health_ok=' + $health.ok + ' name=' + (San ([string]$health.optimized)))
$act=Invoke-JsonTool $wcuBackend 'activate_window' ([pscustomobject]@{ windowTitle='Arena WCU Test App' })
L ('wcu_activate_ok=' + $act.ok + $(if($act.error){' error=' + (San ([string]$act.error))}else{''}))
$bb=$null
try{ $bb=$act.window.boundingBox }catch{}
if($bb){ L ('window_box=' + $bb.x + ',' + $bb.y + ' ' + $bb.width + 'x' + $bb.height) }
$setOk=$false; $invokeOk=$false
$marker='WCU_OPTIMIZED_UIA_SET_BY_ARENA_' + (Get-Date -Format 'HHmmss')
if($bb){
    $tx=[int]($bb.x + 120); $ty=[int]($bb.y + 115)
    $set=Invoke-JsonTool $optTool 'set_value_at_point' ([pscustomobject]@{ x=$tx; y=$ty; value=$marker })
    L ('opt_set_value_ok=' + $set.ok + ' method=' + (San ([string]$set.method)) + ' element=' + (San ([string]$set.element.controlType)) + ' x=' + $tx + ' y=' + $ty + $(if($set.error){' error=' + (San ([string]$set.error))}else{''}))
    $setOk=[bool]$set.ok
    Start-Sleep -Milliseconds 500
    $sx=[int]($bb.x + 80); $sy=[int]($bb.y + 235)
    $inv=Invoke-JsonTool $optTool 'invoke_at_point' ([pscustomobject]@{ x=$sx; y=$sy })
    L ('opt_invoke_save_ok=' + $inv.ok + ' method=' + (San ([string]$inv.method)) + ' element=' + (San ([string]$inv.element.controlType)) + ' x=' + $sx + ' y=' + $sy + $(if($inv.error){' error=' + (San ([string]$inv.error))}else{''}))
    $invokeOk=[bool]$inv.ok
}else{ L 'optimized_smoke_skipped=no_window_box' }
Start-Sleep -Seconds 1
$resultText=''
try{ if(Test-Path -LiteralPath $resultFile){ $resultText=Get-Content -LiteralPath $resultFile -Raw -ErrorAction SilentlyContinue } }catch{}
$typedPresent=[bool]($resultText -match [regex]::Escape($marker))
L ('result_file=' + (San $resultFile))
L ('result_typed_present=' + $typedPresent)
try { if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; L 'test_app_closed=True' } } catch { }
if($health.ok -and $act.ok -and $setOk -and $invokeOk -and $typedPresent){ L 'FINAL_WCU_OPTIMIZED: OK_OPTIMIZED_WRAPPER_OPERATED_DESKTOP_APP' }
else { L 'FINAL_WCU_OPTIMIZED: PARTIAL_CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t158 done ---'
exit 0
