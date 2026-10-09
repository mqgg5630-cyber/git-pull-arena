# t202_docx_last_image_replace_r264.ps1
# Replace the picture on the LAST page of a .docx with image-1.jpeg, without
# changing the document layout or the page count.
#
# Strategy (this is the whole trick):
#   word/document.xml is NEVER touched. The picture's display box is stored
#   there as an explicit EMU extent (<wp:extent cx= cy=>), so if we only swap
#   the bytes of the media part inside the zip, Word redraws the same box with
#   new pixels: identical layout, identical reflow, identical page count.
#   The new JPEG is letterboxed (fit, centered, white) onto a canvas with the
#   ORIGINAL aspect ratio, so nothing is stretched and nothing is cropped, and
#   the canvas DPI is adjusted so the image's natural size is unchanged too.
#
# Runs on the Windows machine inside code\local_check.ps1 section 4.
# ASCII-only source (code/check_all.sh enforces it); paths are built from
# code points and the receipt carries both raw and escaped forms.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path

$round = 265
$outRoot = Join-Path $repo 'results\status'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$reportMd   = Join-Path $outRoot 'DOCX_IMAGE_REPLACE.md'
$reportJson = Join-Path $outRoot 'DOCX_IMAGE_REPLACE.json'

$L = New-Object System.Collections.Generic.List[string]
function Say([string]$s) { $L.Add($s) | Out-Null; Write-Output $s }
# NOTE: do NOT name this 'CP' - 'cp' is a built-in alias for Copy-Item and
# PowerShell resolves aliases BEFORE functions, so the alias would win.
function CpStr([int[]]$codes) { return (-join ($codes | ForEach-Object { [char]$_ })) }
function CodesOf([string]$s) { return @($s.ToCharArray() | ForEach-Object { [int][char]$_ }) }
function CodesStartWith([string]$s, [int[]]$prefix) {
    $c = CodesOf $s
    if ($c.Count -lt $prefix.Count) { return $false }
    for ($i = 0; $i -lt $prefix.Count; $i++) { if ($c[$i] -ne $prefix[$i]) { return $false } }
    return $true
}
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
function Utf8NoBom([byte[]]$b) {
    $t = [System.Text.Encoding]::UTF8.GetString($b)
    if ($t.Length -gt 0 -and [int][char]$t[0] -eq 0xFEFF) { $t = $t.Substring(1) }
    return $t
}
function Sha256Bytes([byte[]]$b) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    return ([System.BitConverter]::ToString($h.ComputeHash($b))).Replace('-','').ToLower()
}

$status = 'failed'
$result = [ordered]@{ round = $round; time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'); host = $env:COMPUTERNAME }

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
} catch {
    Say ('FATAL cannot load .NET assemblies: ' + $_.Exception.Message)
}

# ------------------------------------------------------------ 1. locate input
# E:\0zhongqi\zhongqi-arena_out\deliverable
$dir = 'E:\0zhongqi\zhongqi-arena_out\deliverable'
$imgPath = Join-Path $dir 'image-1.jpeg'
# "<CJK>_<CJK> (1).docx"  ->  code points keep this file ASCII-only
$stemCodes = @(0x4E2D, 0x671F, 0x005F, 0x6700, 0x7EC8, 0x7248)
$docStem = (CpStr $stemCodes) + ' (1)'
$docPath = Join-Path $dir ($docStem + '.docx')

Say ('# docx last-page image replace - round ' + $round)
Say ''
Say ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Say ('host=' + $env:COMPUTERNAME)
Say ''
Say '## 1. inputs'
Say ('dir_raw=' + $dir)

Say ('stem_built_escaped=' + (Esc $docStem) + '  chars=' + $docStem.Length)
if (-not (Test-Path -LiteralPath $docPath)) {
    # fallback: compare CODE POINTS on disk, so the match cannot depend on how
    # this file was encoded or on the console code page
    $all = @(Get-ChildItem -LiteralPath $dir -Filter '*.docx' -ErrorAction SilentlyContinue)
    $exact = @($all | Where-Object { (CodesOf $_.BaseName) -join ',' -eq ((CodesOf ((CpStr $stemCodes) + ' (1)')) -join ',') })
    if ($exact.Count -eq 0) {
        $exact = @($all | Where-Object { CodesStartWith $_.BaseName $stemCodes } |
                   Sort-Object { $_.BaseName.Length })
    }
    if ($exact.Count -gt 0) {
        $docPath = $exact[0].FullName
        Say ('fallback_match_escaped=' + (Esc $exact[0].Name))
    }
}

$docOk = Test-Path -LiteralPath $docPath
$imgOk = Test-Path -LiteralPath $imgPath
Say ('docx_raw=' + $docPath)
Say ('docx_escaped=' + (Esc $docPath))
Say ('docx_found=' + $docOk)
Say ('image_raw=' + $imgPath)
Say ('image_found=' + $imgOk)

if (-not ($docOk -and $imgOk)) {
    Say ''
    Say 'FATAL input missing - listing the folder so the agent can see the real names:'
    try {
        Get-ChildItem -LiteralPath $dir -ErrorAction Stop | ForEach-Object {
            Say ('   entry=' + (Esc $_.Name) + '  raw=' + $_.Name + '  bytes=' + $_.Length)
        }
    } catch { Say ('   cannot list ' + $dir + ': ' + $_.Exception.Message) }
    Say ''
    Say 'DOCX_IMAGE_REPLACE_OK=False'
    Say 'DOCX_IMAGE_REPLACE_DONE=True'
    $L | Set-Content -LiteralPath $reportMd -Encoding UTF8
    $result['status'] = 'input_missing'
    ($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8
    exit 7
}

$srcInfo = Get-Item -LiteralPath $docPath
$imgInfo = Get-Item -LiteralPath $imgPath
Say ('docx_bytes=' + $srcInfo.Length)
Say ('docx_sha256_before=' + (Sha256File $docPath))
Say ('image_bytes=' + $imgInfo.Length)

# ------------------------------------------------------------ 2. output copy
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$outPath = Join-Path $dir ($docStem + '_img-replaced_' + $stamp + '.docx')
Copy-Item -LiteralPath $docPath -Destination $outPath -Force
Say ''
Say '## 2. output'
Say ('out_raw=' + $outPath)
Say ('out_escaped=' + (Esc $outPath))

# --------------------------------------------- 3. find the LAST picture in the body
$zip = [System.IO.Compression.ZipFile]::Open($outPath, 'Update')
$ok = $false
$info = [ordered]@{}
try {
    function Read-Entry($archive, [string]$name) {
        $e = $archive.Entries | Where-Object { $_.FullName -eq $name } | Select-Object -First 1
        if (-not $e) { return $null }
        $ms = New-Object System.IO.MemoryStream
        $s = $e.Open(); $s.CopyTo($ms); $s.Dispose()
        return $ms.ToArray()
    }

    $docBytes = Read-Entry $zip 'word/document.xml'
    if (-not $docBytes) { throw 'word/document.xml not found in the docx' }
    $docXmlShaBefore = Sha256Bytes $docBytes
    $xml = Utf8NoBom $docBytes

    $picPattern = '<a:blip[^>]*r:embed="([^"]+)"|<v:imagedata[^>]*r:id="([^"]+)"'
    $picMatches = @([regex]::Matches($xml, $picPattern))
    Say ''
    Say '## 3. pictures in the body (document order)'
    Say ('images_in_body=' + $picMatches.Count)
    if ($picMatches.Count -eq 0) { throw 'no picture reference found in word/document.xml' }

    # rId -> media part
    $relBytes = Read-Entry $zip 'word/_rels/document.xml.rels'
    if (-not $relBytes) { throw 'word/_rels/document.xml.rels not found' }
    [xml]$rels = Utf8NoBom $relBytes
    function Resolve-Rel($relsDoc, [string]$id) {
        foreach ($r in $relsDoc.Relationships.Relationship) {
            if ([string]$r.Id -eq $id) { return [string]$r.Target }
        }
        return ''
    }

    # describe every picture so a later round can pick a different one by index
    $picList = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $picMatches.Count; $i++) {
        $mm = $picMatches[$i]
        $id = $mm.Groups[1].Value
        if (-not $id) { $id = $mm.Groups[2].Value }
        $head = $xml.Substring(0, $mm.Index)
        $cx = 0; $cy = 0; $nm = ''
        $mx = [regex]::Matches($head, '<wp:extent\s+cx="(\d+)"\s+cy="(\d+)"')
        if ($mx.Count -gt 0) {
            $cx = [int64]$mx[$mx.Count - 1].Groups[1].Value
            $cy = [int64]$mx[$mx.Count - 1].Groups[2].Value
        }
        $mn = [regex]::Matches($head, '<wp:docPr[^>]*name="([^"]*)"')
        if ($mn.Count -gt 0) { $nm = $mn[$mn.Count - 1].Groups[1].Value }
        $tg = Resolve-Rel $rels $id
        $picList.Add([ordered]@{
            index = ($i + 1); rid = $id; target = $tg
            cm = ('' + [math]::Round($cx / 360000, 2) + ' x ' + [math]::Round($cy / 360000, 2))
            emu = ('' + $cx + 'x' + $cy); name = (Esc $nm)
        }) | Out-Null
    }
    $showFrom = [math]::Max(0, $picList.Count - 6)
    for ($i = $showFrom; $i -lt $picList.Count; $i++) {
        $p = $picList[$i]
        Say ('   image[' + $p.index + '] rid=' + $p.rid + ' part=' + $p.target +
             ' box_cm=' + $p.cm + ' name=' + $p.name)
    }

    # pick: 0 = auto (last picture in the body = the one on the last page).
    # Set this to an index from the list above if a later round must pick
    # a different picture.
    $forceIndex = 0
    $pickIdx = $picList.Count
    if ($forceIndex -ge 1 -and $forceIndex -le $picList.Count) { $pickIdx = $forceIndex }
    $pick = $picList[$pickIdx - 1]
    $rid = [string]$pick.rid
    $extCx = 0; $extCy = 0
    if ($pick.emu -match '^(\d+)x(\d+)$') { $extCx = [int64]$Matches[1]; $extCy = [int64]$Matches[2] }
    Say ('picked_index=' + $pickIdx + ' of ' + $picList.Count + ' (auto = last in document order)')
    Say ('picked_rid=' + $rid)
    Say ('display_box_emu=' + $extCx + 'x' + $extCy)
    Say ('display_box_cm=' + $pick.cm)
    Say ('shape_name_escaped=' + $pick.name)

    $target = [string]$pick.target
    if (-not $target) { throw ('relationship ' + $rid + ' has no target') }
    $target = $target -replace '^/', ''
    $mediaPath = 'word/' + ($target -replace '\\', '/')
    $mediaPath = $mediaPath -replace '//+', '/'
    Say ('media_part=' + $mediaPath)
    $mext = [System.IO.Path]::GetExtension($mediaPath).ToLower()
    if ($mext -eq '.emf' -or $mext -eq '.wmf' -or $mext -eq '.svg') {
        throw ('the picture on that page is a vector part (' + $mext +
               ') - swapping raster bytes into it would break the content type; needs a different approach')
    }

    $mediaEntry = $zip.Entries | Where-Object { $_.FullName -eq $mediaPath } | Select-Object -First 1
    if (-not $mediaEntry) { throw ('media part not in the zip: ' + $mediaPath) }
    $origBytes = Read-Entry $zip $mediaPath

    # ------------------------------------------------- 4. build the new bytes
    $origImg = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, $origBytes)))
    $origW = $origImg.Width; $origH = $origImg.Height
    $dpiX = $origImg.HorizontalResolution; $dpiY = $origImg.VerticalResolution
    if ($dpiX -le 0) { $dpiX = 96 }
    if ($dpiY -le 0) { $dpiY = 96 }
    $newImg = [System.Drawing.Image]::FromFile($imgPath)
    $newW = $newImg.Width; $newH = $newImg.Height

    Say ''
    Say '## 4. pixels'
    Say ('original_px=' + $origW + 'x' + $origH + ' dpi=' + [math]::Round($dpiX,1) + 'x' + [math]::Round($dpiY,1))
    Say ('new_image_px=' + $newW + 'x' + $newH)
    $arOrig = [double]$origW / [double]$origH
    $arNew  = [double]$newW / [double]$newH
    Say ('aspect_original=' + [math]::Round($arOrig, 4))
    Say ('aspect_new=' + [math]::Round($arNew, 4))

    # canvas keeps the ORIGINAL aspect ratio; resolution may go up (sharper) but
    # never below the original, and is capped so the file does not explode.
    $canvasW = [int][math]::Max($origW, [math]::Min(3000, $newW))
    $canvasH = [int][math]::Max(1, [math]::Round($canvasW / $arOrig))
    # keep the natural (physical) size identical: px/dpi must not change
    $newDpiX = $dpiX * $canvasW / $origW
    $newDpiY = $dpiY * $canvasH / $origH
    Say ('canvas_px=' + $canvasW + 'x' + $canvasH + ' dpi=' + [math]::Round($newDpiX,1) + 'x' + [math]::Round($newDpiY,1))

    $bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $bmp.SetResolution($newDpiX, $newDpiY)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $scale = [math]::Min($canvasW / [double]$newW, $canvasH / [double]$newH)
    $dw = [int][math]::Round($newW * $scale)
    $dh = [int][math]::Round($newH * $scale)
    $dx = [int][math]::Round(($canvasW - $dw) / 2)
    $dy = [int][math]::Round(($canvasH - $dh) / 2)
    $g.DrawImage($newImg, $dx, $dy, $dw, $dh)
    $g.Dispose()
    $padX = $dx; $padY = $dy
    Say ('drawn_at=' + $dx + ',' + $dy + ' size=' + $dw + 'x' + $dh)
    Say ('letterbox_bars_px=' + $padX + ' left/right, ' + $padY + ' top/bottom')

    # encode in the SAME container as the part it replaces, so [Content_Types]
    # and the relationship stay valid and nothing else in the package changes
    $ext = [System.IO.Path]::GetExtension($mediaPath).ToLower()
    $outMs = New-Object System.IO.MemoryStream
    switch ($ext) {
        '.png'  { $bmp.Save($outMs, [System.Drawing.Imaging.ImageFormat]::Png) }
        '.gif'  { $bmp.Save($outMs, [System.Drawing.Imaging.ImageFormat]::Gif) }
        '.bmp'  { $bmp.Save($outMs, [System.Drawing.Imaging.ImageFormat]::Bmp) }
        '.tif'  { $bmp.Save($outMs, [System.Drawing.Imaging.ImageFormat]::Tiff) }
        '.tiff' { $bmp.Save($outMs, [System.Drawing.Imaging.ImageFormat]::Tiff) }
        default {
            $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                   Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
            $ps = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $ps.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
                [System.Drawing.Imaging.Encoder]::Quality, [int64]95)
            $bmp.Save($outMs, $enc, $ps)
        }
    }
    $newBytes = $outMs.ToArray()
    $bmp.Dispose(); $origImg.Dispose(); $newImg.Dispose()
    Say ('media_format=' + $ext + '  bytes ' + $origBytes.Length + ' -> ' + $newBytes.Length)

    # ------------------------------------------------- 5. swap bytes in place
    $st = $mediaEntry.Open()
    $st.SetLength(0)
    $st.Write($newBytes, 0, $newBytes.Length)
    $st.Flush(); $st.Dispose()

    $info['rid'] = $rid
    $info['media_part'] = $mediaPath
    $info['images_in_body'] = $picMatches.Count
    $info['display_box_emu'] = ('' + $extCx + 'x' + $extCy)
    $info['display_box_cm'] = ('' + $cmW + ' x ' + $cmH)
    $info['original_px'] = ('' + $origW + 'x' + $origH)
    $info['new_image_px'] = ('' + $newW + 'x' + $newH)
    $info['canvas_px'] = ('' + $canvasW + 'x' + $canvasH)
    $info['doc_xml_sha256'] = $docXmlShaBefore
    $ok = $true
} catch {
    Say ('FATAL ' + $_.Exception.Message)
} finally {
    $zip.Dispose()
}

if (-not $ok) {
    Say ''
    Say 'DOCX_IMAGE_REPLACE_OK=False'
    Say 'DOCX_IMAGE_REPLACE_DONE=True'
    $L | Set-Content -LiteralPath $reportMd -Encoding UTF8
    $result['status'] = 'edit_failed'
    ($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8
    exit 7
}

# --------------------------------------- 6. prove document.xml is untouched
$zip2 = [System.IO.Compression.ZipFile]::OpenRead($outPath)
$docXmlShaAfter = ''
$entryCount = 0
try {
    $entryCount = $zip2.Entries.Count
    $e = $zip2.Entries | Where-Object { $_.FullName -eq 'word/document.xml' } | Select-Object -First 1
    $ms = New-Object System.IO.MemoryStream
    $s = $e.Open(); $s.CopyTo($ms); $s.Dispose()
    $docXmlShaAfter = Sha256Bytes $ms.ToArray()
} catch { } finally { $zip2.Dispose() }

$xmlSame = ($docXmlShaAfter -ne '') -and ($docXmlShaAfter -eq $info['doc_xml_sha256'])
Say ''
Say '## 5. layout safety'
Say ('zip_entries=' + $entryCount)
Say ('document_xml_sha256=' + $docXmlShaAfter)
Say ('DOCUMENT_XML_UNCHANGED=' + $xmlSame)

# ------------------------------------------- 7. page count before vs after
function Get-Pages([string]$path) {
    $prog = ''
    foreach ($cand in @('Word.Application', 'KWPS.Application')) {
        if (Test-Path -LiteralPath ('Registry::HKEY_CLASSES_ROOT\' + $cand)) { $prog = $cand; break }
    }
    if (-not $prog) { return @{ pages = -1; note = 'no Word/WPS COM registered' } }
    $job = Start-Job -ArgumentList $prog, $path -ScriptBlock {
        param($srv, $p)
        $app = New-Object -ComObject $srv
        try {
            try { $app.Visible = $false } catch { }
            try { $app.DisplayAlerts = 0 } catch { }
            $doc = $app.Documents.Open($p, $false, $true)
            try { $doc.Repaginate() } catch { }
            $n = [int]$doc.ComputeStatistics(2)   # 2 = wdStatisticPages
            $shapes = 0
            try { $shapes = [int]$doc.InlineShapes.Count } catch { }
            $doc.Close($false)
            return ('' + $n + '|' + $shapes)
        } finally { try { $app.Quit() } catch { } }
    }
    $done = Wait-Job $job -Timeout 180
    if (-not $done) { Stop-Job $job -ErrorAction SilentlyContinue; return @{ pages = -1; note = 'COM timeout' } }
    if ($job.State -ne 'Completed') {
        $why = ('' + $job.ChildJobs[0].JobStateInfo.Reason)
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return @{ pages = -1; note = ('COM failed: ' + $why) }
    }
    $raw = [string](Receive-Job $job)
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    $parts = $raw.Trim().Split('|')
    return @{ pages = [int]$parts[0]; shapes = [int]$parts[1]; note = 'ok' }
}

Say ''
Say '## 6. page count (real Word/WPS)'
$before = Get-Pages $docPath
$after  = Get-Pages $outPath
Say ('pages_before=' + $before.pages + ' (' + $before.note + ')')
Say ('pages_after=' + $after.pages + ' (' + $after.note + ')')
if ($before.ContainsKey('shapes')) { Say ('inline_shapes_before=' + $before.shapes) }
if ($after.ContainsKey('shapes'))  { Say ('inline_shapes_after=' + $after.shapes) }
$pagesSame = $false
$pagesChecked = ($before.pages -gt 0 -and $after.pages -gt 0)
if ($pagesChecked) { $pagesSame = ($before.pages -eq $after.pages) }
Say ('PAGE_COUNT_CHECKED=' + $pagesChecked)
Say ('PAGE_COUNT_UNCHANGED=' + $pagesSame)

# ------------------------------------------------------------ 8. verdict
# the structural guarantee (document.xml byte-identical) is the hard one; the
# Word page count is a belt-and-braces confirmation when COM is available.
$overall = $xmlSame -and ((-not $pagesChecked) -or $pagesSame)
$outSha = Sha256File $outPath
Say ''
Say '## 7. result'
Say ('result_path_raw=' + $outPath)
Say ('result_path_escaped=' + (Esc $outPath))
Say ('result_bytes=' + (Get-Item -LiteralPath $outPath).Length)
Say ('result_sha256=' + $outSha)
Say ('original_untouched=' + $docPath)
Say ''
Say ('DOCX_IMAGE_REPLACE_OK=' + $overall)
Say 'DOCX_IMAGE_REPLACE_DONE=True'

$L | Set-Content -LiteralPath $reportMd -Encoding UTF8

if ($overall) { $result['status'] = 'ok' } else { $result['status'] = 'verify_failed' }
$result['source_docx'] = $docPath
$result['source_image'] = $imgPath
$result['result_path'] = $outPath
$result['result_sha256'] = $outSha
$result['document_xml_unchanged'] = $xmlSame
$result['pages_before'] = $before.pages
$result['pages_after'] = $after.pages
$result['page_count_unchanged'] = $pagesSame
$result['page_count_checked'] = $pagesChecked
foreach ($k in $info.Keys) { $result[$k] = $info[$k] }
($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8

if ($overall) { exit 0 }
exit 7
