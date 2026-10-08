# 多端互通总览（笔记本 / 台式机 / HPC / Muse / 云盘 / Arena）

生成分支：`arena/01a0ff69-git-pull-arena`
最后更新：2026-10-07

本文件是「哪台机器、走什么通道、用什么命令」的总索引。配套的详细文档都在同一文件夹内。

---

## 1. 节点清单

| 节点 | 标识 | 角色 | 可达性 |
|---|---|---|---|
| 笔记本 | `LAPTOP-R77M5D6M` | 主力执行机，git-sync 值守所在 | 出站可达全部节点 |
| 台式机 | 家中台式 | 第二执行机（Antigravity / v2rayN 桥接验证过） | 经 Tailscale 互通 |
| HPC 集群 | `mu01` | 宏基因组重算力（组装/分箱/sORF） | 仅 SSH 出站 |
| Muse | 云端沙箱 | 只出不进（Tailscale 纯客户端） | **不可被入站连接** |
| Google Drive | `jzthjyz@gmail.com` | 云盘中转 | rclone remote `gdrive_jzthjyz` |
| Arena 沙箱 | 本会话 | 编排与代码生成 | 只经 GitHub 分支与各端交互 |

---

## 2. 通道矩阵

| 从 → 到 | 通道 | 状态 | 说明 |
|---|---|---|---|
| Arena → 笔记本 | GitHub 分支 + `watch.ps1` 轮询 | ✅ 常用主通道 | 每轮 `--request` → 本地执行 → 回执提交 |
| 笔记本 → Arena | 同上（回执 commit） | ✅ | `results/status/check_rNNN_*.txt` |
| 笔记本 ↔ 台式机 | Tailscale | ✅ | 两端均为完整节点，可双向 |
| 笔记本 → HPC | SSH / scp（`25wenshaohua@mu01`） | ✅ | 大算力步骤在此执行 |
| 笔记本 → Muse | Tailscale 出站 | ✅ | 仅单向 |
| Muse → 笔记本 | **不可直连** | ❌ | Muse 是纯客户端，不能被入站 |
| Muse → 笔记本（替代） | GitHub 分支目录 / 聊天附件 | ✅ | `sources/muse/`、`deliverable/muse/`、`results/muse/`，建议打包 `muse_out_日期.zip` + `README.txt` |
| 任意端 ↔ Google Drive | rclone | ✅ | 本机浏览器 OAuth，不存口令/令牌 |

---

## 3. 关键路径速查

```text
# 笔记本 git-sync 值守仓库
E:\0github\git-sync\git-pull-arena-01a0ff69

# 笔记本桌面（注意不是 C 盘）
D:\桌面

# 对接结果与报告
D:\桌面\AMP_Docking_Vina_R255_20261005_1552

# WSL（AMP 深度学习预测内核所在）
\\wsl$\...\home\w26\c_AMPs-prediction-master\c_AMPs-prediction-master
conda 环境：camps-tf114（Attention/LSTM，TF1.14）、py36（BERT）

# HPC sORF 流程目录
25wenshaohua@mu01:/mnt/hpc/home/25menglei/25wenshaohua/wsh/ad/codenew/sorf_pipeline

# AMP 预测代码（已备份到 GitHub）
https://github.com/mqgg5630-cyber/c_AMPs-prediction
  分支 arena/01a06f35-c-amps-prediction
```

---

## 4. 常用命令

### 4.1 git-sync 值守（笔记本）

```powershell
# 恢复值守（隐藏窗口 + 只保留本分支）
cd E:\0github\git-sync\git-pull-arena-01a0ff69
git fetch origin arena/01a0ff69-git-pull-arena
git reset --hard origin/arena/01a0ff69-git-pull-arena
powershell -NoProfile -ExecutionPolicy Bypass -File .\code\tasks\clean_flash_and_restore_watch.ps1

# 前台观察一轮
.\watch.ps1 -Focus

# 体检
.\doctor.ps1

# 全部停掉
Get-ScheduledTask | ? { $_.TaskName -match 'git-sync-watch' } | % {
  Stop-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -EA SilentlyContinue
  Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath | Out-Null
}
```

### 4.2 HPC

```bash
ssh 25wenshaohua@mu01
cd /mnt/hpc/home/25menglei/25wenshaohua/wsh/ad/codenew/sorf_pipeline

# 取回分组 FASTA
scp -r 25wenshaohua@mu01:/mnt/hpc/.../sorf_grouped_catalog .

# 上传脚本
scp amp_pipeline/build_grouped_sorf_from_magfiles.py \
    25wenshaohua@mu01:/mnt/hpc/.../c_AMPs-prediction/amp_pipeline/
```

### 4.3 Google Drive

```bash
rclone lsd gdrive_jzthjyz:
rclone copy ./deliverable gdrive_jzthjyz:/arena_out --progress
rclone copy gdrive_jzthjyz:/arena_in ./sources --progress
```

### 4.4 Tailscale

```powershell
tailscale status
tailscale ip -4
# 台式机 ↔ 笔记本 可直接用 Tailscale IP 走 SMB / SSH / HTTP
```

---

## 5. 已知限制与纪律

1. **Muse 不可入站**：不要再尝试笔记本 → Muse 的端口探测或 SMB/SSH/HTTP 共享，走 GitHub 分支目录或聊天附件。
2. **不写入任何密钥**：Google 口令/2FA/OAuth token、Kaggle key、SSH 私钥、v2ray 订阅链接与节点密文，一律不进仓库、不进日志。部署公钥属于 GitHub 设置，不提交到仓库。
3. **不覆盖已交付文件**：`Downloads` 与桌面交付一律用带时间戳的版本名；同名同哈希则保留，不同则 `_copyN`。
4. **Antigravity 地域限制**：`User location is not supported` 是 Google 按出口 IP 的地域封锁，HK 不受支持；且子进程 `python`/`git` 不会继承 IDE 内代理，需系统级代理。
5. **仓库体积纪律**：大二进制（docx / 高分辨率 PNG / PDF）尽量只落桌面，仓库内保留清单与校验和；当前分支已因历史大文件膨胀到约 121 MB，`git pull` 会偏慢。
6. **闪窗根因**：与 git-sync 无关，是壁纸守护脚本（`Lively Wallpaper Keeper.bat` / `keeper12.py` / zTasker）循环调用 `tasklist`/`taskkill` 所致，已清理；值守任务本身为 `-WindowStyle Hidden` + S4U，零窗口。

---

## 6. 同文件夹内的配套文档

| 文件 | 内容 |
|---|---|
| `SKILLS_INTEROP_SUMMARY.md` | 技能与互通能力总结 |
| `skills_cloud-interop_SKILL.md` / `_README_CN.md` | 云盘互通技能（rclone / Drive） |
| `skills_computer-use_SKILL.md` / `_README_CN.md` | Windows 计算机操作 / UIA 自动化技能 |
| `skills_git-sync_SKILL.md` / `_README.md` | git-sync 值守技能本体 |
| `skills_README.md` | 技能总索引 |
| `GDRIVE_SETUP_R249.md` | Google Drive rclone 配置与探针写入记录 |
| `INTEROP_HEALTH.md` | 各通道健康检查记录 |
| `COMPUTER_USE_LAPTOP_R249.md` | 笔记本 computer-use 实机验证记录 |
| `muse_*.md` | Muse 握手协议、互联探测、v2ray 接管记录 |

INTEROP_INDEX_DONE=True
