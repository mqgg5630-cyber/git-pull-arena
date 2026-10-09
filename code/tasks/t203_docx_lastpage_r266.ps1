# t203_docx_lastpage_r266.ps1
# Round 266: find out WHICH picture sits on the last page of the zhongqi docx,
# then replace exactly that one with image-1.jpeg without moving anything.
#
# Why round 265 was not enough: the last reference in document order turned out
# to be a .wmf (vector) part, and all three pictures share the same 6.35x2.22 cm
# box, so "last in XML order" is not proof of "on the last page". Word is the
# only thing that knows page numbers, so we ask Word.
#
# Replacement method (format agnostic, unlike the round 265 byte swap):
#   add a NEW media part + repoint that one relationship at it.
#   word/document.xml is still never rewritten, so the display box - and
#   therefore the reflow and the page count - stay bit-for-bit identical.
#
# ASCII-only source; all non-ASCII in the report is \uXXXX escaped.

$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..\..')
$repo = (Get-Location).Path

$round = 266
$outRoot = Join-Path $repo 'results\status'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$reportMd   = Join-Path $outRoot 'DOCX_IMAGE_REPLACE.md'
$reportJson = Join-Path $outRoot 'DOCX_IMAGE_REPLACE.json'

$L = New-Object System.Collections.Generic.List[string]
function Say([string]$s) { $L.Add($s) | Out-Null; Write-Output $s }
function CpStr([int[]]$codes) { return (-join ($codes | ForEach-Object { [char]$_ })) }
function CodesOf([string]$s) { return @($s.ToCharArray() | ForEach-Object { [int][char]$_ }) }
function Esc([string]$s) {
    if ($null -eq $s) { return '' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $c = [int][char]$ch
        if ($c -ge 32 -and $c -le 126) { [void]$sb.Append($ch) } else { [void]$sb.Append(('\u{0:X4}' -f $c)) }
    }
    return $sb.ToString()
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
function Sha256File([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return '' }
    return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()
}

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

$result = [ordered]@{ round = $round; time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'); host = $env:COMPUTERNAME }

# ------------------------------------------------------------- 1. inputs
$dir = 'E:\0zhongqi\zhongqi-arena_out\deliverable'
$imgPath = Join-Path $dir 'image-1.jpeg'
$stemCodes = @(0x4E2D, 0x671F, 0x005F, 0x6700, 0x7EC8, 0x7248)
$docPath = Join-Path $dir ((CpStr $stemCodes) + ' (1).docx')

Say ('# docx last-page picture - round ' + $round)
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
    Say 'DOCX_IMAGE_REPLACE_OK=False'
    Say 'DOCX_IMAGE_REPLACE_DONE=True'
    $L | Set-Content -LiteralPath $reportMd -Encoding UTF8
    $result['status'] = 'input_missing'
    ($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8
    exit 7
}
Say ('docx_sha256=' + (Sha256File $docPath))

# ------------------------------------------- 2. ask Word which page each picture is on
function Invoke-WordProbe([string]$path) {
    $prog = ''
    foreach ($cand in @('Word.Application', 'KWPS.Application')) {
        if (Test-Path -LiteralPath ('Registry::HKEY_CLASSES_ROOT\' + $cand)) { $prog = $cand; break }
    }
    if (-not $prog) { return @('NOCOM') }
    $job = Start-Job -ArgumentList $prog, $path -ScriptBlock {
        param($srv, $p)
        function E([string]$s) {
            if ($null -eq $s) { return '' }
            $sb = New-Object System.Text.StringBuilder
            foreach ($ch in $s.ToCharArray()) {
                $c = [int][char]$ch
                if ($c -ge 32 -and $c -le 126) { [void]$sb.Append($ch) } else { [void]$sb.Append(('\u{0:X4}' -f $c)) }
            }
            return $sb.ToString()
        }
        $out = New-Object System.Collections.Generic.List[string]
        $app = New-Object -ComObject $srv
        try {
            try { $app.Visible = $false } catch { }
            try { $app.DisplayAlerts = 0 } catch { }
            $doc = $app.Documents.Open($p, $false, $true)
            try { $doc.Repaginate() } catch { }
            $pages = [int]$doc.ComputeStatistics(2)
            $out.Add('PAGES=' + $pages)
            $out.Add('INLINE_COUNT=' + [int]$doc.InlineShapes.Count)
            $out.Add('SHAPE_COUNT=' + [int]$doc.Shapes.Count)
            for ($i = 1; $i -le $doc.InlineShapes.Count; $i++) {
                $sh = $doc.InlineShapes.Item($i)
                $pg = -1
                try { $pg = [int]$sh.Range.Information(3) } catch { }   # 3 = wdActiveEndPageNumber
                $alt = ''
                try { $alt = [string]$sh.AlternativeText } catch { }
                $ty = -1
                try { $ty = [int]$sh.Type } catch { }
                $ole = ''
                try { if ($sh.OLEFormat -ne $null) { $ole = [string]$sh.OLEFormat.ProgID } } catch { }
                $out.Add('INLINE|' + $i + '|' + $pg + '|' + [math]::Round([double]$sh.Width,1) + '|' +
                         [math]::Round([double]$sh.Height,1) + '|' + $ty + '|' + (E $alt) + '|' + (E $ole))
            }
            for ($i = 1; $i -le $doc.Shapes.Count; $i++) {
                $sp = $doc.Shapes.Item($i)
                $pg = -1
                try { $pg = [int]$sp.Anchor.Information(3) } catch { }
                $out.Add('FLOAT|' + $i + '|' + $pg + '|' + [math]::Round([double]$sp.Width,1) + '|' +
                         [math]::Round([double]$sp.Height,1) + '|' + (E ([string]$sp.Name)))
            }
            # what the last page actually says, so the agent can see the context
            try {
                $rng = $doc.GoTo(1, 1, $pages)      # wdGoToPage, wdGoToAbsolute
                $rng.MoveEnd(6, 1) | Out-Null       # 6 = wdStory -> to end of document
                $txt = [string]$rng.Text
                if ($txt.Length -gt 600) { $txt = $txt.Substring(0, 600) }
                $txt = $txt -replace '[\r\n\a]+', ' / '
                $out.Add('LASTPAGETEXT=' + (E $txt))
            } catch { $out.Add('LASTPAGETEXT=(unavailable)') }
            $doc.Close($false)
        } finally { try { $app.Quit() } catch { } }
        return $out.ToArray()
    }
    $done = Wait-Job $job -Timeout 240
    if (-not $done) { Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return @('TIMEOUT') }
    if ($job.State -ne 'Completed') {
        $why = ('' + $job.ChildJobs[0].JobStateInfo.Reason)
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        return @('ERROR ' + $why)
    }
    $r = @(Receive-Job $job)
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return $r
}

Say ''
Say '## 2. what Word sees'
$probe = Invoke-WordProbe $docPath
foreach ($line in $probe) { Say ('   ' + $line) }

$pagesTotal = 0
$inlinePages = @{}
foreach ($line in $probe) {
    if ($line -match '^PAGES=(\d+)') { $pagesTotal = [int]$Matches[1] }
    if ($line -match '^INLINE\|(\d+)\|(-?\d+)\|') { $inlinePages[[int]$Matches[1]] = [int]$Matches[2] }
}
Say ('pages_total=' + $pagesTotal)

# ------------------------------------------- 3. the package side
$zipR = [System.IO.Compression.ZipFile]::OpenRead($docPath)
$docXml = ''
$relsXml = ''
$ctXml = ''
try {
    foreach ($e in $zipR.Entries) {
        if ($e.FullName -eq 'word/document.xml' -or $e.FullName -eq 'word/_rels/document.xml.rels' -or $e.FullName -eq '[Content_Types].xml') {
            $ms = New-Object System.IO.MemoryStream
            $s = $e.Open(); $s.CopyTo($ms); $s.Dispose()
            $t = Utf8NoBom $ms.ToArray()
            if ($e.FullName -eq 'word/document.xml') { $docXml = $t }
            elseif ($e.FullName -eq 'word/_rels/document.xml.rels') { $relsXml = $t }
            else { $ctXml = $t }
        }
    }
} finally { $zipR.Dispose() }

$picPattern = '<a:blip[^>]*r:embed="([^"]+)"|<v:imagedata[^>]*r:id="([^"]+)"'
$picMatches = @([regex]::Matches($docXml, $picPattern))
[xml]$relsDoc = $relsXml
Say ''
Say '## 3. pictures in the package'
Say ('images_in_body=' + $picMatches.Count)

$picList = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $picMatches.Count; $i++) {
    $mm = $picMatches[$i]
    $id = $mm.Groups[1].Value
    if (-not $id) { $id = $mm.Groups[2].Value }
    $tg = ''
    foreach ($r in $relsDoc.Relationships.Relationship) { if ([string]$r.Id -eq $id) { $tg = [string]$r.Target; break } }
    $from = [math]::Max(0, $mm.Index - 700)
    $ctx = $docXml.Substring($from, [math]::Min(900, $docXml.Length - $from))
    # is this reference the preview of an embedded OLE object (equation etc.)?
    $objOpen = $ctx.LastIndexOf('<w:object')
    $objClose = $ctx.LastIndexOf('</w:object>')
    $isOle = ($objOpen -ge 0 -and $objOpen -gt $objClose)
    $progId = ''
    $mp = [regex]::Matches($ctx, 'ProgID="([^"]*)"')
    if ($mp.Count -gt 0) { $progId = $mp[$mp.Count - 1].Groups[1].Value }
    $picList.Add([ordered]@{ index = ($i + 1); rid = $id; target = $tg; ole = $isOle; progid = $progId }) | Out-Null
    $pg = -1
    if ($inlinePages.ContainsKey($i + 1)) { $pg = $inlinePages[$i + 1] }
    Say ('   image[' + ($i + 1) + '] rid=' + $id + ' part=' + $tg + ' word_page=' + $pg +
         ' ole=' + $isOle + ' progid=' + $progId)
}

# context dump: lets the agent read the real markup without shipping the document
Say ''
Say '## 3b. markup around each picture (escaped)'
for ($i = 0; $i -lt $picMatches.Count; $i++) {
    $mm = $picMatches[$i]
    $from = [math]::Max(0, $mm.Index - 420)
    $ctx = $docXml.Substring($from, [math]::Min(560, $docXml.Length - $from))
    Say ('   --- image[' + ($i + 1) + '] ---')
    Say ('   ' + (Esc $ctx))
}

# ------------------------------------------- 4. choose the last-page picture
$inlineCount = 0
foreach ($line in $probe) { if ($line -match '^INLINE_COUNT=(\d+)') { $inlineCount = [int]$Matches[1] } }
$mappable = ($inlineCount -eq $picMatches.Count -and $pagesTotal -gt 0)
$candidates = @()
if ($mappable) {
    for ($i = 1; $i -le $picMatches.Count; $i++) {
        if ($inlinePages.ContainsKey($i) -and $inlinePages[$i] -eq $pagesTotal) { $candidates += $i }
    }
}
Say ''
Say '## 4. decision'
Say ('word_inline_count=' + $inlineCount + '  xml_refs=' + $picMatches.Count + '  mappable=' + $mappable)
Say ('candidates_on_last_page=' + ($candidates -join ','))

$result['pages_total'] = $pagesTotal
$result['images_in_body'] = $picMatches.Count
$result['word_inline_count'] = $inlineCount
$result['candidates_on_last_page'] = ($candidates -join ',')
$result['probe'] = ($probe -join "`n")

if (-not $mappable -or $candidates.Count -ne 1) {
    Say ''
    Say 'STOP: cannot identify a single picture on the last page - not touching the document.'
    Say 'DOCX_IMAGE_REPLACE_OK=False'
    Say 'DOCX_IMAGE_REPLACE_DIAGNOSED=True'
    Say 'DOCX_IMAGE_REPLACE_DONE=True'
    $L | Set-Content -LiteralPath $reportMd -Encoding UTF8
    $result['status'] = 'needs_decision'
    ($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8
    exit 0
}

$pickIdx = $candidates[0]
$pick = $picList[$pickIdx - 1]
Say ('picked_index=' + $pickIdx + ' rid=' + $pick.rid + ' part=' + $pick.target + ' ole=' + $pick.ole)
if ($pick.ole) {
    Say 'STOP: that picture is the preview of an embedded OLE object - replacing it needs a different route.'
    Say 'DOCX_IMAGE_REPLACE_OK=False'
    Say 'DOCX_IMAGE_REPLACE_DIAGNOSED=True'
    Say 'DOCX_IMAGE_REPLACE_DONE=True'
    $L | Set-Content -LiteralPath $reportMd -Encoding UTF8
    $result['status'] = 'ole_picture'
    ($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8
    exit 0
}

# ------------------------------------------- 5. build the replacement image
$boxW = 0.0; $boxH = 0.0
foreach ($line in $probe) {
    if ($line -match ('^INLINE\|' + $pickIdx + '\|-?\d+\|([0-9.]+)\|([0-9.]+)\|')) {
        $boxW = [double]$Matches[1]; $boxH = [double]$Matches[2]
    }
}
if ($boxW -le 0 -or $boxH -le 0) { $boxW = 180; $boxH = 63 }
$boxAspect = $boxW / $boxH
Say ''
Say '## 5. new image'
Say ('display_box_pt=' + $boxW + ' x ' + $boxH + '  aspect=' + [math]::Round($boxAspect, 4))

$newImg = [System.Drawing.Image]::FromFile($imgPath)
Say ('source_px=' + $newImg.Width + 'x' + $newImg.Height + '  aspect=' +
     [math]::Round($newImg.Width / [double]$newImg.Height, 4))
# 300 dpi inside the printed box, so it stays sharp on paper
$canvasH = [int][math]::Max(200, [math]::Round($boxH / 72.0 * 300))
$canvasW = [int][math]::Max(200, [math]::Round($canvasH * $boxAspect))
$bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$bmp.SetResolution(300, 300)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$scale = [math]::Min($canvasW / [double]$newImg.Width, $canvasH / [double]$newImg.Height)
$dw = [int][math]::Round($newImg.Width * $scale)
$dh = [int][math]::Round($newImg.Height * $scale)
$dx = [int][math]::Round(($canvasW - $dw) / 2)
$dy = [int][math]::Round(($canvasH - $dh) / 2)
$g.DrawImage($newImg, $dx, $dy, $dw, $dh)
$g.Dispose()
$newImg.Dispose()
$jpegEnc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
           Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
$encPs = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encPs.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int64]95)
$jms = New-Object System.IO.MemoryStream
$bmp.Save($jms, $jpegEnc, $encPs)
$bmp.Dispose()
$newBytes = $jms.ToArray()
Say ('canvas_px=' + $canvasW + 'x' + $canvasH + ' @300dpi  jpeg_bytes=' + $newBytes.Length)
Say ('fitted_at=' + $dx + ',' + $dy + ' size=' + $dw + 'x' + $dh + ' (letterboxed, no stretch, no crop)')

# ------------------------------------------- 6. new part + repoint the one relationship
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$outPath = Join-Path $dir ((CpStr $stemCodes) + ' (1)_img-replaced_' + $stamp + '.docx')
Copy-Item -LiteralPath $docPath -Destination $outPath -Force
$newPartName = 'arena_r266_' + $stamp + '.jpeg'

$docXmlShaBefore = ''
$zip = [System.IO.Compression.ZipFile]::Open($outPath, 'Update')
$ok = $false
try {
    function Get-Bytes($archive, [string]$name) {
        $e = $archive.Entries | Where-Object { $_.FullName -eq $name } | Select-Object -First 1
        if (-not $e) { return $null }
        $ms = New-Object System.IO.MemoryStream
        $s = $e.Open(); $s.CopyTo($ms); $s.Dispose()
        return $ms.ToArray()
    }
    function Set-Text($archive, [string]$name, [string]$text) {
        $e = $archive.Entries | Where-Object { $_.FullName -eq $name } | Select-Object -First 1
        if (-not $e) { throw ('entry missing: ' + $name) }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        $st = $e.Open(); $st.SetLength(0); $st.Write($bytes, 0, $bytes.Length); $st.Flush(); $st.Dispose()
    }

    $docXmlShaBefore = Sha256Bytes (Get-Bytes $zip 'word/document.xml')

    # 6a. add the new media part
    $entry = $zip.CreateEntry('word/media/' + $newPartName)
    $st = $entry.Open(); $st.Write($newBytes, 0, $newBytes.Length); $st.Flush(); $st.Dispose()

    # 6b. [Content_Types].xml must know about .jpeg
    $ct = Utf8NoBom (Get-Bytes $zip '[Content_Types].xml')
    if ($ct -notmatch '(?i)Extension="jpeg"') {
        $ct = $ct -replace '(?i)(<Types[^>]*>)', '$1<Default Extension="jpeg" ContentType="image/jpeg"/>'
        Set-Text $zip '[Content_Types].xml' $ct
        Say 'content_types: added Default Extension="jpeg"'
    } else {
        Say 'content_types: jpeg already declared'
    }

    # 6c. repoint THIS relationship only - document.xml is never touched
    $rels = Utf8NoBom (Get-Bytes $zip 'word/_rels/document.xml.rels')
    $rid = [string]$pick.rid
    $pat = '(<Relationship[^>]*Id="' + [regex]::Escape($rid) + '"[^>]*Target=")([^"]*)(")'
    $mRel = [regex]::Match($rels, $pat)
    if (-not $mRel.Success) { throw ('relationship not found in rels: ' + $rid) }
    $oldTarget = $mRel.Groups[2].Value
    $rels2 = [regex]::Replace($rels, $pat, ('${1}media/' + $newPartName + '${3}'))
    if ($rels2 -eq $rels) { throw 'relationship rewrite produced no change' }
    Set-Text $zip 'word/_rels/document.xml.rels' $rels2
    Say ''
    Say '## 6. package edit'
    Say ('relationship=' + $rid + '  target: ' + $oldTarget + ' -> media/' + $newPartName)
    $ok = $true
} catch {
    Say ('FATAL ' + $_.Exception.Message)
} finally { $zip.Dispose() }

if (-not $ok) {
    Say 'DOCX_IMAGE_REPLACE_OK=False'
    Say 'DOCX_IMAGE_REPLACE_DONE=True'
    $L | Set-Content -LiteralPath $reportMd -Encoding UTF8
    $result['status'] = 'edit_failed'
    ($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8
    exit 7
}

# ------------------------------------------- 7. verify
$zipV = [System.IO.Compression.ZipFile]::OpenRead($outPath)
$docXmlShaAfter = ''
try {
    $e = $zipV.Entries | Where-Object { $_.FullName -eq 'word/document.xml' } | Select-Object -First 1
    $ms = New-Object System.IO.MemoryStream
    $s = $e.Open(); $s.CopyTo($ms); $s.Dispose()
    $docXmlShaAfter = Sha256Bytes $ms.ToArray()
} catch { } finally { $zipV.Dispose() }
$xmlSame = ($docXmlShaAfter -ne '' -and $docXmlShaAfter -eq $docXmlShaBefore)

$probeAfter = Invoke-WordProbe $outPath
$pagesAfter = 0
foreach ($line in $probeAfter) { if ($line -match '^PAGES=(\d+)') { $pagesAfter = [int]$Matches[1] } }

Say ''
Say '## 7. verification'
Say ('document_xml_sha_before=' + $docXmlShaBefore)
Say ('document_xml_sha_after =' + $docXmlShaAfter)
Say ('DOCUMENT_XML_UNCHANGED=' + $xmlSame)
Say ('pages_before=' + $pagesTotal)
Say ('pages_after=' + $pagesAfter)
$pagesSame = ($pagesTotal -gt 0 -and $pagesAfter -eq $pagesTotal)
Say ('PAGE_COUNT_UNCHANGED=' + $pagesSame)

$overall = $xmlSame -and $pagesSame
Say ''
Say '## 8. result'
Say ('result_path_raw=' + $outPath)
Say ('result_path_escaped=' + (Esc $outPath))
Say ('result_bytes=' + (Get-Item -LiteralPath $outPath).Length)
Say ('result_sha256=' + (Sha256File $outPath))
Say ('original_untouched_raw=' + $docPath)
Say ''
Say ('DOCX_IMAGE_REPLACE_OK=' + $overall)
Say 'DOCX_IMAGE_REPLACE_DIAGNOSED=True'
Say 'DOCX_IMAGE_REPLACE_DONE=True'
$L | Set-Content -LiteralPath $reportMd -Encoding UTF8

if ($overall) { $result['status'] = 'ok' } else { $result['status'] = 'verify_failed' }
$result['result_path'] = $outPath
$result['result_sha256'] = (Sha256File $outPath)
$result['document_xml_unchanged'] = $xmlSame
$result['pages_after'] = $pagesAfter
$result['page_count_unchanged'] = $pagesSame
$result['picked_rid'] = [string]$pick.rid
$result['picked_index'] = $pickIdx
$result['old_target'] = [string]$pick.target
$result['new_part'] = ('media/' + $newPartName)
($result | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $reportJson -Encoding UTF8

if ($overall) { exit 0 }
exit 7
