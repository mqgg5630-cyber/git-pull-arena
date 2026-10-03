# Muse task bridge (outbound-only Tailscale)

Muse is an outbound-only Tailscale client. Do **not** design tasks that require the laptop or Arena sandbox to connect into Muse. Use one of these flows instead.

## Flow A - simplest: chat attachment / download link

Muse finishes work, zips the outputs, and sends either an attachment or a temporary download link.

Zip naming:

```text
muse_out_YYYYMMDD_HHMM.zip
```

Zip layout:

```text
README.txt                       # what was done, commands, important paths
outputs/...                      # generated files
logs/...                         # optional logs
```

## Flow B - long-running bridge via GitHub (Muse pushes outbound)

Shared branch for this Arena session:

```text
arena/01a0ff69-git-pull-arena
```

Repository:

```text
https://github.com/mqgg5630-cyber/git-pull-arena.git
```

Directory convention:

```text
sources/muse/        # Muse -> laptop/Arena inputs
results/muse/        # status JSON, logs, task receipts
deliverable/muse/   # Arena/laptop -> Muse outputs or final packaged files
```

Muse-side one-time clone, if GitHub auth is already configured there:

```bash
git clone -b arena/01a0ff69-git-pull-arena https://github.com/mqgg5630-cyber/git-pull-arena.git git-pull-arena-muse
cd git-pull-arena-muse
mkdir -p sources/muse results/muse deliverable/muse
```

Muse uploads a result zip:

```bash
cd git-pull-arena-muse
git pull --ff-only origin arena/01a0ff69-git-pull-arena
mkdir -p sources/muse results/muse
cp /path/to/muse_out_YYYYMMDD_HHMM.zip sources/muse/
cat > results/muse/latest_status.json <<'JSON'
{
  "state": "uploaded",
  "file": "sources/muse/muse_out_YYYYMMDD_HHMM.zip",
  "note": "short description of the result"
}
JSON
git add sources/muse results/muse
git commit -m "muse: upload result package YYYYMMDD_HHMM"
git push origin arena/01a0ff69-git-pull-arena
```

Arena/laptop will then see it on the next pull / watcher poll.

## Flow C - laptop share, Muse pulls outbound

If Muse needs a file from the laptop and Tailscale allows Muse to initiate outbound connections, the laptop can expose a Windows share. Muse then pulls from:

```text
\\100.71.123.19\<share-name>
```

Use this only for explicit file-transfer tasks. Do not rely on Muse accepting inbound connections.

## Task status schema

When Muse pushes results through GitHub, write a small status file:

```json
{
  "task_id": "muse-YYYYMMDD-HHMM",
  "state": "uploaded",
  "artifact": "sources/muse/muse_out_YYYYMMDD_HHMM.zip",
  "created_by": "muse",
  "notes": "what is inside the zip"
}
```
