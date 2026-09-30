# t37_software_inventory.ps1 - round 48 task: full installed-software
# inventory for the user to review uninstalls: registry uninstall entries
# (HKLM 64/32 + HKCU) with sizes, Store/Appx packages, plus a search for
# "ztask" everywhere. Report to results/status/software_inventory_r48.md.
# READ-ONLY. Windows PowerShell 5.1, ASCII-only (console), Write-Output only.

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

Write-Output '--- task t37: installed-software inventory + ztask search (READ-ONLY) ---'

# ------------------------------------------------------ registry apps
$apps = New-Object System.Collections.Generic.List[object]
$paths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
foreach ($up in $paths) {
    foreach ($it in @(Get-ItemProperty -Path $up -ErrorAction SilentlyContinue)) {
        $dn = [string]$it.DisplayName
        if (-not $dn) { continue }
        $szKB = [long]0
        try { $szKB = [long]$it.EstimatedSize } catch { }
        $d = [string]$it.InstallDate
        if ($d -match '^\d{8}$') { $d = $d.Substring(0, 4) + '-' + $d.Substring(4, 2) + '-' + $d.Substring(6, 2) }
        $apps.Add([pscustomobject]@{
            name = $dn; ver = [string]$it.DisplayVersion; pub = [string]$it.Publisher
            szKB = $szKB; loc = [string]$it.InstallLocation; date = $d
            hidden = ([int]$it.SystemComponent -eq 1)
        })
    }
}
$apps = @($apps | Sort-Object szKB -Descending)
Write-Output ('   desktop apps (registry): ' + $apps.Count + ' ; with size info: ' + @($apps | Where-Object { $_.szKB -gt 0 }).Count)

# ------------------------------------------------------------- appx
$appx = @()
try { $appx = @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { -not $_.IsFramework }) } catch { }
Write-Output ('   store/appx packages (non-framework): ' + $appx.Count)

# -------------------------------------------------------- ztask search
Write-Output '--- ztask search ---'
$z = New-Object System.Collections.Generic.List[string]
foreach ($a in $apps) { if ($a.name -match 'ztask' -or $a.loc -match 'ztask') { $z.Add(('registry: ' + $a.name + ' ' + $a.ver + ' @ ' + $a.loc)) } }
foreach ($x in $appx) { if ($x.Name -match 'ztask') { $z.Add(('appx: ' + $x.Name)) } }
try { foreach ($p in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'ztask' })) { $z.Add(('process: ' + $p.ProcessName + ' -> ' + [string]$p.Path)) } } catch { }
try { foreach ($s in @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'ztask' -or [string]$_.PathName -match 'ztask' })) { $z.Add(('service: ' + $s.Name + ' ' + [string]$s.PathName)) } } catch { }
foreach ($m in @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs")) {
    try { foreach ($f in @(Get-ChildItem -Path $m -Recurse -Filter '*ztask*' -ErrorAction SilentlyContinue)) { $z.Add(('start-menu: ' + $f.FullName)) } } catch { }
}
foreach ($root in @('C:\Program Files', 'C:\Program Files (x86)', 'D:\', 'E:\')) {
    try { foreach ($d in @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'ztask' })) { $z.Add(('dir: ' + $d.FullName)) } } catch { }
}
if ($z.Count -gt 0) { foreach ($h in $z) { Write-Output ('   ZTASK-HIT: ' + (San $h)) } }
else { Write-Output '   no "ztask" in registry / appx / processes / services / start menu / program dirs' }

# -------------------------------------------------------- console top
Write-Output '--- top desktop apps by size (full list in the md report) ---'
$i = 0
foreach ($a in @($apps | Select-Object -First 40)) {
    $i++
    $flag = ''
    if ($a.hidden) { $flag = ' [sys]' }
    Write-Output ('   ' + $i.ToString().PadLeft(3) + '. ' + (FmtKB ([long]$a.szKB)).PadLeft(11) + '  ' + (San ([string]$a.name)) + '  ' + (San ([string]$a.ver)) + $flag)
}

# ----------------------------------------------------------- md report
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# Installed software inventory (round 48, 2026-09-30)')
[void]$md.AppendLine('')
[void]$md.AppendLine('> READ-ONLY scan of registry uninstall entries + Appx packages. Sizes are registry EstimatedSize (approximate). [sys] = hidden system component.')
[void]$md.AppendLine('')
[void]$md.AppendLine(('## 1. Desktop apps (' + $apps.Count + ', sorted by size)'))
[void]$md.AppendLine('')
[void]$md.AppendLine('| # | size | name | version | publisher | installed | location | |')
[void]$md.AppendLine('|---|---|---|---|---|---|---|---|')
$i = 0
foreach ($a in $apps) {
    $i++
    $fl = ''
    if ($a.hidden) { $fl = ' [sys]' }
    [void]$md.AppendLine('| ' + $i + ' | ' + (FmtKB ([long]$a.szKB)) + ' | ' + $a.name + $fl + ' | ' + $a.ver + ' | ' + $a.pub + ' | ' + $a.date + ' | ' + $a.loc + ' | |')
}
[void]$md.AppendLine('')
[void]$md.AppendLine(('## 2. Store / Appx packages (' + $appx.Count + ' non-framework)'))
[void]$md.AppendLine('')
foreach ($x in $appx) { [void]$md.AppendLine('- ' + $x.Name + '  ' + $x.Version) }
[void]$md.AppendLine('')
[void]$md.AppendLine('## 3. ztask search')
[void]$md.AppendLine('')
if ($z.Count -gt 0) { foreach ($h in $z) { [void]$md.AppendLine('- ' + $h) } }
else { [void]$md.AppendLine('Not found: no app/process/service/start-menu/program-dir named "ztask" exists on this machine.') }
[void]$md.AppendLine('')
try {
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'results\status\software_inventory_r48.md'), $md.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ('   report written: results/status/software_inventory_r48.md (' + $apps.Count + ' apps + ' + $appx.Count + ' appx)')
} catch { Write-Output ('   [WARN] report: ' + (San $_.Exception.Message)) }
exit 0
