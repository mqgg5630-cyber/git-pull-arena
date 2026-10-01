# t116_desk_interactive.ps1 - round 152 task: (task 2 finale) run the
# whole WPS COM pipeline inside the desktop's INTERACTIVE session via a
# scheduled task (sshd sessions get 0x80080005 server-exec-failure).
# The interactive script (desk_wps_interactive.ps1) does COM verify +
# harness install + writer/impress smoke + the 12-slide deck + verify and
# logs to interactive_log.txt. This dispatcher stages it, launches the
# task, polls the log until INTERACTIVE-DONE, then collects all artifacts
# into the repo. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

Write-Output '--- task t116: desktop INTERACTIVE WPS session (smoke + 12-slide deck) ---'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=12', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'

foreach ($f in @('desk_wps_interactive.ps1')) {
    $tok = $null; $perrs = $null
    $fp = Join-Path $repoRoot ('code\tasks\' + $f)
    $null = [System.Management.Automation.Language.Parser]::ParseFile($fp, [ref]$tok, [ref]$perrs)
    if ($perrs -and $perrs.Count -gt 0) {
        L ('   [FAIL] parse errors in ' + $f + ': ' + $perrs.Count)
        foreach ($e in ($perrs | Select-Object -First 3)) { L ('      line ' + $e.Extent.StartLineNumber + ': ' + (San $e.Message)) }
        exit 2
    }
}
L '   parse check: OK'

# ---------------- A. stage ----------------
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L '   [FAIL] F$ unreachable'; exit 2 }
try {
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_wps_interactive.ps1') -Destination ($fshare + '\fig1_rebuild\desk_wps_interactive.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\wpsrun.cmd') -Destination ($fshare + '\fig1_rebuild\wpsrun.cmd') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\desk_harness_deck.py') -Destination ($fshare + '\fig1_rebuild\harness_results\desk_harness_deck.py') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'code\tasks\verify_pptx.py') -Destination ($fshare + '\fig1_rebuild\verify_pptx.py') -Force
    L '   staged interactive script + launcher + deck builder'
}
finally { & net use $fshare /delete 2>&1 | Out-Null }

# ---------------- B. register + run the interactive task ----------------
$null = & ssh @sshBase ($duser + '@' + $desktop) 'schtasks /delete /tn wpstest /f 2>nul' 2>&1
$mk = & ssh @sshBase ($duser + '@' + $desktop) 'schtasks /create /tn wpstest /tr F:\fig1_rebuild\wpsrun.cmd /sc once /st 23:59 /f' 2>&1
L ('   schtasks create: ' + (San ((($mk | Out-String).Trim()) -replace "`r?`n", ' | ')))
$rn = & ssh @sshBase ($duser + '@' + $desktop) 'schtasks /run /tn wpstest' 2>&1
L ('   schtasks run: ' + (San ((($rn | Out-String).Trim()) -replace "`r?`n", ' | ')))

# ---------------- C. poll the interactive log ----------------
$deadline = (Get-Date).AddMinutes(15)
$done = $false
$lastLen = 0
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 45
    $log = & ssh @sshBase ($duser + '@' + $desktop) 'type F:\fig1_rebuild\harness_results\interactive_log.txt 2>nul' 2>&1
    $txt = (@($log) -join "`n")
    if ($txt.Length -gt $lastLen) {
        foreach ($ln in @($log)) {
            $t = San ([string]$ln)
            if ($t.Trim()) { L ('   | ' + $t) }
        }
        $lastLen = $txt.Length
    }
    if ($txt -match 'INTERACTIVE-DONE') { $done = $true; break }
}
if (-not $done) { L '   [WARN] interactive session did not finish within 15 min' }

# ---------------- D. collect artifacts ----------------
$dest = Join-Path $repoRoot 'results\harness_wps\desktop'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$netOut2 = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -eq 0) {
    try {
        foreach ($f in @('arena_report.pptx', 'proj_deck.json', 'test_writer.docx', 'test_impress.pptx', 'proj_writer.json', 'proj_impress.json', 'interactive_log.txt')) {
            $src = $fshare + '\fig1_rebuild\harness_results\' + $f
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination (Join-Path $dest $f) -Force
                L ('   collected: ' + $f + ' (' + [math]::Round((Get-Item -LiteralPath $src).Length/1KB) + 'KB)')
            }
        }
    }
    finally { & net use $fshare /delete 2>&1 | Out-Null }
}
else { L '   [WARN] F$ unreachable for collection' }

$pptx = Join-Path $dest 'arena_report.pptx'
if (Test-Path -LiteralPath $pptx) {
    L ('   RESULT repo: ' + $pptx)
    L '   RESULT desktop: F:\fig1_rebuild\harness_results\arena_report.pptx'
}
else { L '   [FAIL] arena_report.pptx not collected' }
L '--- task t116 done ---'
exit 0
