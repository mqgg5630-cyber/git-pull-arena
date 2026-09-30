# t40_mcp_n8n_r_survey.ps1 - round 50 task: survey (1) the MCP folder on E:
# (0mcp-agv), (2) n8n docker status, (3) R installations (delete OLD Windows
# versions if multiple are unambiguous; WSL R = report only).
# Writes findings to results/status/r50_findings.md (embedded in the report
# by t41). READ-ONLY except the R-version deletion (approved) + findings file.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t40: MCP folder + n8n + R survey ---'
$find = New-Object System.Text.StringBuilder

# ---------------------------------------------------- 1. MCP folder
Write-Output '--- 1. MCP folder on E: ---'
$mcpDir = ''
if (Test-Path -LiteralPath 'E:\0mcp-agv' -PathType Container) { $mcpDir = 'E:\0mcp-agv' }
if (-not $mcpDir) {
    try { $mcpDir = [string](Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'mcp' } | Select-Object -First 1).FullName } catch { }
}
if ($mcpDir) {
    Write-Output ('   located: ' + $mcpDir)
    $subs = @(Get-ChildItem -LiteralPath $mcpDir -Directory -ErrorAction SilentlyContinue)
    $files0 = @(Get-ChildItem -LiteralPath $mcpDir -File -ErrorAction SilentlyContinue)
    Write-Output ('   subfolders: ' + $subs.Count + ' ; root files: ' + $files0.Count)
    [void]$find.AppendLine('MCP location: ' + $mcpDir + ' (' + $subs.Count + ' subfolders)')
    [void]$find.AppendLine('')
    $serverLines = 0
    foreach ($s in $subs) {
        $kind = ''
        $entry = ''
        $pkg = Join-Path $s.FullName 'package.json'
        $py = Join-Path $s.FullName 'pyproject.toml'
        if (Test-Path -LiteralPath $pkg) {
            $kind = 'node'
            try {
                $j = Get-Content -LiteralPath $pkg -Raw -Encoding UTF8 | ConvertFrom-Json
                $entry = [string]$j.name
                if ($j.bin) { $bins = @($j.bin.PSObject.Properties.Name); if ($bins.Count -gt 0) { $entry = $entry + ' (bin: ' + ($bins -join ',') + ')' } }
                if ($j.scripts -and $j.scripts.start) { $entry = $entry + ' [start: ' + [string]$j.scripts.start + ']' }
            } catch { $entry = 'package.json (unparsed)' }
        } elseif (Test-Path -LiteralPath $py) {
            $kind = 'python'
            try {
                $head = (Get-Content -LiteralPath $py -TotalCount 25 -Encoding UTF8) -join ' '
                if ($head -match 'name\s*=\s*"([^"]+)"') { $entry = $Matches[1] }
            } catch { $entry = 'pyproject (unparsed)' }
        } else {
            $exe = @(Get-ChildItem -LiteralPath $s.FullName -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\.(exe|bat|cmd|jar)$' } | Select-Object -First 1)
            if ($exe.Count -gt 0) { $kind = 'binary'; $entry = $exe[0].Name }
            else {
                $pyf = @(Get-ChildItem -LiteralPath $s.FullName -File -Filter '*.py' -ErrorAction SilentlyContinue | Select-Object -First 1)
                if ($pyf.Count -gt 0) { $kind = 'python'; $entry = $pyf[0].Name }
            }
        }
        $hasNm = ''
        if (Test-Path -LiteralPath (Join-Path $s.FullName 'node_modules')) { $hasNm = ' [node_modules]' }
        $line = ('- ' + $s.Name + ' : ' + $(if ($kind) { $kind } else { '?' }) + ' ' + $entry + $hasNm)
        [void]$find.AppendLine($line)
        $serverLines++
        if ($serverLines -le 35) { Write-Output ('   MCP  ' + (San ([string]$s.Name)).PadRight(34) + ($kind + $hasNm).PadRight(18) + (San ([string]$entry))) }
    }
    foreach ($f in $files0) {
        if ($f.Extension -eq '.json' -and $f.Length -lt 200KB) {
            try {
                $raw = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
                if ($raw -match 'mcpServers') {
                    $names = @([regex]::Matches($raw, '"([A-Za-z0-9_\-\.]+)"\s*:\s*\{') | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 15)
                    Write-Output ('   CONFIG ' + (San ([string]$f.Name)) + ' registers: ' + (San ($names -join ', ')))
                    [void]$find.AppendLine('')
                    [void]$find.AppendLine(('Config file ' + $f.Name + ' registers servers: ' + ($names -join ', ')))
                }
            } catch { }
        }
    }
    [void]$find.AppendLine('')
    [void]$find.AppendLine('Usability: node/python type MCP servers can be invoked by the watcher loop via stdio JSON-RPC (npx/node/python all on PATH). Pilot candidates: fetch / filesystem / pandas style servers.')
} else {
    Write-Output '   no *mcp* folder found on E:\ root'
    [void]$find.AppendLine('No *mcp* folder found at E:\ root.')
}

# Antigravity mcp config reference
try {
    $agDir = Join-Path $env:APPDATA 'Antigravity'
    if (Test-Path -LiteralPath $agDir) {
        $hits = @(Get-ChildItem -LiteralPath $agDir -Recurse -Depth 2 -Filter '*.json' -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 100KB } | Select-Object -First 40)
        $foundCfg = $false
        foreach ($h in $hits) {
            try {
                $raw = Get-Content -LiteralPath $h.FullName -Raw -Encoding UTF8
                if ($raw -match 'mcpServers') { Write-Output ('   AG-CONFIG ' + (San ($h.FullName.Replace($env:APPDATA, '~APPDATA')))); $foundCfg = $true }
            } catch { }
        }
        if (-not $foundCfg) { Write-Output '   no mcpServers key found in Antigravity config jsons (shallow scan)' }
    }
} catch { }

# ---------------------------------------------------- 2. n8n
Write-Output '--- 2. n8n ---'
$n8nLines = @()
$engOn = $false
$info = ''
try {
    $j = Start-Job -ScriptBlock { docker ps --format '{{.Names}}|{{.Image}}|{{.Ports}}|{{.Status}}' 2>&1 | Out-String }
    if (Wait-Job $j -Timeout 25) { $info = (Receive-Job $j | Out-String) } else { $info = '__TIMEOUT__' }
    Remove-Job $j -Force -ErrorAction SilentlyContinue
    if ($info -match '__TIMEOUT__' -or $info -match 'error during connect') { $engOn = $false }
    else { $engOn = $true }
} catch { }
if ($engOn) {
    Write-Output '   docker engine: RUNNING'
    $n8nLines += ('- Docker engine RUNNING. Containers:')
    foreach ($l in @($info -split "`r?`n" | Where-Object { $_ -match '\S' })) {
        Write-Output ('   CONTAINER ' + (San ([string]$l)))
        $n8nLines += ('  - ' + $l)
    }
    $isN8n = @($info -split "`r?`n" | Where-Object { $_ -match 'n8n' })
    if ($isN8n.Count -gt 0) {
        $health = ''
        try { $health = ((& curl.exe -s --max-time 5 http://localhost:5678/healthz 2>$null | Out-String).Trim()) } catch { }
        Write-Output ('   n8n healthz: ' + $(if ($health) { (San $health) } else { 'no response on :5678 (check port mapping)' }))
        $n8nLines += ('- n8n health: ' + $(if ($health) { $health } else { 'no response on :5678 (check port mapping)' }))
        $n8nLines += '- Usage: open http://localhost:5678 in a browser to design workflows; the agent can drive n8n via REST API / docker exec / webhooks when the engine is on.'
    } else {
        Write-Output '   no n8n container currently running'
        $n8nLines += '- No n8n container currently running.'
    }
} else {
    Write-Output '   docker engine: OFF (Docker Desktop not running)'
    $n8nLines += '- Docker engine NOT running (Docker Desktop closed), n8n not reachable right now.'
    $n8nLines += '- With the engine on, the agent can fully manage n8n via docker CLI (start, backup, trigger workflows via API).'
}

# ---------------------------------------------------- 3. R
Write-Output '--- 3. R environments ---'
$rDirs = @()
foreach ($root in @('C:\Program Files\R', 'C:\Program Files\RStudio', 'E:\', 'D:\', 'C:\Program Files')) {
    try {
        foreach ($d in @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^R(-|studio|\d| )' })) {
            if ($d.Name -match '^R-\d+\.\d+' -or $d.Name -eq 'R' -or $d.Name -match 'RStudio') { $rDirs += $d.FullName }
        }
    } catch { }
}
$rDirs = @($rDirs | Sort-Object -Unique)
$rVers = @()
foreach ($d in $rDirs) {
    if ($d -match 'R-(\d+\.\d+[\.\d]*)') { $rVers += @{ path = $d; ver = $Matches[1] } }
    else {
        try {
            foreach ($sub in @(Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^R-\d' })) {
                if ($sub.Name -match 'R-(\d+\.\d+[\.\d]*)') { $rVers += @{ path = $sub.FullName; ver = $Matches[1] } }
            }
        } catch { }
    }
}
$rVers = @($rVers | Sort-Object -Property @{Expression = { [version]$_.ver }} -Unique)
if ($rVers.Count -eq 0) { Write-Output '   Windows: no R version dirs found' }
else {
    foreach ($v in $rVers) { Write-Output ('   R ' + $v.ver + '  ' + $v.path) }
}
$regR = @()
foreach ($up in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    foreach ($it in @(Get-ItemProperty -Path $up -ErrorAction SilentlyContinue)) {
        if (([string]$it.DisplayName) -match '^R for Windows') { $regR += ([string]$it.DisplayName + ' @ ' + [string]$it.InstallLocation) }
    }
}
foreach ($r in $regR) { Write-Output ('   REG  ' + (San $r)) }

# WSL R (report only - never delete inside WSL)
$wslR = @()
foreach ($distro in @('Ubuntu-24.04', 'Ubuntu-26.04')) {
    $j = Start-Job -ScriptBlock {
        param($d)
        & wsl.exe -d $d -- sh -c 'which R Rscript 2>/dev/null; R --version 2>/dev/null | head -1; conda env list 2>/dev/null | grep -i "^r"; true' 2>&1 | Out-String
    } -ArgumentList $distro
    $o = '__TIMEOUT__'
    if (Wait-Job $j -Timeout 45) { $o = (Receive-Job $j | Out-String) }
    Remove-Job $j -Force -ErrorAction SilentlyContinue
    $clean = @($o -split "`r?`n" | Where-Object { $_ -match '\S' })
    if ($o -eq '__TIMEOUT__') { $clean = @('(probe timeout)') }
    $wslR += ($distro + ': ' + $clean.Count + ' hits')
    foreach ($l in ($clean | Select-Object -First 4)) { Write-Output ('   WSL ' + $distro + '  ' + (San ([string]$l))) }
}

# R action: delete OLD Windows R version dirs (approved), keep newest
$rAction = 'none'
if ($rVers.Count -ge 2) {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $ui = [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs
    $rb = [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
    $keep = $rVers[-1]
    $old = @($rVers | Where-Object { $_.path -ne $keep.path })
    Write-Output ('   keeping R ' + $keep.ver + ' (' + $keep.path + '), binning ' + $old.Count + ' old version(s)')
    foreach ($o in $old) {
        try {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($o.path, $ui, $rb)
            Write-Output ('   BIN  ' + $o.path)
        } catch { Write-Output ('   [WARN] ' + (San $o.path) + ' : ' + (San $_.Exception.Message)) }
    }
    $rAction = ('deleted ' + $old.Count + ' old Windows R version dir(s) to the recycle bin; kept ' + $keep.ver + ' @ ' + $keep.path)
} elseif ($rVers.Count -eq 1) {
    $rAction = ('only one Windows R found (' + $rVers[0].ver + ' @ ' + $rVers[0].path + ') - nothing to delete')
} else {
    $rAction = ('no Windows R installation dirs found (registry entries: ' + $regR.Count + ')')
}

# findings file
[void]$find.AppendLine('')
[void]$find.AppendLine('### n8n')
foreach ($l in $n8nLines) { [void]$find.AppendLine($l) }
[void]$find.AppendLine('')
[void]$find.AppendLine('### R')
[void]$find.AppendLine(('- Windows R version dirs: ' + $rVers.Count))
foreach ($v in $rVers) { [void]$find.AppendLine(('  - R ' + $v.ver + ' @ ' + $v.path)) }
foreach ($r in $regR) { [void]$find.AppendLine(('  - registry: ' + $r)) }
foreach ($w in $wslR) { [void]$find.AppendLine(('  - WSL ' + $w)) }
[void]$find.AppendLine(('- Action: ' + $rAction))
[void]$find.AppendLine('- R inside WSL is reported only, never deleted (WSL stays untouched by agreement).')

try {
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'results\status\r50_findings.md'), $find.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Output '   findings written: results/status/r50_findings.md'
} catch { Write-Output ('   [WARN] findings: ' + (San $_.Exception.Message)) }
exit 0
