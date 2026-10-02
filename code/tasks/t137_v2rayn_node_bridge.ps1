# t137_v2rayn_node_bridge.ps1 - round 180: parse v2rayN local nodes and
# create a private Antigravity HTTP bridge if a supported node is found.
# ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir = Join-Path $repo 'results\antigravity'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$helper = Join-Path $repo 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
L '--- task t137: v2rayN node bridge for Antigravity ---'
if (-not (Test-Path -LiteralPath $helper)) { L '   [FAIL] helper missing'; exit 2 }

L '--- local watcher host ---'
$localReport = Join-Path $outDir 'v2rayn_node_bridge_local_r180.md'
try { & $helper -OutPath $localReport -MaxNodes 60 -Apply -Relaunch; L ('local_exit=' + $LASTEXITCODE) } catch { L ('local_THROW=' + (San $_.Exception.Message)) }
if (Test-Path -LiteralPath $localReport) { foreach ($ln in @(Get-Content -LiteralPath $localReport -Tail 160 -ErrorAction SilentlyContinue)) { L ('local| ' + (San $ln)) } }

L '--- desktop host ---'
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o','BatchMode=yes','-o','ConnectTimeout=15','-o','StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
try {
    $net = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
    L ('net_use=' + (San $net))
    if ($LASTEXITCODE -eq 0 -or $net -match 'success') {
        Copy-Item -LiteralPath $helper -Destination ($fshare + '\fig1_rebuild\v2rayn_antigravity_auto_bridge.ps1') -Force
        & net use $fshare /delete 2>&1 | Out-Null
        $remoteOut = 'F:\fig1_rebuild\v2rayn_node_bridge_desktop_r180.md'
        $job = Start-Job -ScriptBlock {
            param($o,$u,$h,$outp)
            & ssh @o ($u + '@' + $h) ('powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\v2rayn_antigravity_auto_bridge.ps1 -OutPath ' + $outp + ' -MaxNodes 60 -Apply -Relaunch -InteractiveTask') 2>&1 | Out-String
        } -ArgumentList $sshBase,$duser,$desktop,$remoteOut
        if (Wait-Job $job -Timeout 900) {
            $rout = (Receive-Job $job | Out-String)
            foreach ($ln in ($rout -split "`r?`n")) { if ($ln.Trim()) { L ('desk| ' + (San $ln)) } }
        } else { Stop-Job $job -Force -ErrorAction SilentlyContinue; L 'desktop_TIMEOUT' }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        $null = & net use $fshare /persistent:no 2>&1
        $src = $fshare + '\fig1_rebuild\v2rayn_node_bridge_desktop_r180.md'
        $dst = Join-Path $outDir 'v2rayn_node_bridge_desktop_r180.md'
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $dst -Force; foreach ($ln in @(Get-Content -LiteralPath $dst -Tail 160 -ErrorAction SilentlyContinue)) { L ('desk_report| ' + (San $ln)) } }
        else { L 'desktop_report_missing' }
        & net use $fshare /delete 2>&1 | Out-Null
    } else { L 'desktop_share_unreachable' }
} catch { L ('desktop_THROW=' + (San $_.Exception.Message)); try { & net use $fshare /delete 2>&1 | Out-Null } catch { } }
L '--- task t137 done ---'
exit 0
