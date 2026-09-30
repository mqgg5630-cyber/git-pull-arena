# t54_recon2.ps1 - round 66 task: why the zotero-link did not take effect.
# 1. how the success case PUSHES items into Zotero (push_to_zotero.py)
# 2. library-JSON structure comparison (success vs ours)
# 3. zotero.exe location + version, Word plugin (zotero.dotm) presence
# 4. start Zotero, ping local API 23119
# 5. current English.docx field count
# 6. Crossref DOI verification of all 36 refs (python)
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t54: recon2 - why not linked + verify refs ---'

# -------------------------------------------- 1. push_to_zotero.py
Write-Output '--- 1. push_to_zotero.py (success-case import mechanism) ---'
try {
    $ln = 0
    foreach ($l in @(Get-Content -LiteralPath 'E:\0writing\cnki-skills\skills\cnki-export\scripts\push_to_zotero.py' -TotalCount 70 -ErrorAction Stop)) {
        $ln++
        Write-Output ('     ' + (San ([string]$l)))
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# -------------------------------------------- 2. library JSON compare
Write-Output '--- 2. library json structure comparison ---'
try {
    $a = Get-Content -LiteralPath 'E:\0writing\cnki-skills\periodontitis-ad-pg-review\Periodontitis_AD_Zotero_library.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    $b = Get-Content -LiteralPath 'E:\0writing\Light-skills\projects\English_Zotero_library.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Output ('   success-case json: type=' + $a.GetType().Name + ' count=' + @($a).Count)
    Write-Output ('   our json         : type=' + $b.GetType().Name + ' count=' + @($b).Count)
    $a0 = @($a)[0]
    $b0 = @($b)[0]
    Write-Output ('   success item[0] keys: ' + (($a0.PSObject.Properties.Name | Select-Object -First 14) -join ', '))
    Write-Output ('   our    item[0] keys: ' + (($b0.PSObject.Properties.Name | Select-Object -First 14) -join ', '))
    Write-Output ('   success item[0] author[0]: ' + (San ([string]($a0.author[0] | ConvertTo-Json -Compress))))
    Write-Output ('   our    item[0] author[0]: ' + (San ([string]($b0.author[0] | ConvertTo-Json -Compress))))
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# -------------------------------------------- 3. zotero exe + word plugin
Write-Output '--- 3. zotero.exe + Word plugin ---'
$zexe = $null
foreach ($cand in @('E:\Zotero\zotero.exe', 'C:\Program Files\Zotero\zotero.exe')) {
    if (Test-Path -LiteralPath $cand) { $zexe = $cand; break }
}
if (-not $zexe) {
    try { $zexe = [string](Get-ChildItem -Path 'E:\Zotero' -Recurse -Filter 'zotero.exe' -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1).FullName } catch { }
}
Write-Output ('   zotero.exe: ' + $(if ($zexe) { $zexe } else { 'NOT FOUND' }))
foreach ($ini in @('E:\Zotero\application.ini', 'C:\Program Files\Zotero\application.ini')) {
    if (Test-Path -LiteralPath $ini) {
        foreach ($l in @(Get-Content -LiteralPath $ini -ErrorAction SilentlyContinue)) { if ($l -match '^Version=') { Write-Output ('   version: ' + (San $l)) } }
    }
}
$wordStartup = Join-Path $env:APPDATA 'Microsoft\Word\STARTUP'
Write-Output ('   Word STARTUP dir: ' + (San $wordStartup) + ' exists=' + (Test-Path -LiteralPath $wordStartup))
if (Test-Path -LiteralPath $wordStartup) {
    foreach ($f in @(Get-ChildItem -LiteralPath $wordStartup -ErrorAction SilentlyContinue)) { Write-Output ('   STARTUP: ' + (San ([string]$f.Name)) + '  ' + [math]::Round($f.Length / 1KB, 1) + ' KB') }
}
foreach ($alt in @((Join-Path $env:APPDATA 'Microsoft\Word\STARTUP\zotero.dotm'), 'C:\Program Files (x86)\Microsoft Office\root\Office16\STARTUP\zotero.dotm')) {
    if (Test-Path -LiteralPath $alt) { Write-Output ('   dotm found: ' + (San $alt)) }
}
# zotero word integration extension dir
foreach ($d in @('E:\Zotero\extensions\zoteroWinWordIntegration@zotero.org', (Join-Path $env:APPDATA 'Zotero\Zotero\extensions\zoteroWinWordIntegration@zotero.org'))) {
    if (Test-Path -LiteralPath $d) {
        Write-Output ('   integration ext: ' + (San $d))
        foreach ($f in @(Get-ChildItem -LiteralPath $d -Recurse -Filter '*.dotm' -ErrorAction SilentlyContinue | Select-Object -First 3)) { Write-Output ('     dotm: ' + (San ([string]$f.FullName)) + '  ' + [math]::Round($f.Length / 1KB, 1) + ' KB') }
    }
}

# -------------------------------------------- 4. start Zotero + ping
Write-Output '--- 4. start Zotero ---'
$already = $false
try { $already = [bool](Get-Process -Name zotero -ErrorAction SilentlyContinue) } catch { }
if (-not $already -and $zexe) {
    try {
        Start-Process -FilePath $zexe
        Write-Output '   zotero launched, waiting for local API ...'
    } catch { Write-Output ('   [WARN] launch: ' + (San $_.Exception.Message)) }
} elseif ($already) { Write-Output '   zotero already running' }
$ping = ''
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 4
    try {
        $ping = (& curl.exe -s --max-time 4 'http://localhost:23119/connector/ping' 2>$null | Out-String).Trim()
        if ($ping) { break }
    } catch { }
}
Write-Output ('   connector ping: ' + $(if ($ping) { (San $ping.Substring(0, [Math]::Min(150, $ping.Length))) } else { 'NO RESPONSE after 80s' }))

# -------------------------------------------- 5. current docx fields
Write-Output '--- 5. current English.docx field count ---'
try {
    $tmp = Join-Path $env:TEMP ('zck_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $tmp -Force
    Copy-Item -LiteralPath 'E:\0writing\Light-skills\projects\English.docx' -Destination (Join-Path $tmp 'd.zip')
    Expand-Archive -LiteralPath (Join-Path $tmp 'd.zip') -DestinationPath $tmp -Force
    $raw = [System.IO.File]::ReadAllText((Join-Path $tmp 'word\document.xml'))
    Write-Output ('   ZOTERO_ITEM=' + ([regex]::Matches($raw, 'ZOTERO_ITEM')).Count + '  ZOTERO_BIBL=' + ([regex]::Matches($raw, 'ZOTERO_BIBL')).Count + '  custom.xml=' + (Test-Path -LiteralPath (Join-Path $tmp 'docProps\custom.xml')))
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# -------------------------------------------- 6. crossref verify
Write-Output '--- 6. crossref DOI verification of 36 refs ---'
$j = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot\..\..
    $env:PYTHONIOENCODING = 'utf-8'
    python code\tasks\t54_crossref_verify.py 2>&1 | Out-String
}
if (Wait-Job $j -Timeout 400) {
    foreach ($l in @((Receive-Job $j | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   [TIMEOUT] crossref verify' }
Remove-Job $j -Force -ErrorAction SilentlyContinue
exit 0
