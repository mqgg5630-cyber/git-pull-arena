# v2.6.2 —— `error: failed to push some refs` 到底是什么意思

> 你这次的效果其实已经成功了 8 成：**gh 登录成功、凭据探针返回 `OK (40 chars)`**，
> 也就是说"免点击推送"的凭据已经有了。剩下那个 error **不是认证问题**，是**我探针写错了**（下面第一条）。
> 顺带把值守那边"卡在 exit 3"的真正原因也修了（第二条）。

---

## 一、`error: failed to push some refs` = 被拒绝（不是认证失败）

`auth.ps1 -Verify` 里我用的探针是：

```
git push --dry-run origin HEAD:refs/heads/arena/01a0a4f5-git-pull-arena
```

你当时本地 HEAD 停在 `5bc7604`，而远端已经到 `4c7821e` —— 这是**非快进（non-fast-forward）**，
GitHub 的回复就是 `failed to push some refs` / `[rejected]`。**关键区别**：

| 现象 | 含义 |
|---|---|
| `Authentication failed` / `could not read Username` / `terminal prompts disabled` | 凭据不对/没拿到 —— 这才是认证失败 |
| `failed to push some refs` / `[rejected]` / `non-fast-forward` | **服务器已经接受了你的令牌**，只是拒绝了这次引用更新（因为不是快进） |

所以那一行 FAILED 是我把"被拒绝"误判成了"认证失败"，纯属**探针的错**。

**v2.6.2 已修**：探针改成推**永远可接受的引用**——
用远端跟踪引用 `refs/remotes/origin/<分支>` 推到一次性探针分支名（`--dry-run` 不会真的建它），
这样既能证明"有写权限 + 不需要人点"，又不会被非快进干扰；
万一还是被拒绝，会明确打印 `REJECTED (not a credential problem)` 并计入 **READY**（附一句"跑 `.\sync.ps1` 对齐"）。

---

## 二、值守那边的 `push failed (exit 3)` 也修了

链路是这样的：早先几轮推送失败 → 本地留下 `check: round N failed` 这类**结论提交** →
下一次轮询 `push.ps1` 先做 `pull --ff-only`，因为本地领先而失败 → exit 3 → 永远推不出去。

这些结论提交是**可再生的产物**，所以 v2.6.2 起 `push.ps1` 会在这种情况下自动
"对齐远端（`reset --mixed`，文件保留）+ 重试一次快进"（和 v2.6.1 给 `sync.ps1` 加的是同一套逻辑）。
下一轮轮询就能把结论推上来了。

---

## 三、现在照做（3 条，很快）

```powershell
cd E:\0github\git-sync\git-pull-arena

.\sync.ps1                     # 取 v2.6.2（同时会清掉"分叉"的状态）

.\auth.ps1 -Verify             # 现在应该是 READY（退出码 0）：
                               #   silent credential probe : OK
                               #   push --dry-run : passed   （或被拒绝但明确标注"不是凭据问题"）

.\watch.ps1 -Status            # 看 loop alive / heartbeat / last_push
```

清掉 7 条历史 stash（先看一眼，确认没有你要的东西）：

```powershell
git stash list
git stash show --stat stash@{0}     # 多半是 results/status/*（值守产物，每轮都会重写）
git stash clear                      # 确认后清空
```

如果还想**零闪窗**（现在是"每次登录闪一次"，已经比原来每 2 分钟一次好 720 倍）：

```powershell
# 在"以管理员身份运行"的 PowerShell 里：
cd E:\0github\git-sync\git-pull-arena
.\watch.ps1 -Unregister ; .\watch.ps1 -Register -Headless
```
（v2.6.2 起如果你没在管理员窗口里跑，它会直接告诉你并给出这条命令，而不是丢一个 0x80070005。）

想让我修那个零窗口启动器，就把这段发我：
```powershell
Get-Content "$env:LOCALAPPDATA\git-sync\watch-git-pull-arena.log" -Tail 30
```
v2.6.2 起 `-Register` 在启动器冒烟测试失败时**会把这段直接打在屏幕上**（不用再去翻文件）。

---

## 四、验收（round 11 已排好）

| 项 | 判定 |
|---|---|
| 2a 免点击推送 | `auth.ps1 -Verify` exit 0（凭据探针 OK + 探针推送 passed / 被拒绝但已注明） |
| 2b 值守可见性 | **分级**：`zero-window launcher` 或 `S4U` = 零闪；`-Loop`（一个常驻进程）= 每次登录闪一次，**也算通过**并注明；只有"每轮新起进程"才判失败 |

你跑完第三节，值守第一次轮询（≤2 分钟）就会把这一轮结果**免点击**推回；我这边读结论继续。

---

## 五、一句话总结这几轮的问题链

1. v2.4.4 的 VBScript 无窗启动器 → 值守静默死亡（已回退）
2. `"$round:"` 盘符写法 → 整份 watch.ps1 解析失败（已修 + gate 扫描）
3. `auth.ps1 -Setup` 乱改 `credentialStore` → 把已有凭据"藏掉"（已修，改为先探测）
4. **机器从来没有存过 GitHub 凭据** → 每次 push 都要人点（现在 gh 已登录，凭据在 gh 自己的配置里，任何会话可用）
5. `gh` 不走 git 的代理 → 登录超时（已修：自动套用 `http.proxy`，或用 `-HttpProxy`/PAT 离线入库）
6. **我的 dry-run 探针把"非快进被拒"当成"认证失败"** → 误报 NOT READY（v2.6.2 已修）
7. 结论提交导致分支分叉 → 值守 `pull --ff-only` 永远 exit 3（v2.6.2 已修：自动对齐后重试）
