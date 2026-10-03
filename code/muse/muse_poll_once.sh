#!/usr/bin/env bash
# Poll one Muse task from results/muse/requests and complete the safe smoke_zip_v1 task.
# This script is intended to run on Muse's clone. It uses only outbound GitHub access.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
branch="$(git rev-parse --abbrev-ref HEAD)"
remote="origin"

if [ -n "${MUSE_NO_PULL:-}" ]; then
  echo "MUSE_NO_PULL set: skip git pull"
else
  git pull --rebase "$remote" "$branch"
fi

req="$(python3 - <<'PY'
import json, pathlib
reqs=[]
for p in pathlib.Path('results/muse/requests').glob('*.json'):
    try:
        d=json.loads(p.read_text(encoding='utf-8-sig'))
    except Exception:
        continue
    if d.get('state') == 'pending':
        reqs.append((d.get('created_at',''), str(p)))
reqs.sort()
print(reqs[0][1] if reqs else '')
PY
)"

if [ -z "$req" ]; then
  echo "No pending Muse request."
  exit 0
fi

echo "Picked request: $req"

type="$(python3 - "$req" <<'PY'
import json,sys
d=json.load(open(sys.argv[1], encoding='utf-8-sig'))
print(d.get('type',''))
PY
)"

if [ "$type" != "smoke_zip_v1" ]; then
  python3 - "$req" <<'PY'
import json, sys, datetime
d=json.load(open(sys.argv[1], encoding='utf-8-sig'))
d['state']='failed'
d['error']='unsupported task type: ' + str(d.get('type',''))
d['completed_at']=datetime.datetime.utcnow().replace(microsecond=0).isoformat()+'Z'
open(sys.argv[1],'w',encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2)+'\n')
PY
  git add "$req"
  git commit -m "muse: reject unsupported request $(basename "$req" .json)" || true
  git push "$remote" "$branch"
  exit 2
fi

python3 - "$req" <<'PY'
import datetime, getpass, hashlib, json, os, pathlib, platform, socket, sys, tempfile, zipfile
req_path=pathlib.Path(sys.argv[1])
d=json.loads(req_path.read_text(encoding='utf-8-sig'))
task_id=d['task_id']
artifact=pathlib.Path(d.get('expected_artifact') or f'sources/muse/{task_id}.zip')
status_path=pathlib.Path(d.get('expected_status') or f'results/muse/status_{task_id}.json')
artifact.parent.mkdir(parents=True, exist_ok=True)
status_path.parent.mkdir(parents=True, exist_ok=True)

now=datetime.datetime.utcnow().replace(microsecond=0).isoformat()+'Z'
with tempfile.TemporaryDirectory() as td:
    root=pathlib.Path(td)
    (root/'outputs').mkdir()
    (root/'logs').mkdir()
    readme=(
        f'{task_id} - Muse automatic trigger smoke test\n'
        f'created_at_utc={now}\n'
        f'host={socket.gethostname()}\n'
        f'user={getpass.getuser()}\n'
        f'platform={platform.platform()}\n'
        'This package proves Muse detected a pending GitHub request and pushed the result back.\n'
    )
    (root/'README.txt').write_text(readme, encoding='utf-8')
    (root/'outputs'/'hello_from_muse.txt').write_text('hello from Muse via GitHub-triggered poller\n', encoding='utf-8')
    (root/'logs'/'run.txt').write_text(f'completed {task_id} at {now}\n', encoding='utf-8')
    with zipfile.ZipFile(artifact, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in sorted(root.rglob('*')):
            if p.is_file():
                z.write(p, p.relative_to(root).as_posix())

h=hashlib.sha256(artifact.read_bytes()).hexdigest()
status={
    'task_id': task_id,
    'state': 'done',
    'created_by': 'muse',
    'completed_at': now,
    'artifact': artifact.as_posix(),
    'bytes': artifact.stat().st_size,
    'sha256': h,
    'notes': 'Automatic smoke task completed by Muse poller.'
}
status_path.write_text(json.dumps(status, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

d['state']='done'
d['completed_at']=now
d['artifact']=artifact.as_posix()
d['status_file']=status_path.as_posix()
d['sha256']=h
req_path.write_text(json.dumps(d, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(status, ensure_ascii=False, indent=2))
PY

git add "$req" sources/muse results/muse
if git diff --cached --quiet; then
  echo "Nothing to commit."
else
  git commit -m "muse: complete request $(basename "$req" .json)"
fi
git push "$remote" "$branch"
echo "Muse request completed and pushed: $req"
