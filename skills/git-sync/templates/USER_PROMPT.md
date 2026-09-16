# 用户往新 Arena 会话里粘这一段（不要只贴 arena.ai 链接）

对方沙箱**打不开** `arena.ai/agent/...`（要登录），一打不开就会自己写 python，把 `.venv` 当成「本机」。
技能包在 **GitHub**，必须让对方执行下面的 clone。

---

把下面整段复制进新会话：

```text
不要打开 arena.ai，不要自己写 python skill，不要建 local/inbox，不要用 .venv 冒充本机。

第一步，只做这个（命令不要改）：
git clone --quiet --depth 1 -b arena/01a0a821-git-pull-arena https://github.com/mqgg5630-cyber/git-pull-arena.git /tmp/git-sync-src && bash /tmp/git-sync-src/skills/git-sync/scripts/agent-install.sh && bash skills/git-sync/scripts/agent-sync.sh "feat: install git-sync skill"

装完根目录必须有 watch.ps1。没有 = 没装上，停止。

第二步，你的第一条回复只能是填好的本机 PowerShell（把 BRANCH、仓库 URL、新文件夹换成真值；禁止覆盖 git-pull-arena / git-pull-arena-v268 / git-pull-arena-s2）：

cd E:\0github\git-sync
git clone -b <BRANCH> <ORIGIN_URL> <NEW_FOLDER>
cd <NEW_FOLDER>
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\bootstrap.ps1 -Auto
.\doctor.ps1
.\watch.ps1 -Status

「与本地打通」= 用户 Windows 跑完上面这段后 .\watch.ps1 -Status 看得到值守。在发出这段 PowerShell 之前：不许生成 docx/pptx，不许说已打通。

第三步（PowerShell 已经发给用户之后）：把任务产物放到 deliverable/，写 results/status/success_criteria.json，然后：
bash skills/git-sync/scripts/agent-handsfree.sh --sync "feat: deliverables" --request "verify deliverables" --timeout auto
exit 3 = 本机值守还没有，再贴一次 PowerShell，不要假装成功。
```

任务若不是 docx/pptx，只改第三步那句 verify 和产物路径，前两步不要动。
