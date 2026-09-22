# Task 1 — Phase D1 F1 Hardened Candidate

## 1. Executive Summary

An F1 candidate was implemented for `demo-api` alone. Candidate smoke passed: the actual application PID 1 runs as an unprivileged numeric user with zero capability masks and `NoNewPrivs: 1`; the root filesystem is read-only; the normal API request creates and updates its cache on `/tmp`; a nonessential `/app` create is denied; and the Phase B functional oracle passes. The existing backend remains the functional dependency. F2 and F3 were not remediated in D1. This is **F1 D1 candidate acceptance**, not Phase E formal BEFORE/AFTER proof.

## 2. Starting Context and Integrity

- D1 start commit: `b03c132e7ce37883f44f7cf54423c1e0ad7e1858`; branch `temp/work-in-progress`; initial working tree clean. The first timed pre-candidate observation was at or before `2026-09-22T04:11:57Z`.
- The owned `secops-lab` kind cluster, `kind-secops-lab` context, `secops-demo` namespace, and ownership record passed verification before mutation. Every SHA-256 row in the canonical Phase B [integrity record](evidence/phase-b/workload-revision.txt) matched before implementation; the record itself was unchanged. There was no unexpected baseline contradiction.
- Starting API Pod: `demo-api-b8dcfccdf-gnv9c`, UID `d5601ad2-6919-4d58-bedf-5b984f0be056`, `secops-demo-api:phase-b`, imageID `sha256:80e1fd9bd1afe996dfb03d6b2839c88d00fc3bca1269a74b10b13acf777a6e1f`. Starting backend Pod: `demo-backend-549b8f665f-npfsp`, UID `71156c57-8a45-46aa-a365-7566292e6d61`, imageID `sha256:89a9dc8d230e5115be9a00823b47811002332014d46f09548b11d2931f876d41`.
- `make task1-check` returned exit 0 and `FUNCTIONALITY = PASS` before candidate rollout. See [context](evidence/phase-d/d1-context.txt) and [pre-candidate function](evidence/phase-d/d1-pre-functional.txt).

## 3. F1 Implementation Decision

### Non-Root Identity

The image uses numeric `USER 65534:65534`, the pinned Debian Python base image's existing `nobody:nogroup` identity. This is a concrete, non-zero identity that Kubernetes can validate with `runAsNonRoot: true`. It fits the observed permissions: root owns readable `/app` (0755) and `app.py` (0644), while the mounted `/tmp` is writable by that UID. Root ownership and explicit image modes keep application code readable without making it application-owned or writable. `runAsUser` and `runAsGroup` were not added: the numeric image `USER` is the intended stable identity, and the Pod's non-root admission check plus actual PID 1 observation enforce/verify the relevant property without a second exact-identity pin. The numeric choice is an implementation decision, not a scanner requirement.

### Capability Control

The container drops `ALL` capabilities. The actual PID 1 `CapInh`, `CapPrm`, `CapEff`, `CapBnd`, and `CapAmb` are all zero. TCP/8080, backend HTTP, and health checks passed without an exception.

### Privilege-Gain Control

`allowPrivilegeEscalation: false` is set. The actual PID 1 reports `NoNewPrivs: 1`. Phase C demonstrated an absent restriction, not an earlier successful escalation.

### Read-Only Root Filesystem

`readOnlyRootFilesystem: true` is set. `/proc/1/mountinfo` shows `/` as a read-only overlay, corroborated by `statvfs`. `/app` resolves to that same root mount, has no separate writable mount, and retains root ownership. The harmless candidate-context `/app` create failed with `errno=30` (`EROFS`); the unique probe path was absent afterward.

### Writable /tmp Design

The Deployment mounts an ordinary ephemeral `emptyDir` at `/tmp`, with no persistence, memory backing, size setting, init container, or ownership mutation. Runtime inspection found the mount read-write, root-owned `0777`. The selected UID `65534` can therefore write it without `fsGroup`; the resulting cache file is owned `65534:65534`. The cache was absent in the new Pod before normal `/data` requests, then the application created it with the expected synthetic payload. A later normal `/data` call increased its modification time and retained the expected content. This is observed application behavior, not an assessor-created cache.

## 4. Hardened Image Lineage

The separate [Dockerfile](../task1/hardened/images/demo-api.Dockerfile) was built from unchanged `task1/app/demo-api` source with the pinned base `python:3.12.12-slim-bookworm@sha256:593bd06efe90efa80dc4eee3948be7c0fde4134606dd40d8dd8dbcade98e669c`. The local Phase B API tag retained ID `sha256:95dd04cfef5a6d31e10adf7b2371676f0a5ae11d94772790dbd8467ec627ff18` before and after the build. Candidate tag `secops-demo-api:phase-d1` has local ID `sha256:9837f584c9cdaf2c6ac3d5e1b4188908f25ae5a33ea8dceb4d822020b270eb3a` and `Config.User=65534:65534`. The deployed Kubernetes imageID is `sha256:cb82d20063553272d86db019ed015e599633f616535c8ffbed98eae1b5224e25`. The kind runtime reports a different imageID representation from the local Docker ID, as it did for Phase B; the tag, load, and Pod image fields bind the candidate lineage. See [build evidence](evidence/phase-d/d1-build.txt).

## 5. demo-api Candidate Runtime Evidence

The running candidate Pod is `demo-api-79fb54f895-xwdfz`, UID `e84b6903-2da2-4b39-a22a-ea3c2d6cd3cc`, IP `10.244.0.7`. PID 1 is `python app.py`, with all UID and GID slots equal to `65534`. All five capability masks are `0000000000000000`; `NoNewPrivs` is `1`. The root overlay is `ro`; `/app` inherits it and remains root-owned 0755 with root-owned 0644 `app.py`. `/tmp` is a distinct `rw` `emptyDir` mount, root-owned 0777. The application-owned cache contains `{"source":"demo-backend","value":"representative-data"}` and updated on a repeated successful request. The `/app` probe was denied with `EROFS`. The command and exact observations are in [runtime F1 evidence](evidence/phase-d/d1-runtime-f1.txt).

## 6. Functional Smoke Result

After rollout, `make task1-check` returned exit 0 and `FUNCTIONALITY = PASS`: backend `/healthz` and `/data`, API `/healthz`, first and repeated API `/data`, and cache-content inspection all passed. Backend logs recorded candidate API IP `10.244.0.7` as the source of two `/data` calls, supporting the API → backend path. The separate runtime smoke made another successful API `/data` call and confirmed the cache modification time advanced. Both Pods were Ready. See [candidate function evidence](evidence/phase-d/d1-candidate-functional.txt). The old Phase B script footer about H1–H4 is historical text and does not describe this candidate's security state.

## 7. F1 Candidate Acceptance

| D0 D-stage criterion | Actual D1 observation | Evidence |
| --- | --- | --- |
| Container starts and health passes | Candidate 1/1 Ready; API `/healthz` HTTP 200 | [functional](evidence/phase-d/d1-candidate-functional.txt) |
| API → backend `/data` works | First, repeat, and in-Pod calls HTTP 200; backend logs candidate IP | [functional](evidence/phase-d/d1-candidate-functional.txt), [runtime](evidence/phase-d/d1-runtime-f1.txt) |
| Legitimate cache write/readback works | Absent before normal request; application created expected data and updated mtime on repeat | [functional](evidence/phase-d/d1-candidate-functional.txt), [runtime](evidence/phase-d/d1-runtime-f1.txt) |
| Actual PID 1 non-root | UID/GID `65534:65534` in all status slots | [runtime](evidence/phase-d/d1-runtime-f1.txt) |
| Actual capability state at selected minimum | All five capability masks zero; no exception | [runtime](evidence/phase-d/d1-runtime-f1.txt) |
| Actual no-privilege-gain state | `NoNewPrivs: 1` | [runtime](evidence/phase-d/d1-runtime-f1.txt) |
| Root and `/app` mounts protected | Root `ro`; `/app` inherits root, no independent writable mount | [runtime](evidence/phase-d/d1-runtime-f1.txt) |
| Harmless `/app` create denied | Unique create failed `EROFS`; no path left | [runtime](evidence/phase-d/d1-runtime-f1.txt) |

All F1 D-stage candidate criteria passed. No D0 objective revision or capability exception was necessary. Formal same-oracle comparison remains Phase E after integration.

## 8. F2 Non-Interference

The baseline and candidate both use `serviceAccountName: demo-api`. Pod-level `automountServiceAccountToken` is unset in both; the existing ServiceAccount has `automountServiceAccountToken: true`. The D1 Pod still has a projected `kube-api-access` volume, and its token path remains process-readable; no token content was captured. The named `demo-api-fixture-access` Role still grants `get`/`patch` on `configmaps/phase-c-fixture`; its RoleBinding still references that Role and ServiceAccount subject. The backend ServiceAccount and Deployment were not changed. See [non-interference evidence](evidence/phase-d/d1-noninterference.txt). **F2 was not remediated in D1.** No workload-token GET/PATCH was repeated here.

## 9. F3 Non-Interference

No NetworkPolicy exists in `secops-demo` after D1. No CNI change occurred: kindnet image and imageID match the Phase C inventory. The two ClusterIP Services retained their selectors, ports, and addresses; backend Pod UID/imageID remained unchanged. Required API → backend calls still succeeded. See [non-interference evidence](evidence/phase-d/d1-noninterference.txt). No F3 negative reachability or enforcement test was run.

## 10. Compatibility Findings

Docker reported a missing buildx plugin and used its legacy builder; the pinned-base build and kind load succeeded. The first deploy-script run successfully rolled out the candidate, then exited 1 on an invalid mixed `kubectl get` display command. That display command was corrected and the script reran with exit 0, reporting the Ready candidate. No application or security-control compatibility failure remained.

## 11. Trade-offs / Implementation Decisions

The existing numeric `nobody:nogroup` identity avoids an added account and gives Kubernetes an unambiguous non-root image user. Exact `runAsUser`/`runAsGroup` fields were omitted because no compatibility or assurance gap appeared: the image user, admission setting, and PID 1 observation agree. The root-owned `0777` `emptyDir` was writable to the chosen UID without `fsGroup` or an init container. It is disposable Pod storage; its observed mode is part of this candidate's compatibility evidence. No seccomp or unrelated checklist control was added.

## 12. Files Created or Modified

- `task1/hardened/images/demo-api.Dockerfile`
- `task1/hardened/demo-api.yaml`
- `task1/hardened/scripts/build-f1.sh`, `deploy-f1.sh`, `smoke-f1.sh`
- `docs/evidence/phase-d/d1-context.txt`, `d1-pre-functional.txt`, `d1-build.txt`, `d1-candidate-functional.txt`, `d1-runtime-f1.txt`, `d1-noninterference.txt`
- `docs/phase-d-d1-report.md`

No `task1/app/**`, `task1/insecure/**`, backend candidate, `task1/kind.yaml`, prior evidence, canonical Phase C report, or D0 control plan was changed.

## 13. Runtime State at Exit

The owned `secops-lab` cluster remains on `kind-secops-lab`/`secops-demo`. `demo-api-79fb54f895-xwdfz` runs the Ready D1 candidate image `secops-demo-api:phase-d1` (Pod UID `e84b6903-2da2-4b39-a22a-ea3c2d6cd3cc`, imageID `sha256:cb82d20063553272d86db019ed015e599633f616535c8ffbed98eae1b5224e25`). `demo-backend-549b8f665f-npfsp` remains the original phase-b backend. F2 fixture RBAC and token automount remain; there is no NetworkPolicy; kindnet and Service topology remain. The final integrity and Git mutation checks are recorded below.

## 14. D1 Exit Decision

Every canonical Phase B hash still matches at exit. Protected BEFORE files and prior evidence remain unchanged. The final Git status contains only the five candidate files, six D1 evidence files, and this D1 report; no tracked file diff exists outside the authorized scope. Pre- and post-candidate functionality and the F1 runtime smoke passed. No unexplained compatibility issue remains. This is candidate acceptance only; D2 owns F2, D3 owns F3, and Phase E owns formal comparison.

D1 READY FOR F2 HARDENING
