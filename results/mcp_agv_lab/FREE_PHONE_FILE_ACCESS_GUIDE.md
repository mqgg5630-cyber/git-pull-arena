# 免费用手机访问电脑文件：同 Wi‑Fi 浏览器方案

## 当前已配置好的共享目录

电脑上只共享这个受限目录，不共享整盘：

```text
E:\0mcp-agv-arena-optimized\phone-share
```

你要在手机上看的文件，复制到这个目录里即可。

## 手机上打开的地址

手机和电脑连同一个 Wi‑Fi 后，在手机浏览器地址栏输入下面地址之一：

```text
http://192.168.110.172:18089/
```

如果打不开，再试：

```text
http://10.0.0.15:18089/
```

必须完整输入 `http://`，不要输入 `https://`。

## 使用步骤

1. 手机和电脑连接同一个 Wi‑Fi。
2. 手机先关闭 Tailscale、v2ray、其他 VPN 或代理，避免浏览器流量被代理到 Cloudflare。
3. 电脑上把要看的文件复制到：

   ```text
   E:\0mcp-agv-arena-optimized\phone-share
   ```

4. 手机浏览器打开：

   ```text
   http://192.168.110.172:18089/
   ```

5. 页面里点文件名即可下载或查看。

## 看到 Cloudflare 400 怎么办

如果手机显示：

```text
400 Bad Request
The plain HTTP request was sent to HTTPS port
cloudflare
```

说明你打开的不是电脑局域网地址，而是 HTTPS/Cloudflare/代理地址。

处理办法：

- 地址必须是 `http://192.168.110.172:18089/`，不是 `https://...`。
- 不要打开 Arena 预览链接。
- 关闭手机 VPN、代理、Tailscale、v2ray 后再试。
- 如果浏览器自动升级 HTTPS，换一个浏览器或关闭“始终使用安全连接”。

## 如果服务停了，电脑上手动重开

在电脑 PowerShell 里运行：

```powershell
cd /d E:\0mcp-agv-arena-optimized\phone-share
python -m http.server 18089 --bind 0.0.0.0
```

保持这个窗口开着，然后手机访问：

```text
http://192.168.110.172:18089/
```

## 免费替代方案

- 同 Wi‑Fi 浏览器访问：最简单，当前已配置。
- LocalSend：适合同 Wi‑Fi 快速传文件。
- Syncthing：适合手机和电脑自动同步文件夹。
- ZeroTier：类似 Tailscale，可用于不在同一个 Wi‑Fi 的情况。
- 自建 WireGuard：完全免费但配置复杂，需要公网 IP 或端口转发。
