# t136_v2ray_antigravity_bridge.ps1 - round 179: try to bridge V2Ray local
# routes into Antigravity on laptop and desktop. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\antigravity'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$helper = Join-Path $repo 'code\tasks\v2ray_antigravity_bridge.ps1'
L '--- task t136: V2Ray Antigravity bridge ---'
if (-not (Test-Path -LiteralPath $helper)) { L '   [FAIL] missing helper'; exit 2 }

L '--- local watcher host bridge ---'
$localReport = Join-Path $outDir 'v2ray_antigravity_bridge_local_r179.md'
try {
    & $helper -OutPath $localReport -Apply -Relaunch
    L ('local_bridge_exit=' + $LASTEXITCODE)
} catch { L ('local_bridge_THROW=' + (San $_.Exception.Message)) }
if (Test-Path -LiteralPath $localReport) { foreach ($ln in @(Get-Content -LiteralPath $localReport -Tail 120 -ErrorAction SilentlyContinue)) { L ('local| ' + (San $ln)) } }

L '--- desktop bridge ---'
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o','BatchMode=yes','-o','ConnectTimeout=15','-o','StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
try {
    $net = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
    L ('net_use=' + (San $net))
    if ($LASTEXITCODE -eq 0 -or $net -match 'success') {
        Copy-Item -LiteralPath $helper -Destination ($fshare + '\fig1_rebuild\v2ray_antigravity_bridge.ps1') -Force
        & net use $fshare /delete 2>&1 | Out-Null
        $remoteOut = 'F:\fig1_rebuild\v2ray_antigravity_bridge_desktop_r179.md'
        $job = Start-Job -ScriptBlock {
            param($o,$u,$h,$outp)
            & ssh @o ($u + '@' + $h) ('powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\v2ray_antigravity_bridge.ps1 -OutPath ' + $outp + ' -Apply -Relaunch -InteractiveTask') 2>&1 | Out-String
        } -ArgumentList $sshBase,$duser,$desktop,$remoteOut
        if (Wait-Job $job -Timeout 720) {
            $rout = (Receive-Job $job | Out-String)
            foreach ($ln in ($rout -split "`r?`n")) { if ($ln.Trim()) { L ('desk| ' + (San $ln)) } }
        } else { Stop-Job $job -Force -ErrorAction SilentlyContinue; L 'desktop_bridge_TIMEOUT' }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        $null = & net use $fshare /persistent:no 2>&1
        $src = $fshare + '\fig1_rebuild\v2ray_antigravity_bridge_desktop_r179.md'
        $dst = Join-Path $outDir 'v2ray_antigravity_bridge_desktop_r179.md'
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $dst -Force; foreach ($ln in @(Get-Content -LiteralPath $dst -Tail 120 -ErrorAction SilentlyContinue)) { L ('desk_report| ' + (San $ln)) } }
        else { L 'desktop_bridge_report_missing' }
        & net use $fshare /delete 2>&1 | Out-Null
    } else { L 'desktop_share_unreachable' }
} catch { L ('desktop_bridge_THROW=' + (San $_.Exception.Message)); try { & net use $fshare /delete 2>&1 | Out-Null } catch { } }

L '--- task t136 done ---'
exit 0
