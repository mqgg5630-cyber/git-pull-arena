# t150_desk_antigravity_bridge.ps1 - round 193: copy the private node file
# from this machine to the desktop, then apply/verify the Antigravity bridge
# there over ssh. Prints no node secrets. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

L '--- task t150: desktop Antigravity private bridge ---'
$desktop = '100.84.137.117'
$duser = 'BNI'
$sshBase = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', '-o', 'StrictHostKeyChecking=accept-new')
$fshare = '\\' + $desktop + '\F$'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$helperSrc = Join-Path $repoRoot 'code\tasks\v2rayn_antigravity_auto_bridge.ps1'
$deskRunnerSrc = Join-Path $repoRoot 'code\tasks\desk_antigravity_private_bridge.ps1'
$privSubs = Join-Path $env:USERPROFILE '.arena-private\v2ray_subs.txt'
if (-not (Test-Path -LiteralPath $privSubs)) { L 'private_subs_source=absent'; L 'FINAL_T150: NO_PRIVATE_SUBS_SOURCE'; exit 2 }
$nodeLines = @(Get-Content -LiteralPath $privSubs -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(vmess|vless|trojan|ss)://' }).Count
L ('private_subs_source=present node_lines=' + $nodeLines)
if (-not (Test-Path -LiteralPath $helperSrc)) { L 'helper_src_missing'; exit 2 }
if (-not (Test-Path -LiteralPath $deskRunnerSrc)) { L 'desk_runner_src_missing'; exit 2 }
foreach ($f in @($helperSrc, $deskRunnerSrc)) {
    $tok=$null; $perrs=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$tok,[ref]$perrs)
    if($perrs -and $perrs.Count -gt 0){ L ('parse_FAIL=' + (San $f) + ' count=' + $perrs.Count); foreach($e in ($perrs | Select-Object -First 4)){ L ('parse_line=' + $e.Extent.StartLineNumber + ' msg=' + (San $e.Message)) }; exit 2 }
}
L 'parse_checks=OK'

$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { L ('Fshare_unreachable=' + (San $netOut)); L 'FINAL_T150: DESKTOP_FSHARE_UNREACHABLE'; exit 2 }
try {
    $rootUnc = $fshare + '\fig1_rebuild'
    $privUnc = $rootUnc + '\private'
    New-Item -ItemType Directory -Force -Path $rootUnc | Out-Null
    New-Item -ItemType Directory -Force -Path $privUnc | Out-Null
    Copy-Item -LiteralPath $helperSrc -Destination ($rootUnc + '\v2rayn_antigravity_auto_bridge.ps1') -Force
    Copy-Item -LiteralPath $deskRunnerSrc -Destination ($rootUnc + '\desk_antigravity_private_bridge.ps1') -Force
    Copy-Item -LiteralPath $privSubs -Destination ($privUnc + '\v2ray_subs.txt') -Force
    $boot = @'
$ErrorActionPreference = 'Continue'
$dst = Join-Path $env:USERPROFILE '.arena-private'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -LiteralPath 'F:\fig1_rebuild\private\v2ray_subs.txt' -Destination (Join-Path $dst 'v2ray_subs.txt') -Force
Remove-Item -LiteralPath 'F:\fig1_rebuild\private\v2ray_subs.txt' -Force -ErrorAction SilentlyContinue
powershell -NoProfile -ExecutionPolicy Bypass -File 'F:\fig1_rebuild\desk_antigravity_private_bridge.ps1'
'@
    [IO.File]::WriteAllText(($rootUnc + '\desk_agy_bootstrap.ps1'), $boot.Replace("`n","`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    L 'desktop_stage=OK helper runner bootstrap private_payload'
}
catch { L ('desktop_stage_FAIL=' + (San $_.Exception.Message)); exit 2 }
finally { & net use $fshare /delete 2>&1 | Out-Null }

$job = Start-Job -ScriptBlock {
    param($o, $t, $h)
    & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_agy_bootstrap.ps1' 2>&1 | Out-String
} -ArgumentList $sshBase, $duser, $desktop
if (-not (Wait-Job $job -Timeout 1500)) {
    Stop-Job $job -Force -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    L 'remote_bridge_TIMEOUT=1500s'
    L 'FINAL_T150: REMOTE_TIMEOUT'
    exit 2
}
$out = (Receive-Job $job | Out-String).Trim()
$rc = $LASTEXITCODE
Remove-Job $job -Force -ErrorAction SilentlyContinue
L ('remote_bridge_exit=' + $rc)
foreach($ln in ($out -split "`r?`n")){
    $x=San $ln
    if($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +'){ L ('desktop| ' + $x) }
}

# Collect sanitized desktop reports back into the repository results folder.
$netOut = (& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -eq 0) {
    try {
        $dstDir = Join-Path $repoRoot 'results\antigravity'
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        foreach($name in @('antigravity_bridge_desktop_r193.md','v2rayn_node_bridge_desktop_r193.md')){
            $src = $fshare + '\fig1_rebuild\' + $name
            if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination (Join-Path $dstDir $name) -Force; L ('collected=' + $name) }
            else { L ('collect_missing=' + $name) }
        }
    } catch { L ('collect_WARN=' + (San $_.Exception.Message)) }
    finally { & net use $fshare /delete 2>&1 | Out-Null }
} else { L ('collect_skip_Fshare=' + (San $netOut)) }
L '--- task t150 done ---'
exit 0
