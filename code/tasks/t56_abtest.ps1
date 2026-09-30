# t56_abtest.ps1 - round 68 task: (1) import 36 refs into running Zotero via
# Connector saveItems (python), (2) A/B test: run the Zotero.Refresh macro
# on the SUCCESS-CASE docx (temp copy) vs our English.docx (temp copy) -
# tells us whether E_FAIL is environmental or document-specific,
# (3) dump the first ZOTERO_ITEM field XML of both docs for diffing.
# No original files are modified. ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t56: import refs + A/B refresh test + field XML dump ---'

# ---------------------------------------------------- 1. import to Zotero
Write-Output '--- 1. import 36 refs into Zotero (saveItems) ---'
$j = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot\..\..
    $env:PYTHONIOENCODING = 'utf-8'
    python code\tasks\t56_import_zotero.py 2>&1 | Out-String
}
if (Wait-Job $j -Timeout 240) {
    foreach ($l in @((Receive-Job $j | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   [TIMEOUT] import' }
Remove-Job $j -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------- 2. A/B macro test
Write-Output '--- 2. A/B Zotero.Refresh macro test (temp copies) ---'
$abDir = Join-Path $env:TEMP 'zot_ab'
$null = New-Item -ItemType Directory -Path $abDir -Force
$successSrc = $null
try {
    $successSrc = (Get-ChildItem -LiteralPath 'E:\0writing\cnki-skills\periodontitis-ad-pg-review' -Filter '*.docx' -ErrorAction Stop | Where-Object { $_.Name -match 'Zotero' } | Select-Object -First 1).FullName
} catch { }
if ($successSrc) {
    Copy-Item -LiteralPath $successSrc -Destination (Join-Path $abDir 'success_test.docx') -Force
    Write-Output ('   success-case doc: ' + (San $successSrc))
} else { Write-Output '   [WARN] success-case docx not found' }
Copy-Item -LiteralPath 'E:\0writing\Light-skills\projects\English.docx' -Destination (Join-Path $abDir 'mine_test.docx') -Force

foreach ($case in @('success_test.docx', 'mine_test.docx')) {
    $p = Join-Path $abDir $case
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $t = Start-Job -ScriptBlock {
        param($path)
        $out = @()
        $word = $null
        $doc = $null
        try {
            $word = New-Object -ComObject Word.Application
            $word.Visible = $false
            $word.DisplayAlerts = 0
            $doc = $word.Documents.Open($path)
            $out += ('opened fields=' + $doc.Fields.Count)
            try {
                $word.Run('Zotero.Refresh')
                $out += 'macro Zotero.Refresh RAN OK'
                Start-Sleep -Seconds 3
                $out += ('fields after=' + $doc.Fields.Count)
            } catch {
                $out += ('macro error: ' + $_.Exception.Message)
            }
            $doc.Close($false)
            $doc = $null
        } catch {
            $out += ('FAIL: ' + $_.Exception.Message)
        } finally {
            if ($doc) { try { $doc.Close($false) } catch { } }
            if ($word) { try { $word.Quit() } catch { } }
        }
        $out -join "`n"
    } -ArgumentList $p
    if (Wait-Job $t -Timeout 150) {
        foreach ($l in @((Receive-Job $t | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   [' + $case + '] ' + (San ([string]$l))) }
    } else {
        Write-Output ('   [' + $case + '] TIMEOUT - killing Word')
        Stop-Process -Name WINWORD -Force -ErrorAction SilentlyContinue
    }
    Remove-Job $t -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------- 3. field XML dump
Write-Output '--- 3. first-field XML dump of both docs ---'
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Dump-FirstField {
    param([string]$docxPath, [string]$outPath)
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($docxPath)
        $entry = $zip.GetEntry('word/document.xml')
        $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
        $xml = $reader.ReadToEnd()
        $reader.Close()
        $zip.Dispose()
        $i = $xml.IndexOf('ZOTERO_ITEM')
        $start = [Math]::Max(0, $i - 1200)
        $len = [Math]::Min(3000, $xml.Length - $start)
        [System.IO.File]::WriteAllText($outPath, $xml.Substring($start, $len), (New-Object System.Text.UTF8Encoding($false)))
        Write-Output ('   dumped: ' + (San $outPath))
    } catch { Write-Output ('   [WARN] ' + (San $docxPath) + ' : ' + (San $_.Exception.Message)) }
}
$refDir = Join-Path (Get-Location) 'results\reference'
Dump-FirstField (Join-Path $abDir 'mine_test.docx') (Join-Path $refDir 'field_mine.xml')
if ($successSrc) { Dump-FirstField $successSrc (Join-Path $refDir 'field_success.xml') }

# zotero sqlite item count (read-only try)
Write-Output '--- 4. zotero item count (read-only) ---'
$j3 = Start-Job -ScriptBlock {
    $env:PYTHONIOENCODING = 'utf-8'
    python -c "import sqlite3; con=sqlite3.connect('file:E:/ozotero/zotero.sqlite?mode=ro', uri=True); print('items:', con.execute('select count(*) from items').fetchone()[0]); con.close()" 2>&1 | Out-String
}
if (Wait-Job $j3 -Timeout 30) {
    foreach ($l in @((Receive-Job $j3 | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   [TIMEOUT] sqlite (busy - Zotero running)' }
Remove-Job $j3 -Force -ErrorAction SilentlyContinue
exit 0
