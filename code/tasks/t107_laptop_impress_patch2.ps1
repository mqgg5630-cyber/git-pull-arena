# t107_laptop_impress_patch2.ps1 - round 142 task: (task 2, laptop finish)
# 1. patch the harness export.py Visible-E_FAIL bug (WPS rejects the
#    Visible=False property write on some builds -> wrap in try/except)
#    in BOTH the vendored repo copy and the installed site-packages copy
# 2. rerun the impress flow -> editable test_impress.pptx + python reopen
#    verify (slides/shapes/text)
# 3. download the official WPS offline setup on the laptop (China CDN) and
#    stage it + the harness dir on the desktop F$ for the next round
# ASCII-only. Runs on the LAPTOP.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t107: laptop impress patch (retry) + WPS setup staging ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$haDir = Join-Path $repoRoot 'skills\harness-anything'
$workDir = Join-Path $repoRoot 'results\harness_wps\laptop'

# ================= A. patch export.py =================
L '--- A: patch export.py (Visible E_FAIL) ---'
$repoExport = Join-Path $haDir 'cli_anything\wps\core\export.py'
$instExport = (& python -c "import cli_anything.wps.core.export as m; print(m.__file__)" 2>$null | Out-String).Trim()
L ('   installed export.py: ' + (San $instExport)
)
$patchRe = [regex]'(?m)^([ \t]*)app\.Visible = False.*$'
$repl = '${1}try:' + "`n" + '${1}    app.Visible = False' + "`n" + '${1}except Exception:' + "`n" + '${1}    pass'
foreach ($f in @($repoExport, $instExport)) {
    if ($f -and (Test-Path -LiteralPath $f)) {
        $raw = [IO.File]::ReadAllText($f)
        $already = $raw -match '(?m)^[ \t]*try:\s*\r?\n[ \t]*app\.Visible = False'
        if ($raw -match 'app\.Visible = False' -and -not $already) {
            $new = $patchRe.Replace($raw, $repl)
            [IO.File]::WriteAllText($f, $new, (New-Object System.Text.UTF8Encoding($false)))
            L ('   patched: ' + (San $f))
        }
        else { L ('   no patch needed: ' + (San $f)) }
    }
    else { L ('   [WARN] not found: ' + (San $f)) }
}
$chk = Select-String -LiteralPath $repoExport -Pattern 'except Exception:' -SimpleMatch
L ('   verify (repo copy): except-Exception lines=' + @($chk).Count)

# ================= B. impress flow + verify =================
L '--- B: impress flow (editable pptx) ---'
$dj = Start-Job -ScriptBlock {
    param($wd)
    Set-Location -LiteralPath $wd
    $o = @()
    $o += ('new: ' + ((& python -m cli_anything.wps document new --type impress --name 'harness pptx' -o proj_impress.json 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('slide: ' + ((& python -m cli_anything.wps --project proj_impress.json impress add-slide -t 'Harness PPTX Test' -c 'Editable body via WPS COM' 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('elem: ' + ((& python -m cli_anything.wps --project proj_impress.json impress add-element 0 --type text_box --text 'Hello editable pptx' 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o += ('export: ' + ((& python -m cli_anything.wps --project proj_impress.json export render test_impress.pptx -p pptx 2>&1 | Out-String).Trim() -replace "`r?`n", ' | '))
    $o
} -ArgumentList $workDir
if (-not (Wait-Job $dj -Timeout 420)) { Stop-Job $dj -Force; L '   [FAIL] impress flow timed out' }
else { foreach ($ln in @(Receive-Job $dj)) { if ($ln) { L ('   ' + (San ([string]$ln))) } } }
Remove-Job $dj -Force -ErrorAction SilentlyContinue

$pptx = Join-Path $workDir 'test_impress.pptx'
if (Test-Path -LiteralPath $pptx) {
    L ('   pptx: ' + [math]::Round((Get-Item -LiteralPath $pptx).Length/1KB) + 'KB at ' + (San $pptx))
    $rv = & python (Join-Path $repoRoot 'code\tasks\verify_pptx.py') $pptx 2>&1
    foreach ($ln in @($rv | Select-Object -Last 4)) { L ('   ' + (San ([string]$ln))) }
}
else { L '   [FAIL] test_impress.pptx still not produced' }

# ================= C. WPS setup download + staging =================
L '--- C: WPS setup download + desktop staging ---'
$urls = @(
    'https://official-package.wpscdn.cn/wps/download/WPS_Setup_X64_22525.exe',
    'https://official-package.wpscdn.cn/wps/download/WPS_Setup_25225.exe'
)
$pick = $null
foreach ($u in $urls) {
    $head = (& curl.exe -sI --max-time 30 $u 2>$null | Out-String).Trim()
    $code = ''
    $len = ''
    foreach ($ln in ($head -split "`r?`n")) {
        if ($ln -match '^HTTP/\S+\s+(\d{3})') { $code = $Matches[1] }
        if ($ln -match '(?i)^content-length:\s*(\d+)') { $len = [math]::Round([int]$Matches[1]/1MB) }
    }
    L ('   probe ' + (San ($u -replace '.*/', '')) + ': HTTP ' + $code + ' ' + $len + 'MB')
    if ($code -eq '200' -and -not $pick) { $pick = $u }
}
if (-not $pick) { L '   [FAIL] no downloadable WPS setup URL'; exit 2 }
L ('   chosen: ' + (San ($pick -replace '.*/', '')))

$tmp = Join-Path $env:TEMP 'wps_setup.exe'
$dlj = Start-Job -ScriptBlock {
    param($u, $d)
    & curl.exe -L -s -o $d --max-time 700 --connect-timeout 30 $u 2>&1 | Out-Null
} -ArgumentList $pick, $tmp
if (-not (Wait-Job $dlj -Timeout 720)) { Stop-Job $dlj -Force; L '   [FAIL] download timed out'; exit 2 }
Remove-Job $dlj -Force -ErrorAction SilentlyContinue
if (-not (Test-Path -LiteralPath $tmp)) { L '   [FAIL] download produced nothing'; exit 2 }
L ('   downloaded: ' + [math]::Round((Get-Item -LiteralPath $tmp).Length/1MB) + 'MB')
if ((Get-Item -LiteralPath $tmp).Length -lt 50MB) { L '   [FAIL] setup suspiciously small (<50MB)'; exit 2 }

$desktop = '100.84.137.117'
$fshare = '\\' + $desktop + '\F$'
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    $t0 = Get-Date
    $cj = Start-Job -ScriptBlock { param($s, $d) Copy-Item -LiteralPath $s -Destination $d -Force } -ArgumentList $tmp, ($fshare + '\fig1_rebuild\wps_setup.exe')
    if (-not (Wait-Job $cj -Timeout 720)) { Stop-Job $cj -Force; L '   [FAIL] copy to F$ timed out'; exit 2 }
    Remove-Job $cj -Force
    L ('   staged wps_setup.exe: ' + [math]::Round((Get-Item ($fshare + '\fig1_rebuild\wps_setup.exe') -ErrorAction SilentlyContinue).Length/1MB) + 'MB in ' + [int]((Get-Date) - $t0).TotalSeconds + 's')
    & robocopy $haDir ($fshare + '\fig1_rebuild\harness-anything') /E /MT:16 /NFL /NDL /NJH /NP 2>&1 | Select-Object -Last 3 | ForEach-Object { L ('      robocopy harness: ' + (San ([string]$_))) }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\verify_pptx.py') -Destination ($fshare + '\fig1_rebuild\verify_pptx.py') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_wps_install.ps1') -Destination ($fshare + '\fig1_rebuild\desk_wps_install.ps1') -Force
    L '   staged verify_pptx.py + desk_wps_install.ps1'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }
L '--- task t107 done ---'
exit 0
