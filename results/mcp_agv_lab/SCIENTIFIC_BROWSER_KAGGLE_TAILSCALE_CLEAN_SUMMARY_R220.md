# 科研绘图 skills / Browser-Kaggle / Tailscale 手机互通清单（R220）

生成时间：2026-10-02

## 1. cell_su7 等科研绘图 skills 是否用 Antigravity 测试过？

之前已经在本机真实跑过 `cell-lct` 和 `cell_su7` 的 Illustrator 绘图测试，但那时主要是 watcher/PowerShell/Illustrator runner 测试，不是 Antigravity 对话内测试。

本轮补做了 Antigravity 对这些科研绘图 skills 的对比测试：

```text
Antigravity CDP: True
Inserted: True
Submitted: True
Marker found in DOM: True
Final: ANTIGRAVITY_DRAW_SKILL_COMPARE_MARKER_FOUND
```

说明：这次验证的是 Antigravity 可以接收并提交“科研绘图 skill 对比任务”的 prompt；由于 marker 同时会出现在用户消息记录里，它证明提交链路可用，但不把它夸大成完整执行 Illustrator 绘图。真正 Illustrator 产物仍以历史本机 runner 结果为准。

Antigravity 测试记录：

```text
E:\0mcp-agv-arena-optimized\reports\antigravity-draw-skill-compare-r220.json
results/mcp_agv_lab/antigravity-draw-skill-compare-r220.json
```

## 2. 科研绘图 skills 对比

| Skill | 历史实机测试 | 输出 | 适合任务 | 结论 |
|---|---|---|---|---|
| `cell-lct` | R103 smoke PASS | `.ai` + `.png`，2 个文本框 + 4 个路径，Illustrator 导出成功 | 稳定复刻细胞/科研图元、需要 AI 文件后期编辑 | 稳定、偏确定性生产 |
| `cell_su7` | R104 smoke PASS；R107 full demo 启动 | `.ai` + `.png`，2 个文本框 + 4 个路径；full demo 已启动 | 更完整的 Illustrator 科研图重建/批量绘图 | 能力最强，适合复杂科研绘图 |
| `vector-editable-figure` | R219 生成 SVG PASS | `.svg` | 快速生成可编辑 SVG、流程图、科研示意图 | 轻量、跨软件、最适合先出草图 |
| `nature-figure` | 已在 skills 索引中发现 | skill 存在，未单独跑本轮 Illustrator | Nature 风格图表/论文图 | 适合论文图风格化，需后续单独实测 |
| `scipilot-figure-skill` | 已在 skills 索引中发现 | skill 存在，未单独跑本轮 Illustrator | 科研 figure 生成/组织 | 适合科研图自动化候选 |
| `smart-illustrator` | 已在 skills 索引中发现 | skill 存在，未单独跑本轮 Illustrator | Illustrator 脚本化/智能编辑 | 适合作为 Illustrator 专用后端候选 |

历史产物：

```text
results/fig1_rebuild/test/cell-lct/test_cell-lct.ai
results/fig1_rebuild/test/cell-lct/test_cell-lct.png
results/fig1_rebuild/test/cell_su7/test_cell_su7.ai
results/fig1_rebuild/test/cell_su7/test_cell_su7.png
E:\0mcp-agv-arena-optimized\resume-samples\research_vector_editable_figure_r219.svg
```

本轮对比 JSON：

```text
E:\0mcp-agv-arena-optimized\reports\scientific-drawing-skill-compare-r220.json
results/mcp_agv_lab/scientific-drawing-skill-compare-r220.json
```

## 3. Browser 控制 skill / Kaggle 登录状态

检测到浏览器相关能力很多，主要是 Playwright/browser 类文件，例如：

```text
E:\0mcp-agv\.agents\skills\guizang-ppt-skill\tools\node_modules\playwright
E:\0mcp-agv\.agents\skills\light-frontend-design\scripts\browser_qa.py
E:\0mcp-agv\.playwright-mcp
```

这说明浏览器控制基础是有的。

但是 Kaggle 登录/CLI 状态本轮测试结果是：

| 范围 | 结果 |
|---|---|
| Windows 终端 | 未发现 `kaggle` 命令；未发现 `%USERPROFILE%\.kaggle\kaggle.json` |
| WSL | 有 WSL 发行版，但 `kaggle` 命令缺失；`~/.kaggle/kaggle.json` 不存在 |
| Kaggle API 网络 | R219 已测 API 可达，HTTP 200 |

所以当前结论：

> 我不能“直接登录你的 Kaggle”，因为本轮没有发现可用的 Kaggle CLI token，也不会读取/输入你的密码、cookies、2FA。  
> 但可以基于 browser skill 打开 Kaggle；如果浏览器里已经登录，我可以操作已登录会话。若要命令行稳定使用，需要你在本机私有位置放 Kaggle token。

建议打通方式：

```text
Windows: %USERPROFILE%\.kaggle\kaggle.json
WSL:     ~/.kaggle/kaggle.json
```

然后测试：

```bash
kaggle datasets list -s mnist
```

注意：`kaggle.json` 不能进 Git、不能发聊天、不能写公开报告。

## 4. 基于笔记本还需要打通什么？

优先级建议：

1. Kaggle CLI：Windows 和 WSL 各装/配置一次，token 只放本机私有目录。
2. Colab：保留 `E:\0mcp-agv-arena-optimized\compute-bridge\colab_bridge_template.ipynb`，后续用 Google 登录授权。
3. Browser MCP：把已有 Playwright/browser skill 明确注册到 Antigravity MCP config，作为网页自动化后端。
4. WSL 路径映射：让 WSL 能稳定读写 `E:\0mcp-agv-arena-optimized`，对应 `/mnt/e/0mcp-agv-arena-optimized`。
5. Jupyter/Notebook：给本机和 WSL 建一个统一的 notebook 工作目录，方便和 Colab/Kaggle 对接。
6. Tailscale 手机端：把手机加入 tailnet，用手机访问台式机和 HPC。

## 5. Tailscale 当前状态

本轮实测：

```text
Laptop tailnet IP: 100.71.123.19
Desktop tailnet IP: 100.84.137.117
Desktop ping: pong, 约 6ms
Phone online: redmi-note-12-turbo 100.90.87.92
HPC 10.10.5.210:22 probe: TIMEOUT
```

说明：

- 笔记本 ↔ 台式机 Tailscale 已通。
- 手机已经有一台 Android 设备在线：`redmi-note-12-turbo`。
- HPC 当前从笔记本探测 SSH 超时，可能是 subnet route 未批准/路由机器离线/ACL/校园网侧不可达。

## 6. 手机如何和台式机、HPC 互通

### 手机访问台式机

1. 手机安装 Tailscale。
2. 登录同一个 tailnet 账号。
3. 在 Tailscale 管理后台确认手机在线。
4. 手机装 Microsoft Remote Desktop。
5. 新建 RDP：

```text
PC name: 100.84.137.117
```

如果台式机 SSH 开了，也可以用 Termius / Blink / JuiceSSH：

```bash
ssh BNI@100.84.137.117
```

### 手机访问 HPC

历史 HPC route 是：

```text
10.10.5.210/32
```

要让手机能访问 HPC，需要：

1. 确认有一台机器在线作为 subnet router。
2. 这台机器执行过类似：

```bash
tailscale set --advertise-routes=10.10.5.210/32
```

3. 在 Tailscale Admin Console 批准这个 route。
4. ACL 允许手机访问 `10.10.5.210:22`。
5. 手机 Tailscale 保持连接。
6. 手机 SSH 客户端连接：

```bash
ssh <hpc_user>@10.10.5.210
```

如果直接不通，用跳板：

```bash
ssh <hpc_user>@10.10.5.210 -J BNI@100.84.137.117
```

或先连台式机/笔记本，再从那里 SSH 到 HPC。

## 7. 本轮报告路径

```text
results/mcp_agv_lab/SCIENTIFIC_BROWSER_KAGGLE_TAILSCALE_R220.md
results/mcp_agv_lab/scientific-browser-kaggle-tailscale-summary-r220.md
results/mcp_agv_lab/phone-tailscale-desktop-hpc-guide-r220.md
results/mcp_agv_lab/browser-skill-kaggle-probe-r220.json
results/mcp_agv_lab/tailscale-phone-hpc-probe-r220.json
```
