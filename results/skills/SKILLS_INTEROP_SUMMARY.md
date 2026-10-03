# Skills interop summary

Updated: 2026-10-03

## What changed

- Added `skills/README.md` as the top-level skill map.
- Added `skills/cloud-interop/` for Google Drive, Kaggle, local multi-account, HPC/desktop/Muse, and cross-platform handoff guidance.
- Added `setup-gdrive-rclone.ps1`, which installs official rclone, verifies SHA256SUMS, and starts browser OAuth for a Google Drive remote.
- Added `interop-health.ps1`, which writes a non-secret health report for Git, rclone/Google Drive, Kaggle, Tailscale, and Muse protocol status.

## Recommended Google Drive plan

For the requested Gmail account, use one local rclone remote named `gdrive_jzthjyz`. The user must complete one browser OAuth consent on the Windows machine. No Google password, 2FA code, OAuth token, cookie, or refresh token should be sent to Arena or committed.

After OAuth, run a health report with optional probe write to prove the Drive connection:

```powershell
.\skills\cloud-interop\scripts\interop-health.ps1 -GDriveRemote gdrive_jzthjyz -ProbeWrite
```

The report lands at `results/cloud_interop/INTEROP_HEALTH.md` and can be pushed through git-sync.

## Skill categories now used

1. Local bridge: `skills/git-sync/`
2. Cloud/accounts: `skills/cloud-interop/`
3. Machine/compute: laptop watcher, desktop/HPC routes, Muse outbound poller
4. Data platforms: Google Drive and Kaggle, with local-only credentials
5. Office/UI automation: `skills/harness-anything/`, `skills/cell_ppt_edited/`, historical Antigravity/browser/Qingjian/Jianying task scripts

## User input still needed for Google Drive

- Confirm Drive permission scope: full read/write (`drive`), read-only (`drive.readonly`), or limited app-file scope (`drive.file`).
- Confirm whether to use the whole Drive, a folder, or a Shared Drive/folder id.
- Be at the Windows machine once to approve the Google OAuth browser prompt.
- Confirm whether a small `Arena/interop/` probe file may be written.
