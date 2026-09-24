# Task 1 before/after manifest bundles

These files are submission artifacts assembled from the reviewed repository at
commit `723625b5e9424dbd7fbbf83eb9eda1af8af98ef0`. They make the historical
assessment baseline and the intended hardening target easy to review. They do
not replace the source manifests, deployment scripts, or runtime evidence.

`before.yaml` is a faithful multi-document copy of the representative insecure
baseline. `after.yaml` is a clean-environment **target-state** bundle. The after
bundle is not evidence of a fully verified integrated deployment: historical
F1 and F2 candidate tests passed, but historical D3 testing did not demonstrate
either required NetworkPolicy denial. Current cluster state is unknown after
the interrupted D3R-1B execution review.

## Provenance

### `before.yaml`

The documents are copied without semantic changes from:

- `task1/insecure/namespace.yaml`
- `task1/insecure/demo-api.yaml`
- `task1/insecure/demo-backend.yaml`
- `task1/insecure/rbac.yaml`

The baseline images are local images named `secops-demo-api:phase-b` and
`secops-demo-backend:phase-b`; the bundle does not contain their Dockerfiles or
image data. Their build inputs remain under `task1/app/` and are described in
`docs/phase-b-report.md`.

### `after.yaml`

The target state is assembled from these exact objects:

- Namespace: `task1/insecure/namespace.yaml` (unchanged)
- Hardened ServiceAccounts: `task1/hardened/identity.yaml`
- Hardened `demo-api` Deployment: `task1/hardened/demo-api.yaml`
- Unchanged `demo-api` Service: `task1/insecure/demo-api.yaml`
- Unchanged `demo-backend` Deployment and Service:
  `task1/insecure/demo-backend.yaml`
- Candidate NetworkPolicies: `task1/hardened/network-policy.yaml`

The assembly decision was also checked against
`task1/hardened/scripts/build-f1.sh`, `deploy-f1.sh`, `deploy-f2.sh`, and
`deploy-f3.sh`, and against the D0–D3 and E1 reports. The assessment-only
`phase-c-fixture` ConfigMap and its Role/RoleBinding are intentionally absent:
the applications do not consume the ConfigMap, and the grant violates their
zero-Kubernetes-API permission budget. The backend Deployment is deliberately
unchanged; no reviewed source supports silently adding backend process or
filesystem hardening.

## Object inventory

| Bundle | Objects |
|---|---|
| Before (10) | Namespace `secops-demo`; Deployments `demo-api`, `demo-backend`; Services `demo-api`, `demo-backend`; ServiceAccounts `demo-api`, `demo-backend`; ConfigMap `phase-c-fixture`; Role `demo-api-fixture-access`; RoleBinding `demo-api-fixture-access` |
| After (9) | Namespace `secops-demo`; ServiceAccounts `demo-api`, `demo-backend`; Deployments `demo-api`, `demo-backend`; Services `demo-api`, `demo-backend`; NetworkPolicies `demo-api-egress`, `demo-backend-ingress` |

Every namespaced object is in `secops-demo`. No duplicate object identity is
present.

## Control differences and evidence status

| Finding | Before | Intended after control | Evidence status |
|---|---|---|---|
| F1 — excessive `demo-api` local authority with nonessential `/app` write | Phase B image runs as UID 0; no non-root, capability-drop, or no-escalation constraint; writable root filesystem | Separate image user `65534:65534`; `runAsNonRoot`; `allowPrivilegeEscalation: false`; drop `ALL`; read-only root; writable `emptyDir` only at `/tmp` | D1 historical candidate passed process, mount, `/tmp`, `/app`-denial, health, and functional checks. Not a current observation or integrated AFTER proof. |
| F2 — unnecessary `demo-api` authority over one named ConfigMap | Automatic token mounting on both SAs; API Role/RoleBinding permits `get`/`patch` of the fixture | Both SAs set `automountServiceAccountToken: false`; fixture Role/RoleBinding omitted; Pods must be recreated in a migration | D2 historical candidate passed token-path, exact grant, functional, and F1-continuity checks. Not a current observation or integrated AFTER proof. |
| F3 — selected unintended east-west Service reachability | No workload NetworkPolicy | API egress allows backend TCP/8081 and observed CoreDNS UDP/TCP 53; backend ingress allows API TCP/8081 | Candidate YAML passed static checks. Historical D3 admitted both policies but both required denials still returned HTTP 200; runtime enforcement is **not verified**. |

## Image prerequisites

`after.yaml` refers to two local images with `imagePullPolicy: Never`:

- `secops-demo-api:phase-d1`, built from
  `task1/hardened/images/demo-api.Dockerfile` with the context
  `task1/app/demo-api/`;
- `secops-demo-backend:phase-b`, built from
  `task1/app/demo-backend/Dockerfile` with the context
  `task1/app/demo-backend/`.

The hardened API Dockerfile is essential to F1 because it supplies numeric
`USER 65534:65534` and root-owned read-only application files. A YAML-only
deployment cannot create that image. A clean local cluster therefore requires
both images to be built and loaded through the environment's reviewed image
workflow before the Deployments start. No registry substitute or immutable
application-image digest is asserted by this bundle.

## Clean-environment deployment ordering

This is an ordering contract, not permission to deploy during documentation
preflight:

1. Establish a separately authorized clean cluster and confirm its networking
   implementation can enforce the required policy semantics.
2. Build and load the two exact local images above.
3. Create the Namespace, then the two hardened ServiceAccounts.
4. Create the two Deployments and Services; wait for Ready and run the shared
   functional, F1, and F2 checks.
5. Apply the two candidate NetworkPolicies only inside an authorized F3
   verification window. Run the complete fresh positive/negative flow matrix;
   object admission or static validation alone is not acceptance.
6. Treat the environment as an integrated AFTER state only after F3, D4, and
   the same-oracle Phase E verification all pass.

## Clean deployment versus in-place migration

A clean deployment begins with no old assessment objects or old Pods, so the
after inventory defines the intended object set. An in-place transition has
additional deletion and lifecycle semantics that this bundle cannot express:

- `kubectl apply` does **not** delete the existing
  `demo-api-fixture-access` Role or RoleBinding merely because they are absent
  from `after.yaml`.
- It likewise does not delete the synthetic `phase-c-fixture` ConfigMap.
- Existing Pods can retain already projected ServiceAccount tokens after the
  ServiceAccount changes; the selected workloads must be recreated and their
  new UIDs, volumes, mounts, credential paths, and effective grants verified.
- Other selecting NetworkPolicies and other direct or indirect RBAC grants can
  change the effective result and require an authorized inventory.

An in-place migration therefore needs a separately approved inventory,
targeted RBAC/fixture cleanup or reconciliation, controlled Pod recreation,
rollback criteria, and behavioral verification. Do not apply this generated
bundle automatically to an existing cluster or use a broad prune operation.

## Outstanding runtime blocker

During the historical D3 window on 2026-09-22, both policy objects were
admitted and selected the intended Pods, but fresh API-to-unrelated-target and
unrelated-source-to-backend connections both still returned HTTP 200. Kindnet
logged nftables synchronization errors and the intended policy table was not
observed. The policies were rolled back. The deeper cause remained unresolved,
and the later D3R-1B execution was interrupted; its primary transaction result,
cleanup, possible residue, and current cluster state are unknown. No live
runtime was inspected while producing these bundles.

## Offline validation performed

Using Python 3 and PyYAML 6.0.1 with a SafeLoader extended to reject duplicate
mapping keys, both bundles passed the following documentation-only checks:

- every YAML document parsed (`before`: 10; `after`: 9);
- every object had `apiVersion`, `kind`, `metadata.name`, and the expected
  namespace; no duplicate identity existed;
- `before.yaml` was semantically equal, document for document, to the four
  insecure source files;
- every after object was semantically equal to its selected source object;
- Service selectors and Deployment Pod labels agreed;
- the API security context and writable `/tmp` design matched the hardened
  source;
- both hardened ServiceAccounts disabled automount;
- no ConfigMap, Role, or RoleBinding was accidentally retained after hardening;
  and
- exactly the two reviewed candidate NetworkPolicies were present, without an
  added or broadened rule.

Static success confirms bundle fidelity only. It does not establish admitted
runtime objects, process state, token absence, effective authorization,
application health, or NetworkPolicy dataplane enforcement.
