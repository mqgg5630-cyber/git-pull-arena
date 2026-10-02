# ZeroTier + 自建 WireGuard 电脑端准备结果 R233

## 先说结论

我已经把“免费手机访问电脑文件”的共享服务和脚本准备好，但 ZeroTier 和 WireGuard 这类虚拟网卡/VPN 软件在 Windows 上需要管理员权限安装驱动。本轮 watcher 不是管理员权限：

```text
is_admin=False
```

所以电脑端做到的状态是：

- 文件共享服务：已完成，可用。
- ZeroTier：已尝试安装，但安装器返回 1618，CLI 未安装成功；需要管理员权限或等待另一个安装进程结束后重试。
- WireGuard：已尝试安装，但安装器返回 1618，`wg.exe` / `wireguard.exe` 未安装成功；需要管理员权限或等待另一个安装进程结束后重试。
- ZeroTier 和 WireGuard 后续脚本、手机端操作方法已准备好。

## 1. 现在立即可用：同 Wi‑Fi 免费访问电脑文件

电脑共享目录：

```text
E:\0mcp-agv-arena-optimized\phone-share
```

手机和电脑在同一个 Wi‑Fi 时，手机浏览器打开：

```text
http://192.168.110.172:18089/
```

如果打不开，再试：

```text
http://10.0.0.15:18089/
```

本机自测通过的地址还包括：

```text
http://172.30.192.1:18089/
http://172.28.224.1:18089/
```

注意：必须是 `http://`，不是 `https://`。

## 2. ZeroTier 电脑端状态和下一步

当前结果：

```text
status_zerotier=ZEROTIER_INSTALL_ATTEMPTED_NEEDS_ADMIN_OR_RETRY
zerotier_cli=
```

意思是：已经尝试安装 ZeroTier One，但 Windows installer 返回 1618，ZeroTier CLI 还没装好。

### 电脑端下一步

用管理员权限安装 ZeroTier One：

1. 打开管理员 PowerShell。
2. 运行：

```powershell
winget install --id ZeroTier.ZeroTierOne -e --accept-package-agreements --accept-source-agreements
```

安装完成后，如果你已经有 ZeroTier 网络 ID，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\zerotier\join-zerotier-network.ps1" YOUR_NETWORK_ID
```

脚本路径：

```text
E:\0mcp-agv-arena-optimized\zerotier\join-zerotier-network.ps1
```

### 手机端 ZeroTier 操作

1. 手机安装 ZeroTier One。
2. 加入同一个 ZeroTier Network ID。
3. 到 ZeroTier Central 授权电脑和手机。
4. 在电脑上查看 ZeroTier IP。
5. 手机浏览器打开：

```text
http://电脑ZeroTier_IP:18089/
```

## 3. 自建 WireGuard 电脑端状态和下一步

当前结果：

```text
status_wireguard=WIREGUARD_INSTALL_ATTEMPTED_NEEDS_ADMIN_OR_RETRY
wg.exe=
wireguard.exe=
```

意思是：已尝试安装 WireGuard，但 Windows installer 返回 1618，WireGuard 没装好。

### 电脑端下一步

用管理员 PowerShell 安装 WireGuard：

```powershell
winget install --id WireGuard.WireGuard -e --accept-package-agreements --accept-source-agreements
```

安装完成后，生成本地 WireGuard 配置：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\wireguard\generate-wireguard-configs-local.ps1" -EndpointHost YOUR_PUBLIC_IP_OR_DDNS
```

如果只是先在同 Wi‑Fi 内测试，可以临时把 `YOUR_PUBLIC_IP_OR_DDNS` 换成电脑局域网 IP，例如：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\wireguard\generate-wireguard-configs-local.ps1" -EndpointHost 192.168.110.172
```

然后用管理员 PowerShell 安装 WireGuard 隧道：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\wireguard\install-wireguard-tunnel-admin.ps1"
```

生成的手机配置文件在电脑本地：

```text
E:\0mcp-agv-arena-optimized\wireguard\arena-phone-client.conf
```

注意：这个 `.conf` 文件包含私钥，不要上传到 Git，不要发到聊天里。

### 手机端 WireGuard 操作

1. 手机安装 WireGuard。
2. 把电脑生成的文件导入手机：

```text
E:\0mcp-agv-arena-optimized\wireguard\arena-phone-client.conf
```

3. 打开 WireGuard 隧道。
4. 手机浏览器访问：

```text
http://10.66.66.1:18089/
```

如果你要在外网访问家里电脑，还需要在路由器上做端口转发：

```text
UDP 51820 -> 电脑局域网 IP
```

例如：

```text
UDP 51820 -> 192.168.110.172
```

如果没有公网 IP 或者被运营商 CGNAT，WireGuard 直连会比较困难，建议用 ZeroTier。

## 4. 当前推荐顺序

1. 同 Wi‑Fi：直接用 `http://192.168.110.172:18089/`，最快。
2. 不同网络、免折腾：ZeroTier。
3. 想完全自建、可控：WireGuard，但需要公网 IP/端口转发或 VPS。

## 5. 本轮未做的事

本轮没有继续 Antigravity、CLI、Illustrator、IDE 下载或 IDE 安装任务。
