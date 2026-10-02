# WireGuard phone guide r234

PC share root:
`E:\0mcp-agv-arena-optimized\phone-share`

Already generated local-only config files on PC:
Server config: E:\0mcp-agv-arena-optimized\wireguard\arena-phone-server.conf
Phone config: E:\0mcp-agv-arena-optimized\wireguard\arena-phone-client.conf

Do not upload or paste the .conf files; they contain private keys.

PC admin steps:
1. Run PowerShell as Administrator.
2. If WireGuard is not installed: powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\wireguard\ADMIN_1_install_wireguard.ps1"
3. Start PC tunnel: powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\wireguard\ADMIN_2_install_tunnel.ps1"

Phone steps:
1. Install WireGuard from the app store.
2. Import the file from the PC: E:\0mcp-agv-arena-optimized\wireguard\arena-phone-client.conf
3. Turn on the tunnel.
4. Open this in phone browser: http://10.66.66.1:18089/

If testing only on same Wi-Fi, the generated endpoint can be the PC LAN IP. If using from mobile data/outside home, set Endpoint to a public IP/DDNS and forward UDP 51820 on the router to the PC.

Current immediate same-WiFi URLs:
http://172.30.192.1:18089/ , http://172.28.224.1:18089/ , http://192.168.110.172:18089/ , http://10.0.0.15:18089/
