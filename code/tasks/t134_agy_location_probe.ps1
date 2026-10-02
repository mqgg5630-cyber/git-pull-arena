# t134_agy_location_probe.ps1 - round 177: diagnose Antigravity API geo
# restriction on local watcher host and desktop, applying a supported proxy if
# discovered. ASCII-only.

$ErrorActionPreference = 'Continue'

function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\antigravity'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$diag = Join-Path $repo 'code\tasks\agy_location_diag.ps1'

L '--- task t134: Antigravity API location diagnostic ---'
if (-not (Test-Path -LiteralPath $diag)) { L '   [FAIL] missing agy_location_diag.ps1'; exit 2 }

L '--- local watcher host ---'
$localReport = Join-Path $outDir 'agy_location_diag_local_r177.md'
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $diag -OutPath $localReport -Apply
    L ('   local_diag_exit=' + $LASTEXITCODE)
} catch { L ('   local_diag_THROW=' + (San $_.Exception.Message)) }
if (Test-Path -LiteralPath $localReport) {
    foreach ($ln in @(Get-Content -LiteralPath $localReport -Tail 80 -ErrorAction SilentlyContinue)) { L ('   local| ' + (San $ln)) }
}

L '--- desktop host ---'
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$stage = $fshare + '\fig1_rebuild\agy_location_diag.ps1'
$remoteReport = 'F:\fig1_rebuild\agy_location_diag_desktop_r177.md'
try {
    $net = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
    L ('   net_use=' + (San $net))
    if ($LASTEXITCODE -eq 0 -or $net -match 'success') {
        Copy-Item -LiteralPath $diag -Destination $stage -Force
        & net use $fshare /delete 2>&1 | Out-Null
        $job = Start-Job -ScriptBlock {
            param($o, $u, $h, $rp)
            & ssh @o ($u + '@' + $h) ('powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\agy_location_diag.ps1 -OutPath ' + $rp + ' -Apply') 2>&1 | Out-String
        } -ArgumentList $sshBase, $duser, $desktop, $remoteReport
        if (Wait-Job $job -Timeout 420) {
            $rout = (Receive-Job $job | Out-String)
            foreach ($ln in ($rout -split "`r?`n")) { if ($ln.Trim()) { L ('   desk| ' + (San $ln)) } }
        } else {
            Stop-Job $job -Force -ErrorAction SilentlyContinue
            L '   desk_diag_TIMEOUT'
        }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        $null = & net use $fshare /persistent:no 2>&1
        $dst = Join-Path $outDir 'agy_location_diag_desktop_r177.md'
        if (Test-Path -LiteralPath ($fshare + '\fig1_rebuild\agy_location_diag_desktop_r177.md')) {
            Copy-Item -LiteralPath ($fshare + '\fig1_rebuild\agy_location_diag_desktop_r177.md') -Destination $dst -Force
            L ('   collected_desktop_report=' + $dst)
            foreach ($ln in @(Get-Content -LiteralPath $dst -Tail 80 -ErrorAction SilentlyContinue)) { L ('   desk_report| ' + (San $ln)) }
        } else { L '   desktop_report_missing' }
        & net use $fshare /delete 2>&1 | Out-Null
    } else { L '   desktop_share_unreachable' }
} catch {
    L ('   desktop_diag_THROW=' + (San $_.Exception.Message))
    try { & net use $fshare /delete 2>&1 | Out-Null } catch { }
}

L '--- task t134 done ---'
exit 0
