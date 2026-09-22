# Task 1 — E1 Offline Verification Harness

## 1. Executive Summary

E1 completed the bounded offline verification harness and exercised it against the selected source files and isolated negative fixtures. The hardened source set passed separate F1, F2, and F3 static checks. The final E1-PATCH run passed all 24 offline self-tests: the original 18 and six isolated baseline cases. These are source-inspection results. Historical [D1](phase-d-d1-report.md) and [D2](phase-d-d2-report.md) accepted F1 and F2 candidates; historical [D3](phase-d-d3-report.md) failed both required F3 denials after policy admission. D3 remains **NOT READY**, current cluster state and possible diagnostic residue are **UNKNOWN**, and full integrated AFTER verification is **BLOCKED**. This is harness readiness, not Phase E acceptance.

## 2. Existing Evidence and Claim Boundaries

The verifier renders only the ten explicit claims in the unchanged [curated mapping](evidence/phase-e/e1-historical-claims.md). It checks the mapping structure, unique claims, allowed status combinations, and existence of each cited repository source. It does not infer verdicts from the contents of arbitrary Markdown. The cited [Phase B functional baseline](evidence/phase-b/functional-baseline.txt) and [Phase C finding evidence](phase-c-report.md) support historical BEFORE claims. D1 and D2 candidate reports and their linked raw records support their bounded candidate acceptance. The [D3 post-policy reachability record](evidence/phase-d/d3-post-policy-reachability.txt) supports the historical F3 failure; functionality during that candidate test did pass. The [D3R-1B-EXEC interruption review](phase-d-d3r1b-exec-interruption-review.md) leaves execution state, cluster state, and possible residue unknown. The [F0 report](phase-f0-detection-prevention-rollout.md) is a proposed prevention and operations design; its admission and release controls are not deployed by E1.

The declarative insecure baseline is sourced directly from [`task1/insecure/rbac.yaml`](../task1/insecure/rbac.yaml): it contains both ServiceAccounts, the `phase-c-fixture` ConfigMap with `marker: baseline`, and the `demo-api-fixture-access` Role and RoleBinding. The API Deployment and Service come from [`demo-api.yaml`](../task1/insecure/demo-api.yaml); the backend Deployment and Service come from [`demo-backend.yaml`](../task1/insecure/demo-backend.yaml); the Namespace comes from [`namespace.yaml`](../task1/insecure/namespace.yaml). These are repository declarations prepared for the later assessment. Phase B/C/D observations cited above are historical runtime evidence; none establishes the current runtime state.

## 3. Harness Design and CLI

[`task1/scripts/verify.sh`](../task1/scripts/verify.sh) provides `--help`, `--offline [insecure|hardened]`, `--historical-summary`, and `--runtime`. No argument selects `--offline hardened`. Bare `insecure` and `hardened` remain compatibility modes that inspect static files and list blocked runtime checks without contacting runtime tools. The safe Python/PyYAML loader rejects duplicate YAML keys and duplicate selected object identities; it inspects parsed fields, not text matches. PyYAML 6.0.1 was already installed locally; E1 installed nothing. Missing safe YAML loading blocks the selected offline checks. Help and runtime refusal execute in Bash before Python or YAML loading.

The insecure discovery rule includes every top-level `*.yaml` and `*.yml` file in `task1/insecure/`, sorted by path; the self-test copies that same set into its temporary fixture. Every YAML document in each discovered file is parsed. F1/F2/F3 baseline results are separate from the hardened static results. A newly discovered NetworkPolicy in that source set fails F3 BASELINE.

The offline result includes separate F1/F2/F3 static statuses, a visible `F3 ENFORCEMENT: BLOCKED / NOT VERIFIED`, `CURRENT RUNTIME VERIFICATION: NOT RUN`, and `FULL AFTER RESULT: BLOCKED`. Exit 0 means only that selected offline checks succeeded. Aggregation precedence is infrastructure error **3**, genuine selected check failure **1**, blocked selected check **2**, then success **0**. A mixed static FAIL and runtime BLOCKED returns 1 while retaining both lines. Missing historical mapping returns 2; malformed or inconsistent mapping returns 3. A successfully rendered historical summary returns 0 with its required historical-only mode label. `--runtime` prints prerequisites and unknown state and returns 2 before any runtime call.

## 4. Functional Verification Contract

A later authorized full verifier must check backend `/healthz` and `/data`, API `/healthz` and `/data`, repeated API `/data`, the actual `/tmp/demo-cache.json` update/readback, and required API-to-backend connectivity. It must record the selected release, Pod identities, image revisions, timestamps, expected and actual outcomes, and preserve the same functional oracle across BEFORE and AFTER. None of these functional requests ran during E1.

## 5. F1 Verification

The offline F1 check requires the distinct `secops-demo-api:phase-d1` image, the hardened Dockerfile's numeric `USER 65534:65534`, `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, dropped `ALL` capabilities, a read-only root filesystem, and a writable ephemeral `/tmp` mount. The selected source fields passed; an isolated fixture with `runAsNonRoot: false` failed. This does not establish actual process authority. Future runtime verification must bind to the selected Pod UID and imageID, read PID 1 UID/GID, capability masks and `NoNewPrivs`, inspect effective root and `/app` mounts and writable `/tmp`, observe required cache behavior, and demonstrate denial of a harmless cleaned-up `/app` write. The [D1 report](phase-d-d1-report.md) remains historical candidate evidence, not a current E1 probe.

F1 BASELINE compares the declared insecure API image and writable-root configuration in `task1/insecure/demo-api.yaml`. A temporary copy with `readOnlyRootFilesystem: true` returned F1 BASELINE FAIL and exit 1. That is an expected-baseline mismatch; it is not a current runtime observation.

## 6. F2 Verification

The offline F2 check requires both hardened ServiceAccounts to disable automount, both selected templates to use those identities without a `true` override, no explicit token projection or unintended credential mount in either template, no hardened Role or RoleBinding in the selected release set, and retention of the original insecure fixture. The only accepted selected volume/mount is the API's ephemeral `/tmp`. The selected source fields passed; isolated automount and explicit projected-token fixtures failed. Future runtime work must inspect effective ServiceAccount settings, newly admitted Pod token projections and mounts, process-visible credential paths, and all applicable grants, then test the exact former `configmaps/phase-c-fixture` GET/PATCH boundary in the actual API workload context while preserving functionality. `kubectl auth can-i` impersonation is only supporting authorization-model evidence; it cannot prove that the process possesses a usable credential. The [D2 report](phase-d-d2-report.md) remains historical candidate evidence.

F2 BASELINE compares the declarations in `task1/insecure/rbac.yaml`. Both ServiceAccounts must declare automount `true`; the fixture ConfigMap must retain `marker: baseline`; the Role must have exactly one rule for core `configmaps/phase-c-fixture` with only `get` and `patch`; and the RoleBinding must name exactly the `demo-api` ServiceAccount in `secops-demo` and the intended Role. Permission-list order is ignored where it has no effect. Isolated extra-verb and extra-subject fixtures each returned F2 BASELINE FAIL / exit 1; an API ServiceAccount automount change to `false` also returned F2 BASELINE FAIL / exit 1. This last result is expected-baseline drift, not a security regression. Reversing `get` and `patch` remained PASS / exit 0.

## 7. F3 Verification and Blocker

The offline F3 check requires exactly the two selected candidate NetworkPolicies, the intended Pod selectors and policy directions, API egress only to backend TCP/8081 and kube-system DNS UDP/TCP 53, backend ingress only from API TCP/8081, and no extra broadening in those selected specs. The selected source fields passed; a fixture with a broad API egress peer failed. Static policy success cannot establish dataplane enforcement or the complete effective union of other live selecting policies. In the historical [D3 run](phase-d-d3-report.md), both forbidden Service paths remained reachable after policy admission. Future F3 runtime work requires healthy source and target fixtures, exact Pod identities and image revisions, correct Services and EndpointSlices, controller and dataplane health, fresh allowed API-to-backend TCP/8081 and functional UDP/TCP 53 DNS checks, fresh denied API-to-unrelated-target and unrelated-source-to-backend TCP/8081 checks, and preserved application behavior. A timeout without a healthy target and correct wiring is inconclusive. D3 remains **NOT READY**.

F3 BASELINE inspects every parsed object from the discovered insecure files, regardless of the file name. An isolated new `task1/insecure/unexpected-policy.yaml` was discovered and parsed; its NetworkPolicy caused `F3 BASELINE: FAIL` and exit 1. The canonical insecure directory was unchanged.

## 8. Historical BEFORE/AFTER Matrix

| Evidence window | Functionality | F1 | F2 | F3 | Boundary |
| --- | --- | --- | --- | --- | --- |
| Historical BEFORE, B/C insecure | Passed | Weakness demonstrated | Weakness demonstrated | Two unwanted Service paths reached | Historical baseline only |
| Historical AFTER D1/D2 candidates | Passed | D1 candidate accepted | D2 candidate accepted | Not yet remediated | No integrated AFTER proof |
| Historical D3 candidate | Passed | Prior candidate controls preserved in D3 report | Prior candidate controls preserved in D3 report | Both required denials failed | D3 candidate failed |
| Current runtime | Unknown | Not run | Not run | Not run | Cluster and possible residue unknown |
| Full integrated AFTER | Not verified | Not accepted as integrated proof | Not accepted as integrated proof | Blocked | Phase E blocked |

The ten exact machine-readable claims and source paths are in the [historical mapping](evidence/phase-e/e1-historical-claims.md); the matrix is a bounded summary of those claims and the D3R interruption boundary.

## 9. Actual Offline Self-Test Results

The final [raw offline test record](evidence/phase-e/e1-offline-tests.txt) contains the actual output and exit codes. [`test-verify-offline.sh`](../task1/scripts/test-verify-offline.sh) ran the real verifier against temporary copies: tests 01–18 remained in place and passed, and six new baseline cases 19–24 passed. Direct `--help`, default, `--offline`, `--offline insecure`, and `--historical-summary` checks returned 0; the selected hardened static checks were F1 PASS, F2 PASS, F3 PASS while F3 enforcement and full AFTER stayed blocked. Negative F1, F2, F3, and projected-token fixtures returned 1. Simulated parser absence, `--runtime`, and missing mapping returned 2. Invalid usage and malformed or inconsistent mapping returned 3. A mixed F1 FAIL / F3 runtime BLOCKED returned 1 with both results visible. Runtime command shims recorded no invocation. The test fixture added a false current-runtime claim to a copied historical source; the rendered summary still used only the curated mapping.

The six new fixture results were: F1 configuration drift FAIL/1; Role permission drift FAIL/1; RoleBinding drift FAIL/1; a newly discovered NetworkPolicy FAIL/1; insecure API automount drift FAIL/1; and reordered RBAC verbs PASS/0. These are self-test successes because each verifier result matched the expected oracle.

## 10. Deferred Runtime Execution Gate

E1 intentionally refuses runtime execution. Before a later full run, the D3 policy enforcement failure must be resolved and retested; D3R-1B-EXEC's paused execution state and possible residue must be assessed in an authorized owned environment; current cluster ownership and state must be established; D3 must pass its complete fresh-flow matrix; and D4 integration must be completed. Only then can an explicitly authorized bounded Phase E run apply the same functional and security oracles to the selected BEFORE and integrated AFTER states. A flag or environment variable is not that authorization. E1 ran no Docker, Kubernetes, nftables, node, smoke, deploy, cleanup, or interrupted diagnostic operation.

## 11. Limitations and Full Phase E Dependencies

The offline check covers every top-level insecure YAML source, the selected hardened source files and one Dockerfile, not rendered overlays, image contents, admitted objects, effective RBAC, PID 1 state, current token visibility, live selecting-policy union, Service routing, or dataplane behavior. Its source-level PASS is useful for identifying drift in these files but cannot close runtime findings. The D1/D2 evidence is historical; the D3 failed enforcement is historical; the current runtime and diagnostic residue remain unknown. Full Phase E depends on a passing D3 gate, D4 integration, runtime identity and functional checks, and an actual same-oracle BEFORE/AFTER run. The [F0 design](phase-f0-detection-prevention-rollout.md) does not supply a deployed admission or CI gate.

## 12. E1 Exit Decision

The six E1 artifacts exist, all 24 final offline self-tests passed, and no live runtime verification was performed. This accepts the offline harness only. Full integrated AFTER verification remains blocked and D3 remains not ready.

TASK1-E1 HARNESS READY — OFFLINE VERIFIED; FULL RUNTIME VERIFICATION BLOCKED
