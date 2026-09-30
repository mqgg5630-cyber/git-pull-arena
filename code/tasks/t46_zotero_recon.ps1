# t46_zotero_recon.ps1 - round 57 task: recon for "make English.docx
# Zotero-linked, same format, same output path". READ-ONLY.
#  A. E:\0writing tree (find Light-skills + successful case files)
#  B. English.docx deep analysis (citations now? zotero fields? patterns)
#  C. other docx in Light-skills: which are Zotero-linked (the success case)
#  D. zotero-related code in E:\0mcp-agv (rg)
#  E. heads of the most relevant scripts
#  F. Zotero runtime state (process, sqlite, local API)
# Findings -> results/status/r57_zotero_recon.md
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

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

Write-Output '--- task t46: Zotero-link recon (READ-ONLY) ---'
$find = New-Object System.Text.StringBuilder
[void]$find.AppendLine('# r57 zotero recon findings')
[void]$find.AppendLine('')

# ---------------------------------------------------------- A. trees
Write-Output '--- A. E:\0writing tree ---'
foreach ($root in @('E:\0writing', 'E:\0writing\Light-skills', 'E:\0writing\Light-skills\projects')) {
    if (Test-Path -LiteralPath $root) {
        Write-Output ('   DIR ' + $root)
        [void]$find.AppendLine('## ' + $root)
        foreach ($i in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 40)) {
            $line = ('- ' + $(if ($i.PSIsContainer) { '[D] ' } else { (FmtB ([double]$i.Length)).PadLeft(11) + '  ' }) + $i.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + '  ' + $i.Name)
            Write-Output ('   ' + (San $line))
            [void]$find.AppendLine($line)
        }
        [void]$find.AppendLine('')
    } else { Write-Output ('   ABSENT ' + $root) }
}

# --------------------------------------------- docx analysis helper
function Analyze-Docx {
    param([string]$path)
    $r = @{ zitem = 0; zbib = 0; csl = 0; addin = 0; brackets = 0; authyear = 0; paras = 0; samples = @(); fields = @() }
    $tmp = Join-Path $env:TEMP ('zx_' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $null = New-Item -ItemType Directory -Path $tmp -Force
    $zip = Join-Path $tmp 'd.zip'
    try {
        Copy-Item -LiteralPath $path -Destination $zip -ErrorAction Stop
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -ErrorAction Stop
        $docXml = Join-Path $tmp 'word\document.xml'
        if (Test-Path -LiteralPath $docXml) {
            $raw = [System.IO.File]::ReadAllText($docXml)
            $r.zitem = ([regex]::Matches($raw, 'ZOTERO_ITEM')).Count
            $r.zbib = ([regex]::Matches($raw, 'ZOTERO_BIB')).Count
            $r.csl = ([regex]::Matches($raw, 'CSL_CITATION')).Count
            $r.addin = ([regex]::Matches($raw, 'ADDIN')).Count
            # per-paragraph text
            $paras = @()
            foreach ($pm in [regex]::Matches($raw, '(?s)<w:p[ >].*?</w:p>')) {
                $txt = ''
                foreach ($tm in [regex]::Matches($pm.Value, '<w:t(?: [^>]*)?>([^<]*)</w:t>')) { $txt += $tm.Groups[1].Value }
                if ($txt.Trim().Length -gt 0) { $paras += $txt }
            }
            $r.paras = $paras.Count
            $r.brackets = ([regex]::Matches(($paras -join ' '), '\[\d{1,3}[\],;]')).Count
            $r.authyear = ([regex]::Matches(($paras -join ' '), '[A-Z][A-Za-z\-]{1,20}( et al\.)?,? (19|20)\d{2}')).Count
            $r.samples = @($paras | Select-Object -First 25)
            # field codes (instrText)
            $flds = @()
            foreach ($fm in [regex]::Matches($raw, '<w:instrText[^>]*>([^<]*)</w:instrText>')) { $flds += $fm.Groups[1].Value }
            $r.fields = @($flds | Select-Object -First 6)
        }
    } catch { } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $r
}

# --------------------------------------------- B. English.docx itself
Write-Output '--- B. English.docx analysis ---'
$target = 'E:\0writing\Light-skills\projects\English.docx'
if (Test-Path -LiteralPath $target) {
    $fi = Get-Item -LiteralPath $target
    Write-Output ('   file: ' + (FmtB ([double]$fi.Length)) + '  ' + $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
    $a = Analyze-Docx $target
    Write-Output ('   paragraphs: ' + $a.paras + ' ; zotero-item fields: ' + $a.zitem + ' ; zotero-bib: ' + $a.zbib + ' ; CSL: ' + $a.csl + ' ; ADDIN: ' + $a.addin)
    Write-Output ('   citation-ish: [n] pattern x' + $a.brackets + ' ; AuthorYear x' + $a.authyear)
    [void]$find.AppendLine('## English.docx analysis')
    [void]$find.AppendLine(('- paragraphs: ' + $a.paras + ' ; ZOTERO_ITEM: ' + $a.zitem + ' ; ZOTERO_BIB: ' + $a.zbib + ' ; CSL_CITATION: ' + $a.csl + ' ; ADDIN: ' + $a.addin))
    [void]$find.AppendLine(('- bracket-citation [n] matches: ' + $a.brackets + ' ; AuthorYear matches: ' + $a.authyear))
    [void]$find.AppendLine('')
    [void]$find.AppendLine('### first 25 paragraphs')
    foreach ($s in $a.samples) { [void]$find.AppendLine('- ' + $s.Substring(0, [Math]::Min(220, $s.Length))) }
    [void]$find.AppendLine('')
    if ($a.fields.Count -gt 0) {
        [void]$find.AppendLine('### instrText fields (first 6, 500 chars each)')
        foreach ($f in $a.fields) { [void]$find.AppendLine('- ' + $f.Substring(0, [Math]::Min(500, $f.Length))) }
        [void]$find.AppendLine('')
    }
    Write-Output '   first paragraphs (see findings file for full):'
    foreach ($s in @($a.samples | Select-Object -First 6)) { Write-Output ('   P: ' + (San ($s.Substring(0, [Math]::Min(110, $s.Length))))) }
} else {
    Write-Output ('   [FAIL] target not found: ' + $target)
    # search for it
    foreach ($hit in @(Get-ChildItem -Path 'E:\0writing' -Recurse -Filter 'English*.docx' -ErrorAction SilentlyContinue | Select-Object -First 5)) { Write-Output ('   FOUND ' + (San ([string]$hit.FullName))) }
}

# ------------------------------------ C. other docx (success cases)
Write-Output '--- C. other docx in Light-skills (find the zotero-linked case) ---'
$docxs = @(Get-ChildItem -LiteralPath 'E:\0writing\Light-skills' -Recurse -Filter '*.docx' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^~\$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 12)
[void]$find.AppendLine('## docx inventory in Light-skills')
foreach ($d in $docxs) {
    $a = Analyze-Docx $d.FullName
    $linked = ($a.zitem -gt 0 -or $a.csl -gt 0)
    $line = ('- ' + $d.Name + ' : ' + (FmtB ([double]$d.Length)) + ' ; ZOTERO_ITEM=' + $a.zitem + ' CSL=' + $a.csl + ' ZOTERO_BIB=' + $a.zbib + ' ; paras=' + $a.paras + ' ; [n]x' + $a.brackets + ' AYx' + $a.authyear + $(if ($linked) { '  <== ZOTERO-LINKED' } else { '' }) + ' ; ' + $d.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + ' ; ' + $d.FullName)
    Write-Output ('   ' + (San $line))
    [void]$find.AppendLine($line)
    if ($linked) {
        [void]$find.AppendLine(('  - field samples of ' + $d.Name + ':'))
        foreach ($f in $a.fields) { [void]$find.AppendLine('    - ' + $f.Substring(0, [Math]::Min(900, $f.Length))) }
    }
}
[void]$find.AppendLine('')

# ------------------------------------ D. zotero code in 0mcp-agv
Write-Output '--- D. zotero-related files (rg) ---'
$rgHits = @()
try {
    $rgOut = (& rg -i -l --no-messages -g '!node_modules/**' -g '*.py' -g '*.md' -g '*.json' -g '*.txt' -g '*.js' -g '*.ts' 'zotero' 'E:\0mcp-agv' 'E:\0writing' 2>$null | Out-String)
    $rgHits = @($rgOut -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 40)
} catch { }
if ($rgHits.Count -eq 0) { Write-Output '   (rg found nothing or failed - will rely on filenames)' }
foreach ($h in $rgHits) {
    Write-Output ('   RG ' + (San ([string]$h)))
    [void]$find.AppendLine('- rg-hit: ' + $h)
}

# ------------------------------------ E. heads of key scripts
Write-Output '--- E. key script heads ---'
$keyFiles = @()
foreach ($h in $rgHits) { if ($h -match '(zotero|thesis|writing)' -and (Test-Path -LiteralPath $h)) { $keyFiles += $h } }
foreach ($extra in @('E:\0mcp-agv\scratch\inspect_zotero.py', 'E:\0mcp-agv\mcp_servers\lark_thesis_mcp_server.py')) {
    if ((Test-Path -LiteralPath $extra) -and ($keyFiles -notcontains $extra)) { $keyFiles += $extra }
}
foreach ($kf in @($keyFiles | Select-Object -First 6)) {
    Write-Output ('   HEAD ' + (San $kf))
    [void]$find.AppendLine('')
    [void]$find.AppendLine('### head of ' + $kf)
    try {
        $ln = 0
        foreach ($l in @(Get-Content -LiteralPath $kf -TotalCount 45 -ErrorAction SilentlyContinue)) {
            $ln++
            [void]$find.AppendLine(('    ' + $l))
            if ($ln -le 12) { Write-Output ('     ' + (San ([string]$l))) }
        }
    } catch { }
}

# ------------------------------------ F. Zotero runtime
Write-Output '--- F. Zotero runtime ---'
try {
    $zp = Get-Process -Name zotero -ErrorAction SilentlyContinue
    Write-Output ('   zotero.exe process: ' + $(if ($zp) { 'RUNNING (pid ' + ($zp | Select-Object -First 1).Id + ')' } else { 'not running' }))
} catch { }
foreach ($zdir in @('E:\Zotero', 'E:\Zotero\data')) {
    if (Test-Path -LiteralPath $zdir) {
        Write-Output ('   dir ' + $zdir + ': ' + (@(Get-ChildItem -LiteralPath $zdir -ErrorAction SilentlyContinue).Count) + ' entries')
        $sq = Get-ChildItem -LiteralPath $zdir -Recurse -Filter 'zotero.sqlite' -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 2
        foreach ($s in $sq) { Write-Output ('   sqlite: ' + (San ([string]$s.FullName)) + '  ' + (FmtB ([double]$s.Length))) }
    }
}
try {
    $api = (& curl.exe -s --max-time 5 'http://localhost:23119/api/users/0/items?limit=1' 2>$null | Out-String)
    Write-Output ('   local API /items: ' + $(if ($api) { (San ($api.Substring(0, [Math]::Min(160, $api.Length)))) } else { 'no response (Zotero closed or API off)' }))
    $ping = (& curl.exe -s --max-time 5 'http://localhost:23119/connector/ping' 2>$null | Out-String)
    Write-Output ('   connector ping: ' + $(if ($ping) { (San ($ping.Substring(0, [Math]::Min(120, $ping.Length)))) } else { 'no response' }))
} catch { Write-Output ('   [WARN] api probe: ' + (San $_.Exception.Message)) }
# better-bibtex?
try {
    $bb = & curl.exe -s --max-time 5 'http://localhost:23119/better-bibtex/cayw?probe=true' 2>$null
    Write-Output ('   better-bibtex probe: ' + $(if ($bb) { (San ([string]$bb)) } else { 'no response' }))
} catch { }

try {
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'results\status\r57_zotero_recon.md'), $find.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Output '   findings: results/status/r57_zotero_recon.md'
} catch { Write-Output ('   [WARN] findings: ' + (San $_.Exception.Message)) }
exit 0
