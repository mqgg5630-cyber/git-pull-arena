# t184_zerotier_wireguard_desktop_r233.ps1 - round 233.
# Prepare desktop side for ZeroTier and self-hosted WireGuard file access.
# No Antigravity/IDE actions. ASCII-only. No private keys copied to repo.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function Curl-Text([string]$Url,[int]$Sec){ try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -L --max-time $Sec -sS $Url 2>&1|Out-String).Trim() }catch{ return $_.Exception.Message } }
function Find-Exe([string[]]$Paths,[string[]]$Names){ $c=@(); foreach($p in $Paths){ if($p -and (Test-Path -LiteralPath $p)){ $c+=$p } }; foreach($n in $Names){ try{ $cmd=Get-Command $n -ErrorAction SilentlyContinue; if($cmd){$c+=$cmd.Source} }catch{} }; return @($c|Sort-Object -Unique|Select-Object -First 1) }
function FInfo([string]$p){ if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return [pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')} }; return [pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''} }
function ZtCli(){ return Find-Exe @((Join-Path $env:ProgramFiles 'ZeroTier\One\zerotier-cli.bat'),(Join-Path ${env:ProgramFiles(x86)} 'ZeroTier\One\zerotier-cli.bat'),(Join-Path $env:ProgramFiles 'ZeroTier\One\zerotier-cli.exe'),(Join-Path ${env:ProgramFiles(x86)} 'ZeroTier\One\zerotier-cli.exe')) @('zerotier-cli.bat','zerotier-cli.exe','zerotier-cli') }
function WgExe(){ return Find-Exe @((Join-Path $env:ProgramFiles 'WireGuard\wg.exe'),(Join-Path ${env:ProgramFiles(x86)} 'WireGuard\wg.exe')) @('wg.exe','wg') }
function WgApp(){ return Find-Exe @((Join-Path $env:ProgramFiles 'WireGuard\wireguard.exe'),(Join-Path ${env:ProgramFiles(x86)} 'WireGuard\wireguard.exe')) @('wireguard.exe') }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$shareRoot=Join-Path $lab 'phone-share'
$ztRoot=Join-Path $lab 'zerotier'
$wgRoot=Join-Path $lab 'wireguard'
foreach($d in @($reports,$shareRoot,$ztRoot,$wgRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$report=Join-Path $outDir 'ZEROTIER_WIREGUARD_DESKTOP_R233.md'
L '# R233 ZeroTier and self-hosted WireGuard desktop setup'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))
L 'no_antigravity_or_ide_actions=True'
$isAdmin=$false; try{ $isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }catch{}
L ('is_admin='+$isAdmin)

# Safe file share on 18089.
$sharePort=18089
[IO.File]::WriteAllText((Join-Path $shareRoot 'index.html'),'<title>Arena Phone Share R233</title><h1>Arena Phone Share R233</h1><p>Only this folder is exposed. Use LAN, ZeroTier, or WireGuard IP.</p>',(New-Object Text.UTF8Encoding($false)))
$pidFile=Join-Path $shareRoot 'phone_share_python.pid'
if(Test-Path -LiteralPath $pidFile){ try{ Stop-Process -Id ([int](Get-Content -LiteralPath $pidFile -Raw)) -Force -ErrorAction SilentlyContinue }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
$serverPid=''
if($py){ try{ $p=Start-Process -FilePath $py -ArgumentList @('-m','http.server',[string]$sharePort,'--bind','0.0.0.0','--directory',$shareRoot) -PassThru -WindowStyle Hidden; $serverPid=$p.Id; [IO.File]::WriteAllText($pidFile,[string]$p.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('file_share_pid='+$p.Id) }catch{ L ('file_share_start_ERR='+(San $_.Exception.Message)) } }
$fwShare=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 profile=any 2>&1|Out-String } 30
L ('file_share_firewall='+(San (($fwShare -split "`r?`n"|Select-Object -First 4)-join ' | ')))
$ips=@(); try{ $ips=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.|100\.)' -and $_.IPAddress -ne '0.0.0.0' } | Select-Object -ExpandProperty IPAddress -Unique) }catch{}
$lanRows=@(); foreach($ip in $ips){ $u='http://'+$ip+':'+$sharePort+'/'; $ok=((Curl-Text $u 5) -match 'Arena Phone Share R233'); $lanRows += [pscustomobject]@{url=$u;ok=$ok}; L ('lan_url='+$u+' ok='+$ok) }

# ZeroTier install/probe.
$winget=''; try{ $cmd=Get-Command winget.exe -ErrorAction SilentlyContinue; if($cmd){$winget=$cmd.Source} }catch{}
$ztCli=ZtCli; $ztInstallOut=''; $ztInstallAttempted=$false
if(-not $ztCli -and $winget){ $ztInstallAttempted=$true; $wgcmd=$winget; $ztInstallOut=Run-Cap { & $using:wgcmd install --id ZeroTier.ZeroTierOne -e --silent --accept-package-agreements --accept-source-agreements 2>&1|Out-String } 360; L ('zerotier_winget_head='+(San (($ztInstallOut -split "`r?`n"|Select-Object -First 10)-join ' | '))); Start-Sleep -Seconds 5; $ztCli=ZtCli }
L ('zerotier_cli='+(San $ztCli))
$ztInfo=''; $ztNetworks=''; $ztNodeId=''; $ztIps=@()
if($ztCli){
  $cli=$ztCli
  $ztInfo=Run-Cap { & $using:cli info 2>&1|Out-String } 25
  $ztNetworks=Run-Cap { & $using:cli listnetworks 2>&1|Out-String } 25
  if($ztInfo -match '([0-9a-fA-F]{10})'){ $ztNodeId=$Matches[1] }
  L ('zerotier_info='+(San $ztInfo))
  L ('zerotier_networks_head='+(San (($ztNetworks -split "`r?`n"|Select-Object -First 12)-join ' | ')))
  try{ $ztIps=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -match 'ZeroTier|zt' -or $_.InterfaceDescription -match 'ZeroTier|zt' } | Select-Object InterfaceAlias,IPAddress,PrefixLength) }catch{}
  foreach($z in $ztIps){ L ('zerotier_ip='+(San $z.InterfaceAlias)+' '+$z.IPAddress+'/'+$z.PrefixLength) }
}
$ztJoinScript=Join-Path $ztRoot 'join-zerotier-network.ps1'
W $ztJoinScript @(
'param([Parameter(Mandatory=$true)][string]$NetworkId)',
'$ErrorActionPreference="Continue"',
'$cli=$null',
'foreach($p in @((Join-Path $env:ProgramFiles "ZeroTier\One\zerotier-cli.bat"),(Join-Path ${env:ProgramFiles(x86)} "ZeroTier\One\zerotier-cli.bat"),(Join-Path $env:ProgramFiles "ZeroTier\One\zerotier-cli.exe"),(Join-Path ${env:ProgramFiles(x86)} "ZeroTier\One\zerotier-cli.exe"))){ if($p -and (Test-Path -LiteralPath $p)){ $cli=$p; break } }',
'if(-not $cli){ throw "ZeroTier CLI not found. Install ZeroTier One first." }',
'& $cli join $NetworkId',
'Start-Sleep -Seconds 3',
'& $cli listnetworks',
'Write-Host "Authorize this PC and phone in ZeroTier Central if status is REQUESTING_CONFIGURATION."'
)

# WireGuard install/probe and local-only config generator.
$wgExe=WgExe; $wgApp=WgApp; $wgInstallOut=''; $wgInstallAttempted=$false
if((-not $wgExe -or -not $wgApp) -and $winget){ $wgInstallAttempted=$true; $wgcmd=$winget; $wgInstallOut=Run-Cap { & $using:wgcmd install --id WireGuard.WireGuard -e --silent --accept-package-agreements --accept-source-agreements 2>&1|Out-String } 360; L ('wireguard_winget_head='+(San (($wgInstallOut -split "`r?`n"|Select-Object -First 10)-join ' | '))); Start-Sleep -Seconds 5; $wgExe=WgExe; $wgApp=WgApp }
L ('wireguard_wg_exe='+(San $wgExe))
L ('wireguard_app='+(San $wgApp))
$fwWg=Run-Cap { netsh advfirewall firewall add rule name="WireGuard UDP 51820" dir=in action=allow protocol=UDP localport=51820 profile=any 2>&1|Out-String } 30
L ('wireguard_firewall='+(San (($fwWg -split "`r?`n"|Select-Object -First 4)-join ' | ')))
$pubIp=Curl-Text 'https://api.ipify.org' 10
if($pubIp -notmatch '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'){ $pubIp='' }
L ('public_ip_probe='+(San $pubIp))

$genScript=Join-Path $wgRoot 'generate-wireguard-configs-local.ps1'
$installScript=Join-Path $wgRoot 'install-wireguard-tunnel-admin.ps1'
$removeScript=Join-Path $wgRoot 'remove-wireguard-tunnel-admin.ps1'
$serverConf=Join-Path $wgRoot 'arena-phone-server.conf'
$phoneConf=Join-Path $wgRoot 'arena-phone-client.conf'
$wgGen=@'
param(
  [string]$EndpointHost = "REPLACE_WITH_PUBLIC_IP_OR_DDNS",
  [int]$ListenPort = 51820
)
$ErrorActionPreference='Stop'
$root='E:\0mcp-agv-arena-optimized\wireguard'
New-Item -ItemType Directory -Force -Path $root | Out-Null
$wg=$null
foreach($p in @((Join-Path $env:ProgramFiles 'WireGuard\wg.exe'),(Join-Path ${env:ProgramFiles(x86)} 'WireGuard\wg.exe'))){ if($p -and (Test-Path -LiteralPath $p)){ $wg=$p; break } }
if(-not $wg){ throw 'wg.exe not found. Install WireGuard first.' }
function New-KeyPair(){ $priv=(& $wg genkey).Trim(); $pub=($priv | & $wg pubkey).Trim(); return [pscustomobject]@{Private=$priv;Public=$pub} }
$server=New-KeyPair
$phone=New-KeyPair
$serverConf=Join-Path $root 'arena-phone-server.conf'
$phoneConf=Join-Path $root 'arena-phone-client.conf'
@"
[Interface]
PrivateKey = $($server.Private)
Address = 10.66.66.1/24
ListenPort = $ListenPort

[Peer]
# phone
PublicKey = $($phone.Public)
AllowedIPs = 10.66.66.2/32
"@ | Set-Content -LiteralPath $serverConf -Encoding ascii
@"
[Interface]
PrivateKey = $($phone.Private)
Address = 10.66.66.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $($server.Public)
Endpoint = $EndpointHost`:$ListenPort
AllowedIPs = 10.66.66.1/32
PersistentKeepalive = 25
"@ | Set-Content -LiteralPath $phoneConf -Encoding ascii
Write-Host "Wrote local-only configs:"
Write-Host $serverConf
Write-Host $phoneConf
Write-Host "Do not upload these files. Import phone config into the WireGuard phone app."
Write-Host "After installing the PC tunnel, phone opens http://10.66.66.1:18089/"
'@
[IO.File]::WriteAllText($genScript,$wgGen,(New-Object Text.UTF8Encoding($false)))
W $installScript @(
'$ErrorActionPreference="Continue"',
'$app=$null',
'foreach($p in @((Join-Path $env:ProgramFiles "WireGuard\wireguard.exe"),(Join-Path ${env:ProgramFiles(x86)} "WireGuard\wireguard.exe"))){ if($p -and (Test-Path -LiteralPath $p)){ $app=$p; break } }',
'if(-not $app){ throw "wireguard.exe not found. Install WireGuard first." }',
'$conf="E:\0mcp-agv-arena-optimized\wireguard\arena-phone-server.conf"',
'if(-not (Test-Path -LiteralPath $conf)){ throw "server config missing. Run generate-wireguard-configs-local.ps1 first." }',
'& $app /installtunnelservice $conf',
'netsh advfirewall firewall add rule name="Arena Phone Share 18089 over WireGuard" dir=in action=allow protocol=TCP localport=18089 profile=any'
)
W $removeScript @(
'$ErrorActionPreference="Continue"',
'$app=$null',
'foreach($p in @((Join-Path $env:ProgramFiles "WireGuard\wireguard.exe"),(Join-Path ${env:ProgramFiles(x86)} "WireGuard\wireguard.exe"))){ if($p -and (Test-Path -LiteralPath $p)){ $app=$p; break } }',
'if($app){ & $app /uninstalltunnelservice arena-phone-server }'
)

$wgConfigsGenerated=$false; $wgGenerateOut=''
if($wgExe){
  $gs=$genScript; $ep=if($pubIp){$pubIp}else{'REPLACE_WITH_PUBLIC_IP_OR_DDNS'}
  $wgGenerateOut=Run-Cap { powershell.exe -NoProfile -ExecutionPolicy Bypass -File $using:gs -EndpointHost $using:ep 2>&1|Out-String } 60
  $wgConfigsGenerated=(Test-Path -LiteralPath $serverConf) -and (Test-Path -LiteralPath $phoneConf)
  L ('wireguard_generate_configs='+(San (($wgGenerateOut -split "`r?`n"|Select-Object -First 8)-join ' | ')))
}
L ('wireguard_configs_generated='+$wgConfigsGenerated)
L ('wireguard_server_conf_local_only='+(Test-Path -LiteralPath $serverConf))
L ('wireguard_phone_conf_local_only='+(Test-Path -LiteralPath $phoneConf))

# Guides. Do not include secrets.
$guide=Join-Path $outDir 'zerotier-wireguard-phone-guide-r233.md'
$lanUrlText=(($lanRows|ForEach-Object{$_.url}) -join ' , ')
$ztIpText=(($ztIps|ForEach-Object{$_.IPAddress}) -join ' , ')
W $guide @(
'# ZeroTier and WireGuard phone guide r233',
'',
'File share root on PC:',
('`'+$shareRoot+'`'),
'',
'Immediate free same-WiFi URLs:',
$lanUrlText,
'',
'ZeroTier desktop status:',
('CLI: '+$ztCli),
('Node ID: '+$ztNodeId),
('ZeroTier IPs: '+$ztIpText),
('Join script: '+$ztJoinScript),
'',
'ZeroTier phone steps:',
'1. Install ZeroTier One on the phone.',
'2. Create or use a free ZeroTier network ID in ZeroTier Central.',
('3. On PC run: powershell -NoProfile -ExecutionPolicy Bypass -File "'+$ztJoinScript+'" YOUR_NETWORK_ID'),
'4. On phone join the same network ID.',
'5. In ZeroTier Central authorize both PC and phone.',
'6. Find the PC ZeroTier IP, then open http://PC_ZEROTIER_IP:18089/ on the phone.',
'',
'WireGuard desktop status:',
('wg.exe: '+$wgExe),
('wireguard.exe: '+$wgApp),
('Configs generated locally: '+$wgConfigsGenerated),
('Config generator: '+$genScript),
('Install tunnel script: '+$installScript),
'',
'WireGuard phone steps:',
'1. Install WireGuard on PC and phone if not already installed.',
'2. If the phone will connect from outside home, forward UDP 51820 on the router to this PC, or use a public VPS/DDNS endpoint.',
('3. On PC run: powershell -NoProfile -ExecutionPolicy Bypass -File "'+$genScript+'" -EndpointHost YOUR_PUBLIC_IP_OR_DDNS'),
'4. Run PowerShell as Administrator and execute the install tunnel script shown above.',
('5. Import local-only phone config from: '+$phoneConf),
'6. Turn on the tunnel on the phone and open http://10.66.66.1:18089/ .',
'',
'Do not upload WireGuard .conf files; they contain private keys.'
)
$summaryJson=Join-Path $reports 'zerotier-wireguard-desktop-r233.json'
$summary=[pscustomobject]@{
  isAdmin=$isAdmin; shareRoot=$shareRoot; sharePort=$sharePort; lan=$lanRows;
  zeroTier=[pscustomobject]@{installAttempted=$ztInstallAttempted;cli=$ztCli;info=$ztInfo;nodeId=$ztNodeId;networks=$ztNetworks;ips=$ztIps;joinScript=$ztJoinScript};
  wireGuard=[pscustomobject]@{installAttempted=$wgInstallAttempted;wgExe=$wgExe;wgApp=$wgApp;publicIp=$pubIp;configsGenerated=$wgConfigsGenerated;genScript=$genScript;installScript=$installScript;removeScript=$removeScript;serverConfExists=(Test-Path -LiteralPath $serverConf);phoneConfExists=(Test-Path -LiteralPath $phoneConf)};
  guide=$guide
}
[IO.File]::WriteAllText($summaryJson,($summary|ConvertTo-Json -Depth 8)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $summaryJson -Destination (Join-Path $outDir 'zerotier-wireguard-desktop-r233.json') -Force }catch{}
$statusZt=if($ztCli){'ZEROTIER_DESKTOP_READY'}elseif($ztInstallAttempted){'ZEROTIER_INSTALL_ATTEMPTED_NEEDS_ADMIN_OR_RETRY'}else{'ZEROTIER_NOT_INSTALLED'}
$statusWg=if($wgConfigsGenerated){'WIREGUARD_CONFIGS_READY_LOCAL_ONLY'}elseif($wgExe -or $wgApp){'WIREGUARD_INSTALLED_CONFIGS_NOT_READY'}elseif($wgInstallAttempted){'WIREGUARD_INSTALL_ATTEMPTED_NEEDS_ADMIN_OR_RETRY'}else{'WIREGUARD_NOT_INSTALLED'}
$statusShare=if(($lanRows|Where-Object{$_.ok}).Count -gt 0){'FILE_SHARE_OK'}else{'FILE_SHARE_NOT_PROVEN'}
L ('status_zerotier='+$statusZt)
L ('status_wireguard='+$statusWg)
L ('status_share='+$statusShare)
L ('FINAL_R233: '+$statusZt+'_'+$statusWg+'_'+$statusShare)
W $report $script:Lines
exit 0
