# Task 1 — Phase B Execution Report

## 1. Executive Summary

Phase B implements the representative permissive baseline specified in
[task1/BASELINE.md](../task1/BASELINE.md). It uses two small Python services and
one local kind node. Legitimate operating budgets were documented before the
application and manifests were created. H1–H4 remain hypotheses.

Both images built and loaded successfully; both Deployments are Ready/Running.
On 2026-09-21 at 16:33 UTC, both health checks, backend data, repeated API data
and the legitimate `/tmp` cache check passed. The representative permissive
baseline is functional and ready for security assessment. The cluster remains
running. No security assessment, hardened manifests, admission policies, CI
security gates, Task 2 work, commits, pushes or branch changes are included.

## 2. Inputs and Source of Truth

Priority: official [case-study PDF](case-study-secops-engineer-2026.pdf), approved
[architecture](architecture.md), original Phase B execution specification, then
repository documentation. The resume request additionally required inspecting
every current modified/untracked Phase B file and preserving valid existing work.

Task 1 of the official PDF (pages 1–3) explicitly permits a simple representative
workload with constructed workload/manifest mistakes and assumes the Kubernetes
platform is securely configured. Its broader assessment, remediation, prevention
and rollout deliverables belong to subsequent phases. This report is an
intermediate review artifact, not the assignment's final 3–5 page submission PDF.

The PDF was extracted using an ephemeral Python standard-library helper and read
during the initial work. Its requirements support Phase A. Phase A's statement
that the official assignment was unavailable records its historical inputs; the
PDF is now available. No architecture correction was necessary or made.

## 3. Repository State Before Phase B

Initial base commit: `f591c50d3eacebf93f2fbf5938a28d1d3649bb2c`, branch `main`,
clean tracked working tree. `task1/` and the root Makefile were empty. Existing
README, ignore rules, architecture and official PDF were preserved.

On resumption, `git status --short --untracked-files=all` and every Phase B file
were inspected, including hidden `.dockerignore` files. The working tree already
contained the contract, six application files, four workload manifest files,
kind configuration, six scripts, Make targets, README/ignore changes and three
evidence files. There was no report, application image or surviving kind cluster.
The original failed cluster attempt remained in `cluster-up.txt`.

| Exit-criteria group at resumption | State before continuation |
| --- | --- |
| Architecture read; contract and all five budgets; both application implementations; permissive manifests; phase boundaries | Complete as source artifacts; revalidated. |
| Reproduction instructions/scripts; environment evidence; self-review | Partially complete: authored/collected, but not yet validated by a successful run or complete review. |
| Local cluster creation | Partially complete: attempted and failed; kind removed its failed node. |
| Image build, application deployment, health/flow/cache verification | Not started; no success evidence or images. |
| Full execution report, evidence index, final exit review and file reconciliation | Not started. |

Continuation began with the failed environment setup, preserving the application
and workload manifests. [Resume evidence](evidence/phase-b/resume-state.txt)
records the actual empty Docker/kind state and the still-installed CLIs.

## 4. Baseline Design Decisions

### 4.1 Application Topology

Operator test client → `demo-api:8080` → `demo-backend:8081`, each a single-replica
Deployment with a ClusterIP Service in `secops-demo`. One control-plane node in
`secops-lab`; no ingress, database, cloud dependency, extra application service,
data volume or HA topology. Operator access uses temporary loopback port-forwards.

### 4.2 Functional Contract

Both `/healthz` endpoints return HTTP 200 and `{"status":"ok"}`. Backend `/data`
returns `{"source":"demo-backend","value":"representative-data"}`. API `/data`
fetches and validates that response, writes `/tmp/demo-cache.json`, then returns
the same JSON. A repeat request performs a new dependency call and write. There
is no cached-success fallback, timestamp or random response field.

Dependency errors produce 502, cache write errors produce 500, and unknown GET
paths produce 404. Health endpoints report process health; they do not prove the
dependency works. End-to-end `/data` verification provides that separate check.

### 4.3 Local Privilege Budget

No root, privileged mode, additional capabilities, privilege escalation,
privileged ports, host namespaces or host filesystem access is required by either
application. Ordinary unprivileged operation is the design requirement; future
compatibility with hardened settings has not been runtime-tested in this phase.

### 4.4 Kubernetes API Permission Budget

Both applications require **no Kubernetes API permissions** or workload token
use. DNS supplies backend discovery. The synthetic ConfigMap is not mounted,
referenced as environment configuration or read by the application.

### 4.5 Network Communication Budget

The authoritative matrix is in [BASELINE.md](../task1/BASELINE.md). Required paths
are client → API TCP/8080, API → backend TCP/8081, API → DNS UDP/TCP 53, kubelet
health probes and explicitly identified operator diagnostic access to backend.
Responses on those connections are required. Unrelated callers and destinations,
application API-server access and Internet egress have no legitimate runtime use.
The backend requires no new outbound application connections. Namespaces alone
are not considered security boundaries.

### 4.6 Filesystem Write Budget

Only API `/tmp/demo-cache.json` is required, as disposable container-lifetime
data. The backend needs no application filesystem writes. Python bytecode writes
are disabled; logs use stdout/stderr. No durable storage is required or claimed.

## 5. Representative Baseline Conditions

### 5.1 H1 Fixture

Both Dockerfiles explicitly specify `USER 0`. Workload manifests omit non-root,
capability-drop and privilege-escalation restrictions. This represents application
configuration focused on running successfully. There is no privileged application
container, host namespace or hostPath. Runtime privilege assessment is deferred.

### 5.2 H2 Fixture

Dedicated `demo-api` and `demo-backend` ServiceAccounts explicitly retain automatic
token mounting. Only `demo-api` receives the Role/RoleBinding permitting core API
`get` and `patch` on `configmaps`, restricted by `resourceNames` to
`phase-c-fixture` in `secops-demo`. No wildcard, Secret or cluster-wide grant is
introduced. The fixture contains synthetic `marker: baseline`, reserved for later
bounded assessment. No workload-credential API request or fixture mutation was
performed in Phase B. Dedicated identity does not establish least privilege.

### 5.3 H3 Fixture

The two Services exist without workload NetworkPolicy. Only intended application
connections are verified here. Missing policy does not prove any unintended
connection. A later untrusted-source → backend test needs an assessor-provisioned
source; compromised-API → unrelated-target testing needs a declared synthetic
target. Neither gives the initial attacker permission to create arbitrary Pods.

### 5.4 H4 Fixture

Both workloads specify `readOnlyRootFilesystem: false`; there are no application
data volumes. The API's only required write is under `/tmp`. No write outside the
budget or storage-lifecycle persistence experiment is performed in Phase B.

## 6. Application Implementation

Two standard-library `HTTPServer` programs, with no framework, dependencies or
added operating-system packages. API dependency timeout is three seconds and its
response read is bounded to 4,097 bytes, rejecting more than 4,096 bytes or data
that differs from the fixture. A successful response follows a successful write.
Single-threaded serving is adequate for this small local demonstration; load,
authentication, TLS and production server design are outside this contract.

Both images use `python:3.12.12-slim-bookworm` pinned to multi-platform digest
`sha256:593bd06efe90efa80dc4eee3948be7c0fde4134606dd40d8dd8dbcade98e669c`.
Docker contexts admit only the Dockerfile and `app.py`. No secrets, private image
references, exploit/debug packages or real business data are included. Pinned
inputs and deterministic application behavior do not promise byte-identical image
builds on different platforms.

## 7. Kubernetes Baseline Implementation

Four files declare namespace, Deployments/Services and the bounded identity
fixture. Readiness/liveness probes use `/healthz`; requests are 25m CPU/32Mi
memory, limits 250m/128Mi per container. Locally built
`secops-demo-api:phase-b` and `secops-demo-backend:phase-b` are loaded into kind;
`imagePullPolicy: Never` avoids an application registry dependency. Deployment
restarts refresh Pods after rebuilding these fixed local tags.

Scripts always select the repository-local `.local/kubeconfig` and
`kind-secops-lab` context. The cluster ownership record includes checkout path and
Docker node ID, so an unrelated same-name cluster is refused. The kubeconfig and
ownership file have mode 600. Cleanup is confined to that cluster and its local
credentials/record; it leaves downloaded tools and Docker images intact.

Default kind networking is retained. No custom CNI or extra security tool was
installed. The observed image is
`docker.io/kindest/kindnetd:v20251212-v0.29.0-alpha-105-g20ccfc88`.
The [source revision identified by that tag](https://github.com/kubernetes-sigs/kind/blob/20ccfc88/images/kindnetd/cmd/kindnetd/main.go)
includes a NetworkPolicy controller. This supports expecting policy capability;
actual enforcement on this host remains untested and is a Phase C/D validation
question. It would be incorrect to assume that every kindnet version lacks
NetworkPolicy support, or to install another CNI without testing the selected one.

## 8. Environment and Tool Versions

| Component | Version / observation |
| --- | --- |
| Host | Linux 5.15.167.4-microsoft-standard-WSL2, x86_64; Docker reports cgroup v1. |
| Docker client/server | 29.3.0, existing daemon. |
| kind | v0.31.0, Go 1.25.5, linux/amd64. |
| kubectl | v1.35.0, Kustomize v5.7.1. |
| Selected Kubernetes node | v1.34.3, pinned kind node image. |
| Node runtime / CNI | containerd 2.2.0 / kindnetd image above; both observed. |
| Host curl / Git / Python / Make | 8.5.0 / 2.43.0 / 3.12.3 / GNU Make 4.3. |
| Application Python | Pinned image version 3.12.12. |

Node image:
`kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48`.
The kubectl client is one minor newer than the server, within the documented
[supported version skew](https://kubernetes.io/releases/version-skew-policy/#kubectl).
See environment, installation and cluster-state evidence for actual outputs.

## 9. Tools Installed During This Run

| Tool | Why / version | Method and source | Location / elevation |
| --- | --- | --- | --- |
| kind | Missing CLI required to create/load the lab; v0.31.0. | Official GitHub release binary and `.sha256sum`; checksum verified before executable installation. | `.local/bin/kind`; no sudo or system package change. |
| kubectl | Missing CLI required to deploy/check; v1.35.0. | Official `dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl` and `.sha256`; checksum verified first. | `.local/bin/kubectl`; no sudo or system package change. |

Exact URLs, hashes, HTTP status and installation results are in
[tool-installation.txt](evidence/phase-b/tool-installation.txt). These tools were
already present on resumption and were reused. Docker, curl, Git, Python and Make
were pre-existing. No Docker configuration or host security setting was changed.
Sandbox escalation allowed access to the existing Docker socket and network;
it did not use sudo. No Trivy, Kyverno, Calico, Helm or future-phase tool was added.

## 10. Commands Executed

Inspection: `git status --short --untracked-files=all`, complete architecture and
contract reads, all Phase B file reads, original specification and official Task 1
review, CLI versions, `docker info`, `docker ps -a`, `kind get clusters` and image
inventory. Existing application Python and YAML were parsed, scripts checked with
`bash -n`, and whitespace checked with `git diff --check`.

Runtime sequence uses the repository interface:

```sh
make task1-cluster-up
make task1-build
make task1-baseline
make task1-check
```

Command output is captured with `tee` and shell `pipefail`; failed attempts are
retained. The successful source revision is bound by SHA-256 file hashes, build
image IDs and deployed Pod image IDs. Operator-only resource inventory and cache
reading are functional/provenance checks, not attacker-authority demonstrations.
Additional provenance commands used `kubectl get` for versions, nodes,
Deployments, Pods, Services and the kindnet DaemonSet; `docker image inspect`;
`kubectl exec ... python3` to hash `/app/app.py`; and `ctr content get` inside the
kind node for the two application image metadata documents. These read no
credentials. Cleanup was reviewed and syntax-checked but not executed, preserving
the functioning target for Phase C.

## 11. Functional Verification

| Check | Expected / observed result | Status | Evidence |
| --- | --- | --- | --- |
| Image build/load | Both Dockerfiles build and kind accepts both local images; build exit 0. | PASS | `build.txt` |
| Node readiness | One Ready control-plane node; v1.34.3, containerd 2.2.0; cluster-up exit 0. | PASS | `cluster-up.txt`, `cluster-state.txt` |
| Deployment | Both rollouts finish; final snapshot has one 1/1 Running Pod each, zero restarts; deployment exit 0. | PASS | `deployment.txt`, `cluster-state.txt` |
| Backend health | HTTP 200 and JSON `{"status":"ok"}`. | PASS | `functional-baseline.txt` |
| Backend data | HTTP 200 and exact synthetic source/value JSON. | PASS | `functional-baseline.txt` |
| API health | HTTP 200 and JSON `{"status":"ok"}`. | PASS | `functional-baseline.txt` |
| API → backend flow | Two API `/data` requests return HTTP 200 and exact JSON; backend logs show two `/data` calls from API Pod IP `10.244.0.7`. | PASS | `functional-baseline.txt` |
| Legitimate write | Cache content read from `/tmp/demo-cache.json` matches expected data; application code writes before returning 200. | PASS | `functional-baseline.txt`, app source |
| Functional script | All assertions complete; `FUNCTIONALITY = PASS`, exit 0. | PASS | `functional-baseline.txt` |
| Source provenance | Deployed `/app/app.py` hashes match the pre-build source snapshot for both components. | PASS | `workload-revision.txt`, `cluster-state.txt` |

The functional log briefly includes old Pods terminating after the scripted
restart; the later state snapshot shows only the two current Running Pods.
Health/HTTP assertions check status and parsed JSON content, not just a listening
socket. The check opens loopback-only forwards and removes its temporary files
and forwarding processes on exit.

The host Docker image IDs and Kubernetes imageIDs differ in representation in
this runtime: the host ID addresses a loaded image manifest, whose `config.digest`
matches the Pod's imageID. Both mappings and application source hashes were
captured; equality of unrelated identifier types was not assumed.

The 502/500/404 error branches were implemented and code-reviewed but were not
fault-injected in this run. No hardened compatibility, unintended connectivity,
excess-authority operation or nonessential filesystem write was tested.

## 12. Evidence Index

All files are under `docs/evidence/phase-b/`; links below contain real command
output or an explicitly labeled inventory. Credentials, tokens and kubeconfig
contents were excluded. Historical failed attempts are retained.

| Artifact | Claim supported |
| --- | --- |
| [environment.txt](evidence/phase-b/environment.txt) | Original tool discovery, Docker availability, cgroup v1 host and base commit. |
| [tool-installation.txt](evidence/phase-b/tool-installation.txt) | Exact official binary URLs, SHA-256 verification, CLI versions and installation outcomes. |
| [resume-state.txt](evidence/phase-b/resume-state.txt) | No surviving cluster/app images at resumption; existing tools verified. |
| [cluster-up.txt](evidence/phase-b/cluster-up.txt) | Initial permission failure, failed v1.35.0 attempt, then successful pinned v1.34.3 creation. |
| [build.txt](evidence/phase-b/build.txt) | Both image builds and kind loads, IDs, builder warning and exit 0. |
| [deployment.txt](evidence/phase-b/deployment.txt) | Applied resources, successful rollouts and exit 0. |
| [functional-baseline.txt](evidence/phase-b/functional-baseline.txt) | HTTP statuses/content, repeated intended dependency calls, cache content and functional PASS. |
| [cluster-state.txt](evidence/phase-b/cluster-state.txt) | Kubernetes/node/CNI versions, final Pod readiness, Pod UIDs, image identities and deployed source hashes. |
| [workload-revision.txt](evidence/phase-b/workload-revision.txt) | Base commit and SHA-256 of every workload input, including hidden Docker context files; changes are uncommitted. |
| [static-validation.txt](evidence/phase-b/static-validation.txt) | Shell/Python/YAML syntax and whitespace checks; these are not security assessment. |
| [working-tree.txt](evidence/phase-b/working-tree.txt) | Complete modified/untracked inventory reconciled with section 18; final source/link/credential-marker checks. |

To refresh runtime evidence after intentional changes, run the same Make targets
and capture stdout/stderr with shell `pipefail`; capture new timestamps, source
hashes and `kubectl get` image/Pod identities. Historical output only establishes
the observed revision, not any later edits or runtime drift.

## 13. Deviations From the Plan

The initial v1.35.0 node failed during kubelet startup on the existing cgroup v1
host. The resumed configuration uses the v1.34.3 digest supplied by the same kind
release. [kind's release guidance](https://github.com/kubernetes-sigs/kind/releases/tag/v0.31.0)
recommends an older Kubernetes release for cgroup v1. This is a lab compatibility
choice, with no host change or change to Phase A's workload threat model.

The application and workload manifests from the interrupted run were retained.
No architecture edit or broader topology change was needed. The report records
initial and resumed work together; it does not treat the interrupted attempt as
successful. The final assignment PDF is intentionally outside this Phase B run.

## 14. Problems Encountered and Resolutions

1. The sandbox initially could not access Docker's socket. The daemon was
   verified outside that restriction; no installation, group change or daemon
   configuration was needed.
2. The first `make task1-cluster-up` reached a script before its executable bit
   was set. All six scripts are executable; the failed output is retained.
3. The v1.35.0 node failed with a kubelet-health timeout and kind removed it.
   Docker reports cgroup v1, and upstream describes incompatibility beginning
   with this Kubernetes line. Cgroup compatibility is the supported working
   diagnosis; the deleted node's kubelet journal was not retained, so the exact
   internal failure was not independently proven. The pinned v1.34.3 retry is
   recorded separately in the same log.
4. Initial unrestricted `docker info` produced stale Docker CLI-plugin and host
   capability warnings. Scripts now request only the server-version field for
   availability checks. Host plugins were not changed.
5. The prior run stopped before completion. Resume inventory verified the real
   filesystem and runtime state, and all existing useful work was retained.
6. Docker's installed buildx plugin reference is broken. The existing Docker
   builder automatically fell back to its legacy builder and both image builds
   completed successfully. Its deprecation warning is retained in `build.txt`.
   No extra build tool or host plugin change was needed for this baseline.
7. An initial provenance parser treated the Pod imageID as a manifest and failed
   looking for `config.digest`. Inspection identified it as the image config;
   reading the host-ID manifest supplied the matching config digest. This
   corrected evidence interpretation only, with no workload change.

## 15. Security Claims Explicitly NOT Made

Phase B has not confirmed H1, H2, H3 or H4, assigned severities, demonstrated
cluster/host compromise, lateral movement, API abuse or durable persistence.
Root configuration is not host compromise; token mounting is not useful API
authority; a Role is not a completed API action; missing NetworkPolicy is not
universal reachability; a writable root is not persistence after Pod replacement.
No initial exploit, escape, capability probe, token extraction, workload API
authorization test, unintended-network test or nonessential-path write occurred.

## 16. Open Questions for Phase C

* What identity, capabilities and privilege-gain restrictions are effective in
  the admitted application process?
* Which workload credentials are accessible and what effective permissions,
  authentication and API connectivity do they provide?
* Which explicitly selected unintended flow is reachable, from which source?
  An auxiliary source/target must be identified as an assessor fixture.
* Which nonessential paths are writable in the real application process context,
  and what is the affected storage lifetime?
* Does the installed network implementation enforce the selected policy semantics
  under controlled tests? Support in source code is not runtime proof.

These are assessment questions, not findings. Later hardening compatibility,
scanner coverage, admission behavior and rollout decisions remain unproven.

## 17. Phase C Assessment Plan

| Hypothesis | Question / likely method | Confirm / reject criteria |
| --- | --- | --- |
| H1 | Compare image/admitted configuration and application process UID, capabilities, `NoNewPrivs` against the empty privilege budget. | Confirm a demonstrated unnecessary privilege dimension or missing agreed privilege-gain restriction; reject only when all assessed dimensions meet the budget. No escape inference. |
| H2 | Inventory credentials without saving values; review effective grants, exact-action authorization, authentication and API reachability separately; optionally exercise only the named synthetic ConfigMap. | Under approved Phase A, exposed identity plus unnecessary security-relevant effective authorization supports the authority finding; executed abuse requires separate successful API evidence. Reject excess only after an adequate exposed-identity/permission inventory. |
| H3 | Fresh selected intended/unintended connections with identified sources, target-health and DNS controls, plus applicable filtering inventory. | Confirm only a selected unintended listener reached; reject only the tested matrix when unintended flows are blocked and positive controls pass. Ambiguous timeout is inconclusive. |
| H4 | Mount/permission review and harmless create/modify/delete probes outside `/tmp` in the application context. | Confirm a successful nonessential write on a named storage surface; reject only with sufficiently broad confinement evidence. No durability claim without lifecycle tests. |

The Phase B specification asks that H2 include exposure, authorization,
reachability and relevance before confirmation. Phase A distinguishes authorized
excess from executed abuse. Preserve both by collecting all four dimensions in
Phase C and reporting authorization and execution separately; do not silently
rewrite the approved criterion. Broken fixtures or incomplete evidence remain
inconclusive. No assessment procedure in this table was executed in Phase B.

## 18. Files Created or Modified

Reconciled against `git status --short --untracked-files=all`, including files
from the interrupted run. `Modified` means tracked changes; `Created` means
currently untracked. No earlier valid Phase B file was removed.

| File | Working-tree status |
| --- | --- |
| `.gitignore` | Modified |
| `Makefile` | Modified |
| `README.md` | Modified |
| `docs/evidence/phase-b/build.txt` | Created |
| `docs/evidence/phase-b/cluster-state.txt` | Created |
| `docs/evidence/phase-b/cluster-up.txt` | Created |
| `docs/evidence/phase-b/deployment.txt` | Created |
| `docs/evidence/phase-b/environment.txt` | Created |
| `docs/evidence/phase-b/functional-baseline.txt` | Created |
| `docs/evidence/phase-b/resume-state.txt` | Created |
| `docs/evidence/phase-b/static-validation.txt` | Created |
| `docs/evidence/phase-b/tool-installation.txt` | Created |
| `docs/evidence/phase-b/working-tree.txt` | Created |
| `docs/evidence/phase-b/workload-revision.txt` | Created |
| `docs/phase-b-report.md` | Created |
| `task1/BASELINE.md` | Created |
| `task1/app/demo-api/.dockerignore` | Created |
| `task1/app/demo-api/Dockerfile` | Created |
| `task1/app/demo-api/app.py` | Created |
| `task1/app/demo-backend/.dockerignore` | Created |
| `task1/app/demo-backend/Dockerfile` | Created |
| `task1/app/demo-backend/app.py` | Created |
| `task1/insecure/demo-api.yaml` | Created |
| `task1/insecure/demo-backend.yaml` | Created |
| `task1/insecure/namespace.yaml` | Created |
| `task1/insecure/rbac.yaml` | Created |
| `task1/kind.yaml` | Created |
| `task1/scripts/build.sh` | Created |
| `task1/scripts/check-functional.sh` | Created |
| `task1/scripts/cleanup.sh` | Created |
| `task1/scripts/cluster-up.sh` | Created |
| `task1/scripts/common.sh` | Created |
| `task1/scripts/deploy-insecure.sh` | Created |

Ignored runtime state is separate: `.local/bin/{kind,kubectl}` contains downloaded
CLIs; `.local/kubeconfig` contains private lab credentials; `.local/secops-lab.owner`
records cluster ownership. These are not publication artifacts. Docker owns the
lab node and built images. `docs/architecture.md`, the official PDF, Task 2 and
`.github/` are unchanged.

## 19. Reproduction Procedure

Use a Linux host with a working Docker daemon, Bash, curl, Python 3, Git and Make.
Install kind v0.31.0 and kubectl v1.35.0 from the verified official binary/checksum
URLs recorded in the installation evidence, placing them in `.local/bin` or PATH.
No downloaded binary belongs in Git. Docker installation/configuration is a host
prerequisite, not performed by these scripts.

From the repository root, run the four Make targets in section 10 in order.
The fixed `secops-lab` cluster name is reserved for this checkout. Setup refuses
an unrelated same-name cluster. On subsequent builds, rerun build, baseline and
check; deployment restarts consume the refreshed local image tags. To resolve
local port conflicts use, for example, `API_PORT=28080 BACKEND_PORT=28081 make
task1-check`. A passing check prints `FUNCTIONALITY = PASS`.

For operator inspection, use the explicit kubeconfig/context, for example:

```sh
.local/bin/kubectl --kubeconfig .local/kubeconfig --context kind-secops-lab \
  -n secops-demo get deployments,pods,services
```

After finishing with the lab, run `make task1-clean`. This removes only the owned
cluster and its repository-local kubeconfig/ownership record. Keep the cluster
running if immediately continuing to Phase C. Do not publish `.local/` contents.
The [README](../README.md) supplies the concise run path.

## 20. Phase B Exit Review

The senior-review pass checked application size, explicit budgets, fixture scope,
intended traffic, write paths, reproducibility, evidence provenance and wording.
The two small servers have no framework or added packages; source writes are
confined to the API cache. Each fixture maps to one approved hypothesis without
inflating findings. Named-ConfigMap RBAC remains bounded; no artificial workload
dependency justifies it. The network matrix includes DNS, probes and diagnostics.
No real credentials or company data appear in the changed publishable files.

Meaningful revisions after review were the compatible pinned node image, focused
Docker availability output, accurate version-specific CNI support language and
explicit image-ID interpretation. The application, permissive workload manifests
and Phase A document were preserved. Planned Phase C actions, implemented fixture
settings, observed functionality and unproven impact are distinguished throughout.

| Original exit criterion | Final result |
| --- | --- |
| Architecture read and respected | Complete; unchanged. |
| `task1/BASELINE.md` exists | Complete; written before implementation. |
| Functional budget explicit | Complete. |
| Local privilege budget explicit | Complete. |
| Kubernetes API budget explicit | Complete; none. |
| Network communication budget explicit | Complete; traffic matrix. |
| Filesystem write budget explicit | Complete; API `/tmp`, backend none. |
| `demo-api` exists | Complete. |
| `demo-backend` exists | Complete. |
| Container images build successfully | Complete; observed PASS. |
| Representative insecure manifests exist | Complete. |
| Kubernetes workload deploys successfully | Complete; observed PASS. |
| API health passes | Complete; observed PASS. |
| Backend health passes | Complete; observed PASS. |
| API → backend flow passes | Complete; observed PASS. |
| Legitimate `/tmp` write works | Complete; observed PASS. |
| H1–H4 remain hypotheses | Complete; no finding confirmed. |
| No hardened manifests | Complete. |
| No Kyverno policy | Complete. |
| No CI security gate | Complete. |
| No full security assessment | Complete; only functional/provenance checks. |
| Reproduction instructions | Complete; README, section 19 and scripts. |
| Real evidence files | Complete; indexed above. |
| No secrets or company-confidential data added | Complete for publishable changes; lab credentials remain ignored locally. |
| Complete report matches actual execution | Complete. |
| No unresolved blocker to Phase C assessment | Complete; assessment questions in section 16 remain deliberately open. |

No Phase B blocker remains. The cluster is running and ready for bounded Phase C
assessment. NetworkPolicy enforcement, hardened compatibility and security impact
remain unproven; readiness does not claim otherwise. No commit or push was made.

PHASE B READY FOR SECURITY ASSESSMENT
