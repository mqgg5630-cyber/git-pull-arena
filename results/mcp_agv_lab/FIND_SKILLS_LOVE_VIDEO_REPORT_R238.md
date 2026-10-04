# find-skills 安装与「情侣恋爱记录 + 视频」Skills/GitHub 高星仓库调研

生成时间：2026-10-04 17:56:40

桌面报告文件：`D:\桌面\love-record-video-skills-github-report.md`

---

## 1. find-skills 安装结果

- 安装状态：**installed_by_npx**
- 项目级技能目录：`E:\0github\git-sync\git-pull-arena-01a0fa39\.agents\skills\find-skills`
- E 盘备份目录：`E:\0mcp-agv-arena-optimized\skills\find-skills`
- Node：`E:\hermes\node\node.exe`
- npx：`E:\hermes\node\npx.cmd`
- 安装命令：

```bash
npx --yes skills add https://github.com/vercel-labs/skills --skill find-skills --copy --json -y
```

`find-skills` 来自 `vercel-labs/skills`，用途是帮助发现、验证和安装开放 Agent Skills。以后可以用：

```bash
npx skills find video
npx skills find relationship
npx skills add <owner/repo> --skill <skill-name>
```

本次安装输出摘要：

```text
E:\hermes\node\npx.cmd : ??    + CategoryInfo          : NotSpecified: (:String) [], RemoteException??    + FullyQualifiedErrorId : NativeCommandError?? ??T  ?[46m?[30m skills ?[39m?[49m??|??|  ?[2mTip: use the --yes (-y) and --global (-g) flags to install without prompts.?[22m??|???? Selected 1 skill: ?[36mfind-skills?[39m??|???? Installing to: ?[36mAntigravity?[39m, ?[36mClaude Code?[39m, ?[36mOpenClaw?[39m, ?[36mCodex?[39m, ?[36mContinue?[39m??, ?[36mCursor?[39m, ?[36mGemini CLI?[39m, ?[36mGitHub Copilot?[39m, ?[36mHermes Agent?[39m, ?[36mOpenCode?[39m, ?[36mPo??sit Assistant?[39m, ?[36mTrae CN?[39m????|??o  Installation Summary [REDACTED]??|                                                                         |??|  ?[36m.\.agents\skills\find-skills?[39m                                           |??|    ?[2mcopy ??[22m Antigravity, Claude Code, OpenClaw, Codex, Continue +21 more  |??|                                                                         |??[REDACTED]??|??o  Security Risk Assessments [REDACTED]??|                                                             |??|               ?[2mGen?[22m               ?[2mSocket?[22m            ?[2mSnyk?[22m      |??|  ?[36mfind-skills?[39m  ?[32mSafe?[39m              ?[32m0 alerts?[39m          ?[33mMed Risk?[39m  |??|                                                             |??|  ?[2mDetails:?[22m ?[2mhttps://skills.sh/vercel-labs/skills?[22m              |
```

---

## 2. 快速结论

### 情侣/恋爱记录方向

这个方向的 **Agent Skill** 生态还不算成熟：没有找到很多专门做“情侣恋爱记录/纪念日相册/爱情时间线”的高星 Agent Skill。更现实的方案是：

1. 用下面的开源情侣空间/恋爱记录仓库做数据与界面；
2. 用关系分析/恋爱文案类 skill 辅助写文案；
3. 用视频类 skill 或剪映 skill 把照片、纪念日、地点轨迹、聊天梗做成纪念短片。

### 视频方向

视频方向的 Skill 和 GitHub 仓库明显更成熟。建议优先关注：

- `jianying-editor`：适合自动化剪映/CapCut 中文版；你电脑上之前已经安装过。
- `zenstory-ai/drama-skills`：短剧/分镜/视频提示词/审查，适合剧情化情侣纪念短片。
- `narrator-ai-cli-skill`：适合 AI 解说、旁白、口播脚本到视频。
- `maxazure/video-editing-skill`：偏自动剪辑、字幕、口播/访谈视频。
- `blitzreels/agent-skills`：偏短视频、切片、字幕主题、动效。

---

## 3. 相关 Agent Skills 推荐

### 3.1 情侣/恋爱/关系相关 Skills

| 推荐度 | Skill / 仓库 | 安装量 / 星标 | 适合用途 | 安装命令 |
|---|---:|---:|---|---|
| ★★★★☆ | `lijigang/ljg-skills` / `ljg-relationship` | 6.2K installs，约 7.4K stars | 关系结构分析、沟通复盘、恋爱记录总结，不是日记 App，但适合生成“关系洞察/复盘文案” | `npx skills add https://github.com/lijigang/ljg-skills --skill ljg-relationship` |
| ★★★☆☆ | `reason-machines/trending-skills` / `tong-jincheng-relationship-skill` | 636 installs，约 83 stars | 恋爱/关系问题分析，风格更直白，适合做情感类口播内容参考 | `npx skills add https://github.com/reason-machines/trending-skills --skill tong-jincheng-relationship-skill` |
| ★★☆☆☆ | `geeks-accelerator/in-bed-ai` | 188 total installs，约 25 stars | dating/love/social/flirting 等互动类 skill；偏约会/社交，不是恋爱记录 | `npx skills add geeks-accelerator/in-bed-ai` |

> 建议：如果你的目标是“情侣恋爱记录产品”，不要只找 Skill；应优先看第 4 节的开源仓库，再结合上面的 relationship/love skill 做文案与总结。

### 3.2 视频相关 Skills

| 推荐度 | Skill / 仓库 | 安装量 / 星标 | 适合用途 | 安装命令 |
|---|---:|---:|---|---|
| ★★★★★ | `luoluoluo22/jianying-editor-skill` / `jianying-editor` | 2.0K installs，约 3.7K stars | 自动化剪映/CapCut 中文版、素材导入、字幕、配音、导出；最适合中文剪辑链路 | `npx skills add luoluoluo22/jianying-editor-skill` |
| ★★★★★ | `zenstory-ai/drama-skills` | 7.6K total installs，约 2.5K stars | 短剧脚本、角色资产、分镜、图片/视频提示词、短剧生产与审查 | `npx skills add zenstory-ai/drama-skills` |
| ★★★★☆ | `ecliptic-ai/skills` / `beat-sync-video-editing` | 705 total installs；beat-sync 688 installs | 音乐节拍同步剪辑、montage | `npx skills add ecliptic-ai/skills` |
| ★★★★☆ | `blitzreels/agent-skills` | 1.0K total installs；video-editing 518 installs | 短视频剪辑、切片、字幕主题、动效、无露脸视频 | `npx skills add blitzreels/agent-skills` |
| ★★★★☆ | `maxazure/video-editing-skill` / `video-editing` | 356 installs，约 193 stars | 口播/访谈视频自动剪辑、字幕烧录、片段合并 | `npx skills add maxazure/video-editing-skill` |
| ★★★★☆ | `narratorai-studio/narrator-ai-cli-skill` | 351 installs，约 3.0K stars | AI 解说/旁白类工作流，适合情感故事、情侣回忆口播 | `npx skills add narratorai-studio/narrator-ai-cli-skill` |
| ★★★☆☆ | `goldlegendw80/llm-video-maker` | 299 total installs | 一个 prompt 到 MP4，含旁白、字幕、音乐、真实素材 | `npx skills add goldlegendw80/llm-video-maker` |
| ★★★☆☆ | `awesome-genmedia/skills` | 426 total installs | 视频生成、视频编辑、背景移除、TTS、声音生成等多媒体 skill 包 | `npx skills add awesome-genmedia/skills` |

---

## 4. GitHub 高星仓库：情侣/恋爱记录方向

> 说明：情侣恋爱记录属于小众赛道，所以“高星”是相对本赛道而言。星标为 2026-10-04 搜索时的近似值。

| 星标 | 仓库 | 方向 | 适合你怎么用 |
|---:|---|---|---|
| 230 | https://github.com/keeleycenc/cc-our-story | 自托管情侣空间，记录彼此点滴与故事 | 最接近“情侣恋爱记录系统”的方向，可参考数据结构和页面组织 |
| 131 | https://github.com/bbblackclark/1024house | 本地私有情侣/家庭空间，礼账本、纪念日、宝宝成长、日常收支 | 如果想做私有化情侣/家庭空间，这个很值得看 |
| 106 | https://github.com/tech-kev/SharedMoments | Couples special moments / memories website | 适合做照片回忆、特殊时刻记录网站 |
| 71 | https://github.com/Yizack/mappedlove | 地图标记情侣一起去过的地方、上传照片 | 很适合做“我们的足迹地图”模块 |
| 65 | https://github.com/qiaeru/couplecards | 情侣抽活动卡片，打破日常 | 不是记录，但适合做互动玩法模块 |
| 64 | https://github.com/carlassmann/tilly | Relationship journal，离线 PWA，带 AI agent | 适合参考离线关系日记体验 |
| 63 | https://github.com/hoothin/QingLv | 情侣飞行棋互动小游戏 | 可作为情侣记录 App 的小游戏/互动模块 |
| 23 | https://github.com/Enderjua/valentine-mobile-app | Flutter 情侣/伴侣移动应用 | 适合移动端 UI/交互参考 |
| 16 | https://github.com/XTH-LOVE/Love- | CoupleSpace：相册、时光轴、悄悄话、纪念日、AI 日记、地图等 | 功能方向非常贴近，但星数较低，适合参考产品模块 |
| 10 | https://github.com/ibnusab/mylove | 私人数字 love diary，时间线、相册、音乐、倒计时、情书 | 适合参考“恋爱日记/纪念日”轻量化实现 |
| 9 | https://github.com/andrelcalado/nossas-lembrancas | Couple timeline generator | 适合参考时间线生成器 |

---

## 5. GitHub 高星仓库：视频/剪辑/生成方向

| 星标 | 仓库 | 方向 | 适合你怎么用 |
|---:|---|---|---|
| 128K+ | https://github.com/harry0703/MoneyPrinterTurbo | AI 自动短视频工作流，主题/关键词到高清视频 | 研究短视频自动化生产全流程 |
| 64K+ | https://github.com/FFmpeg/FFmpeg | 音视频底层处理工具 | 所有自动剪辑、转码、合成的基础工具 |
| 62K+ | https://github.com/calesthio/OpenMontage | 开源 agentic video production system，含大量工具/技能文件 | 最值得研究的 Agent 视频生产系统之一 |
| 56K+ | https://github.com/heygen-com/hyperframes | Write HTML, render video，面向 agents | 适合用 Web/HTML 动画生成视频素材 |
| 44K+ | https://github.com/mifi/lossless-cut | 无损视频/音频剪切 | 本地快速剪切素材 |
| 19K+ | https://github.com/KlingAIResearch/LivePortrait | 让头像/人像动起来 | 做情侣照片/头像动效视频很合适 |
| 19K+ | https://github.com/hypit-ai/hypit | AI agents 克隆/批量改造短视频工作流 | 适合研究批量短视频变体生产 |
| 15K+ | https://github.com/Zulko/moviepy | Python 视频编辑库 | 编程式剪辑、字幕、拼接、转场 |
| 14K+ | https://github.com/FujiwaraChoki/MoneyPrinter | MoviePy 自动生成 YouTube Shorts | 自动短视频脚本参考 |
| 12K+ | https://github.com/krillinai/OpenCreator | AI 创作者工作区，视频/图片/语音/头像/翻译/编辑 | 综合型创作平台参考 |
| 11K+ | https://github.com/linyqh/NarratoAI | AI 解说并剪辑视频 | 适合口播、解说、剧情视频 |
| 9.5K+ | https://github.com/YaoFANGUK/video-subtitle-extractor | 视频硬字幕提取生成 SRT | 适合从已有视频提取字幕 |
| 6.6K+ | https://github.com/OpenShot/openshot-qt | 开源桌面视频编辑器 | GUI 剪辑软件参考 |
| 6.4K+ | https://github.com/modelscope/FunClip | 转写、字幕、LLM 辅助切片 | 长视频切短视频、字幕生成 |
| 5.5K+ | https://github.com/mifi/editly | Declarative command-line video editing/API | 用 JSON/代码描述视频合成 |
| 3.7K+ | https://github.com/luoluoluo22/jianying-editor-skill | 自动化剪映/CapCut 中文版的 Agent Skill | 中文剪辑工作流首选之一，你已装过 |
| 3.0K+ | https://github.com/NarratorAI-Studio/narrator-ai-cli-skill | AI 解说大师 Agent Skill | 适合“恋爱故事解说/纪念日口播” |
| 2.1K+ | https://github.com/0xsline/OpenChatCut | 本地优先、对话式 AI 视频编辑器，含 Agent Skills/MCP | 适合研究交互式视频编辑产品 |

---

## 6. 我建议的组合方案

### 方案 A：做“情侣恋爱记录网站/小应用”

优先参考：

1. `cc-our-story`
2. `1024house`
3. `SharedMoments`
4. `mappedlove`
5. `mylove`

模块建议：

- 纪念日倒计时
- 时光轴/日记
- 相册/视频素材库
- 足迹地图
- 悄悄话/情书
- 情绪或关系复盘
- 一键生成纪念短视频

### 方案 B：做“情侣纪念日自动短视频”

建议链路：

1. 恋爱记录数据：照片、日期、地点、片段文字；
2. 文案：`ljg-relationship` 做关系复盘，或用普通 LLM 写甜/搞笑口播；
3. 视频：`jianying-editor`、`llm-video-maker`、`narrator-ai-cli-skill`、`zenstory-ai/drama-skills`；
4. 后期：FFmpeg/MoviePy/FunClip 处理字幕、拼接、转场。

### 方案 C：继续沿用你电脑已有的剪映自动化链路

你之前电脑上已有：

```text
E:\0mcp-agv-arena-optimized\skills\jianying-editor
```

可以在这个基础上继续做：情侣素材文件夹 -> 自动写文案 -> 自动配音 -> 自动字幕 -> 自动剪映/MP4 成片。

---

## 7. 优先安装建议

如果只想少装几个，我建议后续按这个顺序：

1. `lijigang/ljg-skills --skill ljg-relationship`：做恋爱记录总结/关系复盘文案。
2. `zenstory-ai/drama-skills`：做剧情、分镜、视频提示词。
3. `narratorai-studio/narrator-ai-cli-skill`：做解说/口播类内容。
4. `maxazure/video-editing-skill` 或 `blitzreels/agent-skills`：做自动剪辑、字幕、切片。
5. 已有的 `jianying-editor` 继续保留，最适合中文剪映落地。

---

## 8. 本报告主要来源

- https://github.com/vercel-labs/skills
- https://www.skills.sh/
- https://www.skills.sh/luoluoluo22/jianying-editor-skill
- https://www.skills.sh/lijigang/ljg-skills/ljg-relationship
- https://www.skills.sh/zenstory-ai/drama-skills
- https://www.skills.sh/narratorai-studio/narrator-ai-cli-skill
- https://www.skills.sh/maxazure/video-editing-skill
- https://www.skills.sh/blitzreels/agent-skills
- https://www.skills.sh/ecliptic-ai/skills
- GitHub repository search by topics: couple, couples, love-app, relationship-app, video-editing, video-generation, subtitles, ffmpeg, remotion
