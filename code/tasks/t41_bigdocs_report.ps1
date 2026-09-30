# t41_bigdocs_report.ps1 - round 50 task: scan big DOCUMENT files (docs
# >= 10MB, archives/data >= 50MB, others >= 200MB) across the user's
# document hotspots + D: + E: (minus app/system dirs), then build the
# combined Chinese report (template + t40 findings) and write it to the
# user's Desktop and the repo.
# READ-ONLY except the two report files.
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
    return ('{0:N1} KB' -f ($b / 1KB))
}

Write-Output '--- task t41: big documents scan + combined report ---'

$docExt = @('.pdf', '.doc', '.docx', '.ppt', '.pptx', '.xls', '.xlsx', '.csv', '.tsv', '.tex', '.ipynb', '.rmd', '.nb')
$arcExt = @('.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.iso', '.hdf5', '.h5', '.parquet', '.pkl', '.npz')
$skipExt = @('.vhdx', '.vmdx', '.sys', '.dll', '.exe')

$docs = New-Object System.Collections.Generic.List[object]
$arcs = New-Object System.Collections.Generic.List[object]
$others = New-Object System.Collections.Generic.List[object]

$deskDir = [Environment]::GetFolderPath('Desktop')
$docDir = [Environment]::GetFolderPath('MyDocuments')
$dlDir = Join-Path $env:USERPROFILE 'Downloads'
$roots = @()
foreach ($r in @($deskDir, $docDir, $dlDir)) { if ($r -and (Test-Path -LiteralPath $r)) { $roots += $r } }
$roots += 'D:\'
$eSkip = @('WSL', 'Docker', 'DockerDesktop', 'hermes', 'vscode', 'Antigravity', 'NsfocusVPN', 'Tailscale', 'LigPlus', 'DS2025', 'Zotero', 'EndNote21', 'sci-HuB', 'Wise Care 365', 'MotrixNext', 'java', 'spider', 'Go', 'LicensePack', 'QwenPaw', '$RECYCLE.BIN', 'System Volume Information', '0mcp-agv', 'pagefile.sys')
$roots += 'E:\'

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$cap = 660
$scanned = [long]0
foreach ($root in $roots) {
    $stack = New-Object System.Collections.Stack
    $stack.Push($root)
    $isE = ($root -eq 'E:\')
    $isD = ($root -eq 'D:\')
    while ($stack.Count -gt 0) {
        if ($sw.Elapsed.TotalSeconds -gt $cap) { break }
        $dir = [string]$stack.Pop()
        try {
            foreach ($sd in [System.IO.Directory]::EnumerateDirectories($dir)) {
                $leaf = [System.IO.Path]::GetFileName($sd)
                $skip = $false
                if ($isE -and ($leaf -in $eSkip -or $leaf -match 'zTasker|RECYCLE|Volume')) { $skip = $true }
                if ($isD -and ($leaf -eq 'WSL' -or $leaf -eq '$RECYCLE.BIN')) { $skip = $true }
                try {
                    $attr = [System.IO.File]::GetAttributes($sd)
                    if (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { $skip = $true }
                } catch { }
                if (-not $skip) { $stack.Push($sd) }
            }
        } catch { }
        try {
            foreach ($f in [System.IO.Directory]::EnumerateFiles($dir)) {
                $len = [double]0
                $lw = [datetime]::MinValue
                $ext = ''
                try {
                    $fi = [System.IO.FileInfo]::new($f)
                    $len = [double]$fi.Length
                    $lw = $fi.LastWriteTime
                    $ext = $fi.Extension.ToLowerInvariant()
                } catch { continue }
                if ($len -le 0) { continue }
                $scanned++
                if ($ext -in $skipExt) { continue }
                if ($ext -in $docExt) {
                    if ($len -ge 10MB) { $docs.Add([pscustomobject]@{ p = $f; sz = $len; lw = $lw }) }
                } elseif ($ext -in $arcExt) {
                    if ($len -ge 50MB) { $arcs.Add([pscustomobject]@{ p = $f; sz = $len; lw = $lw }) }
                } else {
                    if ($len -ge 200MB) { $others.Add([pscustomobject]@{ p = $f; sz = $len; lw = $lw }) }
                }
            }
        } catch { }
    }
    if ($sw.Elapsed.TotalSeconds -gt $cap) { Write-Output ('   [WARN] scan cap hit at ' + $root); break }
}
Write-Output ('   scanned files: ' + $scanned + ' in ' + [int]$sw.Elapsed.TotalSeconds + 's')
$docs = @($docs | Sort-Object sz -Descending)
$arcs = @($arcs | Sort-Object sz -Descending)
$others = @($others | Sort-Object sz -Descending)
Write-Output ('   docs >=10MB: ' + $docs.Count + ' ; archives/data >=50MB: ' + $arcs.Count + ' ; others >=200MB: ' + $others.Count)
Write-Output '--- top documents ---'
foreach ($d in ($docs | Select-Object -First 15)) { Write-Output ('   DOC  ' + (FmtB ([double]$d.sz)).PadLeft(10) + '  ' + $d.lw.ToString('yyyy-MM-dd') + '  ' + (San ([string]$d.p))) }

# ---------------------------------------------- build the report
# Chinese labels assembled from char codes (source stays ASCII)
$wSize = [string]([char]0x5927 + [char]0x5C0F)
$wDate = [string]([char]0x4FEE + [char]0x6539 + [char]0x65E5 + [char]0x671F)
$wFile = [string]([char]0x6587 + [char]0x4EF6)
$wDocs = [string]([char]0x6587 + [char]0x6863 + [char]0x7C7B)
$wArc = [string]([char]0x538B + [char]0x7F29 + [char]0x5305) + '/' + [string]([char]0x6570 + [char]0x636E + [char]0x96C6)
$wOth = [string]([char]0x5176 + [char]0x4ED6 + [char]0x5927 + [char]0x6587 + [char]0x4EF6)
$wGe = [string]([char]0x5171)
$wGe2 = [string]([char]0x4E2A)
$wQian = [string]([char]0x524D)

$tplPath = Join-Path (Get-Location) 'code\tasks\t41_report_template.md'
$findPath = Join-Path (Get-Location) 'results\status\r50_findings.md'
$tpl = ''
$raw = ''
try { $tpl = [System.IO.File]::ReadAllText($tplPath, [System.Text.Encoding]::UTF8) } catch { Write-Output ('   [FAIL] template: ' + (San $_.Exception.Message)); exit 2 }
try { $raw = [System.IO.File]::ReadAllText($findPath, [System.Text.Encoding]::UTF8) } catch { Write-Output ('   [WARN] findings missing: ' + (San $_.Exception.Message)) }

$mcpSec = ''
$n8nSec = ''
$rSec = ''
if ($raw) {
    $iN = $raw.IndexOf('### n8n')
    $iR = $raw.IndexOf('### R')
    if ($iN -ge 0 -and $iR -gt $iN) {
        $mcpSec = $raw.Substring(0, $iN).TrimEnd()
        $n8nSec = $raw.Substring($iN + 8, $iR - ($iN + 8)).TrimEnd()
        $rSec = $raw.Substring($iR + 5).TrimEnd()
    } else { $mcpSec = $raw }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('### ' + $wDocs + ' >= 10 MB, ' + $wGe + ' ' + $docs.Count + ' ' + $wGe2 + ', ' + $wQian + ' 80')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| ' + $wSize + ' | ' + $wDate + ' | ' + $wFile + ' |')
[void]$sb.AppendLine('|---|---|---|')
foreach ($d in ($docs | Select-Object -First 80)) {
    [void]$sb.AppendLine('| ' + (FmtB ([double]$d.sz)) + ' | ' + $d.lw.ToString('yyyy-MM-dd') + ' | ' + $d.p + ' |')
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('### ' + $wArc + ' >= 50 MB, ' + $wGe + ' ' + $arcs.Count + ' ' + $wGe2 + ', ' + $wQian + ' 40')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| ' + $wSize + ' | ' + $wDate + ' | ' + $wFile + ' |')
[void]$sb.AppendLine('|---|---|---|')
foreach ($a in ($arcs | Select-Object -First 40)) {
    [void]$sb.AppendLine('| ' + (FmtB ([double]$a.sz)) + ' | ' + $a.lw.ToString('yyyy-MM-dd') + ' | ' + $a.p + ' |')
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('### ' + $wOth + ' >= 200 MB, ' + $wGe + ' ' + $others.Count + ' ' + $wGe2 + ', ' + $wQian + ' 20')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| ' + $wSize + ' | ' + $wDate + ' | ' + $wFile + ' |')
[void]$sb.AppendLine('|---|---|---|')
foreach ($o in ($others | Select-Object -First 20)) {
    [void]$sb.AppendLine('| ' + (FmtB ([double]$o.sz)) + ' | ' + $o.lw.ToString('yyyy-MM-dd') + ' | ' + $o.p + ' |')
}
$docsTable = $sb.ToString()

$content = $tpl.Replace('{{MCP_SECTION}}', $mcpSec).Replace('{{N8N_SECTION}}', $n8nSec).Replace('{{R_SECTION}}', $rSec).Replace('{{DOCS_TABLE}}', $docsTable)

$desk = [Environment]::GetFolderPath('Desktop')
$name = [string]([char]0x4EFB + [char]0x52A1 + [char]0x573A + [char]0x666F + [char]0x4E0E + [char]0x5927 + [char]0x6587 + [char]0x4EF6 + [char]0x6E05 + [char]0x5355 + '_2026-09-30.md')
$deskFile = Join-Path $desk $name
try {
    [System.IO.File]::WriteAllText($deskFile, $content, (New-Object System.Text.UTF8Encoding($true)))
    Write-Output ('   DESKTOP COPY: ' + (San $deskFile))
} catch { Write-Output ('   [WARN] desktop copy: ' + (San $_.Exception.Message)) }
try {
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'results\status\task_scenarios_r50.md'), $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output '   repo copy: results/status/task_scenarios_r50.md'
} catch { Write-Output ('   [WARN] repo copy: ' + (San $_.Exception.Message)) }
exit 0
