# Task 1 — Phase D0 Control Design Plan

## 1. Executive Summary

D0 locks the control and verification contract for the three Phase C findings. F1 (MEDIUM) concerns excess `demo-api` local authority and a nonessential `/app` write; F2 (MEDIUM) concerns that API workload's unnecessary authority over one named ConfigMap; F3 (LOW) concerns two selected unintended east-west Service paths. The chosen directions are native container process and filesystem constraints, removal of unnecessary workload credentials and RBAC, and Kubernetes NetworkPolicy for the selected communication graph. D1 can begin F1 candidate hardening under the acceptance criteria below. D0 made no application, image, manifest, cluster, or security-control change.

## 2. Design Basis

- **D0 start:** commit `557e60d20ad4f81b7ba7e9666a313ea4a8c65af9`, branch `temp/work-in-progress`, clean initial working tree. [Design context](evidence/phase-d/d0-design-context.txt) records the UTC time and integrity result.
- **Official assignment:** [case-study PDF](case-study-secops-engineer-2026.pdf), all four pages reviewed. Task 1 requires assessment, risk priority, a safer working manifest, detection/prevention reasoning, and an operational rollout approach; this D0 artifact covers the control-design step only. Platform infrastructure may be assumed secure.
- **Locked findings and objectives:** [canonical Phase C report](phase-c-report.md), read completely. No finding count, priority, or lifecycle was reopened. F1 includes the filesystem-write subcondition previously assessed under H4.
- **Legitimate budgets:** [Phase B contract](../task1/BASELINE.md), supported by [Phase B report](phase-b-report.md) and [architecture](architecture.md). The applications need no root, extra Linux capabilities, privilege escalation, or Kubernetes API operations. `demo-api` needs `/tmp/demo-cache.json`, DNS, backend TCP/8081, and the declared client/health paths. Backend needs no application write or Kubernetes API operation.
- **Raw evidence:** F1 [process state](evidence/phase-c/h1-container-privilege.txt) and [filesystem probe](evidence/phase-c/h4-filesystem.txt); F2 [credential exposure](evidence/phase-c/h2-credential-exposure.txt), [authorization model](evidence/phase-c/h2-authorization-model.txt), and [actual API requests](evidence/phase-c/h2-runtime-api.txt); F3 [policy inventory](evidence/phase-c/h3-policy-network-inventory.txt), [fresh reachability probes](evidence/phase-c/h3-network-reachability.txt), and [fixture lifecycle](evidence/phase-c/c3-fixture-lifecycle.txt). Source under `task1/app/`, `task1/insecure/`, `task1/scripts/`, and `task1/kind.yaml` was inspected. All 19 Phase B input hashes still match; no material contradiction was found.

## 3. Design Principles

Each selected control follows a final finding, its security objective, and the legitimate application budget. Prefer the smallest native control set that expresses the required property and can be observed at runtime. Preserve `task1/insecure/**` and the `phase-b` image identities as the reproducible BEFORE profile; build a separate AFTER candidate in D1–D3 and freeze it in D4. D1 → D2 → D3 → D4 is workflow decomposition, **not** a change to the MEDIUM, MEDIUM, LOW risk priorities. Configuration inspection supports but cannot replace process, API-action, filesystem, and fresh-connection observations.

## 4. Control Acceptance Matrix

| Finding | Security objective | Selected control class | Candidate implementation direction | Compatibility risks | D acceptance | E formal proof |
| --- | --- | --- | --- | --- | --- | --- |
| F1 — MEDIUM | Minimize API process authority and confine writes to documented paths. | Native image identity and container process/filesystem constraints. | Intentional non-root image user with `runAsNonRoot`; prohibit privilege gain; drop unneeded capabilities, aiming for `ALL`; read-only root filesystem; writable ephemeral `/tmp` mount. D1 decides whether exact UID/GID pinning is needed. | Non-root startup/ownership, Python runtime, required cache write, entrypoint and probes. | Candidate starts; health, API → backend, and actual cache write pass. Observe API PID 1 non-root, selected capability and privilege-gain state, read-only root mount, and denied harmless `/app` write. | Same functional oracle before/after; compare actual PID 1 UID/GID, capabilities, `NoNewPrivs`, mount/write behavior, with `/tmp` allowed and `/app` denied only after hardening. |
| F2 — MEDIUM | Remove unnecessary API credential exposure and named-resource authority. | ServiceAccount token projection minimization plus RBAC removal. | Disable automatic token mounting for API; omit fixture Role/RoleBinding from hardened candidate. Apply token minimization to backend as consistent zero-API-budget hardening. | Undocumented API or credential dependency, if any; startup and health assumptions. | Both workloads start and function; API → backend works; intended token projections and fixture grant are absent from candidate and effective objects. | In actual API workload context, former named ConfigMap GET/PATCH path is unavailable without a credential or denied by bounded actual request if an identity remains; `can-i` is supporting only. |
| F3 — LOW | Limit communication to documented source/destination/port dependencies while retaining required traffic. | Kubernetes NetworkPolicy (Pod L3/L4 ingress and egress). | Restrict backend ingress to API TCP/8081 and API egress to backend TCP/8081 plus required DNS UDP/TCP 53; D3 resolves exact selectors, client/probe paths, and any necessary allowances. | DNS, Service routing, port-forward versus ordinary ingress, probes and effective node source. | In the current cluster, fresh intended API → backend and DNS connections, functionality, and probes pass; unrelated source → backend and API → unrelated target TCP/8081 are blocked. | Repeat equivalent positive and negative Pod-to-Service probes under both profiles, separately checking ordinary policy-relevant ingress if selected; prove current-cluster enforcement behavior. |

## 5. F1 — Excessive `demo-api` Local Authority

### Security Objective

Run the API with no unneeded local process authority and confine application writes to the documented disposable `/tmp/demo-cache.json` need. F1 contains the observed `/app` write as a write-confinement subcondition.

### Evidence-to-Control Mapping

The actual API PID 1 ran as UID/GID 0, had nonzero effective/permitted/bounding capability masks, and reported `NoNewPrivs: 0` ([process evidence](evidence/phase-c/h1-container-privilege.txt)). Non-root execution addresses the root identity; a capability drop addresses the observed excess mask against the zero-capability budget; `allowPrivilegeEscalation: false` addresses the absent privilege-gain restriction without claiming escalation occurred. The root overlay was `rw`, and that same UID 0 context created/read/removed a file in root-owned `/app` ([filesystem evidence](evidence/phase-c/h4-filesystem.txt)). A read-only root filesystem addresses that surface independently of directory ownership. An explicit writable `/tmp` mount preserves the required cache operation on a read-only image root. These settings address complementary observed dimensions of one F1, rather than creating separate findings.

### Selected Control Class

Image-defined non-root identity plus Kubernetes container `securityContext` for non-root enforcement, no privilege gain, capability minimization, and a read-only root filesystem; an explicit ephemeral writable mount for `/tmp`.

### Candidate Implementation Direction

D1 inspects the intended image user and ownership of `/app`, Python runtime paths, and the `/tmp` mount before choosing identity details. An image-defined non-root user with `runAsNonRoot: true` may suffice. Pin `runAsUser` and `runAsGroup` only if a stable exact identity is a deliberate compatibility or enforcement requirement; no arbitrary numeric UID/GID is locked here. Aim to drop `ALL` capabilities because the app listens on unprivileged TCP/8080 and uses no privileged operation. Use `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, and a writable ephemeral `/tmp` volume compatible with the chosen user. Inspect effective runtime mounts, including `/app`, so another writable mount cannot defeat confinement. If the Dockerfile changes, build a distinctly named/tagged hardened image; never rebuild or overwrite `secops-demo-api:phase-b` as the hardened candidate. `task1/insecure/**` stays reproducible.

### Alternatives Considered

Changing only `/app` permissions would deny this one write under some non-root identities, but leaves the observed writable root overlay. Non-root alone leaves default capabilities and an absent privilege-gain restriction potentially intact. A read-only root without explicit `/tmp` storage breaks the required cache. These narrower partial choices do not satisfy the combined objective.

### Why Selected

Each property maps directly to an observed F1 dimension and the documented zero-privilege, one-write budget. The native image and Pod mechanisms give a small, testable candidate without adding an admission framework.

### Compatibility Concerns

Verify Python can start and serve as the selected user from its working directory; image file ownership must permit read/execute. Python bytecode is already disabled, reducing incidental write demand, but runtime behavior must confirm this. The `/tmp` mount must allow the selected identity to replace `/tmp/demo-cache.json` on repeated calls. Confirm health probes and the image `CMD ["python", "app.py"]` work after identity and filesystem changes. An `ALL` capability drop is the intended minimum and needs runtime and functional validation; record any evidence-based exception rather than silently retaining defaults.

### Trade-offs

An explicit writable mount adds one volume and its ownership/mode decision. Read-only root limits application-directory updates at runtime, which the contract does not need. UID pinning may simplify ownership but would create an unnecessary fixed-identity dependency unless D1 demonstrates a reason.

### D-Stage Acceptance Criteria

D1 candidate smoke must actually observe successful container startup, API `/healthz`, API → backend `/data`, and a successful write/readback of `/tmp/demo-cache.json`. Inspect the **application PID 1**, not just a manifest or unrelated debug container: UID must be non-root; effective capabilities must match the selected minimum (target zero, with bounding/permitted state checked); `NoNewPrivs` must be `1` for the selected no-escalation design. Inspect root and `/app` mount state, then attempt a harmless, cleaned-up nonessential `/app` create as the application identity and observe denial. A failed `/app` write alone is insufficient if the selected read-only-root property is not effective. Any justified capability exception requires a documented D0 decision revision and equivalent minimum-authority proof.

### Phase E Formal Verification Requirement

Apply one semantic oracle to BEFORE and AFTER: health for both components, backend `/data`, API → backend `/data`, repeated cache write, API PID 1 identity/capability/privilege state, and harmless `/app` write outcome. BEFORE must reproduce the recorded root/nonzero-capability/`NoNewPrivs: 0` state and `/app` success; AFTER must show non-root, selected minimum capability state, no privilege gain, `/app` denial, read-only root, and successful `/tmp` write. Record the effective process and mount context; YAML fields alone do not prove the result.

### Explicit Non-Goals

No claim of host escape prevention, successful prior escalation, durable persistence, or backend runtime F1 finding. Seccomp and arbitrary numeric UID/GID requirements are not added from scanner recommendations.

## 6. F2 — Unnecessary Workload API Authority

### Security Objective

Remove Kubernetes API credentials and effective named-ConfigMap authority that neither application needs. The demonstrated finding belongs to `demo-api`.

### Evidence-to-Control Mapping

The API process could read its projected ServiceAccount files ([credential evidence](evidence/phase-c/h2-credential-exposure.txt)), so disable unnecessary token projection. The `demo-api-fixture-access` Role/RoleBinding granted `get` and `patch` on `configmaps/phase-c-fixture` ([authorization evidence](evidence/phase-c/h2-authorization-model.txt)); remove that grant from the hardened candidate. Actual verified-TLS workload-token GET/PATCH requests returned HTTP 200 and changed/restored the marker ([runtime evidence](evidence/phase-c/h2-runtime-api.txt)), so Phase E must test the former operation from the workload context. The backend token projection was observed in the inventory, while its documented API budget is also zero; disabling its token is **consistent workload hardening**, not evidence that F2 was runtime-demonstrated on backend.

### Selected Control Class

Prevent unnecessary ServiceAccount token projection and remove unnecessary namespaced RBAC. Retaining a dedicated ServiceAccount name is permissible for ownership clarity but is not the security control by itself.

### Candidate Implementation Direction

Set `automountServiceAccountToken: false` for both hardened Pods or their dedicated ServiceAccounts, with Pod-level precedence checked, and include no other application credential mount. Omit the synthetic access Role/RoleBinding from the hardened candidate; D2 must also ensure an old grant does not survive in the effective hardened runtime after deployment. Keep the named ConfigMap available as a harmless assessor target when a request test needs to distinguish authorization denial from a missing object; it is not a runtime application dependency. Do not remove the baseline fixture or grant from `task1/insecure/**`.

### Alternatives Considered

A new dedicated ServiceAccount without removing the grant or token exposure does not close the observed path. RBAC removal alone leaves an unnecessary process-readable credential, while token removal alone leaves a dormant unnecessary grant that could be reused if credentials appear. Both dimensions are selected because the legitimate API budget is zero.

### Why Selected

The controls directly remove the credential prerequisite and the exercised authorization with native Kubernetes settings; no application behavior needs an API token or the ConfigMap.

### Compatibility Concerns

Source review finds DNS-based backend discovery and no application API calls. D2 must still check startup, probes, and end-to-end behavior for any undocumented credential assumption. Token projection and DNS are separate mechanisms; do not infer a DNS failure from token removal.

### Trade-offs

The workloads lose in-Pod API credentials, which is intentional under the zero-API budget. If a real dependency emerges, document the exact required action and revise the control narrowly rather than restoring the synthetic grant or broad automatic token exposure.

### D-Stage Acceptance Criteria

D2 smoke must show both workloads start and remain healthy, API → backend `/data` and the required cache still work, the hardened candidate and effective cluster have no `demo-api-fixture-access` Role/RoleBinding, and no selected automatic ServiceAccount token projection is visible to either application process. Check effective Pod settings and process-accessible credential paths; do not claim formal remediation from manifest inspection alone.

### Phase E Formal Verification Requirement

Reproduce the C2 security question using code in the actual `demo-api` container context against an existing harmless `phase-c-fixture` target. BEFORE reproduces credential access and bounded named GET/PATCH success. AFTER records that the former credential prerequisite is absent and that this identity path cannot perform the operations; if any justified workload identity remains, issue bounded actual named GET/PATCH requests and observe denial without changing fixture data. Review effective grants as supporting evidence. `kubectl auth can-i` alone is insufficient. Verify both applications' health, API → backend, and cache behavior in both profiles. Do not present backend token removal as an additional demonstrated F2 finding.

### Explicit Non-Goals

No claim that F2 established general cluster RBAC, Secret access, or backend runtime API abuse. No unrelated RBAC redesign or application API dependency is introduced.

## 7. F3 — Selected Unintended East-West Reachability

### Security Objective

Allow the documented application dependency graph and deny the two demonstrated unintended Pod-to-Service TCP/8081 relationships.

### Evidence-to-Control Mapping

The current namespace had no NetworkPolicy, but that inventory alone proves no connectivity result ([inventory](evidence/phase-c/h3-policy-network-inventory.txt)). Fresh traffic from the existing API Pod reached a healthy, uniquely wired unrelated Service, and an unrelated source Pod reached the backend Service ([reachability](evidence/phase-c/h3-network-reachability.txt), [fixture controls](evidence/phase-c/c3-fixture-lifecycle.txt)). API egress restriction addresses the first observation; backend ingress restriction addresses the second. Both sides are necessary for the complete F3 evidence loop. The Phase B graph requires API → backend TCP/8081, API → DNS UDP/TCP 53, health probes, and the declared functional client path; these remain positive controls.

### Selected Control Class

Kubernetes NetworkPolicy is selected at D0. Its Pod selectors, namespace selectors, ingress/egress directions, TCP/UDP protocols, and ports express the selected L3/L4 relationships. D0 selects required semantics, not a CNI product. Whether the **current kind cluster** enforces the exact candidate semantics remains a D3 evidence question; no CNI replacement is selected here.

### Candidate Implementation Direction

D3 designs policies whose effective union permits API egress to backend TCP/8081 and required cluster DNS UDP/TCP 53, and permits backend ingress from API TCP/8081. It must deny unrelated source → backend TCP/8081 and API → unrelated target TCP/8081 while preserving responses. Determine actual Pod, namespace, DNS endpoint, and Service/EndpointSlice selectors and observe effective traffic paths before locking YAML. Account for any other selecting policy because NetworkPolicy allowances combine. Do not add API ingress isolation solely from the untested unrelated-source-to-API row; if a designated ordinary client-to-API path becomes part of the selected security property, define and test it explicitly. Do not assume the `demo-api` Service name alone is a destination identity for policy purposes.

### Alternatives Considered

Backend-only ingress restriction leaves the demonstrated API → unrelated-target path open. Application-level authorization would govern HTTP requests but does not express the demonstrated L3/L4 reachability property. A CNI replacement is only a conditional implementation option if current-cluster tests show the required NetworkPolicy semantics cannot be enforced and the cause is identified; D0 does not choose one.

### Why Selected

The required property is source/destination/protocol/port reachability among Pods and Services, which is the native scope of Kubernetes NetworkPolicy. It is narrower and more directly testable than introducing a service mesh or platform redesign for two selected flows.

### Compatibility Concerns

`task1/scripts/check-functional.sh` uses loopback `kubectl port-forward` for both API and backend checks. Preserve those checks as application functionality, but their API-server/kubelet-mediated path is **not proof** that ordinary NetworkPolicy-relevant ingress works. D3 must identify the effective source/path for the functional client, probes, and any ordinary client ingress it selects before final selectors. Check DNS egress, Service-to-Pod routing, node/kubelet probe behavior, backend readiness/liveness, and API → backend connections at runtime. Do not infer probe behavior solely from policy theory.

### Trade-offs

Policies add selector and DNS endpoint maintenance and depend on a working enforcement implementation. A denial timeout is meaningful only with healthy target/Service controls and fresh connections; otherwise it may reflect a broken fixture. The accepted claim remains the selected flow matrix, not universal network isolation.

### D-Stage Acceptance Criteria

D3 inspects the current networking/policy implementation and applies its candidate only during D3. It then uses fresh connections to establish API → backend TCP/8081 and required DNS success, application functional checks and probes passing, unrelated source → backend TCP/8081 denied, and API → unrelated target TCP/8081 denied. It must prove source/target identities and target health as C3 did, inspect effective policy selection, and separate functional port-forward success from any ordinary policy-relevant ingress positive control. If semantics fail, diagnose policy design, cluster configuration, or enforcement implementation before evaluating an alternative. Retain the current environment if it satisfies the full matrix.

### Phase E Formal Verification Requirement

Use the same positive/negative flow oracle for both profiles with semantically equivalent C3 fixtures. BEFORE reproduces both unintended Service connections while intended API → backend, DNS, health, and functional client checks pass. AFTER must block both unintended fresh connections while the positives pass. If ordinary client-to-API ingress is selected in D3, test it from a policy-relevant source separately from port-forward. Fixture creation is an assessor action, not an attacker capability. NetworkPolicy object presence alone is not formal proof.

### Explicit Non-Goals

No claim of unrestricted cluster, cross-namespace, or Internet reachability; no CNI selection, cluster networking redesign, service mesh, or backend egress control is required by the two demonstrated F3 paths.

## 8. Cross-Control Compatibility Risks

| Interaction | D4 check |
| --- | --- |
| Non-root identity, image ownership, and `/app` permissions | PID 1 starts and reads code; `/app` stays non-writable under the selected read-only-root control. |
| Read-only root and writable `/tmp` | Repeated API `/data` calls update the cache while `/app` create is denied. |
| Token removal and application behavior | Both health checks, backend call, and cache work without projected API credentials. |
| NetworkPolicy and DNS/Service routing | API resolves backend and reaches TCP/8081; negative target remains healthy but unreachable from API. |
| NetworkPolicy and probes/client transport | Readiness/liveness and port-forward functionality continue; any ordinary policy-relevant ingress has a separate source/path proof. |

## 9. Phase D Execution Contract

**D1:** implement and smoke-test only the F1 candidate; choose image identity/ownership and keep a distinct hardened image lineage. **D2:** implement and smoke-test F2 credential and authorization removal, including consistent backend token minimization. **D3:** implement F3 NetworkPolicy candidate, identify effective traffic paths, and test the **current** cluster's complete allow/deny semantics. **D4:** integrate these candidates and freeze the hardened AFTER profile after resolving interactions. D1–D3 smoke checks are candidate acceptance; Phase E remains the formal two-profile proof. This order reflects dependencies and testability, not finding severity.

## 10. D4 Integration Rules

D4 introduces no new security control by default. If integration breaks a required behavior or security property, identify the responsible decision, return to D1, D2, or D3 for a documented revision, and rerun D4. First check implementation error, then whether a narrow legitimate exception or alternate implementation preserves the C4 objective. Do not weaken an objective solely for convenience. Freeze the integrated image/manifests and their identities only after the full combined candidate passes its checks; keep BEFORE artifacts intact.

## 11. Phase E Behavioral Verification Contract

The future `./task1/scripts/verify.sh insecure` and `./task1/scripts/verify.sh hardened` interface will run the **same security-property oracle**, with profile-specific expected states. Probe commands may differ from Phase C if their semantics remain equivalent. It will report **Functional Tests**, **Security Properties / Observations**, and **Profile Result** separately. Common functionality includes both health endpoints, backend `/data`, API → backend `/data` and repeat cache writes, DNS/dependency traffic, probes, and the declared port-forward client/diagnostic checks.

| Profile | Security expectations | Passing result |
| --- | --- | --- |
| `insecure` | F1 actual root/excess capabilities/`NoNewPrivs: 0` and successful `/app` write; F2 usable token with named GET/PATCH; F3 both selected unintended connections succeed. | Required function `[PASS]`; weaknesses `[EXPECTED-WEAK]`; profile `PASS — insecure baseline reproduced as expected`. |
| `hardened` | F1 non-root/minimum capability/no privilege gain, `/tmp` allowed and `/app` denied; F2 former credential/authority path unavailable or actual named operation denied; F3 both selected unintended connections denied with required paths allowed. | Required function `[PASS]`; security properties `[PASS]`; profile `PASS — hardened security properties satisfied`. |

A true `FAIL` means the probe could not run or its observed state differs from the expected profile, required functionality broke, a hardened security property failed, or the insecure baseline unexpectedly stopped reproducing the recorded weakness. The known weakness on the insecure profile is **not** itself verifier failure. Record actual Pod/image revision, source/target identity, fixture health, and effective runtime state so the final claim supports security improvement without loss of the documented application contract. A `can-i` result and source YAML are supporting evidence only where runtime behavior is required.

## 12. Deferred / Explicitly Unselected Controls

No seccomp requirement, arbitrary numeric UID/GID, resource-limit revision, admission controller, Pod Security Admission redesign, service mesh, CI/CD policy, image signing, unrelated RBAC change, or CNI replacement is selected from scanner/checklist advice. Detect/prevent and operational rollout remain official later deliverables, outside D0 implementation. The current F3 enforcement implementation is deliberately unresolved until D3 behavior proves whether it suffices.

## 13. Open Implementation Questions

- **D1:** Which intentional non-root image user and ownership model allows Python startup and `/tmp` writes? Does exact numeric UID/GID pinning add a necessary constraint? Does dropping `ALL` capabilities produce zero effective/bounding masks with working probes and backend calls? What distinct hardened image tag will be used?
- **D2:** Are the effective Pod token settings and any other process-visible workload credential sources absent after hardening? Does any hidden application dependency appear when credentials are removed?
- **D3:** Which current Pod/namespace/DNS selectors express the required flows? What are the observed source and packet paths for port-forward functionality, ordinary client ingress if selected, and kubelet health probes? Does the current cluster enforce the complete fresh-connection matrix, and if not, why?

These are candidate implementation and evidence questions; none is a material contradiction that blocks D1.

## 14. Files Created or Modified

Created [D0 design context](evidence/phase-d/d0-design-context.txt) and this control plan. No Dockerfile, application file, manifest, script, CNI, RBAC, NetworkPolicy, or prior report was changed by D0.

## 15. D0 Exit Decision

The assignment, canonical finding set, Phase B budgets, raw evidence, and relevant source were reviewed. The baseline hash check passed for all 19 inputs; no material contradiction or runtime test was needed. The matrix and per-finding criteria map each selected control to evidence and required behavior. D1 has a bounded F1 candidate contract; D2 and D3 have explicit decisions and proof gates; D4 and Phase E have integration and same-oracle rules. Only D0 documentation artifacts were created.

D0 READY FOR F1 HARDENING
