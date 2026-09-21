# Task 1 — Phase C3 East-West Network Reachability Assessment

## 1. Executive Summary

**H3 CONFIRMED for two selected flows.** A fresh client process in the existing `demo-api` Pod resolved and connected to a healthy, unrelated assessor target Service on TCP/8081, then received HTTP 200 and the synthetic `/data` response. A separate assessor source Pod also reached the existing `demo-backend` Service on TCP/8081 and received HTTP 200. Both flows are outside the [Phase B communication budget](../task1/BASELINE.md). The first test is primary because it starts in the workload assumed compromised by the [Phase A threat model](architecture.md); the second corroborates the selected backend ingress exposure.

The target's local listener and Service wiring were checked before the remote tests. Pre and post functional checks passed. All three assessor resources were removed. This C3 decision assigns no final finding number or priority; Phase C4 remains independent.

## 2. Assessment Context

Assessment-start commit: `dbf618a761f0099981a044a90c325571c72364c9`; branch: `temp/work-in-progress`; initial Git status: clean. Assessment began at `2026-09-21T18:15:17Z`. The owned `secops-lab` cluster was reused, with context `kind-secops-lab`, namespace `secops-demo`, Kubernetes server v1.34.3, kind v0.31.0, and kubectl v1.35.0. The original API and backend Pods retained their Phase B/C2 UIDs and image IDs. See [assessment context](evidence/phase-c/c3-assessment-context.txt).

The [Phase A frame](architecture.md), [Phase B contract](../task1/BASELINE.md), [Phase B report](phase-b-report.md), [C0+C1 report](phase-c-c0-c1-report.md), and [C2 report](phase-c-c2-report.md) were reviewed. C3 assessed H3 only.

## 3. Baseline Integrity and Pre-Assessment Functionality

All 19 Phase B workload inputs matched the SHA-256 values in the [workload revision record](evidence/phase-b/workload-revision.txt). The initial working tree was clean, including prior Phase C evidence. The checkout path and Docker node ID matched the owned cluster record. Neither original Pod was recreated.

The required pre-assessment `make task1-check` returned **FUNCTIONALITY = PASS**. It checked both health endpoints, backend `/data`, two API `/data` requests, and the API cache. The backend log showed `/data` requests from API Pod IP `10.244.0.7`, establishing the required `demo-api → demo-backend:8081` positive control. See [pre-assessment output](evidence/phase-c/c3-pre-assessment-functional.txt).

## 4. H3 Hypothesis and Legitimate Traffic Budget

H3 asks whether the representative baseline permits a selected east-west flow outside its documented application dependency graph. The legitimate application path is test client → `demo-api:8080` → `demo-backend:8081`; API → cluster DNS and kubelet → health endpoints are also required. The [contract](../task1/BASELINE.md) does not require `demo-api → unrelated services` or `unrelated workload → demo-backend:8081`. Namespaces are not assumed to be security boundaries. A missing NetworkPolicy is configuration context; an actual fresh connection to a healthy listener is needed for the H3 decision.

## 5. Network and Policy Inventory

### 5.1 Services and Endpoints

At the start of C3, `Service/demo-api` selected `app=demo-api`, exposed ClusterIP `10.96.161.44:8080`, and had a ready EndpointSlice pointing to Pod `demo-api-b8dcfccdf-gnv9c`, UID `d5601ad2-6919-4d58-bedf-5b984f0be056`, IP `10.244.0.7`. `Service/demo-backend` selected `app=demo-backend`, exposed ClusterIP `10.96.32.207:8081`, and had a ready EndpointSlice pointing to Pod `demo-backend-549b8f665f-npfsp`, UID `71156c57-8a45-46aa-a365-7566292e6d61`, IP `10.244.0.8`. Both Pods were Running/Ready. Exact ports, selectors, endpoint conditions, and image identities are in the [network inventory](evidence/phase-c/h3-policy-network-inventory.txt).

### 5.2 Current NetworkPolicy Inventory

There were zero NetworkPolicies in `secops-demo`, so none selected either baseline Pod. This observation alone does not establish reachability. No NetworkPolicy was created, modified, or applied during C3.

### 5.3 CNI Observation

The running CNI DaemonSet was `kindnet`, image `docker.io/kindest/kindnetd:v20251212-v0.29.0-alpha-105-g20ccfc88` (image ID recorded in the inventory). CNI policy support or enforcement was **not tested**. The Phase B report's source discussion does not demonstrate policy enforcement in this cluster.

## 6. Assessor Fixture Design

### 6.1 Unrelated Source

After confirming its exact name was absent, the assessor created Pod `phase-c3-untrusted-8f8d61d1`, UID `26fd4fc1-3a40-48ef-9450-561121fb3324`, IP `10.244.0.9`. It reused the loaded `secops-demo-api:phase-b` image with a Python sleep command and had labels `assessment.phase=c3`, `assessment.role=unrelated-source`, and a unique assessment ID. It had `automountServiceAccountToken: false`, no Service, no RBAC grant, and no legitimate backend caller relationship. Python 3.12.12 had been verified in the baseline image before use. See [fixture lifecycle](evidence/phase-c/c3-fixture-lifecycle.txt).

### 6.2 Unrelated Target

After confirming both exact names were absent, the assessor created Pod and ClusterIP Service `phase-c3-target-8f8d61d1`. The Pod reused the loaded `secops-demo-backend:phase-b` image under a distinct identity: UID `53e4c12a-9f04-46ba-94c6-efc6838b5837`, IP `10.244.0.10`; the Service was `10.96.106.109:8081`. Both carried the unique assessment ID, and the Pod used `assessment.role=unrelated-target` and `automountServiceAccountToken: false`. The Service selector matched only this target, and no baseline Service, selector, port, Deployment, application setting, or image was changed. Its use of the backend image explains the shared synthetic response fields; it does not make this Pod an API dependency.

### 6.3 Assessor Capability vs Attacker Capability

The assessor used operator credentials to create and later delete the fixtures. The attacker model grants code execution inside the **existing** `demo-api` container; it does not grant Pod/Service creation, Kubernetes operator credentials, or control of the unrelated source. The fixtures supplied identified healthy endpoints for a bounded test.

## 7. Positive Controls

### 7.1 Baseline demo-api → demo-backend

The pre-assessment functional check returned HTTP 200 for two API `/data` requests and showed corresponding backend `/data` requests from the API Pod IP. This verifies that the intended dependency still worked before H3 probes.

### 7.2 Target Local Listener

Inside the temporary target Pod, `GET http://127.0.0.1:8081/healthz` returned **HTTP 200** with `{"status":"ok"}` at `2026-09-21T18:17:48Z`. This checks the target listener independently of Service DNS and routing.

### 7.3 Temporary Service → EndpointSlice Wiring

The temporary Service selected the unique target labels. Its ready EndpointSlice pointed to `10.244.0.10:8081` with a target reference to the temporary Pod's exact UID. This separately checked Service-to-Pod wiring before the remote test. The exact selector and EndpointSlice output are in the [fixture lifecycle](evidence/phase-c/c3-fixture-lifecycle.txt).

## 8. PRIMARY TEST B — demo-api → Unrelated Target

### Source Identity

Existing Pod `demo-api-b8dcfccdf-gnv9c`, UID `d5601ad2-6919-4d58-bedf-5b984f0be056`, IP `10.244.0.7`, image `secops-demo-api:phase-b`. The client ran inside its existing container, whose Python 3.12.12 runtime was verified beforehand.

### Destination Identity

Temporary Service `phase-c3-target-8f8d61d1`, ClusterIP `10.96.106.109`, TCP/8081, uniquely wired to temporary target Pod `phase-c3-target-8f8d61d1`, UID `53e4c12a-9f04-46ba-94c6-efc6838b5837`, IP `10.244.0.10`. The flow is **NOT INTENDED** by the baseline budget.

### DNS Evidence

At `2026-09-21T18:17:49Z`, a new Python process resolved `phase-c3-target-8f8d61d1.secops-demo.svc.cluster.local` to `10.96.106.109`.

### TCP Evidence

That process created a new socket and connected to `10.96.106.109:8081`; the recorded result was `CONNECTED`. No existing persistent application connection was reused.

### HTTP Evidence

The same fresh socket sent `GET /data` with `Connection: close`. The listener returned **HTTP 200** with selected synthetic fields `source=demo-backend` and `value=representative-data`. The target-local health and unique Service endpoint controls identify the target despite its reused backend image. The [reachability evidence](evidence/phase-c/h3-network-reachability.txt) contains the raw and parsed results and exact safe client code.

### Assessor-Transport Boundary

`kubectl exec` transported the harmless probe into the current container. It is not an attacker capability claim: the assumed attacker has code execution in that container, not `kubectl`, Pod exec authorization, or the assessor's kubeconfig. The security property tested is connection establishment from the existing API network/runtime context.

### Interpretation

The existing `demo-api` context reached one selected healthy service outside its documented dependency graph. This primary test is sufficient for a bounded H3 confirmation. It does not show compromise of the target or reachability to every workload.

## 9. CORROBORATING TEST A — Unrelated Source → demo-backend

### Source Identity

Temporary unrelated source Pod `phase-c3-untrusted-8f8d61d1`, UID `26fd4fc1-3a40-48ef-9450-561121fb3324`, IP `10.244.0.9`. The assessor created it; attacker Pod creation is not assumed.

### Destination Identity

Existing `Service/demo-backend`, ClusterIP `10.96.32.207:8081`, selected ready Pod `demo-backend-549b8f665f-npfsp`, UID `71156c57-8a45-46aa-a365-7566292e6d61`, IP `10.244.0.8`. The precheck independently verified its `/healthz` and `/data` responses. This unrelated caller flow is **NOT INTENDED**.

### DNS Evidence

At `2026-09-21T18:17:50Z`, a new Python process resolved `demo-backend.secops-demo.svc.cluster.local` to `10.96.32.207`.

### TCP Evidence

The process created a new socket and connected to `10.96.32.207:8081`; the recorded result was `CONNECTED`.

### HTTP Evidence

`GET /data` on that socket returned **HTTP 200** and the selected synthetic fields `source=demo-backend`, `value=representative-data`. See [reachability evidence](evidence/phase-c/h3-network-reachability.txt).

### Interpretation

This selected workload with no legitimate backend caller relationship reached the backend listener and received its synthetic response. It corroborates insufficient source-side segmentation for the tested path. It does not imply that the assumed API attacker created or controls this source.

## 10. Comparison to Legitimate Traffic Budget

| Flow | Budget | Observation |
| --- | --- | --- |
| `demo-api → demo-backend:8081` | Required | Pre and post functionality passed; backend logs showed API Pod requests. |
| `demo-api → temporary unrelated target:8081` | Not intended | Fresh DNS resolution, TCP connection, HTTP 200. |
| `temporary unrelated source → demo-backend:8081` | Not intended | Fresh DNS resolution, TCP connection, HTTP 200. |

The two unintended flows were chosen to answer the threat-model question and a corroborating backend ingress question. No other Services were enumerated for probes and no ports were scanned.

## 11. H3 Assessment Decision

### Demonstrated Impact

The compromised-context `demo-api` Pod can connect to this selected unrelated healthy application listener. Separately, the selected unrelated source can reach the existing backend listener. Each tested request received the synthetic `/data` response.

### Possible Impact

A compromised workload may be able to contact other reachable services outside its intended dependency graph. That possibility was not tested broadly.

### Conditional Impact

Meaningful lateral impact would require a reachable target with security-relevant functionality, trust, weak authentication or authorization, or another exploitable condition. Those conditions were not established by these synthetic listeners.

### Blast-Radius Interpretation

The evidence establishes reachability for two identified Pod-to-Service paths on TCP/8081 at the recorded time. It does not characterize all east-west traffic, other ports, other namespaces, or production behavior.

### Claim Boundaries

Missing NetworkPolicy is not proof of reachability; the DNS, TCP and HTTP observations supply that proof here. Selected unintended reachability does not imply all east-west traffic is unrestricted. A successful connection does not establish target compromise. Assessor-created source does not mean the attacker can create Pods; assessor-created target is not a baseline dependency. `kubectl exec` does not mean the attacker possesses `kubectl`. CNI identity or source support information does not demonstrate NetworkPolicy enforcement in this cluster.

### Decision

**H3 CONFIRMED.** TEST B independently established a fresh connection from the existing assumed-compromised workload context to a selected healthy unrelated listener, outside the documented budget. TEST A adds corroborating reachability to the backend from an unrelated source. This is a C3 decision only; final finding numbering and priority are deferred to C4.

## 12. Fixture Cleanup Verification

The assessor deleted only `Pod/phase-c3-untrusted-8f8d61d1`, `Pod/phase-c3-target-8f8d61d1`, and `Service/phase-c3-target-8f8d61d1`. Exact-name checks found all three absent. A final label query found no C3 Pod or Service, and NetworkPolicy count remained zero. No baseline resource was deleted or changed. See [lifecycle evidence](evidence/phase-c/c3-fixture-lifecycle.txt) and [post-assessment verification](evidence/phase-c/c3-post-assessment-functional.txt).

## 13. Post-Assessment Functional Verification

After cleanup, `make task1-check` again returned **FUNCTIONALITY = PASS**. Both original Pods were 1/1 Running/Ready with zero restarts, original Services remained, all 19 Phase B source hashes matched, and the protected tracked files were unchanged. The [post-assessment artifact](evidence/phase-c/c3-post-assessment-functional.txt) contains the commands and results.

## 14. Evidence Index

| Artifact | Claim supported |
| --- | --- |
| [c3-assessment-context.txt](evidence/phase-c/c3-assessment-context.txt) | Commit, branch, reused cluster, versions, CNI and baseline identities. |
| [c3-pre-assessment-functional.txt](evidence/phase-c/c3-pre-assessment-functional.txt) | Required functional PASS and intended API → backend positive control. |
| [h3-policy-network-inventory.txt](evidence/phase-c/h3-policy-network-inventory.txt) | Baseline Services, EndpointSlices, Pods, NetworkPolicy inventory and CNI image. |
| [c3-fixture-lifecycle.txt](evidence/phase-c/c3-fixture-lifecycle.txt) | Unique fixture specs/identities, target health, Service wiring, cleanup. |
| [h3-network-reachability.txt](evidence/phase-c/h3-network-reachability.txt) | Time-bound source/destination identities and raw/parsed DNS, TCP, HTTP results for B and A. |
| [c3-post-assessment-functional.txt](evidence/phase-c/c3-post-assessment-functional.txt) | Required functional PASS, hashes, baseline readiness and fixture/policy absence. |

## 15. Unexpected Observations

None observed.

## 16. Problems Encountered and Resolutions

The host's default PATH did not contain the repository-local `kind` and `kubectl` binaries; the assessment used the tools through `task1/scripts/common.sh` or their explicit `.local/bin` path. The workspace sandbox initially denied Docker-socket access for the ownership check; scoped access to the existing owned lab resolved that. Neither issue changed cluster configuration or the baseline. No probe, fixture-health, or cleanup failure occurred.

## 17. Files Created or Modified

Created this report and the six C3 evidence artifacts in Section 14. No tracked file, baseline workload input, prior Phase B/C evidence, NetworkPolicy, CNI, RBAC, Deployment, or baseline Service was modified. The temporary assessor script under `/tmp`, its Python bytecode cache, and the three Kubernetes fixtures were removed. No commit, push, or branch switch occurred.

## 18. Security Claims Explicitly NOT Made

No claim is made that all east-west traffic is unrestricted, the temporary target or backend was compromised, arbitrary workloads are reachable, the attacker can create Kubernetes workloads, the attacker has operator credentials or `kubectl`, or the current CNI enforces any prospective policy. No H1/H2/H4 reassessment, remediation, NetworkPolicy enforcement test, C4 synthesis, or production inference was performed.

## 19. Open Questions for Phase D

What exact workload network policy would preserve API → backend, DNS, and required health behavior while blocking the demonstrated unintended paths? Does this exact kindnet runtime enforce the needed policy semantics? Only if necessary after that validation, would another CNI such as Calico be required? Those are future control and compatibility questions, not C3 answers.

## 20. Readiness for Phase C4 Synthesis

The source and runtime identities were verified; intended and target-health controls passed; the primary and corroborating fresh flows have layered DNS/TCP/HTTP evidence; H3 has a bounded decision; all fixtures were removed; and post-assessment functionality and source integrity passed. No C3 blocker prevents independent C4 synthesis.

C3 READY FOR PHASE C4 SYNTHESIS
