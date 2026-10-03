# Muse GitHub-trigger protocol

Because Muse is outbound-only on Tailscale, Arena/laptop cannot connect into Muse.
Automatic triggering therefore works by **polling this GitHub branch**:

1. Arena writes a pending request JSON under `results/muse/requests/`.
2. Muse periodically runs `git pull --rebase` and scans for `state: pending`.
3. Muse performs the task locally.
4. Muse writes outputs to `sources/muse/`, status to `results/muse/`, marks the request `done`, commits, and pushes.
5. Laptop watcher / Arena pulls the result and continues.

## Request schema

```json
{
  "task_id": "muse-smoke-20261003-1718",
  "state": "pending",
  "type": "smoke_zip_v1",
  "created_by": "arena",
  "created_at": "2026-10-03T09:18:00Z",
  "instructions": "Human-readable task description.",
  "expected_artifact": "sources/muse/muse_out_smoke_20261003_1718.zip",
  "expected_status": "results/muse/status_smoke_20261003_1718.json"
}
```

## State values

- `pending`: Muse should pick it up.
- `running`: optional intermediate state if Muse wants to push progress.
- `done`: task completed; `artifact` and `status_file` should be set.
- `failed`: task failed; `error` should be set.

## Muse poller

Run once:

```bash
bash code/muse/muse_poll_once.sh
```

Run continuously:

```bash
while true; do
  bash code/muse/muse_poll_once.sh || true
  sleep 60
done
```

A cron entry is also fine. The poller never requires inbound network access; it only pulls/pushes GitHub.
