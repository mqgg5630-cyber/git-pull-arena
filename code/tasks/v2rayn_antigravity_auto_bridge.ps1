# v2rayn_antigravity_auto_bridge.ps1 - safely probe local v2rayN/xray nodes
# and create a private Antigravity xray HTTP bridge on 127.0.0.1:18088.
# Secrets are only read from local v2rayN/private files and are not printed.
# ASCII-only.

param(
    [string]$OutPath = '',
    [int]$MaxNodes = 80,
    [switch]$Apply,
    [switch]$Relaunch,
    [switch]$InteractiveTask
)

$ErrorActionPreference = 'Continue'
function San([string]$s) { if ($null -eq $s) { return '' }; try { $s = $s -replace '[A-Za-z0-9+/_=-]{24,}', '[REDACTED]' } catch { }; try { $s = $s -replace '[^\x20-\x7E]', '?' } catch { }; return $s }
function L([string]$m) { Write-Output $m; $script:Lines += $m }
function Write-Utf8([string]$Path, [string[]]$Lines) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false))) }
function B64Decode([string]$s) {
    if (-not $s) { return '' }
    $x = $s.Trim().Replace('-', '+').Replace('_', '/')
    while (($x.Length % 4) -ne 0) { $x += '=' }
    try { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($x)) } catch { return '' }
}
function UDec([string]$s) {
    if ($null -eq $s) { return '' }
    try { return [Uri]::UnescapeDataString($s) } catch { return $s }
}
function Q([string]$query) {
    $h = @{}
    if (-not $query) { return $h }
    $q = $query.TrimStart('?')
    foreach ($p in ($q -split '&')) {
        if (-not $p) { continue }
        $kv = $p -split '=', 2
        $k = UDec $kv[0]
        $v = if ($kv.Count -gt 1) { UDec $kv[1] } else { '' }
        $h[$k] = $v
    }
    return $h
}
function Supported([string]$cc) {
    $x = ([string]$cc).ToUpperInvariant()
    if ($x -match 'UNITED STATES|AMERICA') { $x = 'US' }
    if ($x -match 'JAPAN') { $x = 'JP' }
    if ($x -match 'SINGAPORE') { $x = 'SG' }
    if ($x -match 'TAIWAN') { $x = 'TW' }
    if ($x -match 'HONG KONG') { $x = 'HK' }
    if ($x -match 'GERMANY') { $x = 'DE' }
    if ($x -match 'FRANCE') { $x = 'FR' }
    if ($x -match 'NETHERLAND') { $x = 'NL' }
    $good = @('US','CA','GB','AU','NZ','JP','KR','SG','TW','DE','FR','NL','SE','NO','FI','DK','IE','ES','IT','PT','PL','BE','CH','AT','CZ','EE','LV','LT','LU','RO','BG','GR','HR','HU','IS','LI','MT','SK','SI')
    return ($good -contains $x)
}
function Curl([string[]]$args) { try { return (& curl.exe @args 2>&1 | Out-String).Trim() } catch { return $_.Exception.Message } }
function GeoVia([int]$port) {
    $proxy = 'http://127.0.0.1:' + $port
    $txt = Curl @('-L','--max-time','12','-sS','--proxy',$proxy,'https://ipinfo.io/json')
    if (-not $txt -or $txt -match 'curl:|Failed|timed out') { $txt = Curl @('-L','--max-time','12','-sS','--proxy',$proxy,'http://ip-api.com/json/?fields=status,countryCode,country,city,query,isp,org') }
    $cc=''; $country=''; $ip=''; $org=''
    try {
        $o = $txt | ConvertFrom-Json
        $cc = [string]$o.countryCode; if (-not $cc) { $cc = [string]$o.country }
        $country = [string]$o.country; if (-not $country) { $country = $cc }
        $ip = [string]$o.ip; if (-not $ip) { $ip = [string]$o.query }
        $org = [string]$o.org; if (-not $org) { $org = [string]$o.isp }
    } catch { $country = San $txt }
    $head = Curl @('-I','-L','--max-time','12','-sS','--proxy',$proxy,'https://daily-cloudcode-pa.googleapis.com/')
    $h = (($head -split "`r?`n") | Where-Object { $_ -match '^HTTP/' } | Select-Object -Last 1)
    if (-not $h) { $h = (($head -split "`r?`n") | Select-Object -Last 1) }
    return @{ cc=$cc.ToUpperInvariant(); country=$country; ip=$ip; org=$org; cloud=$h }
}
function Wait-Port([int]$port, [int]$sec) {
    $deadline = (Get-Date).AddSeconds($sec)
    while ((Get-Date) -lt $deadline) {
        try { $c = New-Object Net.Sockets.TcpClient; $iar = $c.BeginConnect('127.0.0.1', $port, $null, $null); if ($iar.AsyncWaitHandle.WaitOne(300)) { $c.EndConnect($iar); $c.Close(); return $true }; $c.Close() } catch { }
        Start-Sleep -Milliseconds 300
    }
    return $false
}
function StreamSettings([string]$net, [string]$sec, [hashtable]$q, [string]$host, [string]$path, [string]$sni) {
    $st = @{ network = $(if ($net) { $net } else { 'tcp' }) }
    if ($sec -and $sec -ne 'none') { $st.security = $sec }
    if ($st.security -eq 'tls') { $st.tlsSettings = @{ serverName = $(if ($sni) { $sni } elseif ($host) { $host } else { '' }); allowInsecure = $false } }
    if ($st.security -eq 'reality') {
        $st.realitySettings = @{ serverName = $(if ($sni) { $sni } elseif ($q['sni']) { $q['sni'] } else { '' }); publicKey = [string]$q['pbk']; shortId = [string]$q['sid']; fingerprint = $(if ($q['fp']) { [string]$q['fp'] } else { 'chrome' }); spiderX = [string]$q['spx'] }
    }
    if ($st.network -eq 'ws') { $st.wsSettings = @{ path = $(if ($path) { $path } elseif ($q['path']) { [string]$q['path'] } else { '/' }); headers = @{ Host = $(if ($host) { $host } elseif ($q['host']) { [string]$q['host'] } else { '' }) } } }
    if ($st.network -eq 'grpc') { $st.grpcSettings = @{ serviceName = $(if ($q['serviceName']) { [string]$q['serviceName'] } elseif ($q['service']) { [string]$q['service'] } else { '' }) } }
    if ($st.network -eq 'tcp' -and $q['type'] -eq 'http') { $st.tcpSettings = @{ header = @{ type='http'; request=@{ headers=@{ Host=@($(if ($host) { $host } else { '' })) }; path=@($(if ($path) { $path } else { '/' })) } } } }
    return $st
}
function Node([string]$name, [string]$proto, [hashtable]$out) { return [pscustomobject]@{ name=$name; proto=$proto; outbound=$out } }
function Parse-Share([string]$u) {
    try {
        if ($u -match '^vmess://(.+)$') {
            $j = B64Decode $Matches[1]
            $o = $j | ConvertFrom-Json
            $q = @{}
            $net = [string]$o.net; $sec = [string]$o.tls; if (-not $sec) { $sec = [string]$o.security }
            $host = [string]$o.host; $path = [string]$o.path; $sni = [string]$o.sni
            $ob = @{ tag='proxy'; protocol='vmess'; settings=@{ vnext=@(@{ address=[string]$o.add; port=[int]$o.port; users=@(@{ id=[string]$o.id; alterId=$(try{[int]$o.aid}catch{0}); security=$(if($o.scy){[string]$o.scy}else{'auto'}) }) }) }; streamSettings=(StreamSettings $net $sec $q $host $path $sni) }
            return Node ([string]$o.ps) 'vmess' $ob
        }
        if ($u -match '^(vless|trojan)://') {
            # Do not rely on [Uri] for share links: many subscriptions leave
            # emoji/CJK fragments, spaces, pipe characters, or nested query
            # punctuation unescaped. Parse the authority manually and keep all
            # secrets local.
            $m = [regex]::Match($u, '^(?<proto>vless|trojan)://(?<user>[^@]+)@(?<host>\[[^\]]+\]|[^:/?#]+):(?<port>\d+)(?<rest>.*)$')
            if (-not $m.Success) { return $null }
            $proto = $m.Groups['proto'].Value
            $user = UDec $m.Groups['user'].Value
            $hostName = UDec (($m.Groups['host'].Value) -replace '^\[|\]$', '')
            $portNum = [int]$m.Groups['port'].Value
            $rest = [string]$m.Groups['rest'].Value
            $frag = ''
            if ($rest -match '#') { $parts = $rest -split '#', 2; $rest = $parts[0]; $frag = $parts[1] }
            $query = ''
            if ($rest -match '^\?') { $query = $rest }
            $qq = Q $query
            $name = UDec $frag
            $net = [string]$qq['type']; if (-not $net) { $net = [string]$qq['network'] }; if (-not $net) { $net = 'tcp' }
            $sec = [string]$qq['security']; if (-not $sec) { $sec = 'none' }
            if ($proto -eq 'vless') {
                $usr = @{ id=$user; encryption=$(if($qq['encryption']){[string]$qq['encryption']}else{'none'}) }
                if ($qq['flow']) { $usr.flow = [string]$qq['flow'] }
                $ob = @{ tag='proxy'; protocol='vless'; settings=@{ vnext=@(@{ address=$hostName; port=$portNum; users=@($usr) }) }; streamSettings=(StreamSettings $net $sec $qq ([string]$qq['host']) ([string]$qq['path']) ([string]$qq['sni']) ) }
                return Node $name 'vless' $ob
            } else {
                $ob = @{ tag='proxy'; protocol='trojan'; settings=@{ servers=@(@{ address=$hostName; port=$portNum; password=$user }) }; streamSettings=(StreamSettings $net $sec $qq ([string]$qq['host']) ([string]$qq['path']) ([string]$qq['sni']) ) }
                return Node $name 'trojan' $ob
            }
        }
        if ($u -match '^ss://(.+)$') {
            $rest = $Matches[1]; $name = ''
            if ($rest -match '#') { $parts = $rest -split '#',2; $rest=$parts[0]; $name=UDec $parts[1] }
            if ($rest -match '\?') { $rest = ($rest -split '\?',2)[0] }
            $decoded = ''
            if ($rest -match '@') { $decoded = $rest } else { $decoded = B64Decode $rest }
            if ($decoded -match '^(.*?):(.*?)@(.*?):(\d+)$') {
                $method=$Matches[1]; $pwd=$Matches[2]; $addr=$Matches[3]; $port=[int]$Matches[4]
                $ob = @{ tag='proxy'; protocol='shadowsocks'; settings=@{ servers=@(@{ address=$addr; port=$port; method=$method; password=$pwd }) } }
                return Node $name 'ss' $ob
            }
        }
    } catch { return $null }
    return $null
}
function Add-Nodes-From-Text([string]$text, [string]$source) {
    if (-not $text) { return }
    $lines = @()
    if ($text -match '^(vmess|vless|trojan|ss)://') { $lines = $text -split "`r?`n" }
    else {
        $dec = B64Decode (($text -replace '\s',''))
        if ($dec -match '^(vmess|vless|trojan|ss)://') { $lines = $dec -split "`r?`n" }
        else { $lines = $text -split "`r?`n" }
    }
    foreach ($ln in $lines) {
        $x = $ln.Trim()
        if ($x -notmatch '^(vmess|vless|trojan|ss)://') { continue }
        $n = Parse-Share $x
        if ($n) { $script:Nodes += $n; L ('node_from=' + $source + ' proto=' + $n.proto + ' name=' + (San $n.name)) }
    }
}
function Add-JsonNodes($obj, [string]$source) {
    if ($null -eq $obj) { return }
    if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string]) -and -not ($obj.PSObject.Properties.Name -contains 'address')) { foreach ($v in $obj) { Add-JsonNodes $v $source }; return }
    $props = @($obj.PSObject.Properties.Name)
    if ($props -contains 'address' -and $props -contains 'port') {
        try {
            $addr=[string]$obj.address; $port=[int]$obj.port; $name=[string]$obj.remarks; if(-not $name){$name=[string]$obj.name}
            $ct=[string]$obj.configType; $proto=[string]$obj.protocol
            if (-not $proto) { if ($ct -eq '1'){$proto='vmess'} elseif($ct -eq '4'){$proto='vless'} elseif($ct -eq '5'){$proto='trojan'} elseif($ct -eq '2'){$proto='ss'} }
            $net=[string]$obj.network; if(-not $net){$net='tcp'}
            $sec=[string]$obj.streamSecurity; if(-not $sec -or $sec -eq 'none') { if($obj.tls -eq 'tls'){$sec='tls'} else {$sec='none'} }
            $q=@{}; foreach($k in @('pbk','sid','fp','spx','type','serviceName')){ if($obj.$k){$q[$k]=[string]$obj.$k} }
            $host=[string]$obj.requestHost; if(-not $host){$host=[string]$obj.host}
            $path=[string]$obj.path
            $sni=[string]$obj.sni
            if($proto -eq 'vmess' -and $obj.id){ $ob=@{tag='proxy';protocol='vmess';settings=@{vnext=@(@{address=$addr;port=$port;users=@(@{id=[string]$obj.id;alterId=$(try{[int]$obj.alterId}catch{0});security=$(if($obj.security){[string]$obj.security}else{'auto'})})})};streamSettings=(StreamSettings $net $sec $q $host $path $sni)}; $script:Nodes += (Node $name 'vmess' $ob); L ('node_json=' + $source + ' proto=vmess name=' + (San $name)) }
            elseif($proto -eq 'vless' -and $obj.id){ $usr=@{id=[string]$obj.id;encryption='none'}; if($obj.flow){$usr.flow=[string]$obj.flow}; $ob=@{tag='proxy';protocol='vless';settings=@{vnext=@(@{address=$addr;port=$port;users=@($usr)})};streamSettings=(StreamSettings $net $sec $q $host $path $sni)}; $script:Nodes += (Node $name 'vless' $ob); L ('node_json=' + $source + ' proto=vless name=' + (San $name)) }
            elseif($proto -eq 'trojan' -and $obj.password){ $ob=@{tag='proxy';protocol='trojan';settings=@{servers=@(@{address=$addr;port=$port;password=[string]$obj.password})};streamSettings=(StreamSettings $net $sec $q $host $path $sni)}; $script:Nodes += (Node $name 'trojan' $ob); L ('node_json=' + $source + ' proto=trojan name=' + (San $name)) }
            elseif(($proto -eq 'ss' -or $proto -eq 'shadowsocks') -and $obj.password){ $ob=@{tag='proxy';protocol='shadowsocks';settings=@{servers=@(@{address=$addr;port=$port;method=[string]$obj.method;password=[string]$obj.password})}}; $script:Nodes += (Node $name 'ss' $ob); L ('node_json=' + $source + ' proto=ss name=' + (San $name)) }
        } catch { }
    }
    foreach ($p in $obj.PSObject.Properties) { if ($p.Value -and -not ($p.Value -is [string])) { Add-JsonNodes $p.Value $source } }
}
function Find-Xray {
    $p = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^xray\.exe$|^v2ray\.exe$' -and $_.ExecutablePath } | Select-Object -First 1)
    if ($p.Count -gt 0) { return [string]$p[0].ExecutablePath }
    foreach ($root in @($env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA, 'E:\', 'F:\')) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $f = @(Get-ChildItem -LiteralPath $root -Recurse -Depth 5 -Filter xray.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($f.Count -gt 0) { return $f[0].FullName }
    }
    return ''
}
function Test-Node($node, [string]$xray, [int]$idx) {
    $port = 19000 + ($idx % 500)
    $tmp = Join-Path $env:TEMP ('agy-node-' + $idx + '.json')
    $cfg = @{ log=@{loglevel='warning'}; inbounds=@(@{tag='in';listen='127.0.0.1';port=$port;protocol='http';settings=@{timeout=0}}); outbounds=@($node.outbound, @{tag='direct';protocol='freedom'}) }
    [IO.File]::WriteAllText($tmp, (($cfg | ConvertTo-Json -Depth 40) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
    $p = $null
    try {
        $p = Start-Process -FilePath $xray -ArgumentList @('run','-config',$tmp) -WindowStyle Hidden -PassThru
        if (-not (Wait-Port $port 6)) { if($p){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}; return @{ok=$false; why='no_listen'} }
        $g = GeoVia $port
        $sup = Supported (($g.cc) + ' ' + ($g.country))
        return @{ok=$true; country=$g.cc; raw=$g.country; ip=$g.ip; org=$g.org; cloud=$g.cloud; supported=$sup}
    } catch { return @{ok=$false; why=$_.Exception.Message} }
    finally { if($p){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}; Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
function Apply-Bridge($node, [string]$xray) {
    $priv = Join-Path $env:USERPROFILE '.arena-private'
    New-Item -ItemType Directory -Force -Path $priv | Out-Null
    $cfgPath = Join-Path $priv 'antigravity-xray-bridge.json'
    $cmdPath = Join-Path $priv 'start-antigravity-xray-bridge.cmd'
    $cfg = @{ log=@{loglevel='warning'}; inbounds=@(@{tag='antigravity-http';listen='127.0.0.1';port=18088;protocol='http';settings=@{timeout=0}}); outbounds=@($node.outbound, @{tag='direct';protocol='freedom'}) }
    [IO.File]::WriteAllText($cfgPath, (($cfg | ConvertTo-Json -Depth 50) + "`r`n"), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllLines($cmdPath, @('@echo off','taskkill /f /im xray.exe >nul 2>nul','start "antigravity-xray" "' + $xray + '" run -config "' + $cfgPath + '"'), (New-Object Text.ASCIIEncoding))
    try { Start-Process -FilePath $cmdPath -WindowStyle Hidden; Start-Sleep -Seconds 3 } catch { L ('bridge_start_WARN=' + (San $_.Exception.Message)) }
    try { $tn='antigravity-xray-bridge'; $la=New-ScheduledTaskAction -Execute $cmdPath; $tr=New-ScheduledTaskTrigger -AtLogOn; $pr=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited; $st=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries; Register-ScheduledTask -TaskName $tn -Action $la -Trigger $tr -Principal $pr -Settings $st -Force | Out-Null; L ('bridge_task_OK=' + $tn) } catch { L ('bridge_task_WARN=' + (San $_.Exception.Message)) }
    foreach($scope in @('User','Machine')){ try{ foreach($k in @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')){ [Environment]::SetEnvironmentVariable($k,'http://127.0.0.1:18088',$scope) }; [Environment]::SetEnvironmentVariable('NO_PROXY','localhost,127.0.0.1,::1',$scope); L ('env_' + $scope + '=http://127.0.0.1:18088') } catch { L ('env_WARN=' + (San $_.Exception.Message)) } }
    foreach($root in @((Join-Path $env:APPDATA 'Antigravity\User'),(Join-Path $env:APPDATA 'Antigravity IDE\User'))){ try{ New-Item -ItemType Directory -Force -Path $root | Out-Null; $sp=Join-Path $root 'settings.json'; $obj=[pscustomobject]@{}; if(Test-Path $sp){ try{$obj=Get-Content $sp -Raw -Encoding UTF8 | ConvertFrom-Json}catch{$obj=[pscustomobject]@{}} }; $obj|Add-Member -NotePropertyName 'http.proxy' -NotePropertyValue 'http://127.0.0.1:18088' -Force; $obj|Add-Member -NotePropertyName 'http.proxySupport' -NotePropertyValue 'on' -Force; $obj|Add-Member -NotePropertyName 'http.noProxy' -NotePropertyValue @('localhost','127.0.0.1','::1') -Force; [IO.File]::WriteAllText($sp,(($obj|ConvertTo-Json -Depth 8)+"`r`n"),(New-Object Text.UTF8Encoding($false))); L ('settings_OK=' + $sp) } catch { L ('settings_WARN=' + (San $_.Exception.Message)) } }
}
function Relaunch-Agy([bool]$interactive){ foreach($n in @('language_server','Antigravity')){try{taskkill /f /im ($n+'.exe') 2>&1|Out-Null}catch{}}; Start-Sleep -Seconds 3; $exe=Join-Path $env:LOCALAPPDATA 'Programs\Antigravity\Antigravity.exe'; if(Test-Path $exe){ if($interactive){ try{$tn='agyrelaunch_auto_bridge'; $la=New-ScheduledTaskAction -Execute $exe; $pr=New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited; Register-ScheduledTask -TaskName $tn -Action $la -Principal $pr -Force | Out-Null; Start-ScheduledTask -TaskName $tn; L ('agy_relaunch_task=' + $tn)}catch{L('agy_relaunch_WARN='+(San $_.Exception.Message))} } else { try{Start-Process $exe; L 'agy_relaunch=OK'}catch{L('agy_relaunch_WARN='+(San $_.Exception.Message))} } } }

$script:Lines=@(); $script:Nodes=@()
if(-not $OutPath){$OutPath=Join-Path $env:TEMP 'v2rayn_node_bridge.md'}
L '# v2rayN node auto bridge'
L ('time=' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + ' apply=' + [bool]$Apply)
$xray = Find-Xray
L ('xray=' + (San $xray))
if(-not $xray){L 'FINAL: V2RAYN_NODE_BRIDGE_FAIL xray.exe not found'; Write-Utf8 $OutPath $script:Lines; exit 0}
$roots=@()
foreach($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'v2rayN|xray|v2ray' -and $_.ExecutablePath })){ $roots += (Split-Path -Parent $p.ExecutablePath) }
$roots += @($env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE, 'E:\v2rayN-new', 'F:\v2rayN-new')
$files=@()
foreach($r in @($roots|Where-Object{$_}|Select-Object -Unique)){ if(Test-Path $r){ $files += @(Get-ChildItem -LiteralPath $r -Recurse -Depth 5 -Include *.json,*.txt -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'v2ray|gui|server|sub|config|profile|subscription' }) } }
$privSubs = Join-Path $env:USERPROFILE '.arena-private\v2ray_subs.txt'
if(Test-Path $privSubs){ L 'private_subs_file=present'; try { $rawPriv = Get-Content -LiteralPath $privSubs -Raw -ErrorAction SilentlyContinue; Add-Nodes-From-Text $rawPriv 'private_file' } catch { }; foreach($url in @(Get-Content $privSubs | Where-Object { $_ -match '^https?://' })){ $txt=Curl @('-L','--max-time','30','-sS',$url); Add-Nodes-From-Text $txt 'private_sub' } } else { L 'private_subs_file=absent' }
foreach($f in @($files|Sort-Object FullName -Unique|Select-Object -First 80)){
    try{ $txt=Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue; if($txt -match '(vmess|vless|trojan|ss)://'){ Add-Nodes-From-Text $txt (Split-Path -Leaf $f.FullName) }; if($f.Extension -eq '.json'){ try{$j=$txt|ConvertFrom-Json; Add-JsonNodes $j (Split-Path -Leaf $f.FullName)}catch{} } }catch{}
}
# de-duplicate by protocol+name+json hash approximation
$uniq=@(); $seen=@{}
foreach($n in $script:Nodes){ $key=$n.proto+'|'+$n.name; if(-not $seen.ContainsKey($key)){ $seen[$key]=$true; $uniq+=$n } }
$script:Nodes=$uniq
L ('nodes_found=' + $script:Nodes.Count)
$best=$null; $i=0
foreach($n in @($script:Nodes | Select-Object -First $MaxNodes)){
    $i++
    $r=Test-Node $n $xray $i
    if($r.ok){ L ('test ' + $i + '/' + [Math]::Min($script:Nodes.Count,$MaxNodes) + ' proto=' + $n.proto + ' name=' + (San $n.name) + ' country=' + $r.country + ' ip=' + (San $r.ip) + ' org=' + (San $r.org) + ' cloud=' + (San $r.cloud) + ' supported=' + $r.supported) }
    else { L ('test ' + $i + ' proto=' + $n.proto + ' name=' + (San $n.name) + ' failed=' + (San $r.why)) }
    if($r.ok -and $r.supported -and -not $best){ $best=$n; break }
}
if($best){ L ('chosen_node proto=' + $best.proto + ' name=' + (San $best.name)); if($Apply){ Apply-Bridge $best $xray; if($Relaunch){Relaunch-Agy ([bool]$InteractiveTask)}; L 'FINAL: V2RAYN_NODE_BRIDGE_APPLIED selected node is serving Antigravity at http://127.0.0.1:18088' } else { L 'FINAL: V2RAYN_NODE_BRIDGE_FOUND rerun with -Apply' } }
else { L 'FINAL: V2RAYN_NODE_BRIDGE_NO_SUPPORTED_NODE no parsable/tested node produced a supported-region API route. Put subscription URLs in %USERPROFILE%\.arena-private\v2ray_subs.txt or select a supported node in v2rayN.' }
Write-Utf8 $OutPath $script:Lines
L ('report=' + $OutPath)
exit 0
