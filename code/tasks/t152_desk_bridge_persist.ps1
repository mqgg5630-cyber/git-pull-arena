# t152_desk_bridge_persist.ps1 - round 195: make desktop bridge persistent
# by running xray directly as a scheduled task. ASCII-only.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m }

L '--- task t152: desktop Antigravity persistent bridge ---'
$desktop='100.84.137.117'
$duser='BNI'
$sshBase=@('-o','BatchMode=yes','-o','ConnectTimeout=15','-o','StrictHostKeyChecking=accept-new')
$fshare='\\' + $desktop + '\F$'
$repoRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$scriptSrc=Join-Path $repoRoot 'code\tasks\desk_antigravity_persist_bridge.ps1'
if(-not (Test-Path -LiteralPath $scriptSrc)){ L 'persist_script_missing'; exit 2 }
$tok=$null; $perrs=$null
$null=[System.Management.Automation.Language.Parser]::ParseFile($scriptSrc,[ref]$tok,[ref]$perrs)
if($perrs -and $perrs.Count -gt 0){ L ('parse_FAIL count=' + $perrs.Count); foreach($e in ($perrs | Select-Object -First 4)){ L ('parse_line=' + $e.Extent.StartLineNumber + ' msg=' + (San $e.Message)) }; exit 2 }
L 'parse_check=OK'
$netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if($LASTEXITCODE -ne 0){ L ('Fshare_unreachable=' + (San $netOut)); L 'FINAL_T152: FSHARE_UNREACHABLE'; exit 2 }
try{
    $rootUnc=$fshare + '\fig1_rebuild'
    New-Item -ItemType Directory -Force -Path $rootUnc | Out-Null
    Copy-Item -LiteralPath $scriptSrc -Destination ($rootUnc + '\desk_antigravity_persist_bridge.ps1') -Force
    L 'persist_script_staged=OK'
}catch{ L ('stage_FAIL=' + (San $_.Exception.Message)); exit 2 }
finally{ & net use $fshare /delete 2>&1 | Out-Null }
$job=Start-Job -ScriptBlock { param($o,$t,$h) & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_antigravity_persist_bridge.ps1' 2>&1 | Out-String } -ArgumentList $sshBase,$duser,$desktop
if(-not (Wait-Job $job -Timeout 600)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; L 'remote_persist_TIMEOUT=600s'; L 'FINAL_T152: REMOTE_TIMEOUT'; exit 2 }
$out=(Receive-Job $job | Out-String).Trim()
Remove-Job $job -Force -ErrorAction SilentlyContinue
foreach($ln in ($out -split "`r?`n")){ $x=San $ln; if($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +'){ L ('desktop_persist| ' + $x) } }
$netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if($LASTEXITCODE -eq 0){
    try{
        $dstDir=Join-Path $repoRoot 'results\antigravity'; New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        $src=$fshare + '\fig1_rebuild\antigravity_bridge_desktop_persist_r195.md'
        if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination (Join-Path $dstDir 'antigravity_bridge_desktop_persist_r195.md') -Force; L 'collected=antigravity_bridge_desktop_persist_r195.md' }
        else{ L 'collect_missing=antigravity_bridge_desktop_persist_r195.md' }
    }catch{ L ('collect_WARN=' + (San $_.Exception.Message)) }
    finally{ & net use $fshare /delete 2>&1 | Out-Null }
}else{ L ('collect_skip_Fshare=' + (San $netOut)) }
L '--- task t152 done ---'
exit 0
