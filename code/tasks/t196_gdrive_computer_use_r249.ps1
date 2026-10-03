# t196_gdrive_computer_use_r249.ps1 - round 249.
# Configure Google Drive rclone remote for jzthjyz@gmail.com and run a fresh
# laptop computer-use / Windows MCP smoke test. ASCII-only. No secrets printed.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path
$cloudDir = Join-Path $repo 'results\cloud_interop'
$cuDir = Join-Path $repo 'results\computer_use'
New-Item -ItemType Directory -Force -Path $cloudDir,$cuDir | Out-Null
$gReport = Join-Path $cloudDir 'GDRIVE_SETUP_R249.md'
$cReport = Join-Path $cuDir 'COMPUTER_USE_LAPTOP_R249.md'
$cJson = Join-Path $cuDir 'COMPUTER_USE_LAPTOP_R249.json'
$lines = New-Object System.Collections.Generic.List[string]
$caps = New-Object System.Collections.Generic.List[object]

function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace 'ya29\.[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]' } catch { }
    try { $s = $s -replace '1//[A-Za-z0-9_\.-]+','[REDACTED-OAUTH]' } catch { }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{28,}','[REDACTED]' } catch { }
    try { $s = $s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]','?' } catch { }
    return $s
}
function L([string]$m) { $script:lines.Add($m) | Out-Null; Write-Output $m }
function W([string]$p,[object]$content) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; Set-Content -LiteralPath $p -Encoding UTF8 -Value $content }
function Add-Cap([string]$App,[string]$Backend,[string]$Task,[string]$Result,[string]$Evidence,[string]$Artifact) {
    $script:caps.Add([pscustomobject]@{ computer=$env:COMPUTERNAME; app=$App; backend=$Backend; task=$Task; result=$Result; evidence=(San $Evidence); artifact=(San $Artifact) }) | Out-Null
}
function Run-Capped([string]$Name,[scriptblock]$Block,[int]$TimeoutSec) {
    $job = Start-Job -ScriptBlock $Block
    if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return @{ ok=$false; text='TIMEOUT'; name=$Name }
    }
    $txt = (Receive-Job $job 2>&1 | Out-String).Trim()
    $state = [string]$job.State
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return @{ ok=($state -eq 'Completed'); text=$txt; name=$Name }
}
function Ensure-Clone([string]$Url,[string]$Dest) {
    if (Test-Path -LiteralPath (Join-Path $Dest '.git')) { return 'present' }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return 'git-missing' }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dest) | Out-Null
    $r = Run-Capped ('clone_' + (Split-Path $Dest -Leaf)) { git clone --depth 1 $using:Url $using:Dest 2>&1 | Out-String } 240
    if (Test-Path -LiteralPath (Join-Path $Dest '.git')) { return 'cloned' }
    return ('clone-failed-' + (San $r.text))
}
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
    if ($err) { L ('wcu_stderr_' + $Action + '=' + (San (($err -split "`r?`n")[-1]))) }
    try { return ($out | ConvertFrom-Json) } catch { return @{ ok=$false; raw=$out; parseError=$_.Exception.Message } }
}

L '# Google Drive + computer-use setup r249'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
L ('host=' + $env:COMPUTERNAME)
L ''
L '## Google Drive rclone setup'
L 'remote=gdrive_jzthjyz:'
L 'account_hint=jzthjyz@gmail.com'
L 'scope=drive'
L 'probe_write_allowed=True'

# Put a visible local instruction in case rclone opens a browser during the watcher run.
try {
    $note = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Arena_Google_Drive_OAuth_Instructions.txt'
    Set-Content -LiteralPath $note -Encoding UTF8 -Value @(
        'Arena is connecting Google Drive via rclone.',
        'Use account: jzthjyz@gmail.com',
        'Permission scope: drive',
        'If a browser authorization page opens, approve it locally.',
        'Do not paste passwords, OAuth tokens, or 2FA codes into chat.'
    )
    Start-Process -FilePath 'notepad.exe' -ArgumentList $note -ErrorAction SilentlyContinue | Out-Null
    L ('oauth_instruction_note=' + (San $note))
} catch { L ('oauth_instruction_note_WARN=' + (San $_.Exception.Message)) }

$setupScript = Join-Path $repo 'skills\cloud-interop\scripts\setup-gdrive-rclone.ps1'
$healthScript = Join-Path $repo 'skills\cloud-interop\scripts\interop-health.ps1'
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$setupText = ''
if (Test-Path -LiteralPath $setupScript) {
    $setup = Run-Capped 'gdrive_setup' { & $using:psExe -NoProfile -ExecutionPolicy Bypass -File $using:setupScript -RemoteName 'gdrive_jzthjyz' -AccountEmail 'jzthjyz@gmail.com' -Scope 'drive' 2>&1 | Out-String } 1500
    $setupText = [string]$setup.text
    foreach ($ln in (($setupText -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 80)) { L ('setup| ' + (San $ln)) }
} else {
    L 'setup_script_missing=True'
}
$healthText = ''
if (Test-Path -LiteralPath $healthScript) {
    $health = Run-Capped 'interop_health' { & $using:psExe -NoProfile -ExecutionPolicy Bypass -File $using:healthScript -GDriveRemote 'gdrive_jzthjyz' -ProbeWrite 2>&1 | Out-String } 420
    $healthText = [string]$health.text
    foreach ($ln in (($healthText -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 80)) { L ('health| ' + (San $ln)) }
} else {
    L 'health_script_missing=True'
}
$gdriveReady = ($setupText -match 'GDRIVE_RCLONE_READY=True' -or $healthText -match 'gdrive_about_ok=True')
$probeOk = ($healthText -match 'gdrive_probe_write=True')
L ('GDRIVE_RCLONE_READY=' + $gdriveReady)
L ('GDRIVE_PROBE_WRITE_OK=' + $probeOk)
L ''
W $gReport $lines

# Fresh laptop computer-use / Windows MCP smoke.
$cuLines = New-Object System.Collections.Generic.List[string]
function CL([string]$m) { $script:cuLines.Add($m) | Out-Null; Write-Output $m }
CL '# Laptop computer-use / Windows MCP smoke r249'
CL ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
CL ('host=' + $env:COMPUTERNAME)
$lab = 'E:\0mcp-agv-arena-optimized'
$github = Join-Path $lab 'github'
$tools = Join-Path $lab 'tools'
$smoke = Join-Path $lab 'smoke'
New-Item -ItemType Directory -Force -Path $github,$tools,$smoke | Out-Null
CL ('lab_root=' + (San $lab))
$projects = @(
    @{ name='windows-computer-use'; url='https://github.com/cgissing/windows-computer-use.git'; dest=(Join-Path $github 'windows-computer-use') },
    @{ name='Windows-MCP'; url='https://github.com/CursorTouch/Windows-MCP.git'; dest=(Join-Path $github 'Windows-MCP') },
    @{ name='pywinauto-mcp'; url='https://github.com/sandraschi/pywinauto-mcp.git'; dest=(Join-Path $github 'pywinauto-mcp') }
)
foreach ($p in $projects) {
    $st = Ensure-Clone $p.url $p.dest
    CL ('project|' + $p.name + '|status=' + (San $st) + '|path=' + (San $p.dest))
    Add-Cap $p.name 'E-drive install' 'install/presence check' $(if($st -match 'present|cloned'){'OK'}else{'CHECK_REPORT'}) $st $p.dest
}
$wcuBackend = Join-Path $github 'windows-computer-use\plugins\windows-computer-use\scripts\windows-uia.ps1'
$wcuOk = $false
$markerPresent = $false
if (Test-Path -LiteralPath $wcuBackend) {
    $appScript = Join-Path $tools 'arena_wcu_button_app_r249.ps1'
    $resultFile = Join-Path $smoke 'wcu_find_invoke_result_r249.txt'
    $marker = 'WCU_R249_' + (Get-Date -Format 'HHmmss')
    @'
param([string]$OutFile,[string]$Marker)
$ErrorActionPreference='Continue'
Add-Type -AssemblyName System.Windows.Forms
$form=New-Object Windows.Forms.Form
$form.Text='Arena WCU Button App R249'
$form.Width=520; $form.Height=240; $form.StartPosition='CenterScreen'
$label=New-Object Windows.Forms.Label
$label.Left=30; $label.Top=30; $label.Width=440; $label.Text='Computer-use UIA invoke proof on E drive'
$btn=New-Object Windows.Forms.Button
$btn.Text='Write Marker'; $btn.Left=30; $btn.Top=80; $btn.Width=150; $btn.Height=44
$btn.Add_Click({ [IO.File]::WriteAllText($OutFile,$Marker,(New-Object Text.UTF8Encoding($false))); $form.Close() })
$form.Controls.Add($label); $form.Controls.Add($btn)
[void]$form.ShowDialog()
'@ | Set-Content -LiteralPath $appScript -Encoding UTF8
    Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
    $p = $null
    try { $p = Start-Process -FilePath $psExe -ArgumentList @('-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',$appScript,'-OutFile',$resultFile,'-Marker',$marker) -PassThru; Start-Sleep -Seconds 3 } catch { CL ('wcu_app_start_WARN=' + (San $_.Exception.Message)) }
    $health = Invoke-Wcu $wcuBackend 'health' ([pscustomobject]@{})
    $act = Invoke-Wcu $wcuBackend 'activate_window' ([pscustomobject]@{ windowTitle='Arena WCU Button App R249' })
    $find = Invoke-Wcu $wcuBackend 'find' ([pscustomobject]@{ scope='active_window'; windowTitle='Arena WCU Button App R249'; activate=$true; query='Write Marker'; controlType='Button'; maxDepth=6; maxResults=5 })
    $btnId = ''
    try { if ($find.ok -and $find.results.Count -gt 0) { $btnId = [string]$find.results[0].id } } catch { }
    $inv = $null
    if ($btnId) { $inv = Invoke-Wcu $wcuBackend 'invoke' ([pscustomobject]@{ elementId=$btnId; fallbackClick=$true; windowTitle='Arena WCU Button App R249'; activate=$true }) }
    Start-Sleep -Seconds 2
    $txt = ''
    if (Test-Path -LiteralPath $resultFile) { $txt = Get-Content -LiteralPath $resultFile -Raw -ErrorAction SilentlyContinue }
    $markerPresent = [bool]($txt -match [regex]::Escape($marker))
    try { if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } } catch { }
    $wcuOk = [bool]($health.ok -and $act.ok -and $find.ok -and $inv.ok -and $markerPresent)
    CL ('wcu_health=' + $health.ok + ' activate=' + $act.ok + ' find=' + $find.ok + ' button_id=' + (San $btnId) + ' invoke=' + $(if($inv){$inv.ok}else{$false}) + ' marker=' + $markerPresent)
    Add-Cap 'Lab WinForms app' 'windows-computer-use MCP/UIA' 'find button and invoke it' $(if($wcuOk){'OK'}else{'CHECK_REPORT'}) ('health=' + $health.ok + ';activate=' + $act.ok + ';find=' + $find.ok + ';invoke=' + $(if($inv){$inv.ok}else{$false}) + ';marker=' + $markerPresent) $resultFile
} else {
    CL ('wcu_backend_missing=' + (San $wcuBackend))
    Add-Cap 'Lab WinForms app' 'windows-computer-use MCP/UIA' 'find button and invoke it' 'NOT_READY' 'backend missing' $wcuBackend
}

# Antigravity and common UI automation surface checks.
$agExe = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'
$agPresent = Test-Path -LiteralPath $agExe
CL ('antigravity_exe_present=' + $agPresent)
Add-Cap 'Antigravity' 'terminal/GUI surface' 'detect installed executable' $(if($agPresent){'OK'}else{'NOT_FOUND'}) $agPresent $agExe
foreach ($pg in @('KWPS.Application','KET.Application','KWPP.Application')) {
    $ok = $false
    try { $o = New-Object -ComObject $pg; $ok = $true; try { $o.Quit() } catch { } } catch { }
    CL ('wps_com|' + $pg + '=' + $ok)
    Add-Cap 'WPS Office' 'COM automation' ('instantiate ' + $pg) $(if($ok){'OK'}else{'NOT_READY'}) $ok $pg
}
$wins = @(Get-Process | Where-Object { $_.MainWindowTitle } | Select-Object -First 30 ProcessName,Id,MainWindowTitle)
CL ('open_window_count=' + $wins.Count)
foreach ($w in ($wins | Select-Object -First 12)) { CL ('window|' + (San $w.ProcessName) + '|title=' + (San $w.MainWindowTitle)) }
CL ''
CL '## Capability list'
foreach ($c in $caps) { CL ('cap|' + $c.computer + '|' + $c.app + '|' + $c.backend + '|' + $c.task + '|' + $c.result + '|' + $c.evidence + '|' + $c.artifact) }
CL ('WCU_UIA_INVOKE_OK=' + $wcuOk)
CL ('COMPUTER_USE_LAPTOP_OK=' + $wcuOk)
W $cReport $cuLines
[ordered]@{ time=(Get-Date).ToString('s'); computer=$env:COMPUTERNAME; gdriveReady=$gdriveReady; gdriveProbeWrite=$probeOk; wcuUiaInvokeOk=$wcuOk; capabilities=$caps } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cJson -Encoding UTF8

L ('computer_use_report=' + (San $cReport))
L ('computer_use_json=' + (San $cJson))
L ('COMPUTER_USE_LAPTOP_OK=' + $wcuOk)
L ('GDRIVE_SETUP_OK=' + ($gdriveReady -and $probeOk))
W $gReport $lines

if (-not $gdriveReady) { exit 2 }
if (-not $probeOk) { exit 3 }
if (-not $wcuOk) { exit 4 }
exit 0
