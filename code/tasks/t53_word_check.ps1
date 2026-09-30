# t53_word_check.ps1 - round 65 task: open the Zotero-linked English.docx
# in the REAL Microsoft Word (COM, read-only, hidden) and count the fields -
# the ultimate compatibility check. READ-ONLY for the document.
# Windows PowerShell 5.1, ASCII-only, Write-Output only.

$ErrorActionPreference = 'Continue'

function San {
    param([string]$s)
    if ($null -eq $s) { return '' }
    try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }
    return $s
}

Write-Output '--- task t53: real-Word open test of the zotero-linked docx ---'
$path = 'E:\0writing\Light-skills\projects\English.docx'
$word = $null
$doc = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $doc = $word.Documents.Open($path, $false, $true)
    Write-Output ('   opened OK: ' + (San ([string]$doc.Name)))
    Write-Output ('   paragraphs: ' + $doc.Paragraphs.Count)
    $fc = $doc.Fields.Count
    Write-Output ('   total fields: ' + $fc)
    $zitem = 0
    $zbib = 0
    $i = 0
    foreach ($f in $doc.Fields) {
        $i++
        $code = ''
        try { $code = [string]$f.Code.Text } catch { }
        if ($code -match 'ZOTERO_ITEM') { $zitem++ }
        if ($code -match 'ZOTERO_BIBL') { $zbib++ }
        if ($i -gt 400) { break }
    }
    Write-Output ('   ZOTERO_ITEM fields: ' + $zitem + ' ; ZOTERO_BIBL fields: ' + $zbib)
    # first citation display text sample
    try {
        $f1 = $doc.Fields.Item(1)
        Write-Output ('   field1 result text: ' + (San ([string]$f1.Result.Text)).Trim())
    } catch { }
    $doc.Close($false)
    $doc = $null
    Write-Output '   closed cleanly (no repair prompt, no crash)'
} catch {
    Write-Output ('   [FAIL] ' + (San $_.Exception.Message))
} finally {
    if ($doc) { try { $doc.Close($false) } catch { } }
    if ($word) { try { $word.Quit() } catch { } }
}
exit 0
