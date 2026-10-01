# 台式机 Antigravity 登录修复报告（r129–r137）

日期：2026-10-01　状态：**已修复（日志级验证通过）**，待用户到台式机前做最后确认

## 结论

台式机（BNI，100.84.137.117）的 Antigravity 2.12.2 登录失败根因与笔记本同款：
**Go 语言服务器（language_server.exe）不走系统代理、只认 HTTP(S)_PROXY 环境变量**，
没有变量时直连 googleapis 被墙。v4 修复后（2026-10-01 19:35:19 会话）语言服务器已
通过本地代理 127.0.0.1:10808 与 Google 正常通信，日志中出现 `Auth succeeded` 与
`RemoteControl Connection status: Connected`（连上 jetski-webchannel.googleapis.com:443）。

## 修复前后对比（language_server.log 同窗口实测）

| 指标 | v3 会话 (18:58) | v4 会话 (19:35) |
|---|---|---|
| dial-tcp 直连错误 | 136 条 | **0 条** |
| tls-garbage（被墙注入） | 有 | **0** |
| 语言服务器初始化耗时 | 6 分 29 秒 | **3.6 秒** |
| 主要报错端点 | daily-cloudcode-pa.googleapis.com (92) | 无 |
| 认证状态 | Failed to get OAuth | **Auth succeeded / Connected** |

## 根因链（四层，全部实锤）

1. Go 后端只认环境变量；settings.json 的 http.proxy 只对 electron 主进程生效。
2. `setx` 用户级 env 对"计划任务拉起的进程"不可靠（r132 实锤，直连变成 tls 垃圾）。
3. r133 包装器里两行小写 `set x=...` 被数组拼接 bug 拆成两行（r135 磁盘读回实锤）。
4. 机器级（HKLM）env 此前从未设置——这是计划任务进程唯一可靠继承的来源。

## v4 修复栈（全部落盘并自证）

- `F:\fig1_rebuild\agy_proxy.cmd` — 11 行纯字面量启动包装器（逐字节读回校验），
  set HTTP(S)_PROXY/ALL_PROXY/NO_PROXY(+小写, NO_PROXY 含 ::1) 后 start Antigravity。
- `F:\fig1_rebuild\agy_launch.log` — 每次包装器调用的时间戳记录（链路证明）。
- `F:\fig1_rebuild\agy_env_snapshot.txt` — 启动瞬间 env 快照（4 个代理变量齐全）。
- HKLM 机器级 env：HTTP_PROXY/HTTPS_PROXY/NO_PROXY（`setx /M`，**所有启动路径都继承**，
  包括开始菜单正常启动——修复是永久的，不依赖包装器）。
- HKCU 用户级 env 同步设置。
- `C:\Users\BNI\AppData\Roaming\Antigravity\User\settings.json`（+ `Antigravity IDE` 变体）：
  http.proxy / http.proxySupport=on / http.noProxy=["localhost","127.0.0.1"]（对齐笔记本参照）。
- 计划任务 `agyrelaunch` → 指向包装器；WinINET ProxyOverride 含 127.*（登录回调直连豁免）。
- 本地代理：`http://127.0.0.1:10808`（curl 经它到 daily-cloudcode-pa 返回 404=TLS 通）；
  笔记本代理 100.71.123.19:10808 为 Tailscale 备份。

## 用户最后一步（无人值守无法代做）

到台式机前看 Antigravity 窗口（19:35 由计划任务拉起，应在桌面）：
- 若已显示登录/账户信息 → 完成（缓存 token 已自动续上）。
- 若未登录 → 点一次 Sign in with Google。浏览器走系统代理、127.0.0.1 回调已豁免，链路已铺好。

## 证据与脚本路径

- 仓库脚本：`code/tasks/desk_antigravity_{diag,fix,fix2,fix3,fix4,verify,verify2,verify3,verify4}.ps1`
- 派发器：`code/tasks/t93…t102`（t101=r137 修复轮，t102=r138 终验轮已备好未派发）
- 回执：`results/status/check_r129_*.txt` … `check_r137_*.txt`
- 台式机日志：`C:\Users\BNI\AppData\Roaming\Antigravity\logs\{language_server,main}.log`

## 遗留

- r138 终验轮（desk_antigravity_verify4.ps1，含修正后的 to-proxy TCP 探针）已写好并通过
  解析预检，因沙箱 GitHub token 失效暂未派发；GitHub 重连后一条命令补发。
- 无害遗留错误：playwright 驱动下载 404（CDN 问题，只影响 IDE 内置浏览器自动化，与登录无关）。
