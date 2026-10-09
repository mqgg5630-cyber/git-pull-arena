# t204_lastpage_evidence_r267.ps1
# Round 267: round 266 proved the last page carries NO picture at all - the only
# real picture in the document is a 180x63pt floating logo anchored on page 1,
# and the two "images" Word reports on page 6 are the WMF previews of two
# Forms.CheckBox.1 ActiveX controls. So there is nothing to swap, and the
# request has to be read differently.
#
# This round ships the evidence the agent needs to decide, and nothing else:
#   1. sources/zhongqi/image-1.jpeg            - the picture the user wants placed
#   2. sources/zhongqi/lastpage.pdf            - ONLY page 6, exported by Word
#      (one page, so the rest of the thesis is not published anywhere)
# The document itself is NOT modified in this round.
#
# ASCII-only source.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path

$outRoot = Join-Path $repo 'results\status'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$reportMd = Join-Path $outRoot 'LASTPAGE_EVIDENCE_R267.md'
$dest = Join-Path $repo 'sources\zhongqi'
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$L = New-Object System.Collections.Generic.List[string]
function Say([string]$s) { $L.Add($s) | Out-Null; Write-Output $s }
function CpStr([int[]]$codes) { return (-join ($codes | ForEach-Object { [char]$_ })) }

$dir = 'E:\0zhongqi\zhongqi-arena_out\deliverable'
$imgPath = Join-Path $dir 'image-1.jpeg'
$stemCodes = @(0x4E2D, 0x671F, 0x005F, 0x6700, 0x7EC8, 0x7248)
$docPath = Join-Path $dir ((CpStr $stemCodes) + ' (1).docx')

Say '# last-page evidence - round 267'
Say ''
Say ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Say ('host=' + $env:COMPUTERNAME)
Say ('docx_found=' + (Test-Path -LiteralPath $docPath))
Say ('image_found=' + (Test-Path -LiteralPath $imgPath))

# ------------------------------------------------- 1. the user's picture
$imgCopied = $false
if (Test-Path -LiteralPath $imgPath) {
    Copy-Item -LiteralPath $imgPath -Destination (Join-Path $dest 'image-1.jpeg') -Force
    $imgCopied = Test-Path -LiteralPath (Join-Path $dest 'image-1.jpeg')
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $im = [System.Drawing.Image]::FromFile($imgPath)
        Say ('image_px=' + $im.Width + 'x' + $im.Height)
        Say ('image_aspect=' + [math]::Round($im.Width / [double]$im.Height, 4))
        $im.Dispose()
    } catch { }
    Say ('image_bytes=' + (Get-Item -LiteralPath $imgPath).Length)
}
Say ('IMAGE_COPIED=' + $imgCopied)

# ------------------------------------------- 2. export ONLY the last page
$pdfOut = Join-Path $dest 'lastpage.pdf'
$pdfOk = $false
$pages = 0
$prog = ''
foreach ($cand in @('Word.Application', 'KWPS.Application')) {
    if (Test-Path -LiteralPath ('Registry::HKEY_CLASSES_ROOT\' + $cand)) { $prog = $cand; break }
}
Say ('com_server=' + $prog)
if ($prog -and (Test-Path -LiteralPath $docPath)) {
    $job = Start-Job -ArgumentList $prog, $docPath, $pdfOut -ScriptBlock {
        param($srv, $src, $pdf)
        $app = New-Object -ComObject $srv
        try {
            try { $app.Visible = $false } catch { }
            try { $app.DisplayAlerts = 0 } catch { }
            $doc = $app.Documents.Open($src, $false, $true)
            try { $doc.Repaginate() } catch { }
            $n = [int]$doc.ComputeStatistics(2)
            # ExportAsFixedFormat: 17 = wdExportFormatPDF, Range 3 = wdExportFromTo
            $doc.ExportAsFixedFormat($pdf, 17, $false, 0, 3, $n, $n, 0, $false, $true, 0, $false, $true, $false)
            $doc.Close($false)
            return ('PAGES=' + $n)
        } finally { try { $app.Quit() } catch { } }
    }
    $done = Wait-Job $job -Timeout 240
    if ($done -and $job.State -eq 'Completed') {
        $r = [string](Receive-Job $job)
        if ($r -match 'PAGES=(\d+)') { $pages = [int]$Matches[1] }
        Say ('export_result=' + $r.Trim())
    } elseif ($done) {
        Say ('export_failed=' + ('' + $job.ChildJobs[0].JobStateInfo.Reason))
    } else {
        Stop-Job $job -ErrorAction SilentlyContinue
        Say 'export_failed=timeout'
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    $pdfOk = Test-Path -LiteralPath $pdfOut
}
Say ('pages_total=' + $pages)
Say ('LASTPAGE_PDF_EXPORTED=' + $pdfOk)
if ($pdfOk) { Say ('lastpage_pdf_bytes=' + (Get-Item -LiteralPath $pdfOut).Length) }

Say ''
Say 'LASTPAGE_EVIDENCE_DONE=True'
$L | Set-Content -LiteralPath $reportMd -Encoding UTF8

if ($imgCopied -and $pdfOk) { exit 0 }
exit 7
