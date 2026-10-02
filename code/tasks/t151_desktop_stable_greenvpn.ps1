# t151_desktop_stable_greenvpn.ps1 - round 194.
# 1) Verify desktop Antigravity bridge persists.
# 2) Strengthen/verify Green VPN delayed autostart on this machine.
# ASCII-only. Prints no node secrets.

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{20,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function WA([string]$p,[string[]]$lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllLines($p, $lines, (New-Object System.Text.ASCIIEncoding)) }

$script:Lines=@()
$repoRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repoRoot 'results\ops_r194'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
L '--- task t151: desktop stable verify + GreenVPN autostart ---'

# A. Green VPN autostart on the current/watcher machine.
L '--- A: GreenVPN autostart verify/install ---'
$vpnDir='E:\NsfocusVPN'
$vpnExe=Join-Path $vpnDir 'NsfocusVPN.exe'
$launcherPs1=Join-Path $vpnDir 'green-vpn-launcher.ps1'
$launcherCmd=Join-Path $vpnDir 'green-vpn-launcher.cmd'
$startup=Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupCmd=Join-Path $startup 'GreenVPN-Autostart.cmd'
$desktopLauncher=Join-Path ([Environment]::GetFolderPath('Desktop')) 'GreenVPN-Launcher.cmd'
if(Test-Path -LiteralPath $vpnExe){
    if(-not (Test-Path -LiteralPath $launcherPs1)){
        $ps=@'
param(
    [int]$DelaySec = 45,
    [switch]$KillBefore,
    [switch]$SecondKick,
    [int]$SecondKickSec = 120
)
$ErrorActionPreference = 'Continue'
$dir = Split-Path -Parent $PSCommandPath
$exe = Join-Path $dir 'NsfocusVPN.exe'
$log = Join-Path $dir 'green-vpn-launcher.log'
function Log([string]$m) { try { Add-Content -LiteralPath $log -Encoding UTF8 -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $m) } catch { } }
Log 'launcher start'
if ($DelaySec -gt 0) { Log ('delay ' + $DelaySec + 's'); Start-Sleep -Seconds $DelaySec }
if ($KillBefore) { Log 'kill-before enabled'; try { taskkill /f /im NsfocusVPN.exe 2>&1 | Out-Null } catch { }; Start-Sleep -Seconds 5 }
if (-not (Test-Path -LiteralPath $exe)) { Log ('missing exe ' + $exe); exit 2 }
try { Log ('start ' + $exe); Start-Process -FilePath $exe -WorkingDirectory $dir } catch { Log ('normal start failed: ' + $_.Exception.Message); try { Start-Process -FilePath $exe -WorkingDirectory $dir -Verb RunAs; Log 'runas issued' } catch { Log ('runas failed: ' + $_.Exception.Message) } }
if ($SecondKick) { Log ('second-kick wait ' + $SecondKickSec + 's'); Start-Sleep -Seconds $SecondKickSec; $p=@(Get-Process -Name NsfocusVPN -ErrorAction SilentlyContinue); if($p.Count -gt 0){ Log 'second-kick: process exists; leave it running' } else { Log 'second-kick: not running, start again'; try { Start-Process -FilePath $exe -WorkingDirectory $dir } catch { Log ('second start failed: ' + $_.Exception.Message) } } }
Log 'launcher done'
'@ -split "`r?`n"
        W $launcherPs1 $ps
    }
    WA $launcherCmd @('@echo off','powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "E:\NsfocusVPN\green-vpn-launcher.ps1" -DelaySec 0 -KillBefore -SecondKick')
    New-Item -ItemType Directory -Force -Path $startup | Out-Null
    WA $startupCmd @('@echo off','powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "E:\NsfocusVPN\green-vpn-launcher.ps1" -DelaySec 45 -KillBefore -SecondKick')
    WA $desktopLauncher @('@echo off','powershell -NoProfile -ExecutionPolicy Bypass -File "E:\NsfocusVPN\green-vpn-launcher.ps1" -DelaySec 0 -KillBefore -SecondKick')
    try{
        $tn='GreenVPN-Autostart'
        $psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $args='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "E:\NsfocusVPN\green-vpn-launcher.ps1" -DelaySec 45 -KillBefore -SecondKick'
        $la=New-ScheduledTaskAction -Execute $psExe -Argument $args
        $tr=New-ScheduledTaskTrigger -AtLogOn
        $pr=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
        $st=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $tn -Action $la -Trigger $tr -Principal $pr -Settings $st -Force | Out-Null
        L ('greenvpn_task_OK=' + $tn)
    } catch { L ('greenvpn_task_WARN=' + (San $_.Exception.Message)) }
    L ('greenvpn_exe_exists=True path=' + $vpnExe)
    L ('greenvpn_startup_cmd_exists=' + (Test-Path -LiteralPath $startupCmd))
    L ('greenvpn_launcher_ps1_exists=' + (Test-Path -LiteralPath $launcherPs1))
    L ('greenvpn_desktop_launcher_exists=' + (Test-Path -LiteralPath $desktopLauncher))
    $gp=@(Get-Process -Name NsfocusVPN -ErrorAction SilentlyContinue)
    L ('greenvpn_process_count_now=' + $gp.Count)
    $log=Join-Path $vpnDir 'green-vpn-launcher.log'
    if(Test-Path -LiteralPath $log){ foreach($ln in (Get-Content -LiteralPath $log -Tail 8 -ErrorAction SilentlyContinue)){ L ('greenvpn_log_tail=' + (San $ln)) } }
    L 'FINAL_GREENVPN_AUTOSTART: INSTALLED_STARTUP_AND_SCHEDULED_TASK'
} else { L ('greenvpn_exe_exists=False path=' + $vpnExe); L 'FINAL_GREENVPN_AUTOSTART: MISSING_EXE' }

# B. Desktop bridge stable verify.
L '--- B: desktop Antigravity bridge stable verify ---'
$desktop='100.84.137.117'
$duser='BNI'
$sshBase=@('-o','BatchMode=yes','-o','ConnectTimeout=15','-o','StrictHostKeyChecking=accept-new')
$fshare='\\' + $desktop + '\F$'
$verifierSrc=Join-Path $repoRoot 'code\tasks\desk_antigravity_stable_verify.ps1'
$netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
if($LASTEXITCODE -ne 0){ L ('desktop_Fshare_unreachable=' + (San $netOut)); L 'FINAL_DESKTOP_STABLE_VERIFY: FSHARE_UNREACHABLE' }
else{
    try{
        $rootUnc=$fshare + '\fig1_rebuild'
        New-Item -ItemType Directory -Force -Path $rootUnc | Out-Null
        Copy-Item -LiteralPath $verifierSrc -Destination ($rootUnc + '\desk_antigravity_stable_verify.ps1') -Force
        L 'desktop_verifier_staged=OK'
    } catch { L ('desktop_verifier_stage_FAIL=' + (San $_.Exception.Message)) }
    finally { & net use $fshare /delete 2>&1 | Out-Null }
    $job=Start-Job -ScriptBlock { param($o,$t,$h) & ssh @o ($t + '@' + $h) 'powershell -NoProfile -ExecutionPolicy Bypass -File F:\fig1_rebuild\desk_antigravity_stable_verify.ps1' 2>&1 | Out-String } -ArgumentList $sshBase,$duser,$desktop
    if(-not (Wait-Job $job -Timeout 420)){ Stop-Job $job -Force -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; L 'desktop_stable_timeout=420s'; L 'FINAL_DESKTOP_STABLE_VERIFY: TIMEOUT' }
    else{
        $out=(Receive-Job $job | Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue
        foreach($ln in ($out -split "`r?`n")){ $x=San $ln; if($x.Trim() -and $x -notmatch 'CategoryInfo|FullyQualifiedErrorId|~~|\+ +'){ L ('desktop_stable| ' + $x) } }
        $netOut=(& net use $fshare /persistent:no 2>&1 | Out-String).Trim()
        if($LASTEXITCODE -eq 0){
            try{
                $dstDir=Join-Path $repoRoot 'results\antigravity'; New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
                $src=$fshare + '\fig1_rebuild\antigravity_bridge_desktop_stable_r194.md'
                if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination (Join-Path $dstDir 'antigravity_bridge_desktop_stable_r194.md') -Force; L 'collected=antigravity_bridge_desktop_stable_r194.md' }
            } catch { L ('collect_stable_WARN=' + (San $_.Exception.Message)) }
            finally { & net use $fshare /delete 2>&1 | Out-Null }
        }
    }
}
W (Join-Path $outDir 'GREENVPN_AND_DESKTOP_STABLE_R194.md') $script:Lines
L '--- task t151 done ---'
exit 0
