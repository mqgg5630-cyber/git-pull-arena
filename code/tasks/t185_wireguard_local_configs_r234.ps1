# t185_wireguard_local_configs_r234.ps1 - round 234.
# Build local-only WireGuard configs for phone file access and prepare admin
# install/start scripts. Does not print or commit private keys. ASCII-only.

$ErrorActionPreference='Continue'
function San([string]$s){ if($null -eq $s){return ''}; try{$s=$s -replace '[A-Za-z0-9+/_=-]{24,}','[REDACTED]'}catch{}; try{$s=$s -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}','[REDACTED-GUID]'}catch{}; try{$s=$s -replace '[^\x20-\x7E]','?'}catch{}; return $s }
function L([string]$m){ Write-Output $m; $script:Lines += $m }
function W([string]$p,[string[]]$lines){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p)|Out-Null; [IO.File]::WriteAllText($p,($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding($false))) }
function Run-Cap([scriptblock]$Block,[int]$TimeoutSec){ $job=Start-Job -ScriptBlock $Block; if(-not(Wait-Job $job -Timeout $TimeoutSec)){ Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; return 'TIMEOUT' }; $txt=(Receive-Job $job|Out-String).Trim(); Remove-Job $job -Force -ErrorAction SilentlyContinue; return $txt }
function Curl-Text([string]$Url,[int]$Sec){ try{ $ce=Join-Path $env:SystemRoot 'System32\curl.exe'; return (& $ce -L --max-time $Sec -sS $Url 2>&1|Out-String).Trim() }catch{ return $_.Exception.Message } }
function FInfo([string]$p){ if(Test-Path -LiteralPath $p){ $f=Get-Item -LiteralPath $p; return [pscustomobject]@{exists=$true;path=$p;bytes=$f.Length;mtime=$f.LastWriteTime.ToString('s')} }; return [pscustomobject]@{exists=$false;path=$p;bytes=0;mtime=''} }
function Find-WgExe(){ foreach($p in @((Join-Path $env:ProgramFiles 'WireGuard\wg.exe'),(Join-Path ${env:ProgramFiles(x86)} 'WireGuard\wg.exe'))){ if($p -and(Test-Path -LiteralPath $p)){return $p} }; try{ $cmd=Get-Command wg.exe -ErrorAction SilentlyContinue; if($cmd){return $cmd.Source} }catch{}; return '' }
function Find-WgApp(){ foreach($p in @((Join-Path $env:ProgramFiles 'WireGuard\wireguard.exe'),(Join-Path ${env:ProgramFiles(x86)} 'WireGuard\wireguard.exe'))){ if($p -and(Test-Path -LiteralPath $p)){return $p} }; try{ $cmd=Get-Command wireguard.exe -ErrorAction SilentlyContinue; if($cmd){return $cmd.Source} }catch{}; return '' }

$script:Lines=@()
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$outDir=Join-Path $repo 'results\mcp_agv_lab'
New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$lab='E:\0mcp-agv-arena-optimized'
$reports=Join-Path $lab 'reports'
$shareRoot=Join-Path $lab 'phone-share'
$wgRoot=Join-Path $lab 'wireguard'
foreach($d in @($reports,$shareRoot,$wgRoot)){ New-Item -ItemType Directory -Force -Path $d|Out-Null }
$report=Join-Path $outDir 'WIREGUARD_LOCAL_CONFIGS_R234.md'
L '# R234 self-hosted WireGuard local config prep'
L ('time='+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
L ('computer='+$env:COMPUTERNAME+' user='+(San $env:USERNAME))
L 'no_antigravity_or_ide_actions=True'
$isAdmin=$false; try{ $isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }catch{}
L ('is_admin='+$isAdmin)

# Keep file share live.
$sharePort=18089
[IO.File]::WriteAllText((Join-Path $shareRoot 'index.html'),'<title>Arena WireGuard Share R234</title><h1>Arena WireGuard Share R234</h1><p>Open via LAN, ZeroTier, or WireGuard http://10.66.66.1:18089/ after tunnel is up.</p>',(New-Object Text.UTF8Encoding($false)))
$pidFile=Join-Path $shareRoot 'phone_share_python.pid'
if(Test-Path -LiteralPath $pidFile){ try{ Stop-Process -Id ([int](Get-Content -LiteralPath $pidFile -Raw)) -Force -ErrorAction SilentlyContinue }catch{} }
$py=''; try{ $cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){$py=$cmd.Source} }catch{}
$serverPid=''
if($py){ try{ $p=Start-Process -FilePath $py -ArgumentList @('-m','http.server',[string]$sharePort,'--bind','0.0.0.0','--directory',$shareRoot) -PassThru -WindowStyle Hidden; $serverPid=$p.Id; [IO.File]::WriteAllText($pidFile,[string]$p.Id,(New-Object Text.UTF8Encoding($false))); Start-Sleep -Seconds 3; L ('file_share_pid='+$p.Id) }catch{ L ('file_share_start_ERR='+(San $_.Exception.Message)) } }
$fw1=Run-Cap { netsh advfirewall firewall add rule name="Arena Phone Share 18089" dir=in action=allow protocol=TCP localport=18089 profile=any 2>&1|Out-String } 30
$fw2=Run-Cap { netsh advfirewall firewall add rule name="WireGuard UDP 51820" dir=in action=allow protocol=UDP localport=51820 profile=any 2>&1|Out-String } 30
L ('firewall_share='+(San (($fw1 -split "`r?`n"|Select-Object -First 3)-join ' | ')))
L ('firewall_wg='+(San (($fw2 -split "`r?`n"|Select-Object -First 3)-join ' | ')))

# LAN URLs.
$ips=@(); try{ $ips=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.|100\.)' -and $_.IPAddress -ne '0.0.0.0' } | Select-Object -ExpandProperty IPAddress -Unique) }catch{}
$lanRows=@(); foreach($ip in $ips){ $u='http://'+$ip+':'+$sharePort+'/'; $ok=((Curl-Text $u 5) -match 'Arena WireGuard Share R234'); $lanRows += [pscustomobject]@{url=$u;ok=$ok}; L ('lan_url='+$u+' ok='+$ok) }
$preferredLan=''; foreach($r in $lanRows){ if($r.ok -and $r.url -match '192\.168\.|10\.'){ $preferredLan=($r.url -replace '^http://','' -replace ':18089/$',''); break } }
if(-not $preferredLan -and $lanRows.Count -gt 0){ $preferredLan=($lanRows[0].url -replace '^http://','' -replace ':18089/$','') }
$publicIp=Curl-Text 'https://api.ipify.org' 10; if($publicIp -notmatch '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'){ $publicIp='' }
$endpoint=if($publicIp){$publicIp}else{$preferredLan}
L ('preferred_lan_endpoint='+$preferredLan)
L ('public_ip_probe='+(San $publicIp))
L ('default_wireguard_endpoint='+$endpoint)

# Generate WireGuard-compatible keys/configs locally using pure Python X25519.
$keygen=Join-Path $wgRoot 'generate-wireguard-configs-local.py'
$serverConf=Join-Path $wgRoot 'arena-phone-server.conf'
$phoneConf=Join-Path $wgRoot 'arena-phone-client.conf'
$keygenCode=@'
import os, base64, argparse, pathlib, stat
P = 2**255 - 19
A24 = 121665
BASE = bytes([9]) + bytes(31)
def clamp(k):
    k = bytearray(k)
    k[0] &= 248
    k[31] &= 127
    k[31] |= 64
    return bytes(k)
def x25519(k, u=BASE):
    k = clamp(k)
    x1 = int.from_bytes(u, 'little')
    x2, z2 = 1, 0
    x3, z3 = x1, 1
    swap = 0
    scalar = int.from_bytes(k, 'little')
    for t in range(254, -1, -1):
        kt = (scalar >> t) & 1
        swap ^= kt
        if swap:
            x2, x3 = x3, x2
            z2, z3 = z3, z2
        swap = kt
        A = (x2 + z2) % P
        AA = (A * A) % P
        B = (x2 - z2) % P
        BB = (B * B) % P
        E = (AA - BB) % P
        C = (x3 + z3) % P
        D = (x3 - z3) % P
        DA = (D * A) % P
        CB = (C * B) % P
        x3 = ((DA + CB) * (DA + CB)) % P
        z3 = (x1 * ((DA - CB) * (DA - CB) % P)) % P
        x2 = (AA * BB) % P
        z2 = (E * ((AA + A24 * E) % P)) % P
    if swap:
        x2, x3 = x3, x2
        z2, z3 = z3, z2
    return (x2 * pow(z2, P-2, P) % P).to_bytes(32, 'little')
def b64(b): return base64.b64encode(b).decode('ascii')
def pair():
    priv = clamp(os.urandom(32))
    pub = x25519(priv)
    return b64(priv), b64(pub)
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', required=True)
    ap.add_argument('--endpoint', required=True)
    ap.add_argument('--port', type=int, default=51820)
    args = ap.parse_args()
    root = pathlib.Path(args.root)
    root.mkdir(parents=True, exist_ok=True)
    s_priv, s_pub = pair()
    p_priv, p_pub = pair()
    server = f"""[Interface]\nPrivateKey = {s_priv}\nAddress = 10.66.66.1/24\nListenPort = {args.port}\n\n[Peer]\n# phone\nPublicKey = {p_pub}\nAllowedIPs = 10.66.66.2/32\n"""
    phone = f"""[Interface]\nPrivateKey = {p_priv}\nAddress = 10.66.66.2/32\nDNS = 1.1.1.1\n\n[Peer]\nPublicKey = {s_pub}\nEndpoint = {args.endpoint}:{args.port}\nAllowedIPs = 10.66.66.1/32\nPersistentKeepalive = 25\n"""
    server_path = root / 'arena-phone-server.conf'
    phone_path = root / 'arena-phone-client.conf'
    server_path.write_text(server, encoding='ascii')
    phone_path.write_text(phone, encoding='ascii')
    try:
        os.chmod(server_path, stat.S_IREAD | stat.S_IWRITE)
        os.chmod(phone_path, stat.S_IREAD | stat.S_IWRITE)
    except Exception:
        pass
    print('wrote_server=' + str(server_path))
    print('wrote_phone=' + str(phone_path))
    print('endpoint=' + args.endpoint + ':' + str(args.port))
if __name__ == '__main__': main()
'@
[IO.File]::WriteAllText($keygen,$keygenCode,(New-Object Text.UTF8Encoding($false)))
$keygenOut=''
if($py -and $endpoint){ $kg=$keygen; $rt=$wgRoot; $ep=$endpoint; $keygenOut=Run-Cap { & $using:py $using:kg --root $using:rt --endpoint $using:ep --port 51820 2>&1|Out-String } 60 }
L ('keygen_out='+(San (($keygenOut -split "`r?`n"|Select-Object -First 8)-join ' | ')))
$serverInfo=FInfo $serverConf; $phoneInfo=FInfo $phoneConf
$configsReady=$serverInfo.exists -and $phoneInfo.exists -and ($serverInfo.bytes -gt 100) -and ($phoneInfo.bytes -gt 100)
L ('wireguard_configs_ready='+$configsReady+' server_bytes='+$serverInfo.bytes+' phone_bytes='+$phoneInfo.bytes)

# Probe WireGuard installation and prepare admin scripts.
$wgExe=Find-WgExe; $wgApp=Find-WgApp
if(-not $wgExe -or -not $wgApp){
    $winget=''; try{ $cmd=Get-Command winget.exe -ErrorAction SilentlyContinue; if($cmd){$winget=$cmd.Source} }catch{}
    if($winget){ $wgcmd=$winget; $inst=Run-Cap { & $using:wgcmd install --id WireGuard.WireGuard -e --silent --accept-package-agreements --accept-source-agreements 2>&1|Out-String } 240; L ('wireguard_install_attempt_head='+(San (($inst -split "`r?`n"|Select-Object -First 10)-join ' | '))); Start-Sleep -Seconds 3; $wgExe=Find-WgExe; $wgApp=Find-WgApp }
}
L ('wireguard_wg_exe='+(San $wgExe))
L ('wireguard_app='+(San $wgApp))
$adminInstall=Join-Path $wgRoot 'ADMIN_1_install_wireguard.ps1'
$adminStart=Join-Path $wgRoot 'ADMIN_2_install_tunnel.ps1'
$adminStop=Join-Path $wgRoot 'ADMIN_3_remove_tunnel.ps1'
W $adminInstall @(
'$ErrorActionPreference="Continue"',
'winget install --id WireGuard.WireGuard -e --accept-package-agreements --accept-source-agreements',
'Write-Host "After install, run ADMIN_2_install_tunnel.ps1 as Administrator."'
)
W $adminStart @(
'$ErrorActionPreference="Continue"',
'$app=$null',
'foreach($p in @((Join-Path $env:ProgramFiles "WireGuard\wireguard.exe"),(Join-Path ${env:ProgramFiles(x86)} "WireGuard\wireguard.exe"))){ if($p -and (Test-Path -LiteralPath $p)){ $app=$p; break } }',
'if(-not $app){ throw "wireguard.exe not found. Run ADMIN_1_install_wireguard.ps1 first." }',
'$conf="E:\0mcp-agv-arena-optimized\wireguard\arena-phone-server.conf"',
'if(-not (Test-Path -LiteralPath $conf)){ throw "server config missing. Run generate script first." }',
'& $app /installtunnelservice $conf',
'netsh advfirewall firewall add rule name="Arena Phone Share 18089 over WireGuard" dir=in action=allow protocol=TCP localport=18089 profile=any',
'netsh advfirewall firewall add rule name="WireGuard UDP 51820" dir=in action=allow protocol=UDP localport=51820 profile=any',
'Write-Host "WireGuard tunnel requested. Phone URL after tunnel: http://10.66.66.1:18089/"'
)
W $adminStop @(
'$ErrorActionPreference="Continue"',
'$app=$null',
'foreach($p in @((Join-Path $env:ProgramFiles "WireGuard\wireguard.exe"),(Join-Path ${env:ProgramFiles(x86)} "WireGuard\wireguard.exe"))){ if($p -and (Test-Path -LiteralPath $p)){ $app=$p; break } }',
'if($app){ & $app /uninstalltunnelservice arena-phone-server }'
)

# Try installing tunnel only if admin and WireGuard is installed.
$tunnelAttempt='skipped'; $tunnelOut=''
if($isAdmin -and $wgApp -and $configsReady){ $app=$wgApp; $conf=$serverConf; $tunnelAttempt='attempted'; $tunnelOut=Run-Cap { & $using:app /installtunnelservice $using:conf 2>&1|Out-String } 60; L ('tunnel_install_out='+(San (($tunnelOut -split "`r?`n"|Select-Object -First 10)-join ' | '))) }
L ('tunnel_install_attempt='+$tunnelAttempt)

# Write phone guide.
$guide=Join-Path $outDir 'wireguard-phone-guide-r234.md'
W $guide @(
'# WireGuard phone guide r234',
'',
'PC share root:',
('`'+$shareRoot+'`'),
'',
'Already generated local-only config files on PC:',
('Server config: '+$serverConf),
('Phone config: '+$phoneConf),
'',
'Do not upload or paste the .conf files; they contain private keys.',
'',
'PC admin steps:',
('1. Run PowerShell as Administrator.'),
('2. If WireGuard is not installed: powershell -NoProfile -ExecutionPolicy Bypass -File "'+$adminInstall+'"'),
('3. Start PC tunnel: powershell -NoProfile -ExecutionPolicy Bypass -File "'+$adminStart+'"'),
'',
'Phone steps:',
'1. Install WireGuard from the app store.',
('2. Import the file from the PC: '+$phoneConf),
'3. Turn on the tunnel.',
'4. Open this in phone browser: http://10.66.66.1:18089/',
'',
'If testing only on same Wi-Fi, the generated endpoint can be the PC LAN IP. If using from mobile data/outside home, set Endpoint to a public IP/DDNS and forward UDP 51820 on the router to the PC.',
'',
'Current immediate same-WiFi URLs:',
(($lanRows|ForEach-Object{$_.url}) -join ' , ')
)
$summaryJson=Join-Path $reports 'wireguard-local-configs-r234.json'
$summary=[pscustomobject]@{isAdmin=$isAdmin;shareRoot=$shareRoot;sharePort=$sharePort;lan=$lanRows;preferredLan=$preferredLan;publicIp=$publicIp;endpoint=$endpoint;serverConf=$serverInfo;phoneConf=$phoneInfo;configsReady=$configsReady;wgExe=$wgExe;wgApp=$wgApp;adminInstall=$adminInstall;adminStart=$adminStart;adminStop=$adminStop;tunnelAttempt=$tunnelAttempt;tunnelOut=$tunnelOut;guide=$guide}
[IO.File]::WriteAllText($summaryJson,($summary|ConvertTo-Json -Depth 8)+"`r`n",(New-Object Text.UTF8Encoding($false)))
try{ Copy-Item -LiteralPath $summaryJson -Destination (Join-Path $outDir 'wireguard-local-configs-r234.json') -Force }catch{}
$statusCfg=if($configsReady){'WIREGUARD_CONFIGS_READY_LOCAL_ONLY'}else{'WIREGUARD_CONFIGS_NOT_READY'}
$statusInstall=if($isAdmin -and $wgApp){'WIREGUARD_INSTALLED_ADMIN_AVAILABLE'}elseif($wgApp){'WIREGUARD_INSTALLED_NEEDS_ADMIN_TO_START_TUNNEL'}else{'WIREGUARD_APP_NOT_INSTALLED_NEEDS_ADMIN_INSTALL'}
$statusShare=if(($lanRows|Where-Object{$_.ok}).Count -gt 0){'FILE_SHARE_OK'}else{'FILE_SHARE_NOT_PROVEN'}
L ('status_configs='+$statusCfg)
L ('status_install='+$statusInstall)
L ('status_share='+$statusShare)
L ('FINAL_R234: '+$statusCfg+'_'+$statusInstall+'_'+$statusShare)
W $report $script:Lines
exit 0
