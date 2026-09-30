软件工具清单 2026-09-30
===

> r49 生成：已装软件（含本地路径）+ Agent 可用工具箱。QwenPaw Desktop 已于本轮卸载。

## 一、已安装软件（含本地路径）

| # | 大小 | 名称 | 版本 | 本地路径 | 状态 |
|---|---|---|---|---|---|
{{APPS_TABLE}}

## 二、Agent 可用工具箱

Agent（值守循环）可直接调用的命令行工具：

| 工具 | 路径 |
|---|---|
{{TOOLS_TABLE}}

已知固定位置（不在 PATH）：

{{FIXED_LIST}}

能力说明：

- 容器：docker CLI（引擎随 Docker Desktop 启动）；WSL：Ubuntu-24.04 / Ubuntu-26.04（Linux 环境）
- 远程：tailscale（子网路由已通 HPC）、ssh/scp、RDP（双向已开）
- 开发：git/gh、VSCode、Java 21、Go、Rust、Python、Node
- GUI 类（zTasker、NSFOCUS、远程桌面）只能启动或给人工提示，不能无人值守驱动
