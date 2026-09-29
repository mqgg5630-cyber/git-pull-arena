# t2_install_java.ps1 - round 23 task 2: install a portable JDK 21 (Temurin
# LTS preferred) to E:\java WITHOUT any admin rights, because round 22 proved
# nothing Java was ever installed (no PATH entry, no registry entry, empty
# E:\java folder) and MSI-based installers are what kept failing.
#
# Method: download a zip from a China-friendly mirror (Tsinghua TUNA, Huawei)
# with fallbacks (Microsoft, Adoptium API), validate the zip, extract to
# E:\java\<jdk-dir>, set JAVA_HOME + append bin to the USER Path (with a
# backup of the old Path written to E:\java\), then verify java -version.
# Nothing touches the Machine environment; no UAC prompt; no installer.
#
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'
try { [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { }
try { [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 12288 } catch { }

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

function FmtB {
    param([double]$b)
    if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    if ($b -ge 1KB) { return ('{0:N1} KB' -f ($b / 1KB)) }
    return ('{0:N0} B' -f $b)
}

Write-Output '--- task t2 (install): portable JDK 21 -> E:\java (no admin needed) ---'

# ------------------------------------------------------------ proxy detect
$proxyUrl = ''
try {
    $is = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
    $psv = [string]$is.ProxyServer
    if (([int]$is.ProxyEnable -eq 1) -and $psv) {
        if ($psv -notmatch '^[a-z]+://') { $proxyUrl = 'http://' + $psv }
        else { $proxyUrl = $psv }
    }
} catch { }
if (-not $proxyUrl) {
    foreach ($n in @('HTTP_PROXY', 'HTTPS_PROXY')) {
        $v = [Environment]::GetEnvironmentVariable($n, 'User')
        if (-not $v) { $v = [Environment]::GetEnvironmentVariable($n, 'Machine') }
        if ($v) { $proxyUrl = $v; break }
    }
}
Write-Output ('proxy: ' + $(if ($proxyUrl) { $proxyUrl } else { '(none detected - direct only)' }))

# --------------------------------------------------------- http helpers
function Get-Text {
    param([string]$u, [bool]$viaProxy, [int]$timeoutSec)
    try {
        $req = [System.Net.HttpWebRequest]::Create($u)
        $req.Method = 'GET'
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        $req.Timeout = ($timeoutSec * 1000)
        $req.ReadWriteTimeout = 30000
        $req.AllowAutoRedirect = $true
        if ($viaProxy -and $script:proxyUrl) { $req.Proxy = New-Object System.Net.WebProxy($script:proxyUrl) }
        else { $req.Proxy = $null }
        $resp = $req.GetResponse()
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $t = $sr.ReadToEnd()
        $sr.Close()
        $resp.Close()
        return $t
    } catch { return $null }
}

function Get-FileHttp {
    param([string]$u, [string]$out, [bool]$viaProxy, [int]$totalCapSec)
    try {
        $req = [System.Net.HttpWebRequest]::Create($u)
        $req.Method = 'GET'
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        $req.Timeout = 60000
        $req.ReadWriteTimeout = 120000
        $req.AllowAutoRedirect = $true
        if ($viaProxy -and $script:proxyUrl) { $req.Proxy = New-Object System.Net.WebProxy($script:proxyUrl) }
        else { $req.Proxy = $null }
        $resp = $req.GetResponse()
        $cl = [double]0
        try { $cl = [double]$resp.ContentLength } catch { }
        $st = $resp.GetResponseStream()
        $fs = [System.IO.File]::Create($out)
        $buf = New-Object byte[] 1048576
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $got = [double]0
        $lastReport = 0
        while (($n = $st.Read($buf, 0, $buf.Length)) -gt 0) {
            $fs.Write($buf, 0, $n)
            $got += $n
            if ($sw.Elapsed.TotalSeconds -gt $totalCapSec) {
                $fs.Close()
                $resp.Close()
                return 'CAP'
            }
            if (($got - $lastReport) -ge 52428800) {
                [Console]::WriteLine('      ... ' + (FmtB $got) + $(if ($cl -gt 0) { (' of ' + (FmtB $cl)) } else { '' }) + ' (' + [int]$sw.Elapsed.TotalSeconds + 's)')
                $lastReport = $got
            }
        }
        $fs.Close()
        $resp.Close()
        return ('OK ' + $got + ' bytes in ' + [int]$sw.Elapsed.TotalSeconds + 's' + $(if ($cl -gt 0) { (' (content-length ' + (FmtB $cl) + ')') } else { '' }))
    } catch {
        return ('ERR ' + (San ([string]$_.Exception.Message)))
    }
}

# --------------------------------------------------------- early-exit check
$javaRoot = 'E:\java'
if (-not (Test-Path -LiteralPath $javaRoot)) {
    try { New-Item -ItemType Directory -Force -Path $javaRoot | Out-Null } catch { Write-Output ('[FAIL] cannot create ' + $javaRoot + ': ' + (San $_.Exception.Message)); exit 2 }
}
$existing = @(Get-ChildItem -LiteralPath $javaRoot -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe') })
if ($existing.Count -gt 0) {
    $jHome = $existing[0].FullName
    Write-Output ('already present: ' + $jHome + ' - verifying and wiring env only')
} else {

    # ------------------------------------------------------- pick a source
    $sources = @(
        @{ name = 'tuna-mirror';    kind = 'listing'; base = 'https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/x64/windows/'; preferProxy = $false },
        @{ name = 'huawei-mirror';  kind = 'listing'; base = 'https://mirrors.huaweicloud.com/adoptium/21/jdk/x64/windows/'; preferProxy = $false },
        @{ name = 'microsoft';      kind = 'fixed';   url = 'https://aka.ms/download-jdk/microsoft-jdk-21-windows-x64.zip'; preferProxy = $false },
        @{ name = 'adoptium-api';   kind = 'fixed';   url = 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse'; preferProxy = $true }
    )
    $zipPath = Join-Path $env:TEMP ('jdk21_' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.zip')
    $dlOk = $false
    $usedName = ''
    foreach ($src in $sources) {
        $modes = @()
        if ($src.preferProxy) { $modes = @($true, $false) } else { $modes = @($false, $true) }
        $url = ''
        foreach ($m in $modes) {
            if ($m -and -not $proxyUrl) { continue }
            $modeName = 'direct'
            if ($m) { $modeName = 'proxy' }
            if ($src.kind -eq 'listing') {
                Write-Output ('   trying ' + $src.name + ' (' + $modeName + '): listing ' + $src.base)
                $lst = Get-Text -u $src.base -viaProxy $m -timeoutSec 20
                if (-not $lst) { Write-Output '      listing failed'; continue }
                $best = $null
                $bestV = $null
                foreach ($mt in [regex]::Matches($lst, 'OpenJDK21U-jdk_x64_windows_hotspot_[0-9][0-9._]*\.zip')) {
                    $fn = $mt.Value
                    $vpart = ($fn -replace '^OpenJDK21U-jdk_x64_windows_hotspot_', '') -replace '\.zip$', ''
                    $v = $null
                    try { $v = [version]($vpart -replace '_', '.') } catch { $v = $null }
                    if ($v -and (($null -eq $bestV) -or ($v -gt $bestV))) { $bestV = $v; $best = $fn }
                }
                if (-not $best) { Write-Output '      no OpenJDK21 zip found in listing'; continue }
                $url = $src.base + $best
                Write-Output ('      latest: ' + $best)
            } else {
                $url = [string]$src.url
                Write-Output ('   trying ' + $src.name + ' (' + $modeName + '): ' + $url)
            }
            $r = Get-FileHttp -u $url -out $zipPath -viaProxy $m -totalCapSec 600
            Write-Output ('      download: ' + $r)
            if ($r -like 'OK *') { $dlOk = $true; $usedName = $src.name; break }
            if ($r -eq 'CAP') { Write-Output '      download cap hit - trying next mode/source' }
        }
        if ($dlOk) { break }
    }
    if (-not $dlOk) {
        Write-Output '[FAIL] every download source failed (see above). Nothing was installed.'
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue }
        exit 2
    }
    Write-Output ('downloaded via: ' + $usedName)

    # ------------------------------------------------------- validate zip
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zf = [double](Get-Item -LiteralPath $zipPath).Length
    Write-Output ('zip size: ' + (FmtB $zf))
    if ($zf -lt 100MB) { Write-Output '[FAIL] zip too small - not a JDK'; Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue; exit 2 }
    $zip = $null
    try { $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath) } catch { $zip = $null }
    if (-not $zip) { Write-Output '[FAIL] not a readable zip'; Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue; exit 2 }
    $topDir = ''
    $hasJava = $false
    $entrySum = [double]0
    try {
        foreach ($ze in $zip.Entries) {
            $entrySum += [double]$ze.Length
            if (-not $topDir -and $ze.FullName.Contains('/')) { $topDir = $ze.FullName.Split('/')[0] }
            if ($ze.FullName -match '^[^/]+/bin/java\.exe$') { $hasJava = $true }
        }
    } catch { }
    $nEntries = $zip.Entries.Count
    $zip.Dispose()
    Write-Output ('zip check: entries=' + $nEntries + ' topDir=' + $topDir + ' uncompressed=' + (FmtB $entrySum) + ' bin/java.exe=' + $hasJava)
    if (-not $topDir -or -not $hasJava -or $nEntries -lt 50 -or $entrySum -lt 100MB) {
        Write-Output '[FAIL] zip failed validation - not installing'
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        exit 2
    }

    # ---------------------------------------------------------- extract
    $jHome = Join-Path $javaRoot $topDir
    if (Test-Path -LiteralPath $jHome) {
        Write-Output ('   target exists, removing incomplete dir: ' + $jHome)
        try { Remove-Item -LiteralPath $jHome -Recurse -Force -ErrorAction Stop } catch { Write-Output ('[FAIL] cannot remove old dir: ' + (San $_.Exception.Message)); Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue; exit 2 }
    }
    Write-Output ('   extracting to ' + $javaRoot + ' (this takes 1-3 minutes) ...')
    $t0 = Get-Date
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $javaRoot)
    } catch {
        Write-Output ('[FAIL] extract threw: ' + (San $_.Exception.Message))
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        exit 2
    }
    $exSec = [int]((Get-Date) - $t0).TotalSeconds
    Write-Output ('   extracted in ' + $exSec + 's')
    Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path -LiteralPath (Join-Path $jHome 'bin\java.exe'))) {
        Write-Output '[FAIL] java.exe missing after extract'
        exit 2
    }
}

$jExe = Join-Path $jHome 'bin\java.exe'
Write-Output ('JDK home: ' + $jHome)

# ------------------------------------------------------------- env vars
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$oldPath = [string][Environment]::GetEnvironmentVariable('Path', 'User')
$backupFile = Join-Path $javaRoot ('PATH-backup-' + $stamp + '.txt')
try {
    [System.IO.File]::WriteAllText($backupFile, $oldPath, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ('old user PATH backed up to: ' + $backupFile + ' (' + $oldPath.Length + ' chars)')
} catch { Write-Output ('   [WARN] PATH backup failed: ' + (San $_.Exception.Message)) }

[Environment]::SetEnvironmentVariable('JAVA_HOME', $jHome, 'User')
Write-Output ('JAVA_HOME (User) = ' + $jHome)

$binDir = Join-Path $jHome 'bin'
if ($oldPath -and ($oldPath.IndexOf($binDir, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)) {
    Write-Output ('user PATH already contains ' + $binDir)
} else {
    $newPath = $binDir
    if ($oldPath) { $newPath = $oldPath.TrimEnd(';') + ';' + $binDir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    $chk = [string][Environment]::GetEnvironmentVariable('Path', 'User')
    Write-Output ('user PATH: ' + $oldPath.Length + ' -> ' + $chk.Length + ' chars, appended ' + $binDir)
    if ($chk -notlike ('*' + $binDir + '*')) { Write-Output '[FAIL] PATH update did not stick'; exit 2 }
}

# --------------------------------------------------------------- verify
$env:JAVA_HOME = $jHome
$env:Path = ($env:Path + ';' + $binDir)
$vJob = Start-Job -ScriptBlock { param($p) & $p -version 2>&1 | Out-String } -ArgumentList $jExe
$vOut = ''
if (Wait-Job $vJob -Timeout 60) { $vOut = (Receive-Job $vJob 2>&1 | Out-String) } else { $vOut = 'TIMEOUT' }
Remove-Job $vJob -Force -ErrorAction SilentlyContinue
Write-Output ('java -version: ' + ((San $vOut).Trim() -replace "`r?`n", ' | '))

$cJob = Start-Job -ScriptBlock { param($p) & $p -version 2>&1 | Out-String } -ArgumentList (Join-Path $jHome 'bin\javac.exe')
$cOut = ''
if (Wait-Job $cJob -Timeout 60) { $cOut = (Receive-Job $cJob 2>&1 | Out-String) } else { $cOut = 'TIMEOUT' }
Remove-Job $cJob -Force -ErrorAction SilentlyContinue
Write-Output ('javac -version: ' + ((San $cOut).Trim() -replace "`r?`n", ' | '))

try {
    $w = (& where.exe java 2>&1 | Out-String)
    Write-Output ('where java (refreshed PATH): ' + ((San $w).Trim() -replace "`r?`n", ' ; '))
} catch { }

if ($vOut -match 'version') {
    Write-Output '== JDK INSTALLED OK (portable zip, no admin was needed)'
    Write-Output '   open a NEW terminal (old ones keep the old PATH) and run: java -version'
    exit 0
}
Write-Output '[FAIL] java -version did not report a version'
exit 2
