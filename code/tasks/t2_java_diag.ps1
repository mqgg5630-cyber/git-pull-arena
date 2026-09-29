# t2_java_diag.ps1 - round 22 task 2: find out why Java will not install and
# snapshot the current Java state. READ-ONLY: nothing is installed, changed
# or deleted here; the actual install happens in a later round once the cause
# is known.
#
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t2: Java diagnosis (read-only) ---'
Write-Output ('arch: ' + $env:PROCESSOR_ARCHITECTURE + ' / os: ' + [string]$env:OS)

# ------------------------------------------------- what java resolves to
foreach ($n in @('java', 'javaw', 'javac')) {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($c) { Write-Output ($n + ' -> ' + (San ([string]$c.Source))) }
    else { Write-Output ($n + ' -> (not on PATH)') }
}
try {
    $w = (& where.exe java 2>&1 | Out-String)
    $w = ($w -replace "`r?`n", ' ; ').Trim()
    if ($w) { Write-Output ('where.exe java: ' + (San $w)) }
} catch { }

if (Get-Command java -ErrorAction SilentlyContinue) {
    $job = Start-Job -ScriptBlock { & java -version 2>&1 | Out-String }
    if (Wait-Job $job -Timeout 30) {
        $v = (Receive-Job $job | Out-String)
        $v = ($v -replace "`r?`n", ' | ').Trim()
        Write-Output ('java -version: ' + (San $v))
    } else {
        Write-Output 'java -version: TIMEOUT after 30s (broken shim on PATH?)'
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------- JAVA_HOME
foreach ($scope in @('Process', 'User', 'Machine')) {
    $jh = [Environment]::GetEnvironmentVariable('JAVA_HOME', $scope)
    if ($jh) { Write-Output ('JAVA_HOME (' + $scope + '): ' + (San $jh)) }
    else { Write-Output ('JAVA_HOME (' + $scope + '): (unset)') }
}
foreach ($n in @('_JAVA_OPTIONS', 'JAVA_TOOL_OPTIONS')) {
    foreach ($scope in @('User', 'Machine')) {
        $jv = [Environment]::GetEnvironmentVariable($n, $scope)
        if ($jv) { Write-Output ($n + ' (' + $scope + '): ' + (San $jv)) }
    }
}

# ------------------------------------------------------ PATH java entries
foreach ($scope in @('User', 'Machine')) {
    $p = [Environment]::GetEnvironmentVariable('Path', $scope)
    $hits = @()
    if ($p) {
        foreach ($e in ($p -split ';')) {
            if ($e -and $e -match '(?i)java|jdk|jre') { $hits += $e }
        }
    }
    if ($hits.Count -gt 0) { Write-Output ('PATH (' + $scope + ') java entries: ' + (($hits | ForEach-Object { San $_ }) -join ' ; ')) }
    else { Write-Output ('PATH (' + $scope + '): no java/jdk/jre entries') }
}

# ------------------------------------------- registry: installed products
Write-Output '--- installed Java-related products (registry) ---'
$unPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$found = 0
foreach ($up in $unPaths) {
    $items = @(Get-ItemProperty -Path $up -ErrorAction SilentlyContinue)
    foreach ($it in $items) {
        $dn = [string]$it.DisplayName
        if (-not $dn) { continue }
        if ($dn -match '(?i)java|jdk|jre|openjdk|temurin|zulu|corretto|liberica') {
            $found++
            Write-Output ('   ' + (San $dn) + ' | version=' + (San ([string]$it.DisplayVersion)) + ' | date=' + (San ([string]$it.InstallDate)) + ' | loc=' + (San ([string]$it.InstallLocation)))
        }
    }
}
if ($found -eq 0) { Write-Output '   (no Java/JDK entries in the uninstall registry)' }

# ------------------------------------------------- common install folders
Write-Output '--- common install folders ---'
foreach ($d in @('C:\Program Files\Java', 'C:\Program Files (x86)\Java', 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Microsoft', 'E:\Java', 'E:\jdk')) {
    if (Test-Path -LiteralPath $d) {
        $kids = @(Get-ChildItem -LiteralPath $d -ErrorAction SilentlyContinue | Select-Object -First 8)
        Write-Output ('   ' + $d + ' : ' + ((@($kids) | ForEach-Object { San ([string]$_.Name) }) -join ', '))
    }
}
try {
    $ej = @(Get-ChildItem -Path 'E:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)jdk|java|jre' })
    foreach ($e in $ej) { Write-Output ('   E: top-level match: ' + (San $e.FullName)) }
} catch { }

# ------------------------------------------------- MSI failure evidence
Write-Output '--- MsiInstaller events, last 60 days (java filter) ---'
try {
    $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'MsiInstaller'; StartTime = (Get-Date).AddDays(-60) } -ErrorAction Stop | Select-Object -First 400)
    $jev = @($ev | Where-Object { $_.Message -match '(?i)java|jdk|jre|openjdk|temurin|zulu|corretto' })
    if ($jev.Count -eq 0) { Write-Output '   (no MsiInstaller events mentioning Java)' }
    foreach ($e in @($jev | Select-Object -First 12)) {
        $msg = ((San ([string]$e.Message)).Trim() -replace "`r?`n", ' ')
        if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) + ' ...' }
        $tc = ''
        try { $tc = $e.TimeCreated.ToString('yyyy-MM-dd HH:mm') } catch { }
        Write-Output ('   [' + $tc + '] id=' + $e.Id + ' ' + $msg)
    }
} catch {
    Write-Output ('   (MsiInstaller events unreadable: ' + (San $_.Exception.Message) + ')')
}

Write-Output '--- installer logs in TEMP (last 60 days, java-ish names) ---'
try {
    $tmpLogs = @(Get-ChildItem -Path $env:TEMP -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-60) -and $_.Name -match '(?i)msi|java|jdk|jre|install' } | Sort-Object LastWriteTime -Descending | Select-Object -First 8)
} catch { $tmpLogs = @() }
if ($tmpLogs.Count -eq 0) { Write-Output '   (none)' }
foreach ($tl in $tmpLogs) {
    $tc = ''
    try { $tc = $tl.LastWriteTime.ToString('yyyy-MM-dd HH:mm') } catch { }
    Write-Output ('   ' + (San $tl.Name) + ' (' + $tc + ', ' + $tl.Length + ' B)')
    if ($tl.Length -lt 5MB) {
        $hitLines = @()
        try {
            $txt = Get-Content -LiteralPath $tl.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            foreach ($ln in ($txt -split "`r?`n")) {
                if ($ln -match '(?i)return value 3|installation failed|error 1603|java|jdk') { $hitLines += ((San $ln).Trim()) }
                if ($hitLines.Count -ge 6) { break }
            }
        } catch { }
        foreach ($h in $hitLines) { Write-Output ('      ' + $h) }
    }
}

# --------------------------------------------------------------- winget
Write-Output '--- winget list (java filter, 60s cap) ---'
$wgJob = Start-Job -ScriptBlock { & winget list --accept-source-agreements --disable-interactivity 2>&1 | Out-String }
$wg = $null
if (Wait-Job $wgJob -Timeout 60) { $wg = (Receive-Job $wgJob | Out-String) }
else { Write-Output '   (winget timed out after 60s)' }
Remove-Job $wgJob -Force -ErrorAction SilentlyContinue
if ($wg) {
    $lines = @(($wg -split "`r?`n") | Where-Object { $_ -match '(?i)\bjava\b|jdk|jre|openjdk|temurin|zulu|corretto|liberica' })
    if ($lines.Count -eq 0) { Write-Output '   (no java-related packages in winget list)' }
    foreach ($l in @($lines | Select-Object -First 12)) { Write-Output ('   ' + ((San $l)).Trim()) }
}

# ------------------------------------------------- installer service / disk
try {
    $svc = Get-Service msiserver -ErrorAction Stop
    Write-Output ('Windows Installer service (msiserver): ' + $svc.Status + ' / start type ' + [string]$svc.StartType)
} catch { Write-Output 'Windows Installer service: unreadable' }
$isAdmin = $false
try { $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { }
Write-Output ('this check runs elevated: ' + $isAdmin + ' (MSI installs usually need admin; a zip install to E: does not)')
try {
    $disks = @(Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:' or DeviceID='E:'" -ErrorAction Stop)
    foreach ($dk in $disks) {
        $fr = [math]::Round($dk.FreeSpace / 1GB, 1)
        $tt = [math]::Round($dk.Size / 1GB, 1)
        Write-Output ('   disk ' + $dk.DeviceID + ' free ' + $fr + ' GB of ' + $tt + ' GB (' + (San ([string]$dk.FileSystem)) + ')')
    }
} catch { Write-Output ('   disk info failed: ' + (San $_.Exception.Message)) }

Write-Output '--- task t2 done (read-only, nothing installed or changed) ---'
exit 0
