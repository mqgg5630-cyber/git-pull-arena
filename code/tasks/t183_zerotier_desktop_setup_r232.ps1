# t183_zerotier_desktop_setup_r232.ps1 - round 232.
# Desktop-side ZeroTier setup for free phone file access. ASCII-only.
# Does not install or touch Antigravity/IDE. Does not require secrets.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function Curl-Text([string]$Url,[int]$Sec){ try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -L --max-time $Sec -sS $Url 2>&1|Out-String).Trim() }catch{ return $_.Exception.Message } }
function Find-ZtCli(){
  $cands=@()
  foreach($p in @(
    (Join-Path $env:ProgramFiles 'ZeroTier\One\zerotier-cli.bat'),
    (Join-Path ${env:ProgramFiles(x86)} 'ZeroTier\One\zerotier-cli.bat'),
    (Join-Path $env:ProgramFiles 'ZeroTier\One\zerotier-cli.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'ZeroTier\One\zerotier-cli.exe')
  )){ if($p -and (Test-Path -LiteralPath $p)){ $cands += $p } }
  foreach($n in @('zerotier-cli.bat','zerotier-cli.exe','zerotier-cli')){ try{ $cmd=Get-Command $n -ErrorAction SilentlyContinue; if($cmd){ $cands += $cmd.Source } }catch{} }
  return @($cands | Sort-Object -Unique | Select-Object -First 1)
}
function ZtRun([string]$Cli,[string[]]$Args,[int]$Sec){ $c=$Cli; $a=$Args; return Run-Cap { & $using:c @using:a 2>&1|Out-String } $Sec }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$ztRoot=Join-Path $lab 'zerotier'
$shareRoot=Join-Path $lab 'phone-share'
foreach($d in @($reports,$ztRoot,$shareRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$report=Join-Path $outDir 'ZEROTIER_DESKTOP_SETUP_R232.md'
L '# R232 ZeroTier desktop setup for free phone file access'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))
L 'no_antigravity_or_ide_actions=True'

# 1. Keep safe folder share active. This is useful for LAN now and ZeroTier later.
$sharePort=18089
[IO.File]::WriteAllText((Join-Path $shareRoot 'index.html'),'<title>Arena Phone Share R232</title><h1>Arena Phone Share R232</h1><p>Only this folder is exposed. Use LAN IP now or ZeroTier IP after both devices join the same network.</p>',(New-Object Text.UTF8Encoding($false)))
$pidFile=Join-Path $shareRoot 'phone_share_python.pid'
if(Test-Path -LiteralPath $pidFile){ try{ Stop-Process -Id ([int](Get-Content -LiteralPath $pidFile -Raw)) -Force -ErrorAction SilentlyContinue }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
$serverPid=''
if($py){ try{ $p=Start-Process -FilePath $py -ArgumentList @('-m','http.server',[string]$sharePort,'--bind','0.0.0.0','--directory',$shareRoot) -PassThru -WindowStyle Hidden; $serverPid=$p.Id; [IO.File]::WriteAllText($pidFile,[string]$p.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('file_share_pid='+$p.Id) }catch{ L ('file_share_start_ERR='+(San $_.Exception.Message)) } } else { L 'python_missing_for_file_share=True' }
$fwShare=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 profile=any 2>&1|Out-String } 30
L ('file_share_firewall='+(San (($fwShare -split "`r?`n"|Select-Object -First 4)-join ' | ')))

# LAN URLs for immediate free same-WiFi access.
$ips=@()
try{ $ips=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.|100\.)' -and $_.IPAddress -ne '0.0.0.0' } | Select-Object -ExpandProperty IPAddress -Unique) }catch{}
$lanRows=@(); foreach($ip in $ips){ $u='http://'+$ip+':'+$sharePort+'/'; $ok=((Curl-Text $u 5) -match 'Arena Phone Share R232'); $lanRows += [pscustomobject]@{url=$u;ok=$ok}; L ('lan_url='+$u+' ok='+$ok) }

# 2. Install/probe ZeroTier One on desktop.
$isAdmin=$false
try{ $isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }catch{}
L ('is_admin='+$isAdmin)
$ztCli=Find-ZtCli
$installAttempted=$false
$installOut=''
if(-not $ztCli){
  $winget=''; try{ $cmd=Get-Command winget.exe -ErrorAction SilentlyContinue; if($cmd){$winget=$cmd.Source} }catch{}
  if($winget){
    $installAttempted=$true
    $wg=$winget
    L ('winget_found='+(San $winget))
    $installOut=Run-Cap { & $using:wg install --id ZeroTier.ZeroTierOne -e --silent --accept-package-agreements --accept-source-agreements 2>&1|Out-String } 420
    L ('winget_install_head='+(San (($installOut -split "`r?`n"|Select-Object -First 12)-join ' | ')))
    Start-Sleep -Seconds 5
    $ztCli=Find-ZtCli
  } else {
    L 'winget_not_found=True'
  }
}
L ('zerotier_cli='+(San $ztCli))

# Start service if present.
$serviceRows=@()
try{ $serviceRows=@(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'ZeroTier|zerotier' -or $_.DisplayName -match 'ZeroTier|zerotier' }) }catch{}
foreach($svc in $serviceRows){
  L ('service_before name='+$svc.Name+' display='+(San $svc.DisplayName)+' status='+$svc.Status)
  try{ if($svc.Status -ne 'Running'){ Start-Service -Name $svc.Name -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3 } }catch{ L ('service_start_ERR name='+$svc.Name+' err='+(San $_.Exception.Message)) }
}
try{ $serviceRows=@(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'ZeroTier|zerotier' -or $_.DisplayName -match 'ZeroTier|zerotier' }) }catch{}
foreach($svc in $serviceRows){ L ('service_after name='+$svc.Name+' display='+(San $svc.DisplayName)+' status='+$svc.Status) }

# Firewall for ZeroTier UDP and the app if installed.
$fwZt=Run-Cap { netsh advfirewall firewall add rule name="ZeroTier One UDP 9993" dir=in action=allow protocol=UDP localport=9993 profile=any 2>&1|Out-String } 30
L ('zerotier_firewall_udp='+(San (($fwZt -split "`r?`n"|Select-Object -First 4)-join ' | ')))

$ztInfo=''; $ztList=''; $ztVersion=''; $nodeId=''; $netRows=@(); $ztIps=@()
if($ztCli){
  $ztVersion=ZtRun $ztCli @('-v') 20
  $ztInfo=ZtRun $ztCli @('info') 25
  $ztList=ZtRun $ztCli @('listnetworks') 25
  L ('zerotier_version='+(San $ztVersion))
  L ('zerotier_info='+(San $ztInfo))
  L ('zerotier_networks_head='+(San (($ztList -split "`r?`n"|Select-Object -First 12)-join ' | ')))
  if($ztInfo -match '([0-9a-fA-F]{10})'){ $nodeId=$Matches[1] }
  foreach($line in ($ztList -split "`r?`n")){
    if($line -match '^200\s+listnetworks\s+([0-9a-fA-F]+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$'){
      $netRows += [pscustomobject]@{id=$Matches[1];name=$Matches[2];mac=$Matches[3];status=$Matches[4];tail=$Matches[5]}
    }
  }
}
try{ $ztIps=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -match 'ZeroTier|zt' -or $_.InterfaceDescription -match 'ZeroTier|zt' } | Select-Object InterfaceAlias,IPAddress,PrefixLength) }catch{}
foreach($z in $ztIps){ L ('zerotier_ip alias='+(San $z.InterfaceAlias)+' ip='+$z.IPAddress+'/'+$z.PrefixLength) }

# Optional join if a network id file already exists.
$networkFile=Join-Path $ztRoot 'network-id.txt'
$joinScript=Join-Path $ztRoot 'join-zerotier-network.ps1'
$joinText=@'
param([Parameter(Mandatory=$true)][string]$NetworkId)
$ErrorActionPreference='Continue'
$cli=$null
foreach($p in @((Join-Path $env:ProgramFiles 'ZeroTier\One\zerotier-cli.bat'),(Join-Path ${env:ProgramFiles(x86)} 'ZeroTier\One\zerotier-cli.bat'),(Join-Path $env:ProgramFiles 'ZeroTier\One\zerotier-cli.exe'),(Join-Path ${env:ProgramFiles(x86)} 'ZeroTier\One\zerotier-cli.exe'))){ if($p -and (Test-Path -LiteralPath $p)){ $cli=$p; break } }
if(-not $cli){ throw 'ZeroTier CLI not found. Install ZeroTier One first.' }
Write-Host "Joining ZeroTier network $NetworkId ..."
& $cli join $NetworkId
Start-Sleep -Seconds 3
& $cli listnetworks
Write-Host 'If status is REQUESTING_CONFIGURATION, authorize this computer in ZeroTier Central.'
'@
[IO.File]::WriteAllText($joinScript,$joinText,(New-Object Text.UTF8Encoding($false)))
$joinAttempted=$false; $joinOut=''; $networkId=''
if(Test-Path -LiteralPath $networkFile){
  $networkId=(Get-Content -LiteralPath $networkFile -Raw -ErrorAction SilentlyContinue).Trim()
  if($networkId -match '^[0-9a-fA-F]{16}$' -and $ztCli){
    $joinAttempted=$true
    $joinOut=ZtRun $ztCli @('join',$networkId) 30
    Start-Sleep -Seconds 3
    $ztList=ZtRun $ztCli @('listnetworks') 25
    L ('join_network_id='+$networkId+' out='+(San $joinOut))
    L ('zerotier_networks_after_join='+(San (($ztList -split "`r?`n"|Select-Object -First 12)-join ' | ')))
  } else { L ('network_id_file_invalid_or_no_cli='+(San $networkId)) }
} else {
  [IO.File]::WriteAllText($networkFile,"PUT_YOUR_16_HEX_ZEROTIER_NETWORK_ID_HERE`r`n",(New-Object Text.UTF8Encoding($false)))
  L ('network_id_file_created='+(San $networkFile))
}

# Build phone guide.
$ztPhoneUrl=''
if($ztIps.Count -gt 0){ $ztPhoneUrl='http://'+$ztIps[0].IPAddress+':'+$sharePort+'/' }
$phoneGuide=Join-Path $outDir 'zerotier-phone-access-guide-r232.md'
$guideLines=@(
'# ZeroTier phone file access guide r232',
'',
'Free desktop-side status is prepared as far as possible without a network ID.',
'',
('Share root: '+$shareRoot),
('LAN URLs now: '+(($lanRows|ForEach-Object{$_.url}) -join ' , ')),
('ZeroTier node ID: '+$nodeId),
('ZeroTier phone URL after join: '+$ztPhoneUrl),
'',
'If no ZeroTier network is joined yet:',
'1. Create a free ZeroTier network in ZeroTier Central and copy the 16-character network ID.',
('2. On this PC run: powershell -NoProfile -ExecutionPolicy Bypass -File "'+$joinScript+'" YOUR_NETWORK_ID'),
'3. Authorize this PC in ZeroTier Central if the network is private.',
'4. On the phone install ZeroTier One, join the same network ID, and authorize the phone.',
'5. Then open http://PC_ZEROTIER_IP:18089/ in the phone browser.',
'',
'Immediate no-VPN free option: keep phone and PC on the same Wi-Fi and open one of the LAN URLs above.'
)
W $phoneGuide $guideLines

$summaryJson=Join-Path $reports 'zerotier-desktop-setup-r232.json'
$summary=[pscustomobject]@{
  isAdmin=$isAdmin; installAttempted=$installAttempted; installOut=$installOut;
  cli=$ztCli; version=$ztVersion; info=$ztInfo; nodeId=$nodeId; listnetworks=$ztList;
  services=$serviceRows; zerotierIps=$ztIps; lan=$lanRows;
  shareRoot=$shareRoot; sharePort=$sharePort; serverPid=$serverPid;
  networkFile=$networkFile; joinScript=$joinScript; joinAttempted=$joinAttempted; joinOut=$joinOut;
  phoneGuide=$phoneGuide
}
[IO.File]::WriteAllText($summaryJson,($summary|ConvertTo-Json -Depth 8)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $summaryJson -Destination (Join-Path $outDir 'zerotier-desktop-setup-r232.json') -Force }catch{}
$statusZt=if($ztCli){'ZEROTIER_DESKTOP_READY_NEEDS_NETWORK_JOIN_OR_AUTH'}elseif($installAttempted){'ZEROTIER_INSTALL_ATTEMPTED_CLI_NOT_FOUND'}else{'ZEROTIER_NOT_INSTALLED_NEEDS_ADMIN_OR_MANUAL_INSTALL'}
$statusShare=if(($lanRows|Where-Object{$_.ok}).Count -gt 0){'FILE_SHARE_LAN_OK'}else{'FILE_SHARE_LAN_NOT_PROVEN'}
L ('status_zerotier='+$statusZt)
L ('status_share='+$statusShare)
L ('FINAL_R232: '+$statusZt+'_'+$statusShare)
W $report $script:Lines
exit 0
