# Task 1 — Representative Baseline Contract

This contract was written before the Phase B application and manifests. It defines
legitimate requirements against which H1–H4 can later be assessed. The baseline is
intentionally permissive; no hypothesis is a confirmed finding.

## Application Purpose

Provide a small, synthetic client → API → backend flow for workload security
assessment. The official [assignment](../docs/case-study-secops-engineer-2026.pdf)
(Task 1, pages 1–3) permits representative workload mistakes and assumes trusted
platform infrastructure. The approved [Phase A frame](../docs/architecture.md)
remains unchanged. Assessment, remediation, prevention and production rollout are
later work; Phase B establishes functionality only.

## Component Topology

```text
operator's test client → demo-api:8080 → demo-backend:8081
```

Two single-replica Deployments and ClusterIP Services in namespace `secops-demo`,
on one control-plane node in local kind cluster `secops-lab`. Test access uses
loopback-only kubectl port-forward; no ingress or public registry is required.
No database, external service, persistent volume or third application component.

## Functional Contract

| Component / request | Expected behavior |
| --- | --- |
| Both: `GET /healthz` | HTTP 200, JSON `{"status":"ok"}`; process health, independent of dependency health. |
| Backend: `GET /data` | HTTP 200, JSON `{"source":"demo-backend","value":"representative-data"}`. |
| API: `GET /data` | Fetch backend `/data` over HTTP, validate its synthetic payload, write the response to `/tmp/demo-cache.json`, then return the same JSON with HTTP 200. |
| API: dependency unavailable / invalid response | HTTP 502; never serve a cached success. Backend HTTP request has a bounded timeout. |
| API: cache write fails | HTTP 500; never report successful `/data` without its required write. |
| Both: unknown GET path | HTTP 404. |

Response JSON content is deterministic, with no clock, random value or Pod name.
The cache is replaced on every successful `/data`; it is not used as a fallback.
Startup requires no bootstrap credentials or API calls. Logs go to stdout/stderr.
Python standard-library HTTP servers suffice for a low-volume local demo; this is
not a production application server or an application-authentication assessment.

## Local Privilege Budget

Both processes require **no root, privileged container, additional Linux
capabilities, privilege escalation, privileged ports, host namespaces or host
filesystem access**. Listeners use TCP 8080 and 8081. Ordinary unprivileged process
execution is sufficient by design; compatibility with future hardened settings
will be verified in the remediation phase.

## Kubernetes API Permission Budget

Both applications require **NONE**: no verbs, API groups, resources/subresources,
resource names, namespace or cluster-scoped operations. They use DNS, not the
Kubernetes API, for backend discovery. Neither application reads workload tokens.

The H2 fixture gives ServiceAccount `demo-api` only `get` and `patch` on the core
API `configmaps` resource named `phase-c-fixture` in `secops-demo`, through a
namespaced Role/RoleBinding. The ConfigMap contains synthetic `marker: baseline`
and is not mounted, consumed as configuration or read by either application.
This narrowly scoped mutation target is reserved for Phase C. `demo-backend`
uses its own ServiceAccount with no application RoleBinding. Both explicitly
retain automatic token mounting as part of the permissive baseline.

## Network Communication Budget

| Source | Destination | Protocol / port | Intended? | Reason |
| --- | --- | --- | --- | --- |
| Operator test client | `demo-api` | TCP/8080 via loopback port-forward | Yes | Application entry point. |
| `demo-api` | `demo-backend` Service | TCP/8081 | Yes | Required `/data` dependency. |
| `demo-api` | Cluster DNS | UDP/53 and TCP/53 | Yes | Service name resolution, including TCP fallback. |
| Kubelet | Both Pod health endpoints | TCP/8080, TCP/8081 | Yes | Readiness and liveness checks. |
| Operator functional check | Backend `/healthz`, `/data` | TCP/8081 via loopback port-forward | Yes, diagnostic only | Positive target-health control. |
| Unrelated workload | `demo-backend` | TCP/8081 | No | No legitimate caller relationship. |
| Unrelated workload | `demo-api` | TCP/8080 | No, unless designated test client | No legitimate caller relationship. |
| `demo-api` | Unrelated services | Any | No | No application dependency. |
| Either application | Kubernetes API, Internet | Any | No | No legitimate runtime use. |
| `demo-backend` | New outbound application connections | Any | No | Static response needs no dependency. |

Return traffic on intended connections is required. Build-time downloads and the
operator's Kubernetes administration are outside the application's budget.
Namespaces are naming/policy scopes, not implicit security boundaries. No
NetworkPolicy will be installed in Phase B. Phase C may provision a separate
untrusted-source fixture for the backend negative test; this does not grant the
assumed attacker permission to create Pods. A compromised-API → unrelated-target
test needs a separately declared healthy synthetic target in Phase C.

## Filesystem Write Budget

* `demo-api`: only `/tmp/demo-cache.json`, written by the application after a
  successful dependency request; temporary, container-lifetime, disposable data.
* `demo-backend`: no application runtime filesystem writes.
* Python bytecode generation is disabled; no log files or application-directory
  writes are required. Standard output/error are runtime-managed streams.

The baseline uses the writable container root filesystem and no data volumes.
`/tmp` is not a persistent-storage contract. Future read-only-root plus writable
`/tmp` is a candidate control only; it is not implemented or tested in Phase B.

## Representative Baseline Conditions

| Hypothesis | Deliberate candidate condition | Boundary on claims |
| --- | --- | --- |
| H1 — Weak Container Isolation | Images explicitly use UID 0; manifests omit non-root, capability-drop and privilege-escalation restrictions. | Effective application authority must be assessed; root does not imply host compromise. |
| H2 — Excessive Workload Identity / RBAC | Automatic workload tokens plus the API's named synthetic ConfigMap grant exceed the empty design budget. | Token exposure, effective authorization, API reachability and relevance need evidence; no attacker API action in Phase B. |
| H3 — Unrestricted East-West Connectivity | ClusterIP Services with no workload NetworkPolicy. | Missing policy does not establish unintended connectivity. |
| H4 — Unnecessary Filesystem Write Access | `readOnlyRootFilesystem: false`; application needs only `/tmp`. | Writes outside the budget and their lifetime remain untested. |

No privileged application container, host namespace, hostPath, wildcard grant,
Secret grant or cluster-admin binding is introduced. Dedicated ServiceAccounts
make ownership explicit; they do not establish least privilege.

## Phase C Evidence Targets

* H1: inspect admitted configuration, image user, application process identity,
  capabilities and `NoNewPrivs`; compare to the local privilege budget.
* H2: inventory process-accessible credentials without retaining values, review
  effective grants, test exact authorization and API reachability separately;
  if appropriate, read/patch only `phase-c-fixture` using the workload identity.
* H3: compare fresh intended and selected unintended connections against the
  matrix, with healthy target controls and explicit source identities.
* H4: review mounts and permissions, then harmless write probes outside `/tmp`
  in the actual process context; do not infer persistence from a successful write.

Use Phase A's scoped confirm/reject criteria; incomplete evidence is inconclusive.
Phase B functional checks use operator credentials only for deployment, forwarding
and reading the legitimate cache, never as assumed attacker authority.

## Assumptions and Limitations

Single-node Linux kind, Docker available to the operator, public image/CLI
downloads available during setup. Versions and image digests will be pinned and
runtime image IDs recorded. This provides repeatable inputs and behavior, not a
claim of bit-identical Docker builds across machines.

Default kind networking is retained. The report must record its actual image and
version-specific support for NetworkPolicy. Enforcement is not demonstrated until
later controlled tests; no custom CNI or security tooling is needed for Phase B.
No authentication, TLS, scale, HA, exploitation or production rollout is modeled.
Only synthetic data is used; H1–H4 remain hypotheses until Phase C evidence.
