# t205_lastpage_swap_r268.ps1
# Round 268: the evidence from round 267 settled what the request means.
#   image-1.jpeg (1280x1840) is a PHOTO of page 6 of this very document, signed
#   by the supervisor, signed by the panel chair and stamped with the red seal.
#   Page 6 of the docx is the same form, blank. So "replace the last page" =
#   make that scan BE page 6, with the document still 6 pages long and pages
#   1-5 untouched.
#
# Method (Word COM, on a COPY - the original is never opened read-write):
#   1. remember the text of pages 1..5 (hash) so we can prove they survive
#   2. delete everything from the start of the last page to the end
#   3. re-create exactly one page and drop the scan on it, scaled to the
#      printable area with its aspect ratio locked (no stretch, no crop)
#   4. if the page count moved, shrink 2% and retry - never accept 7 pages
#   5. export the new last page to PDF so the agent can SEE the result
#
# ASCII-only source.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path

$outRoot = Join-Path $repo 'results\status'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$reportMd   = Join-Path $outRoot 'LASTPAGE_SWAP_R268.md'
$reportJson = Join-Path $outRoot 'LASTPAGE_SWAP_R268.json'
$dest = Join-Path $repo 'sources\zhongqi'
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$L = New-Object System.Collections.Generic.List[string]
function Say([string]$s) { $L.Add($s) | Out-Null; Write-Output $s }
function CpStr([int[]]$codes) { return (-join ($codes | ForEach-Object { [char]$_ })) }
function Esc([string]$s) {
    if ($null -eq $s) { return '' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $c = [int][char]$ch
        if ($c -ge 32 -and $c -le 126) { [void]$sb.Append($ch) } else { [void]$sb.Append(('\u{0:X4}' -f $c)) }
    }
    return $sb.ToString()
}
function Sha256File([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return '' }
    return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()
}

$dir = 'E:\0zhongqi\zhongqi-arena_out\deliverable'
$imgPath = Join-Path $dir 'image-1.jpeg'
$stemCodes = @(0x4E2D, 0x671F, 0x005F, 0x6700, 0x7EC8, 0x7248)
$docPath = Join-Path $dir ((CpStr $stemCodes) + ' (1).docx')
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$outPath = Join-Path $dir ((CpStr $stemCodes) + ' (1)_signed-lastpage_' + $stamp + '.docx')
$pdfAfter = Join-Path $dest 'lastpage_after.pdf'

$result = [ordered]@{ round = 268; time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'); host = $env:COMPUTERNAME }

Say '# replace the last page with the signed scan - round 268'
Say ''
Say ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Say ('host=' + $env:COMPUTERNAME)
Say ''
Say '## 1. inputs'
Say ('docx_raw=' + $docPath)
Say ('docx_found=' + (Test-Path -LiteralPath $docPath))
Say ('image_found=' + (Test-Path -LiteralPath $imgPath))
if (-not (Test-Path -LiteralPath $docPath) -or -not (Test-Path -LiteralPath $imgPath)) {
    Say 'FATAL input missing'
    Say 'LASTPAGE_SWAP_OK=False'
    Say 'LASTPAGE_SWAP_DONE=True'
    $L | Set-Content -LiteralPath $reportMd -Encoding UTF8
    $result['status'] = 'input_missing'
    ($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8
    exit 7
}
Say ('source_sha256=' + (Sha256File $docPath))

Copy-Item -LiteralPath $docPath -Destination $outPath -Force
Say ('working_copy=' + $outPath)

$prog = ''
foreach ($cand in @('Word.Application', 'KWPS.Application')) {
    if (Test-Path -LiteralPath ('Registry::HKEY_CLASSES_ROOT\' + $cand)) { $prog = $cand; break }
}
Say ('com_server=' + $prog)
if (-not $prog) {
    Say 'FATAL no Word/WPS COM server registered - cannot repaginate reliably'
    Say 'LASTPAGE_SWAP_OK=False'
    Say 'LASTPAGE_SWAP_DONE=True'
    $L | Set-Content -LiteralPath $reportMd -Encoding UTF8
    $result['status'] = 'no_com'
    ($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8
    exit 7
}

$job = Start-Job -ArgumentList $prog, $outPath, $imgPath, $pdfAfter -ScriptBlock {
    param($srv, $docFile, $picFile, $pdfFile)
    $log = New-Object System.Collections.Generic.List[string]
    function Add-Log($s) { $log.Add([string]$s) | Out-Null }
    $app = New-Object -ComObject $srv
    try {
        try { $app.Visible = $false } catch { }
        try { $app.DisplayAlerts = 0 } catch { }
        try { $app.ScreenUpdating = $false } catch { }
        $doc = $app.Documents.Open($docFile, $false, $false)   # read-write
        try { $doc.Repaginate() } catch { }
        $pagesBefore = [int]$doc.ComputeStatistics(2)
        Add-Log ('PAGES_BEFORE=' + $pagesBefore)
        if ($pagesBefore -lt 2) { throw 'document has fewer than 2 pages' }

        # --- remember pages 1..(n-1) so we can prove they are untouched
        $startLast = $doc.GoTo(1, 1, $pagesBefore)             # wdGoToPage, wdGoToAbsolute
        $prefix = $doc.Range(0, $startLast.Start)
        $prefixText = [string]$prefix.Text
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $prefixHash = ([System.BitConverter]::ToString(
            $sha.ComputeHash([System.Text.Encoding]::Unicode.GetBytes($prefixText)))).Replace('-','').ToLower()
        Add-Log ('PREFIX_CHARS=' + $prefixText.Length)
        Add-Log ('PREFIX_SHA_BEFORE=' + $prefixHash)

        # --- page geometry (printable area)
        $ps = $doc.Sections.Item($doc.Sections.Count).PageSetup
        $contentW = [double]$ps.PageWidth - [double]$ps.LeftMargin - [double]$ps.RightMargin
        $contentH = [double]$ps.PageHeight - [double]$ps.TopMargin - [double]$ps.BottomMargin
        Add-Log ('CONTENT_AREA_PT=' + [math]::Round($contentW,1) + 'x' + [math]::Round($contentH,1))

        # --- delete the whole last page
        $del = $doc.Range($startLast.Start, $doc.Content.End)
        $del.Delete() | Out-Null
        try { $doc.Repaginate() } catch { }
        $pagesAfterDelete = [int]$doc.ComputeStatistics(2)
        Add-Log ('PAGES_AFTER_DELETE=' + $pagesAfterDelete)

        # --- make sure the picture lands on its own, final page
        $end = $doc.Content
        $end.Collapse(0) | Out-Null                            # 0 = wdCollapseEnd
        if ($pagesAfterDelete -lt $pagesBefore) {
            $end.InsertBreak(7) | Out-Null                     # 7 = wdPageBreak
            Add-Log 'INSERTED_PAGE_BREAK=True'
        } else {
            Add-Log 'INSERTED_PAGE_BREAK=False'
        }
        try { $doc.Repaginate() } catch { }

        $anchor = $doc.Content
        $anchor.Collapse(0) | Out-Null
        $para = $anchor.Paragraphs.Item(1)
        $para.SpaceBefore = 0
        $para.SpaceAfter = 0
        $para.LineSpacingRule = 0                              # wdLineSpaceSingle
        $para.Alignment = 1                                    # centre
        try { $para.LeftIndent = 0; $para.RightIndent = 0; $para.FirstLineIndent = 0 } catch { }

        $shape = $doc.InlineShapes.AddPicture($picFile, $false, $true, $anchor)
        $natW = [double]$shape.Width
        $natH = [double]$shape.Height
        Add-Log ('PICTURE_NATIVE_PT=' + [math]::Round($natW,1) + 'x' + [math]::Round($natH,1))

        # fit inside the printable area, aspect locked
        $fit = [math]::Min($contentW / $natW, $contentH / $natH)
        $pagesAfter = 0
        $attempt = 0
        $k = $fit
        while ($attempt -lt 12) {
            $shape.LockAspectRatio = 0                         # msoFalse - we set both explicitly
            $shape.Width  = [double]($natW * $k)
            $shape.Height = [double]($natH * $k)
            try { $doc.Repaginate() } catch { }
            $pagesAfter = [int]$doc.ComputeStatistics(2)
            Add-Log ('TRY ' + $attempt + ' scale=' + [math]::Round($k,4) +
                     ' size=' + [math]::Round($shape.Width,1) + 'x' + [math]::Round($shape.Height,1) +
                     ' pages=' + $pagesAfter)
            if ($pagesAfter -eq $pagesBefore) { break }
            $k = $k * 0.98
            $attempt = $attempt + 1
        }
        Add-Log ('FINAL_SCALE=' + [math]::Round($k, 4))
        Add-Log ('FINAL_SIZE_PT=' + [math]::Round($shape.Width,1) + 'x' + [math]::Round($shape.Height,1))
        Add-Log ('PAGES_AFTER=' + $pagesAfter)

        # --- prove pages 1..(n-1) are byte-identical in text
        $startLast2 = $doc.GoTo(1, 1, $pagesAfter)
        $prefix2 = $doc.Range(0, $startLast2.Start)
        $prefixText2 = [string]$prefix2.Text
        $prefixHash2 = ([System.BitConverter]::ToString(
            $sha.ComputeHash([System.Text.Encoding]::Unicode.GetBytes($prefixText2)))).Replace('-','').ToLower()
        Add-Log ('PREFIX_SHA_AFTER=' + $prefixHash2)
        Add-Log ('PREFIX_UNCHANGED=' + ($prefixHash2 -eq $prefixHash))

        $doc.Save()
        # export just the new last page so the agent can look at it
        try {
            $doc.ExportAsFixedFormat($pdfFile, 17, $false, 0, 3, $pagesAfter, $pagesAfter, 0, $false, $true, 0, $false, $true, $false)
            Add-Log 'EXPORTED_LASTPAGE_PDF=True'
        } catch { Add-Log ('EXPORTED_LASTPAGE_PDF=False ' + $_.Exception.Message) }
        $doc.Close($false)
        return $log.ToArray()
    } catch {
        Add-Log ('EXCEPTION ' + $_.Exception.Message)
        return $log.ToArray()
    } finally { try { $app.Quit() } catch { } }
}

$done = Wait-Job $job -Timeout 420
Say ''
Say '## 2. Word transcript'
$lines = @()
if (-not $done) {
    Stop-Job $job -ErrorAction SilentlyContinue
    Say '   TIMEOUT after 420s'
} elseif ($job.State -ne 'Completed') {
    Say ('   JOB FAILED ' + ('' + $job.ChildJobs[0].JobStateInfo.Reason))
} else {
    $lines = @(Receive-Job $job)
    foreach ($l in $lines) { Say ('   ' + $l) }
}
Remove-Job $job -Force -ErrorAction SilentlyContinue

function Pick([string]$key) {
    foreach ($l in $lines) { if ($l -match ('^' + [regex]::Escape($key) + '=(.*)$')) { return $Matches[1] } }
    return ''
}
$pagesBefore = Pick 'PAGES_BEFORE'
$pagesAfter  = Pick 'PAGES_AFTER'
$prefixOk    = Pick 'PREFIX_UNCHANGED'
$pagesSame   = ($pagesBefore -ne '' -and $pagesBefore -eq $pagesAfter)

Say ''
Say '## 3. verification'
Say ('pages_before=' + $pagesBefore)
Say ('pages_after=' + $pagesAfter)
Say ('PAGE_COUNT_UNCHANGED=' + $pagesSame)
Say ('PAGES_1_TO_N_MINUS_1_UNCHANGED=' + $prefixOk)
$pdfOk = Test-Path -LiteralPath $pdfAfter
Say ('LASTPAGE_AFTER_PDF=' + $pdfOk)

$overall = $pagesSame -and ($prefixOk -eq 'True') -and (Test-Path -LiteralPath $outPath)
Say ''
Say '## 4. result'
Say ('result_path_raw=' + $outPath)
Say ('result_path_escaped=' + (Esc $outPath))
if (Test-Path -LiteralPath $outPath) {
    Say ('result_bytes=' + (Get-Item -LiteralPath $outPath).Length)
    Say ('result_sha256=' + (Sha256File $outPath))
}
Say ('original_untouched_raw=' + $docPath)
Say ('original_sha256_still=' + (Sha256File $docPath))
Say ''
Say ('LASTPAGE_SWAP_OK=' + $overall)
Say 'LASTPAGE_SWAP_DONE=True'
$L | Set-Content -LiteralPath $reportMd -Encoding UTF8

if ($overall) { $result['status'] = 'ok' } else { $result['status'] = 'failed' }
$result['result_path'] = $outPath
$result['pages_before'] = $pagesBefore
$result['pages_after'] = $pagesAfter
$result['prefix_unchanged'] = $prefixOk
$result['transcript'] = ($lines -join "`n")
($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8

if ($overall) { exit 0 }
exit 7
