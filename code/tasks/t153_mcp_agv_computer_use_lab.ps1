# t153_mcp_agv_computer_use_lab.ps1 - round 196.
# Inspect laptop 0mcp-agv, create an isolated optimized lab folder, clone
# selected GitHub computer-use projects without configuring Antigravity, and
# run a safe Notepad GUI-control smoke test. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) {
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function WA([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllLines($p, $lines, (New-Object System.Text.ASCIIEncoding)) }
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
    foreach($ln in (($txt -split "`r?`n") | Select-Object -First 120)) { if($ln.Trim()){ L ('RUN_OUT|' + $Name + '| ' + (San $ln)) } }
    return @{ ok=$true; text=$txt }
}

$script:Lines=@()
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$mainReport = Join-Path $outDir 'MCP_AGV_COMPUTER_USE_LAB_R196.md'
L '--- task t153: 0mcp-agv survey + isolated computer-use lab ---'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer=' + $env:COMPUTERNAME + ' user=' + $env:USERNAME)

# Locate 0mcp-agv without changing it.
$candidates = @()
try { $candidates += (Join-Path $env:USERPROFILE '0mcp-agv') } catch { }
foreach($d in @('C:\','D:\','E:\','F:\')) { $candidates += (Join-Path $d '0mcp-agv') }
try { $candidates += (Join-Path ([Environment]::GetFolderPath('Desktop')) '0mcp-agv') } catch { }
try {
    foreach($drive in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
        foreach($hit in @(Get-ChildItem -LiteralPath $drive.Root -Directory -Filter '0mcp-agv' -ErrorAction SilentlyContinue | Select-Object -First 3)) { $candidates += $hit.FullName }
    }
} catch { }
$agvPaths = @($candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
L ('mcp_agv_paths_found=' + $agvPaths.Count)
foreach($p in $agvPaths){ L ('mcp_agv_path=' + (San $p)) }

# Create a sibling/isolated lab folder. Do not write into 0mcp-agv.
$labRoot = Join-Path $env:USERPROFILE '0mcp-agv-arena-optimized'
$toolsDir = Join-Path $labRoot 'tools'
$reportsDir = Join-Path $labRoot 'reports'
$reposDir = Join-Path $labRoot 'github'
$smokeDir = Join-Path $labRoot 'smoke'
foreach($d in @($labRoot,$toolsDir,$reportsDir,$reposDir,$smokeDir)){ New-Item -ItemType Directory -Force -Path $d | Out-Null }
L ('lab_root=' + (San $labRoot))

# Inventory source folder: names only, no content dump.
$inv = @()
$inv += '# 0mcp-agv source inventory'
$inv += ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$inv += ''
if($agvPaths.Count -eq 0){ $inv += 'No 0mcp-agv folder found in common locations.' }
foreach($root in $agvPaths){
    $inv += ('## Source: ' + $root)
    try {
        $dirs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 80)
        $files = @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 100)
        $inv += '### Top-level directories'
        foreach($d in $dirs){ $inv += ('- ' + $d.Name) }
        $inv += '### Top-level files'
        foreach($f in $files){ $inv += ('- ' + $f.Name + ' (' + $f.Length + ' bytes)') }
        $all = @(Get-ChildItem -LiteralPath $root -Recurse -Depth 4 -File -ErrorAction SilentlyContinue | Select-Object -First 2000)
        $inv += ('total_files_sampled=' + $all.Count)
        $exts = $all | Group-Object Extension | Sort-Object Count -Descending | Select-Object -First 20
        $inv += '### Extension counts'
        foreach($e in $exts){ $name = if($e.Name){$e.Name}else{'(none)'}; $inv += ('- ' + $name + ': ' + $e.Count) }
        $interesting = $all | Where-Object { $_.Extension -match '^\.(ps1|py|js|mjs|ts|json|md|toml|yaml|yml)$' -or $_.Name -match 'agent|mcp|task|manifest|readme|package' } | Sort-Object FullName | Select-Object -First 260
        $inv += '### Interesting script/config files (names only)'
        foreach($f in $interesting){ $rel = $f.FullName.Substring($root.Length).TrimStart('\'); $inv += ('- ' + $rel + ' (' + $f.Length + ' bytes)') }
        foreach($pkg in @($all | Where-Object { $_.Name -eq 'package.json' } | Select-Object -First 8)){
            try{
                $j = Get-Content -LiteralPath $pkg.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                $inv += ('### package.json: ' + $pkg.FullName.Substring($root.Length).TrimStart('\'))
                if($j.name){ $inv += ('name=' + $j.name) }
                if($j.scripts){ $inv += ('scripts=' + ((@($j.scripts.PSObject.Properties.Name) | Sort-Object) -join ', ')) }
            } catch { $inv += ('package_parse_warn=' + $pkg.Name + ' ' + (San $_.Exception.Message)) }
        }
    } catch { $inv += ('inventory_warn=' + (San $_.Exception.Message)) }
}
W (Join-Path $reportsDir 'source_inventory.md') $inv
L ('inventory_report=' + (San (Join-Path $reportsDir 'source_inventory.md')))

# Write an optimization plan and safe local tooling.
$readme = @(
'# 0mcp-agv Arena Optimized Lab',
'',
'This folder is intentionally separate from the existing 0mcp-agv folder so Antigravity can keep using its original tasks and agents unchanged.',
'',
'What this lab contains:',
'- reports/source_inventory.md: read-only inventory of the existing 0mcp-agv folder.',
'- tools/notepad_gui_smoke.ps1: safe GUI-control test that opens Notepad on a lab-owned text file, types a marker, saves, and closes.',
'- tools/window_inventory.ps1: read-only process/window inventory.',
'- github/: cloned computer-use/MCP projects for inspection only. No Antigravity/Codex/Claude config is changed automatically.',
'',
'Recommended optimization direction:',
'1. Keep original Antigravity artifacts read-only.',
'2. Build small, testable tools first: window inventory, click/type wrappers, screenshot capture, and app-specific scripts.',
'3. Add MCP server integration only after the tools are proven safe, with active-window scope and no credential/clipboard logging.',
'4. Use scheduled tasks only for explicit keepalive helpers such as the Antigravity proxy bridge, not for experimental agents.',
'',
'GitHub projects staged for evaluation:',
'- cgissing/windows-computer-use: native Windows computer-use MCP plugin/server.',
'- CursorTouch/Windows-MCP: lightweight Windows MCP server for application control and UI interaction.',
'- anthropics/claude-quickstarts computer-use-demo: reference computer-use loop; noted because it is Docker/Linux-desktop oriented and not ideal for controlling native Windows apps directly.',
''
)
W (Join-Path $labRoot 'README.md') $readme

$windowInv = @'
$ErrorActionPreference = 'Continue'
Get-Process | Where-Object { $_.MainWindowTitle } | Sort-Object ProcessName | Select-Object ProcessName,Id,MainWindowTitle,Path | Format-Table -AutoSize
'@ -split "`r?`n"
W (Join-Path $toolsDir 'window_inventory.ps1') $windowInv

$notepadSmoke = @'
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$smoke = Join-Path $root 'smoke'
New-Item -ItemType Directory -Force -Path $smoke | Out-Null
$file = Join-Path $smoke 'notepad_gui_smoke.txt'
$marker = 'ARENA_NOTEPAD_GUI_SMOKE_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
Set-Content -LiteralPath $file -Encoding UTF8 -Value @('initial line from lab file', $marker)
$p = Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $file + '"') -PassThru
Start-Sleep -Seconds 2
$ws = New-Object -ComObject WScript.Shell
$ok = $false
for($i=0; $i -lt 10; $i++){
    if($ws.AppActivate((Split-Path $file -Leaf))){ $ok = $true; break }
    Start-Sleep -Milliseconds 500
}
if($ok){
    $typed = ' GUI_TYPED_BY_ARENA_' + (Get-Date -Format 'HHmmss')
    $ws.SendKeys('^{END}')
    Start-Sleep -Milliseconds 200
    $ws.SendKeys('{ENTER}' + $typed)
    Start-Sleep -Milliseconds 300
    $ws.SendKeys('^s')
    Start-Sleep -Seconds 1
    $ws.SendKeys('%{F4}')
    Start-Sleep -Seconds 1
}
try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { }
$text = Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
$result = [pscustomobject]@{ app='notepad'; appactivate=$ok; file=$file; marker_present=($text -match [regex]::Escape($marker)); typed_present=($text -match 'GUI_TYPED_BY_ARENA') }
$result | ConvertTo-Json -Compress
'@ -split "`r?`n"
W (Join-Path $toolsDir 'notepad_gui_smoke.ps1') $notepadSmoke
L 'lab_files_written=README tools/window_inventory tools/notepad_gui_smoke'

# Environment check.
foreach($cmd in @('git','node','npm','py','python')){
    try { $v = (& $cmd --version 2>&1 | Out-String).Trim(); if($v){ L ('tool_' + $cmd + '=' + (San (($v -split "`r?`n")[0]))) } }
    catch { L ('tool_' + $cmd + '=missing') }
}

# Clone selected GitHub projects into isolated github/ only.
$projects = @(
    @{ name='windows-computer-use'; url='https://github.com/cgissing/windows-computer-use.git' },
    @{ name='Windows-MCP'; url='https://github.com/CursorTouch/Windows-MCP.git' }
)
foreach($pr in $projects){
    $dest = Join-Path $reposDir $pr.name
    if(Test-Path -LiteralPath (Join-Path $dest '.git')) { L ('git_repo_exists=' + $pr.name) }
    else {
        $url = $pr.url; $d = $dest
        $r = Run-Capped ('git_clone_' + $pr.name) { git clone --depth 1 $using:url $using:d 2>&1 | Out-String } 240
        L ('git_clone_result=' + $pr.name + ' ok=' + $r.ok)
    }
    if(Test-Path -LiteralPath (Join-Path $dest '.git')){
        try { $head = (& git -C $dest rev-parse --short HEAD 2>&1 | Out-String).Trim(); L ('git_repo_head=' + $pr.name + ' ' + (San $head)) } catch { }
    }
}

# Sparse-clone just the Anthropic computer-use-demo folder if possible; skip if it is too slow.
$anth = Join-Path $reposDir 'claude-quickstarts-computer-use-demo'
if(-not (Test-Path -LiteralPath (Join-Path $anth '.git'))){
    $r = Run-Capped 'git_sparse_anthropic_computer_use_demo' {
        git clone --depth 1 --filter=blob:none --sparse https://github.com/anthropics/claude-quickstarts.git $using:anth 2>&1 | Out-String
        if(Test-Path -LiteralPath (Join-Path $using:anth '.git')){ git -C $using:anth sparse-checkout set computer-use-demo 2>&1 | Out-String }
    } 240
    L ('git_sparse_result=claude-quickstarts computer-use-demo ok=' + $r.ok)
} else { L 'git_repo_exists=claude-quickstarts-computer-use-demo' }

# Try the windows-computer-use verification script if node is available.
$wcu = Join-Path $reposDir 'windows-computer-use'
$verify = Join-Path $wcu 'plugins\windows-computer-use\scripts\verify-plugin.mjs'
if((Test-Path -LiteralPath $verify) -and (Get-Command node -ErrorAction SilentlyContinue)){
    $verifyCopy = Join-Path $reportsDir 'windows-computer-use-verify.txt'
    $vpath = $verify
    $r = Run-Capped 'windows_computer_use_verify' { node $using:vpath 2>&1 | Tee-Object -FilePath $using:verifyCopy | Out-String } 180
    L ('windows_computer_use_verify_ok=' + $r.ok)
} else { L ('windows_computer_use_verify_skipped exists=' + (Test-Path -LiteralPath $verify)) }

# Safe GUI software-control smoke test using Notepad.
$smokeScript = Join-Path $toolsDir 'notepad_gui_smoke.ps1'
$r = Run-Capped 'notepad_gui_smoke' { powershell -NoProfile -ExecutionPolicy Bypass -File $using:smokeScript 2>&1 | Out-String } 60
$smokeJson = (($r.text -split "`r?`n") | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
if($smokeJson){
    try { $so = $smokeJson | ConvertFrom-Json; L ('notepad_smoke_appactivate=' + $so.appactivate + ' marker_present=' + $so.marker_present + ' typed_present=' + $so.typed_present + ' file=' + (San $so.file)) } catch { L ('notepad_smoke_parse_warn=' + (San $_.Exception.Message)) }
}

# Optional Python package probe and pywinauto sample (do not require success).
$pycmd = $null
foreach($c in @('py','python')){ if(Get-Command $c -ErrorAction SilentlyContinue){ $pycmd=$c; break } }
if($pycmd){
    $pySmoke = Join-Path $toolsDir 'pywinauto_notepad_smoke.py'
    $pyLines = @(
'import json, os, subprocess, sys, time',
'root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))',
'smoke = os.path.join(root, "smoke")',
'os.makedirs(smoke, exist_ok=True)',
'out = os.path.join(smoke, "pywinauto_notepad_smoke.txt")',
'res = {"pywinauto_available": False, "started": False, "wrote": False, "file": out}',
'try:',
'    import pywinauto',
'    from pywinauto.application import Application',
'    res["pywinauto_available"] = True',
'    app = Application(backend="uia").start("notepad.exe " + out)',
'    res["started"] = True',
'    time.sleep(2)',
'    # Modern and classic Notepad expose different edit controls; use keyboard fallback.',
'    app.top_window().type_keys("Arena pywinauto GUI smoke test", with_spaces=True)',
'    app.top_window().type_keys("^s")',
'    time.sleep(1)',
'    app.kill()',
'    res["wrote"] = os.path.exists(out)',
'except Exception as e:',
'    res["error"] = str(e)[:300]',
'print(json.dumps(res, ensure_ascii=False))'
    )
    [IO.File]::WriteAllLines($pySmoke, $pyLines, (New-Object System.Text.UTF8Encoding($false)))
    $venv = Join-Path $labRoot '.venv'
    if(-not (Test-Path -LiteralPath (Join-Path $venv 'Scripts\python.exe'))){
        $pname = $pycmd; $vdir = $venv
        Run-Capped 'python_venv_create' { & $using:pname -3 -m venv $using:vdir 2>&1 | Out-String } 180 | Out-Null
    }
    $venvPy = Join-Path $venv 'Scripts\python.exe'
    if(Test-Path -LiteralPath $venvPy){
        $hasPyw = (& $venvPy -c "import importlib.util; print(importlib.util.find_spec('pywinauto') is not None)" 2>&1 | Out-String).Trim()
        if($hasPyw -notmatch 'True'){
            $vp = $venvPy
            Run-Capped 'pip_install_pywinauto' { & $using:vp -m pip install --disable-pip-version-check pywinauto psutil six 2>&1 | Out-String } 240 | Out-Null
        }
        $vp = $venvPy; $psm = $pySmoke
        $rr = Run-Capped 'pywinauto_notepad_smoke' { & $using:vp $using:psm 2>&1 | Out-String } 90
        $last = (($rr.text -split "`r?`n") | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
        if($last){ L ('pywinauto_smoke_result=' + (San $last)) }
    } else { L 'pywinauto_smoke_skipped=no_venv_python' }
} else { L 'pywinauto_smoke_skipped=no_python' }

# Write summary plan.
$plan = @(
'# Optimization candidates',
'',
'Safe changes already made:',
'- Created isolated lab root: ' + $labRoot,
'- Did not modify the original 0mcp-agv folder.',
'- Did not register any new MCP server inside Antigravity or Codex automatically.',
'',
'Good optimization candidates:',
'1. Convert repeated PowerShell task scripts into idempotent modules: path discovery, process control, settings JSON update, scheduled task creation, and report writing.',
'2. Add a safe GUI automation layer using Windows UI Automation / pywinauto with active-window scope.',
'3. Add an MCP server only after local smoke tests pass; keep it in this lab folder and use explicit allowlists.',
'4. Keep all node subscriptions and secrets under %USERPROFILE%\.arena-private, never in Git or public logs.',
'5. For desktop software, prefer app-specific adapters before broad screen-control agents.',
'',
'Projects evaluated:',
'- windows-computer-use: best match for native Windows app control through MCP.',
'- Windows-MCP: good lightweight MCP option for Windows operations.',
'- Anthropic computer-use-demo: useful reference, but Docker/Linux desktop focused rather than native Windows app control.',
''
)
W (Join-Path $reportsDir 'optimization_plan.md') $plan
L ('optimization_plan=' + (San (Join-Path $reportsDir 'optimization_plan.md')))
W $mainReport $script:Lines
L ('main_report=' + (San $mainReport))
L 'FINAL_MCP_AGV_LAB: CREATED_ISOLATED_LAB_AND_TESTED_GUI_CONTROL'
L '--- task t153 done ---'
exit 0
