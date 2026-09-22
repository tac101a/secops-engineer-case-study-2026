#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"

require_cluster
pod="$(k get pods -l app=demo-api -o json | python3 -c '
import json, sys
pods = [p for p in json.load(sys.stdin)["items"]
        if p["spec"]["containers"][0]["image"] == "secops-demo-api:phase-d1"
        and not p["metadata"].get("deletionTimestamp")]
assert len(pods) == 1, f"Expected exactly one active D1 Pod, found {len(pods)}"
print(pods[0]["metadata"]["name"])
')"
[[ -n "$pod" ]] || die 'No demo-api Pod found.'
printf 'UTC: %s\n' "$(date -u +%FT%TZ)"
k get pod "$pod" -o jsonpath='Pod={.metadata.name} UID={.metadata.uid} IP={.status.podIP} image={.spec.containers[0].image} imageID={.status.containerStatuses[0].imageID}{"\n"}'
k exec -i "$pod" -c demo-api -- python3 - <<'PY'
import errno
import json
import os
from pathlib import Path
import stat
import time
from urllib.request import urlopen
from uuid import uuid4

expected = {"source": "demo-backend", "value": "representative-data"}
status = {}
for line in Path("/proc/1/status").read_text().splitlines():
    if ":" in line:
        key, value = line.split(":", 1)
        status[key] = value.strip()
print("PID 1 command:", Path("/proc/1/cmdline").read_bytes().replace(b"\0", b" ").decode().strip())
for key in ("Uid", "Gid", "CapInh", "CapPrm", "CapEff", "CapBnd", "CapAmb", "NoNewPrivs"):
    print(f"{key}: {status[key]}")
assert list(map(int, status["Uid"].split())) == [65534] * 4
assert list(map(int, status["Gid"].split())) == [65534] * 4
assert all(int(status[key], 16) == 0 for key in ("CapInh", "CapPrm", "CapEff", "CapBnd", "CapAmb"))
assert status["NoNewPrivs"] == "1"
print("Probe process UID/GID:", os.geteuid(), os.getegid())
assert (os.geteuid(), os.getegid()) == (65534, 65534)

mounts = []
for line in Path("/proc/1/mountinfo").read_text().splitlines():
    left, right = line.split(" - ", 1)
    fields = left.split()
    mounts.append((fields[4], fields[5], right.split()[0]))
def mount_for(path):
    return max((m for m in mounts if path == m[0] or path.startswith(m[0].rstrip("/") + "/")), key=lambda m: len(m[0]))
for path in ("/", "/app", "/tmp"):
    m = mount_for(path)
    s = os.stat(path)
    ro = bool(os.statvfs(path).f_flag & os.ST_RDONLY)
    print(f"{path}: mountpoint={m[0]} options={m[1]} filesystem={m[2]} statvfs_readonly={ro} owner={s.st_uid}:{s.st_gid} mode={oct(stat.S_IMODE(s.st_mode))}")
assert mount_for("/")[0] == "/" and "ro" in mount_for("/")[1].split(",")
assert mount_for("/app")[0] == "/" and bool(os.statvfs("/app").f_flag & os.ST_RDONLY)
assert mount_for("/tmp")[0] == "/tmp" and not bool(os.statvfs("/tmp").f_flag & os.ST_RDONLY)
print("/app/app.py:", os.stat("/app/app.py").st_uid, os.stat("/app/app.py").st_gid, oct(stat.S_IMODE(os.stat("/app/app.py").st_mode)))

cache = Path("/tmp/demo-cache.json")
assert cache.exists(), "Application cache must already exist after normal /data request"
assert json.loads(cache.read_text()) == expected
before = cache.stat().st_mtime_ns
print("Cache before repeat: owner=%s:%s mtime_ns=%s content=%s" % (cache.stat().st_uid, cache.stat().st_gid, before, json.dumps(expected, sort_keys=True)))
assert (cache.stat().st_uid, cache.stat().st_gid) == (65534, 65534)
time.sleep(0.03)
with urlopen("http://127.0.0.1:8080/data", timeout=5) as response:
    payload = json.load(response)
    print("Repeat GET /data:", response.status, payload)
    assert response.status == 200 and payload == expected
after = cache.stat().st_mtime_ns
assert after > before and json.loads(cache.read_text()) == expected
print("Cache after repeat: mtime_ns=%s updated=%s" % (after, after > before))

probe = Path("/app/phase-d1-f1-probe-" + uuid4().hex)
print("/app probe path:", probe)
try:
    with probe.open("xb") as output:
        output.write(b"phase-d1\n")
except OSError as exc:
    print("/app write: DENIED errno=%s reason=%s" % (exc.errno, exc.strerror))
    assert exc.errno in (errno.EROFS, errno.EACCES, errno.EPERM)
else:
    probe.unlink(missing_ok=True)
    raise AssertionError("Nonessential /app write unexpectedly succeeded")
assert not probe.exists()
print("F1 CANDIDATE RUNTIME SMOKE = PASS")
PY
