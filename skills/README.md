# Skills index for this repo

This repository now treats "skills" as reusable, audited playbooks plus scripts.  Secrets and OAuth tokens stay on the user's own machines; the repo stores only code, non-secret status, and transfer artifacts.

## 1. Local bridge / git-sync

- Path: `skills/git-sync/`
- Purpose: Arena branch <-> GitHub <-> Windows machine round-trip, local watcher, receipts, local checks, hands-free pull/push.
- Use when: a task must run on the user's actual Windows laptop or another checked-out machine.
- Secret rule: GitHub credentials are handled by `gh`/GCM on the local machine, never committed.

## 2. Cloud and account interop

- Path: `skills/cloud-interop/`
- Purpose: connect local machines and agents to Google Drive, Kaggle, and other account-backed platforms via local-only credentials.
- Current Google Drive recommendation: `rclone` remote with browser OAuth.
- Current Kaggle recommendation: `kaggle.json` stays in `%USERPROFILE%\.kaggle\` or `KAGGLE_CONFIG_DIR`, never in git.
- Use when: files/results should move between GitHub, Google Drive, Kaggle notebooks/datasets, the laptop, desktop/HPC, or Muse.

## 3. Machine / compute interop

- Laptop watcher: driven by `skills/git-sync` and `code/tasks/manifest.json`.
- Desktop/HPC bridge: documented in `CONNECTIONS.md` and historical reports under `results/status/`.
- Muse: outbound-only flow documented in `results/muse/HANDOFF.md` and `results/muse/REQUEST_PROTOCOL.md`; poller script is `code/muse/muse_poll_once.sh`.
- Rule: if a machine cannot accept inbound connections, use GitHub branch directories or an approved cloud drive as the mailbox.

## 4. Office, browser, and GUI automation

- `skills/harness-anything/`: CLI/WPS/Office harness and Windows automation pieces.
- `skills/cell_ppt_edited/`: cell/PPT editing prototype code.
- Historical browser/Antigravity/Kaggle/Jianying/Qingjian reports live under `results/mcp_agv_lab/`, `results/antigravity/`, `results/input/`, and `code/tasks/`.

## 5. Security defaults

1. Never ask the user for passwords, OAuth tokens, API tokens, cookies, or 2FA codes.
2. Use browser OAuth or provider CLIs on the user's own machine.
3. Keep `rclone.conf`, `kaggle.json`, SSH keys, service-account JSON, subscription URLs, and proxy secrets outside the repo.
4. Reports may say "configured/present/verified" and may include public account names if the user requested them, but must not include credential material.
5. Use GitHub branch files for non-secret handoff; use Google Drive/Kaggle only after the local credential is configured.
