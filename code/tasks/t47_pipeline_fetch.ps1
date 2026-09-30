# t47_pipeline_fetch.ps1 - round 58 task: pull the SUCCESS-CASE pipeline
# (periodontitis-ad-pg-review) into the repo for study: full tree, docx
# field counts, copy of tools + README + build.py, library JSONs, English.docx
# references section text, E:\ozotero state. READ-ONLY except copies into
# results/reference/. Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}
function FmtB {
    param([double]$b)
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    if ($b -ge 1KB) { return ('{0:N1} KB' -f ($b / 1KB)) }
    return ('{0:N0} B' -f $b)
}

Write-Output '--- task t47: fetch success-case pipeline (periodontitis-ad-pg-review) ---'
$src = 'E:\0writing\cnki-skills\periodontitis-ad-pg-review'
$ref = Join-Path (Get-Location) 'results\reference\pgreview'
$null = New-Item -ItemType Directory -Path $ref -Force

# ---------------------------------------------------------- A. tree
Write-Output '--- A. tree ---'
$items = @(Get-ChildItem -LiteralPath $src -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -First 60)
foreach ($i in $items) {
    $rel = $i.FullName.Substring($src.Length + 1)
    Write-Output ('   ' + $(if ($i.PSIsContainer) { '[D] ' } else { (FmtB ([double]$i.Length)).PadLeft(10) + '  ' }) + (San $rel))
}

# --------------------------------------- B. docx zotero-field counts
function Count-ZFields {
    param([string]$path)
    $n = 0
    $tmp = Join-Path $env:TEMP ('zx_' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $null = New-Item -ItemType Directory -Path $tmp -Force
    try {
        $zip = Join-Path $tmp 'd.zip'
        Copy-Item -LiteralPath $path -Destination $zip -ErrorAction Stop
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -ErrorAction Stop
        $docXml = Join-Path $tmp 'word\document.xml'
        if (Test-Path -LiteralPath $docXml) {
            $raw = [System.IO.File]::ReadAllText($docXml)
            $n = ([regex]::Matches($raw, 'ZOTERO_ITEM')).Count
            $bib = ([regex]::Matches($raw, 'ZOTERO_BIB')).Count
            return @($n, $bib)
        }
    } catch { } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    return @(-1, -1)
}
Write-Output '--- B. docx in the success project ---'
foreach ($d in @(Get-ChildItem -LiteralPath $src -Recurse -Filter '*.docx' -ErrorAction SilentlyContinue | Select-Object -First 6)) {
    $c = Count-ZFields $d.FullName
    Write-Output ('   DOCX ' + (San $d.Name) + '  ZOTERO_ITEM=' + $c[0] + ' ZOTERO_BIB=' + $c[1] + '  ' + (FmtB ([double]$d.Length)))
}

# -------------------------------------------------- C. copy sources
Write-Output '--- C. copy pipeline sources into repo ---'
$copied = 0
foreach ($rel in @('tools\zotero_word_fields.py', 'tools\bib2csljson.py', 'build.py', 'README_Zotero_and_Template.md', 'tests\test_zotero_refresh.py')) {
    $p = Join-Path $src $rel
    if (Test-Path -LiteralPath $p) {
        $dest = Join-Path $ref ($rel -replace '\\', '_')
        Copy-Item -LiteralPath $p -Destination $dest -Force
        $sz = (Get-Item -LiteralPath $dest).Length
        Write-Output ('   COPY ' + (San $rel) + '  ' + (FmtB ([double]$sz)))
        $copied++
    } else { Write-Output ('   ABSENT ' + (San $rel)) }
}
# library jsons anywhere in cnki-skills
foreach ($lj in @(Get-ChildItem -LiteralPath 'E:\0writing\cnki-skills' -Recurse -Filter '*Zotero_library*.json' -ErrorAction SilentlyContinue | Select-Object -First 5)) {
    Write-Output ('   LIBJSON ' + (San ([string]$lj.FullName)) + '  ' + (FmtB ([double]$lj.Length)))
    $dest = Join-Path $ref ('lib_' + $lj.Name)
    Copy-Item -LiteralPath $lj.FullName -Destination $dest -Force
}

# --------------------------------- D. English.docx references section
Write-Output '--- D. English.docx last paragraphs (references list) ---'
$target = 'E:\0writing\Light-skills\projects\English.docx'
$tmp2 = Join-Path $env:TEMP ('zx_' + [guid]::NewGuid().ToString('N').Substring(0, 10))
$null = New-Item -ItemType Directory -Path $tmp2 -Force
$refsTxt = Join-Path (Get-Location) 'results\reference\english_refs.txt'
try {
    $zip2 = Join-Path $tmp2 'd.zip'
    Copy-Item -LiteralPath $target -Destination $zip2 -ErrorAction Stop
    Expand-Archive -LiteralPath $zip2 -DestinationPath $tmp2 -ErrorAction Stop
    $raw = [System.IO.File]::ReadAllText((Join-Path $tmp2 'word\document.xml'))
    $paras = @()
    foreach ($pm in [regex]::Matches($raw, '(?s)<w:p[ >].*?</w:p>')) {
        $txt = ''
        foreach ($tm in [regex]::Matches($pm.Value, '<w:t(?: [^>]*)?>([^<]*)</w:t>')) { $txt += $tm.Groups[1].Value }
        if ($txt.Trim().Length -gt 0) { $paras += $txt }
    }
    $tail = @($paras | Select-Object -Last 80)
    [System.IO.File]::WriteAllLines($refsTxt, $tail, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ('   total paras ' + $paras.Count + ' ; last 80 -> results\reference\english_refs.txt')
    foreach ($t in @($tail | Select-Object -First 12)) { Write-Output ('   R: ' + (San ([string]$t.Substring(0, [Math]::Min(120, $t.Length))))) }
} catch { Write-Output ('   [WARN] refs extract: ' + (San $_.Exception.Message)) } finally { Remove-Item -LiteralPath $tmp2 -Recurse -Force -ErrorAction SilentlyContinue }

# ---------------------------------------------------- E. E:\ozotero
Write-Output '--- E. E:\ozotero (zotero data dir?) ---'
if (Test-Path -LiteralPath 'E:\ozotero') {
    foreach ($z in @(Get-ChildItem -LiteralPath 'E:\ozotero' -ErrorAction SilentlyContinue | Select-Object -First 15)) {
        Write-Output ('   ' + $(if ($z.PSIsContainer) { '[D] ' } else { (FmtB ([double]$z.Length)).PadLeft(10) + '  ' }) + (San ([string]$z.Name)))
    }
    $sq = Get-Item -LiteralPath 'E:\ozotero\zotero.sqlite' -ErrorAction SilentlyContinue
    if ($sq) { Write-Output ('   zotero.sqlite: ' + (FmtB ([double]$sq.Length)) + '  mtime ' + $sq.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) }
} else { Write-Output '   E:\ozotero does not exist' }

# --------------------------------------------- F. python availability
Write-Output '--- F. python + docx libs ---'
try {
    $j = Start-Job -ScriptBlock {
        python --version 2>&1
        python -c "import docx; print('python-docx OK', docx.__version__ if hasattr(docx,'__version__') else '')" 2>&1
        python -c "import lxml; print('lxml OK')" 2>&1
    }
    if (Wait-Job $j -Timeout 40) { foreach ($l in @((Receive-Job $j | Out-String) -split "`r?`n" | Where-Object { $_ -match '\S' })) { Write-Output ('   ' + (San ([string]$l))) } }
    else { Write-Output '   python probe timeout' }
    Remove-Job $j -Force -ErrorAction SilentlyContinue
} catch { Write-Output ('   [WARN] ' + (San $_.Exception.Message)) }
Write-Output ('   copied files: ' + $copied + ' into results/reference/pgreview/')
exit 0
