# ZeroTier phone file access guide r232

Free desktop-side status is prepared as far as possible without a network ID.

Share root: E:\0mcp-agv-arena-optimized\phone-share
LAN URLs now: http://172.30.192.1:18089/ , http://172.28.224.1:18089/ , http://192.168.110.172:18089/ , http://10.0.0.15:18089/
ZeroTier node ID: 
ZeroTier phone URL after join: 

If no ZeroTier network is joined yet:
1. Create a free ZeroTier network in ZeroTier Central and copy the 16-character network ID.
2. On this PC run: powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\zerotier\join-zerotier-network.ps1" YOUR_NETWORK_ID
3. Authorize this PC in ZeroTier Central if the network is private.
4. On the phone install ZeroTier One, join the same network ID, and authorize the phone.
5. Then open http://PC_ZEROTIER_IP:18089/ in the phone browser.

Immediate no-VPN free option: keep phone and PC on the same Wi-Fi and open one of the LAN URLs above.
