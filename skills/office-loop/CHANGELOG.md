# 变更记录

## 2.0.0 — 2026-09-17（任务无关的架构）

**为什么**：v1 把"生成 docx/pptx + 本机 PPT Master 出稿"写死成技能本身，而那只是一种**默认测试任务**；
真实仓库的任务各不相同，有些必须装到用户机器上，有些在沙箱里做完推上去就行。

新增（都不动已验证的 Windows 路径）：

* `code/local_loop.py` — 任务无关的 runner：`plan` / `sandbox` / `local` / `gates`。
  配方（recipe）声明沙箱平面与本机平面、成品回执契约与证据；runner 从不猜"该在哪跑"。
* `code/recipes/*.json` + `code/loop.json` — 任务被抽成配置：`office-deck`（本案默认测试任务）
  与两个示例（纯沙箱任务、需要本机安装的任务）。换任务＝改一个文件。
* `code/gates.py` + `code/gates.json` — 门禁列表数据化（pre-commit 的思路，无依赖）：
  `severity: block|warn`、`plane: sandbox|local`，新增门禁＝加一条 JSON。
* `code/local_check.sh`、`code/pptmaster_local.sh`、`code/watch-linux.sh` +
  `templates/local-loop.{service,timer,cron}` — Linux/macOS 适配器（本机检查 / 本机执行 / 定时触发），
  编号与 Windows 版一致（3a–3h、4a–4c），"真应用打开"用 LibreOffice headless。
* 统一回执 `results/status/local_loop_receipt.{json,txt}`：任何任务/系统同一格式，
  含 `opened=`（真应用是否打开成功），可直接被 `success_criteria.json` 断言。
* `ARCHITECTURE.md`（两平面/五概念/判定矩阵/借自高 star 仓库的做法）与 `PORTING.md`
  （换任务、换系统、换身份、CI-only、真 Linux 首次检查清单）。

验证：Linux 平面在本沙箱端到端跑通（`loop-ok … os=linux ok=true deck_slides=12(/12)`，
`local_check.sh` gates + 交付物 3a–3g 全过，`watch-linux.sh` 对着 bare 远端完成一次完整轮次并 push verdict）；
Windows 路径保持 v1 的原文不动，由真机继续判定。

## 1.0.0 — 2026-09-16（本案成功案例）

* 把 `arena/01a0aa00-git-pull-arena` 的循环装成可安装技能：自带 payload、幂等安装器、
  两段机器已验证的 `local_check.ps1`、安装回执、payload 漂移门禁。
