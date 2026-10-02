# 自建 WireGuard 电脑端准备结果 R234

## 结论

电脑端已完成这些内容：

- 文件共享服务已开启。
- WireGuard 服务端/手机端配置文件已在电脑本地生成。
- 防火墙规则已尝试添加：TCP 18089、UDP 51820。
- 管理员安装/启动脚本已准备好。
- 手机端操作方法已写好。

但当前 watcher 不是管理员权限：

```text
is_admin=False
```

因此还不能替你直接安装 WireGuard 驱动或启动 WireGuard 隧道服务。Windows 上 WireGuard 安装虚拟网卡/服务必须管理员权限。

## 电脑端当前文件

共享目录：

```text
E:\0mcp-agv-arena-optimized\phone-share
```

WireGuard 服务端配置，本地文件，不要上传：

```text
E:\0mcp-agv-arena-optimized\wireguard\arena-phone-server.conf
```

WireGuard 手机端配置，本地文件，不要上传：

```text
E:\0mcp-agv-arena-optimized\wireguard\arena-phone-client.conf
```

管理员安装 WireGuard 脚本：

```text
E:\0mcp-agv-arena-optimized\wireguard\ADMIN_1_install_wireguard.ps1
```

管理员启动 WireGuard 隧道脚本：

```text
E:\0mcp-agv-arena-optimized\wireguard\ADMIN_2_install_tunnel.ps1
```

停止/移除隧道脚本：

```text
E:\0mcp-agv-arena-optimized\wireguard\ADMIN_3_remove_tunnel.ps1
```

## 电脑端下一步

请用“管理员 PowerShell”运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\wireguard\ADMIN_1_install_wireguard.ps1"
```

安装完成后，再运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\0mcp-agv-arena-optimized\wireguard\ADMIN_2_install_tunnel.ps1"
```

启动成功后，手机连上 WireGuard 后访问：

```text
http://10.66.66.1:18089/
```

## 手机端操作方法

1. 手机安装 WireGuard。
2. 把电脑上的这个文件导入手机 WireGuard：

```text
E:\0mcp-agv-arena-optimized\wireguard\arena-phone-client.conf
```

3. 打开手机 WireGuard 隧道。
4. 手机浏览器打开：

```text
http://10.66.66.1:18089/
```

## 关于外网访问

当前生成配置时检测到的 Endpoint 是：

```text
192.236.234.71:51820
```

如果这是你真实公网 IP，并且你要手机用蜂窝网络/外网访问，需要在路由器做端口转发：

```text
UDP 51820 -> 电脑局域网 IP 192.168.110.172
```

如果你只是同 Wi‑Fi 测试，可以把手机配置里的 Endpoint 改成：

```text
192.168.110.172:51820
```

如果你的宽带没有公网 IP，或者这个公网 IP 是代理/TUN/VPN 出口，WireGuard 直连会失败；这种情况下建议用 ZeroTier。

## 立即可用的免 VPN 地址

同 Wi‑Fi 下仍然可以直接访问：

```text
http://192.168.110.172:18089/
```

备用：

```text
http://10.0.0.15:18089/
```

## 隐私说明

WireGuard `.conf` 文件包含私钥。本报告没有写出私钥内容，也没有把配置文件提交到 Git。请不要把 `.conf` 发到聊天或公开仓库。
