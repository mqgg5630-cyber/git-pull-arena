# t55_run.ps1 - round 67 task: (1) rebuild English.docx with zoteroVersion
# 9.0.0 (matches installed Zotero 9.0.6 + success case), (2) fetch the FULL
# push_to_zotero.py source into the repo, (3) drive REAL Word + run the
# Zotero.Refresh macro on the rebuilt document to learn definitively
# whether the fields are recognized. Document opened read-write but closed
# WITHOUT saving, so the file stays as rebuilt.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t55: rebuild v9 + fetch import script + real Refresh test ---'
$path = 'E:\0writing\Light-skills\projects\English.docx'

# ---------------------------------------------------------- 1. rebuild
Write-Output '--- 1. rebuild with zoteroVersion 9.0.0 ---'
$j = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot\..\..
    $env:PYTHONIOENCODING = 'utf-8'
    python code\tasks\t55_rebuild9.py 2>&1 | Out-String
}
if (Wait-Job $j -Timeout 420) {
    foreach ($l in @((Receive-Job $j | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else { Write-Output '   [TIMEOUT] rebuild' }
Remove-Job $j -Force -ErrorAction SilentlyContinue

# --------------------------------------------- 2. fetch push script full
Write-Output '--- 2. fetch full push_to_zotero.py ---'
try {
    $src = 'E:\0writing\cnki-skills\skills\cnki-export\scripts\push_to_zotero.py'
    $dst = Join-Path (Get-Location) 'results\reference\pgreview\push_to_zotero_full.py'
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Write-Output ('   copied: ' + (San $dst) + '  ' + [math]::Round((Get-Item -LiteralPath $dst).Length / 1KB, 1) + ' KB')
    # show the save-call part (lines containing saveItems / sessionID usage)
    $ln = 0
    foreach ($l in @(Get-Content -LiteralPath $src -Encoding UTF8)) {
        $ln++
        if ($l -match 'saveItems|saveSnapshot|sessionID|target|collection') {
            Write-Output ('   L' + $ln + ': ' + (San ([string]$l.Trim())))
        }
    }
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }

# ------------------------------------------ 3. real Zotero Refresh test
Write-Output '--- 3. real-Word Zotero.Refresh macro test ---'
$test = Start-Job -ScriptBlock {
    $path = 'E:\0writing\Light-skills\projects\English.docx'
    $out = @()
    $word = $null
    $doc = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $doc = $word.Documents.Open($path)
        $out += ('opened: ' + $doc.Name + ' fields=' + $doc.Fields.Count)
        $ran = $false
        foreach ($name in @('Zotero.Refresh', 'Zotero.RefreshCmd', 'zotero.Refresh')) {
            try {
                $word.Run($name)
                $out += ('macro ' + $name + ' RAN without exception')
                $ran = $true
                break
            } catch {
                $out += ('macro ' + $name + ' error: ' + $_.Exception.Message)
            }
        }
        if ($ran) {
            Start-Sleep -Seconds 3
            $out += ('fields after refresh: ' + $doc.Fields.Count)
            $i = 0
            foreach ($f in $doc.Fields) {
                $i++
                if ($i -le 2) {
                    $code = ''
                    try { $code = ([string]$f.Code.Text) } catch { }
                    $res = ''
                    try { $res = ([string]$f.Result.Text) } catch { }
                    $out += ('field' + $i + ' code[:90]: ' + $code.Trim().Substring(0, [Math]::Min(90, $code.Trim().Length)))
                    $out += ('field' + $i + ' result[:60]: ' + $res.Trim().Substring(0, [Math]::Min(60, $res.Trim().Length)))
                }
                if ($i -gt 2) { break }
            }
        }
        $doc.Close($false)
        $doc = $null
        $out += 'closed WITHOUT saving (file kept as rebuilt)'
    } catch {
        $out += ('FAIL: ' + $_.Exception.Message)
    } finally {
        if ($doc) { try { $doc.Close($false) } catch { } }
        if ($word) { try { $word.Quit() } catch { } }
    }
    $out -join "`n"
}
if (Wait-Job $test -Timeout 180) {
    foreach ($l in @((Receive-Job $test | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) }
} else {
    Write-Output '   [TIMEOUT] Word/Zotero macro test - a Zotero dialog may be blocking; killing Word'
    Stop-Process -Name WINWORD -Force -ErrorAction SilentlyContinue
}
Remove-Job $test -Force -ErrorAction SilentlyContinue
exit 0
