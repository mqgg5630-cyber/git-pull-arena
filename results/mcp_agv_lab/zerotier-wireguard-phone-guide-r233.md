# ZeroTier and WireGuard phone guide r233

File share root on PC:
`E:\0mcp-agv-arena-optimized\phone-share`

Immediate free same-WiFi URLs:
http://172.30.192.1:18089/ , http://172.28.224.1:18089/ , http://192.168.110.172:18089/ , http://10.0.0.15:18089/

ZeroTier desktop status:
CLI: 
Node ID: 
ZeroTier IPs: 
Join script: E:\0mcp-agv-arena-optimized\zerotier\join-zerotier-network.ps1

ZeroTier phone steps:
1. Install ZeroTier One on the phone.
2. Create or use a free ZeroTier network ID in ZeroTier Central.
3. On PC run: powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\zerotier\join-zerotier-network.ps1" YOUR_NETWORK_ID
4. On phone join the same network ID.
5. In ZeroTier Central authorize both PC and phone.
6. Find the PC ZeroTier IP, then open http://PC_ZEROTIER_IP:18089/ on the phone.

WireGuard desktop status:
wg.exe: 
wireguard.exe: 
Configs generated locally: False
Config generator: E:\0mcp-agv-arena-optimized\wireguard\generate-wireguard-configs-local.ps1
Install tunnel script: E:\0mcp-agv-arena-optimized\wireguard\install-wireguard-tunnel-admin.ps1

WireGuard phone steps:
1. Install WireGuard on PC and phone if not already installed.
2. If the phone will connect from outside home, forward UDP 51820 on the router to this PC, or use a public VPS/DDNS endpoint.
3. On PC run: powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\wireguard\generate-wireguard-configs-local.ps1" -EndpointHost YOUR_PUBLIC_IP_OR_DDNS
4. Run PowerShell as Administrator and execute the install tunnel script shown above.
5. Import local-only phone config from: E:\0mcp-agv-arena-optimized\wireguard\arena-phone-client.conf
6. Turn on the tunnel on the phone and open http://10.66.66.1:18089/ .

Do not upload WireGuard .conf files; they contain private keys.
