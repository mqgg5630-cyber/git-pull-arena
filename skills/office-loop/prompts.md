# 给下一个会话用的提示词

## 直接粘贴（和本案一模一样的开场）

**第一轮**

```
安装<你的会话链接/仓库>的skills，与本机 [<conda env>](base) PS <仓库父目录> 打通
```

例：`安装 https://arena.ai/agent/<会话ID> 的skills，与本机 [spyder](base) PS E:\0github\git-sync 打通`

**第二轮**

```
先清理掉其他任务并开始自循环：生成 docx 和 pptx，推到本会话分支，本机检查后把状态 push 回来，一直循环到你觉得没问题为止。
```

> **助手注意**：**不要打开 arena.ai 链接**。把它映射到 GitHub：会话 ID `01a0aa00`
> → 仓库分支 `arena/01a0aa00-git-pull-arena`（`https://github.com/mqgg5630-cyber/git-pull-arena`）。
> 第 1 轮装 git-sync（`skills/git-sync/`），第 2 轮装 office-loop（`skills/office-loop/`）。

## 追加要求（本案实际用过的，可按需加）

```
你能直接装进我的本地吗，你写代码自循环验证装成功没有，自循环验证生成好ppt了没有
```

```
这个不是之前就有的，那你再生成一份，不要覆盖
```

```
自循环任务，同时主题换位<新主题>，用我电脑的安装好的venv环境生成
```

## 装好之后，助手该说什么

说清楚**三个证据**都在机器推回来的文件里，而不是"我这边测试通过了"：

1. 本轮判定：`results/status/check_r<N>_*.txt` 里的 `4a / 4b / 4c`；
2. 回执：`results/status/pptmaster_local.txt`（`environment=windows … powerpoint=yes`）；
3. 成品与质检：`results/<evidence_dir>/` 下的 pptx + `pptmaster_local_quality.json` + `svg/`。

## 不给用户添麻烦的三条约定（本案验证过）

* **粘贴块只发一次**：第一次打通时的 `agent-handoff.sh` 块；之后每轮都是自动的，别再让用户点。
* **不覆盖**：新主题一定用自己的 `deck_name` 与项目目录，并在日志里打印 `out before/after` 作证。
* **不编数据**：仓库里没有的数据，页面上一律标"示例"，并把替换点写在页源里。

## 任务因仓库而异（v2）

上面那两轮提示词里的「生成 docx 和 pptx」只是**本案的默认测试任务**。真实仓库的任务要按它自己的目标写，
助手应该做的是：**先把任务写成配方，再跑循环**。

```
提示词示例 A（纯沙箱就够的任务）
  在这个仓库里把 <任务> 做出来并推到本会话分支：跑测试、修到全绿、把产物 commit 上去；
  证明责任在沙箱（配方 local.skip 写明理由），不需要我本机参与。

提示词示例 B（必须装到我机器上的任务）
  把这套工具装到我的机器上（<路径/环境>），并且在机器上证明它真的能用：
  写一个配方说清楚装什么、怎么验、回执里必须有哪几个键；沙箱只做能做的部分。

提示词示例 C（Linux 本机）
  我的机器是 Linux（<发行版>），仓库在 <路径>，用 systemd --user 或 cron 起值守；
  code/local_check.sh 是我的机器检查入口，验证结果照旧 push 回来。
```

助手在这三种情况下的动作差别只有一处：**配方里 `sandbox` / `local` 两个平面怎么分**（见 ARCHITECTURE.md 的判定矩阵）。
其余（门禁、回执格式、验收标准、一轮到底的循环命令）完全一样。
