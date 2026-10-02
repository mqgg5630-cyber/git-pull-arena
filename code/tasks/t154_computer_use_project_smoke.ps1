# t154_computer_use_project_smoke.ps1 - round 197.
# Use the cloned GitHub windows-computer-use backend to operate Notepad in the
# isolated lab folder; collect 0mcp-agv inventory/plan reports. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function Run-Capped([string]$Name, [scriptblock]$Block, [int]$TimeoutSec) {
    L ('RUN_START=' + $Name)
    $job = Start-Job -ScriptBlock $Block
    if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        L ('RUN_TIMEOUT=' + $Name + ' seconds=' + $TimeoutSec)
        return @{ ok=$false; text='TIMEOUT' }
    }
    $txt = (Receive-Job $job | Out-String).Trim()
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    foreach($ln in (($txt -split "`r?`n") | Select-Object -First 100)) { if($ln.Trim()){ L ('RUN_OUT|' + $Name + '| ' + (San $ln)) } }
    return @{ ok=$true; text=$txt }
}
function Invoke-Wcu([string]$Backend, [string]$Action, [object]$Payload) {
    $json = ($Payload | ConvertTo-Json -Depth 20 -Compress)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
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
    if (-not $p.WaitForExit(30000)) { try { $p.Kill() } catch { }; return @{ ok=$false; raw='TIMEOUT' } }
    $out = $p.StandardOutput.ReadToEnd().Trim()
    $err = $p.StandardError.ReadToEnd().Trim()
    if($err){ L ('wcu_stderr_' + $Action + '=' + (San (($err -split "`r?`n")[-1]))) }
    try { return ($out | ConvertFrom-Json) } catch { return @{ ok=$false; raw=$out; parseError=$_.Exception.Message } }
}

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report=Join-Path $outDir 'COMPUTER_USE_PROJECT_SMOKE_R197.md'
L '--- task t154: windows-computer-use actual GUI smoke ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)
$labRoot=Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$reportsDir=Join-Path $labRoot 'reports'
$smokeDir=Join-Path $labRoot 'smoke'
$configDir=Join-Path $labRoot 'configs'
New-Item -ItemType Directory -Force -Path $smokeDir,$configDir | Out-Null
L ('lab_root=' + (San $labRoot))

# Collect existing inventory/plan/verification files into repository results.
$collect = @{
    'source_inventory.md' = 'source_inventory_r196.md';
    'optimization_plan.md' = 'optimization_plan_r196.md';
    'windows-computer-use-verify.txt' = 'windows-computer-use-verify_r196.txt'
}
foreach($kv in $collect.GetEnumerator()){
    $src=Join-Path $reportsDir $kv.Key
    $dst=Join-Path $outDir $kv.Value
    if(Test-Path -LiteralPath $src){ try{ Copy-Item -LiteralPath $src -Destination $dst -Force; L ('collected=' + $kv.Value) }catch{ L ('collect_WARN=' + $kv.Key + ' ' + (San $_.Exception.Message)) } }
    else{ L ('collect_missing=' + $kv.Key) }
}

$wcuRoot=Join-Path $labRoot 'github\windows-computer-use\plugins\windows-computer-use'
$backend=Join-Path $wcuRoot 'scripts\windows-uia.ps1'
$server=Join-Path $wcuRoot 'mcp\server.mjs'
L ('wcu_backend_exists=' + (Test-Path -LiteralPath $backend))
L ('wcu_server_exists=' + (Test-Path -LiteralPath $server))
if(Test-Path -LiteralPath $server){
    $sample = @{
        mcpServers = @{
            'windows-computer-use' = @{
                command = 'node'
                args = @($server)
                env = @{ WINDOWS_COMPUTER_USE_SCOPE = 'active_window' }
            }
        }
    } | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText((Join-Path $configDir 'windows-computer-use-mcp-sample.json'), $sample + "`r`n", (New-Object Text.UTF8Encoding($false)))
    L ('sample_config_written=' + (San (Join-Path $configDir 'windows-computer-use-mcp-sample.json')))
}

$wcuOk=$false
if(Test-Path -LiteralPath $backend){
    $health = Invoke-Wcu $backend 'health' ([pscustomobject]@{})
    L ('wcu_health_ok=' + $health.ok + ' platform=' + (San ([string]$health.platform)) + ' screenshot=' + $health.screenshot)
    # Start Notepad on a lab-owned file, then type/save/close through the GitHub backend.
    $file=Join-Path $smokeDir 'wcu_notepad_smoke.txt'
    $marker='WCU_NOTEPAD_MARKER_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
    [IO.File]::WriteAllText($file, "initial line`r`n$marker`r`n", (New-Object Text.UTF8Encoding($false)))
    $p=$null
    try{ $p=Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $file + '"') -PassThru; L ('notepad_started_pid=' + $p.Id) }catch{ L ('notepad_start_WARN=' + (San $_.Exception.Message)) }
    Start-Sleep -Seconds 3
    $act=Invoke-Wcu $backend 'activate_window' ([pscustomobject]@{ windowTitle = (Split-Path $file -Leaf) })
    L ('wcu_activate_ok=' + $act.ok)
    $typed='WCU_TYPED_BY_ARENA_' + (Get-Date -Format 'HHmmss')
    $typ=Invoke-Wcu $backend 'type_text' ([pscustomobject]@{ text = "`r`n" + $typed + "`r`n"; restoreClipboard = $true })
    L ('wcu_type_ok=' + $typ.ok + ' length=' + $typ.length)
    Start-Sleep -Milliseconds 500
    $sav=Invoke-Wcu $backend 'keypress' ([pscustomobject]@{ keys = @('CTRL','S') })
    L ('wcu_save_ok=' + $sav.ok)
    Start-Sleep -Seconds 1
    $cls=Invoke-Wcu $backend 'keypress' ([pscustomobject]@{ keys = @('ALT','F4') })
    L ('wcu_close_ok=' + $cls.ok)
    Start-Sleep -Seconds 1
    try{ if($p -and -not $p.HasExited){ Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; L 'notepad_force_closed=True' } }catch{}
    $txt=Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
    $markerPresent=[bool]($txt -match [regex]::Escape($marker))
    $typedPresent=[bool]($txt -match [regex]::Escape($typed))
    L ('wcu_notepad_file=' + (San $file))
    L ('wcu_notepad_marker_present=' + $markerPresent + ' typed_present=' + $typedPresent)
    $wcuOk = [bool]($health.ok -and $act.ok -and $typ.ok -and $sav.ok -and $typedPresent)
} else { L 'wcu_smoke_skipped=no_backend' }

# Fixed direct PowerShell SendKeys fallback using explicit powershell.exe invocation.
$directScript=Join-Path $labRoot 'tools\notepad_gui_smoke.ps1'
if(Test-Path -LiteralPath $directScript){
    $psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $ds=$directScript
    $r=Run-Capped 'direct_notepad_gui_smoke_fixed' { & $using:psExe -NoProfile -ExecutionPolicy Bypass -File $using:ds 2>&1 | Out-String } 90
    $json=(($r.text -split "`r?`n") | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
    if($json){ try{ $o=$json|ConvertFrom-Json; L ('direct_notepad_appactivate=' + $o.appactivate + ' marker_present=' + $o.marker_present + ' typed_present=' + $o.typed_present) }catch{ L ('direct_notepad_parse_WARN=' + (San $_.Exception.Message)) } }
} else { L 'direct_notepad_smoke_skipped=no_script' }

# Improved pywinauto probe: connect through Desktop rather than assuming the spawned process owns the window.
$venvPy=Join-Path $labRoot '.venv\Scripts\python.exe'
if(Test-Path -LiteralPath $venvPy){
    $pyScript=Join-Path $labRoot 'tools\pywinauto_notepad_smoke2.py'
    $pyLines=@(
'import json, os, subprocess, time',
'root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))',
'smoke = os.path.join(root, "smoke")',
'os.makedirs(smoke, exist_ok=True)',
'out = os.path.join(smoke, "pywinauto_notepad_smoke2.txt")',
'marker = "PYWINAUTO2_MARKER"',
'open(out, "w", encoding="utf-8").write(marker + "\\n")',
'res = {"pywinauto_available": False, "started": False, "typed_present": False, "file": out}',
'typed = "PYWINAUTO2_TYPED_BY_ARENA"',
'try:',
'    from pywinauto import Desktop',
'    from pywinauto.keyboard import send_keys',
'    res["pywinauto_available"] = True',
'    p = subprocess.Popen(["notepad.exe", out])',
'    res["started"] = True',
'    time.sleep(3)',
'    win = Desktop(backend="uia").window(title_re=".*pywinauto_notepad_smoke2.*|.*Notepad.*|.*\\u8bb0\\u4e8b.*")',
'    win.set_focus()',
'    send_keys("^{END}")',
'    send_keys("{ENTER}" + typed, with_spaces=True)',
'    send_keys("^s")',
'    time.sleep(1)',
'    send_keys("%{F4}")',
'    time.sleep(1)',
'    try:',
'        p.kill()',
'    except Exception:',
'        pass',
'    txt = open(out, "r", encoding="utf-8", errors="ignore").read()',
'    res["typed_present"] = typed in txt',
'except Exception as e:',
'    res["error"] = str(e)[:300]',
'print(json.dumps(res, ensure_ascii=False))'
    )
    [IO.File]::WriteAllLines($pyScript, $pyLines, (New-Object Text.UTF8Encoding($false)))
    $vp=$venvPy; $psm=$pyScript
    $rr=Run-Capped 'pywinauto_notepad_smoke2' { & $using:vp $using:psm 2>&1 | Out-String } 120
    $last=(($rr.text -split "`r?`n") | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
    if($last){ L ('pywinauto2_result=' + (San $last)) }
} else { L 'pywinauto2_skipped=no_venv' }

if($wcuOk){ L 'FINAL_COMPUTER_USE_SMOKE: OK_WINDOWS_COMPUTER_USE_OPERATED_NOTEPAD' }
else { L 'FINAL_COMPUTER_USE_SMOKE: PARTIAL_CHECK_REPORT' }
W $report $script:Lines
L ('main_report=' + (San $report))
L '--- task t154 done ---'
exit 0
