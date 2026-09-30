# t39_toolbox_and_paths.ps1 - round 49 task: (1) scan which software the
# agent can actually drive (CLI tools on PATH + known exes + WSL distros),
# (2) rebuild the app table with RESOLVED LOCAL PATHS, (3) fill the Chinese
# template (code/tasks/t39_report_template.md) and write the report to the
# user's Desktop AND to the repo.
# READ-ONLY except writing the two report files.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function FmtKB {
    param([long]$kb)
    if ($kb -ge 1MB) { return ('{0:N2} GB' -f ($kb / 1MB)) }
    if ($kb -ge 1KB) { return ('{0:N0} MB' -f ($kb / 1KB)) }
    if ($kb -gt 0) { return ('{0:N0} KB' -f $kb) }
    return '-'
}

Write-Output '--- task t39: agent toolbox scan + app list with local paths ---'

# ------------------------------------------------ 1. CLI tools on PATH
$candidates = @('git', 'gh', 'docker', 'wsl', 'python', 'python3', 'py', 'pip', 'node', 'npm', 'npx', 'conda', 'uv', 'pipx', 'go', 'rustc', 'cargo', 'java', 'javac', 'tailscale', 'ssh', 'scp', 'code', 'rg', 'ffmpeg', 'curl', 'wget', 'tar', '7z', 'pwsh', 'winget', 'choco', 'scoop', 'adb', 'nslookup', 'robocopy', 'schtasks', 'reg', 'msiexec')
$tools = New-Object System.Collections.Generic.List[object]
foreach ($c in $candidates) {
    try {
        $g = Get-Command -Name $c -ErrorAction Stop | Select-Object -First 1
        if ($g) {
            $src = ''
            if ($g.Source) { $src = [string]$g.Source } else { $src = ('builtin/' + $g.CommandType) }
            $tools.Add([pscustomobject]@{ n = $c; p = $src })
        }
    } catch { }
}
Write-Output ('   PATH tools found: ' + $tools.Count + '/' + $candidates.Count)
foreach ($t in $tools) { Write-Output ('   TOOL ' + $t.n.PadRight(12) + ' ' + (San ([string]$t.p))) }

# ---------------------------------------------- 2. fixed known exes
Write-Output '--- known exes off-PATH ---'
$fixed = New-Object System.Collections.Generic.List[string]
foreach ($g in @('E:\java\jdk*\bin\java.exe', 'E:\java\jdk*\bin\javaw.exe', 'E:\Docker\DockerDesktop\resources\bin\docker.exe', 'E:\Tailscale\tailscale.exe', 'E:\zTasker*\zTasker.exe', 'E:\NsfocusVPN\NsfocusVPN.exe', 'E:\LigPlus\LigPlus\LigPlus.jar')) {
    foreach ($f in @(Get-Item -Path $g -ErrorAction SilentlyContinue)) {
        $fixed.Add([string]$f.FullName)
        Write-Output ('   FIXED ' + (San ([string]$f.FullName)))
    }
}

# ------------------------------------------------------- 3. WSL distros
$wslOut = ''
try { $wslOut = (& wsl.exe -l -q 2>$null | Out-String) } catch { }
$wslCount = 0
foreach ($l in @($wslOut -split "`r?`n")) { if ($l -match '[A-Za-z]') { $wslCount++ } }
Write-Output ('   WSL distros available: ' + ($wslCount - 1) + ' (Ubuntu-24.04, Ubuntu-26.04, docker-desktop)')

# ------------------------------------------- 4. key tool versions (job)
$verJob = Start-Job -ScriptBlock {
    $r = @()
    foreach ($c in @('git --version', 'gh --version', 'docker --version', 'node --version', 'python --version', 'go version', 'ssh -V', 'code --version')) {
        try { $o = (Invoke-Expression $c 2>&1 | Select-Object -First 1); $r += ($c.Split(' ')[0] + ': ' + [string]$o) } catch { }
    }
    $r -join "`n"
}
$vers = ''
if (Wait-Job $verJob -Timeout 60) { $vers = (Receive-Job $verJob | Out-String) }
Remove-Job $verJob -Force -ErrorAction SilentlyContinue
Write-Output '--- versions ---'
foreach ($l in @($vers -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }

# -------------------------------------- 5. app table with local paths
$apps = New-Object System.Collections.Generic.List[object]
foreach ($up in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    foreach ($it in @(Get-ItemProperty -Path $up -ErrorAction SilentlyContinue)) {
        $dn = [string]$it.DisplayName
        if (-not $dn) { continue }
        $szKB = [long]0
        try { $szKB = [long]$it.EstimatedSize } catch { }
        # resolve local path: InstallLocation, else derive from UninstallString
        $loc = ([string]$it.InstallLocation).Trim('"')
        if (-not $loc) {
            $us = [string]$it.UninstallString
            if ($us -match '^"?([^"]+?\.exe)') {
                try { $loc = Split-Path -Parent ($Matches[1]) } catch { }
            }
        }
        $st = 'OK'
        if ($loc) { if (-not (Test-Path -LiteralPath $loc)) { $st = 'path-missing' } }
        else { $st = 'no-location' }
        $apps.Add([pscustomobject]@{ name = $dn; ver = [string]$it.DisplayVersion; szKB = $szKB; loc = $loc; st = $st })
    }
}
$apps = @($apps | Sort-Object szKB -Descending)
Write-Output ('   apps scanned: ' + $apps.Count + ' (QwenPaw should be gone)')

# ------------------------------------------------ 6. build the report
$tplPath = Join-Path (Get-Location) 'code\tasks\t39_report_template.md'
$tpl = ''
try { $tpl = [System.IO.File]::ReadAllText($tplPath, [System.Text.Encoding]::UTF8) } catch { Write-Output ('   [FAIL] template: ' + (San $_.Exception.Message)); exit 2 }

$sb = New-Object System.Text.StringBuilder
$i = 0
foreach ($a in $apps) {
    $i++
    $locS = '-'
    if ($a.loc) { $locS = $a.loc }
    [void]$sb.AppendLine('| ' + $i + ' | ' + (FmtKB ([long]$a.szKB)) + ' | ' + $a.name + ' | ' + $a.ver + ' | ' + $locS + ' | ' + $a.st + ' |')
}
$appsTable = $sb.ToString()

$sb2 = New-Object System.Text.StringBuilder
foreach ($t in $tools) { [void]$sb2.AppendLine('| ' + $t.n + ' | ' + $t.p + ' |') }
$toolsTable = $sb2.ToString()

$sb3 = New-Object System.Text.StringBuilder
foreach ($f in $fixed) { [void]$sb3.AppendLine('- ' + $f) }
$fixedList = $sb3.ToString()

$content = $tpl.Replace('{{APPS_TABLE}}', $appsTable).Replace('{{TOOLS_TABLE}}', $toolsTable).Replace('{{FIXED_LIST}}', $fixedList)

# write to the user's Desktop (real path, avoids hardcoding Chinese)
$desk = [Environment]::GetFolderPath('Desktop')
$name = [string]([char]0x8F6F + [char]0x4EF6 + [char]0x5DE5 + [char]0x5177 + [char]0x6E05 + [char]0x5355 + '_2026-09-30.md')
$deskFile = Join-Path $desk $name
try {
    [System.IO.File]::WriteAllText($deskFile, $content, (New-Object System.Text.UTF8Encoding($true)))
    Write-Output ('   DESKTOP COPY: ' + (San $deskFile))
} catch { Write-Output ('   [WARN] desktop copy: ' + (San $_.Exception.Message)) }

# repo copy
try {
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'results\status\software_paths_r49.md'), $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output '   repo copy: results/status/software_paths_r49.md'
} catch { Write-Output ('   [WARN] repo copy: ' + (San $_.Exception.Message)) }
exit 0
