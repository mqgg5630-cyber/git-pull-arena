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
