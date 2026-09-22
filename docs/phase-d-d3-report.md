# Task 1 — Phase D3 F3 NetworkPolicy Candidate

## 1. Executive Summary

The D3 candidate implements native Kubernetes NetworkPolicy for `demo-api` egress and `demo-backend` ingress. The current owned kind cluster admitted both objects but **did not enforce either required denial** in fresh Service-level tests: API → unrelated target and unrelated source → backend each still returned HTTP 200. Required API → backend traffic, DNS, functionality, health, and accepted F1/F2 controls passed. Kindnet logged nftables sync errors after policy application; the node table inventory did not show the intended policy table. No CNI replacement or cluster reconfiguration occurred. The two failed D3 policies were removed, restoring the accepted D2 runtime. D3 is a candidate validation stage; formal same-oracle BEFORE/AFTER proof remains Phase E after D4.

## 2. Starting Context and Integrity

D3 started at commit `eabd67131696beb45dec612d9f8caf747d8dfe6e` on `temp/work-in-progress` with a clean Git status. The exact start clock time was not captured; the first recorded runtime check was at 08:04Z on 2026-09-22. The owned `secops-lab` cluster, `kind-secops-lab` context, and `secops-demo` namespace passed the repository ownership check. Every row dynamically parsed from the canonical Phase B [integrity record](evidence/phase-b/workload-revision.txt) matched SHA-256 before and after D3. The complete protected D1/D2 hardened file set is recorded in [D3 context](evidence/phase-d/d3-context.txt).

The accepted API Pod was `demo-api-6d49d5c8bd-nmjr5`, UID `67e10621-03de-45f3-a6f2-8bcc30f0d9d4`, image `secops-demo-api:phase-d1`, imageID `sha256:cb82d20063553272d86db019ed015e599633f616535c8ffbed98eae1b5224e25`. The backend Pod was `demo-backend-5d4449cb58-vzhs2`, UID `65aa8380-cd09-4da0-85af-4ec762f68f37`, image `secops-demo-backend:phase-b`, imageID `sha256:89a9dc8d230e5115be9a00823b47811002332014d46f09548b11d2931f876d41`. Both were Ready with zero restarts. Both ServiceAccounts had automount disabled; projected credentials, the F2 Role and RoleBinding were absent; the fixture ConfigMap marker was `baseline`; NetworkPolicy count was zero. Pre-D3 `make task1-check`, F1 smoke, and F2 smoke all passed. See [context](evidence/phase-d/d3-context.txt).

## 3. Current Cluster Network Context

The one Ready node ran Kubernetes v1.34.3 with node image `kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48`. Observed system components were kindnet `docker.io/kindest/kindnetd:v20251212-v0.29.0-alpha-105-g20ccfc88`, kube-proxy v1.34.3, and CoreDNS v1.12.1. The initial namespace NetworkPolicy count was zero. API and backend admitted labels were `app=demo-api` and `app=demo-backend`; their Services and EndpointSlices resolved to the expected Pods. See [network inventory](evidence/phase-d/d3-network-inventory.txt). Component presence alone was not treated as enforcement evidence.

The API's `/etc/resolv.conf` named `10.96.0.10`, the `kube-dns` Service. Its ready EndpointSlice mapped UDP/TCP 53 to ordinary, non-host-network CoreDNS Pods at `10.244.0.2` and `10.244.0.3` in `kube-system`, both labeled `k8s-app=kube-dns`. This observed path supports a namespace-and-Pod selector. No node-local or host-network DNS resolver was observed.

## 4. F3 Policy Design

### demo-api Egress

[The candidate](../task1/hardened/network-policy.yaml) selects `app=demo-api` for `Egress`. It permits same-namespace `app=demo-backend` Pods on TCP/8081 and the verified DNS Pods on UDP/53 and TCP/53. Other egress has no allowance from this policy, subject to Kubernetes's additive policy union. There was no other selecting policy in the effective namespace.

### demo-backend Ingress

The second policy selects `app=demo-backend` for `Ingress`, permitting same-namespace `app=demo-api` Pods on TCP/8081. There was no other selecting ingress policy.

### Selector Trust Boundary

The design assumes trusted Kubernetes deployment and platform paths control the `app` labels. The assumed attacker has code execution in the API container and no authority to create or relabel Pods or templates. Protection against an actor with such Kubernetes mutation authority is outside this tested F3 scope.

### Explicitly Unselected Directions

No API ingress isolation, backend egress isolation, namespace default deny, cross-namespace application restriction, Service change, or CNI replacement was selected. The API ingress row in the baseline budget was not one of the demonstrated F3 paths.

## 5. DNS Design

The policy's one DNS peer combines `kubernetes.io/metadata.name=kube-system` namespaceSelector **AND** `k8s-app=kube-dns` podSelector. Separate peer entries would be OR alternatives and would be broader. No Service ClusterIP `ipBlock` was used. Normal `getaddrinfo` resolution succeeded both before and after policy application. Separate API-container DNS queries to the observed `kube-dns` Service succeeded on UDP/53 and TCP/53, each returning `rcode=0` and one answer. These are actual post-apply transport observations; because the same cluster failed both policy denials, they do **not** independently prove the DNS allowance was enforced or narrowly selected.

## 6. Test Fixture Design

The [smoke script](../task1/hardened/scripts/smoke-f3.sh) created uniquely named, same-namespace assessor fixtures with local images: an unrelated source Pod, an unrelated target Pod, and a target Service on TCP/8081. Only `assessment.*` labels were used, so neither Pod matched an application allow selector. Both Pods set `automountServiceAccountToken: false`. The target had a ready `/healthz` listener. The script checked Pod-local `/healthz`, Service selector and ready EndpointSlice targetRef UID/IP/port, then used unrelated source → target HTTP 200 as a network-positive control. Fixtures were created by the assessor with operator authority, not by the assumed attacker. See [fixture lifecycle](evidence/phase-d/d3-fixture-lifecycle.txt).

## 7. Pre-Policy Current-State Reproduction

Fresh probes on accepted D2 state showed API → backend HTTP 200, normal DNS and explicit UDP/TCP DNS success, and unrelated source → unrelated target HTTP 200. Both selected F3 weaknesses also reproduced: API → unrelated target HTTP 200 and unrelated source → backend HTTP 200. Each connection used a new Python process/socket in the actual source Pod network context and a Service FQDN. The target Pod and Service were healthy and correctly wired. See [pre-policy reachability](evidence/phase-d/d3-pre-policy-reachability.txt).

## 8. NetworkPolicy Deployment

[deploy-f3.sh](../task1/hardened/scripts/deploy-f3.sh) verified ownership, context, D2 F2 state, expected pre-policy object set, and server-side dry-run scope, then applied only the D3 YAML. At 08:11:53Z the API egress and backend ingress objects were admitted. The post-apply count was two, with exactly `demo-api-egress` and `demo-backend-ingress`; effective YAML matched the reviewed selectors, peers, protocols and ports. The original API and backend Pod UIDs, images, Services, and CNI configuration were unchanged; no rollout was done. See [policy apply](evidence/phase-d/d3-policy-apply.txt) and [deploy run](evidence/phase-d/d3-deploy-run.txt). Admission is configuration evidence, not enforcement proof.

## 9. Current-Cluster Enforcement Matrix

| Flow | Required candidate state | Pre-policy | Post-policy | Result |
| --- | --- | --- | --- | --- |
| API → backend TCP/8081 | ALLOW | DNS, TCP, HTTP 200 | DNS, TCP, HTTP 200 | PASS |
| API → normal DNS resolver | ALLOW | Resolved | Resolved | PASS for behavior; allowance enforcement unproven |
| API → DNS UDP/53 | ALLOW | DNS answer | DNS answer | PASS for behavior; allowance enforcement unproven |
| API → DNS TCP/53 | ALLOW | DNS answer | DNS answer | PASS for behavior; allowance enforcement unproven |
| Unrelated source → unrelated target TCP/8081 | ALLOW | HTTP 200 | HTTP 200 | PASS |
| Unrelated source → backend TCP/8081 | DENY | HTTP 200 | HTTP 200 | **FAIL** |
| API → unrelated target TCP/8081 | DENY | HTTP 200 | HTTP 200 | **FAIL** |
| Health/readiness/liveness | PASS | Both Ready, zero restarts | Both Ready, zero restarts through 22 s | PASS |
| Functional port-forward checks | PASS | `FUNCTIONALITY = PASS` | `FUNCTIONALITY = PASS` | PASS |

The complete candidate run was after policy admission and used newly created fixtures and fresh sockets. See [post-policy reachability](evidence/phase-d/d3-post-policy-reachability.txt), [health window](evidence/phase-d/d3-health-window.txt), and [functional oracle](evidence/phase-d/d3-post-functional.txt). The first candidate smoke stopped after the API egress failure; the corrected run collected both failed denials.

## 10. Negative-Test Controls

Both would-be negative FQDNs resolved to the expected Service ClusterIPs. The unrelated target had Pod-local `/healthz` HTTP 200, a Ready Pod, and a matching ready EndpointSlice; unrelated source → target returned HTTP 200 after policy apply. The backend was Ready, had a correct Service/EndpointSlice, and API → backend returned HTTP 200. Thus the expected denials were not masked by DNS failure, dead listeners, broken Services, or source networking. The observed HTTP 200 on fresh sockets is itself direct evidence that the two paths remained reachable. The effective policy inventory showed no additional policy reopening them. Kindnet's attempted nftables sync logged repeated `netlink receive: no such file or directory` errors and dropped the work item; node `nft list tables` showed only the existing ip/ip6 nat, mangle and filter tables, with no policy table. See [diagnosis](evidence/phase-d/d3-enforcement-diagnosis.txt). This supports an implementation/configuration enforcement failure in this cluster; the underlying netlink or kernel cause was not isolated.

## 11. Functional and Probe Compatibility

Post-apply `make task1-check` passed backend and API health/data, repeated API `/data`, and `/tmp` cache readback. It uses loopback `kubectl port-forward` and is application/diagnostic evidence, not ordinary API ingress NetworkPolicy proof. Admitted readiness period was 2 s and liveness period 10 s (initial delay 3 s, timeout 1 s, failure threshold 3). A 22 s observation covered multiple readiness evaluations and at least two nominal liveness periods: both same Pod UIDs remained Ready with zero restarts. Listed warning events were 48 minutes old, before policy apply. See [health window](evidence/phase-d/d3-health-window.txt).

## 12. F1 Non-Interference

Post-apply F1 smoke passed. The accepted API image/imageID, non-root PID 1 UID/GID 65534, all-zero capability masks, `NoNewPrivs=1`, read-only `/` and `/app`, denied `/app` create, and writable updated `/tmp` cache were observed. See [F1 regression](evidence/phase-d/d3-post-f1.txt). This is continuity evidence, not a new F1 proof.

## 13. F2 Non-Interference

Post-apply F2 smoke passed. Both ServiceAccounts remained automount=false; no projected token or process-visible token path appeared; exact Role and RoleBinding remained absent; named ConfigMap GET/PATCH `can-i` returned no; fixture marker remained `baseline`. See [F2 regression](evidence/phase-d/d3-post-f2.txt). This is continuity evidence, not Phase E workload-token comparison.

## 14. Current Cluster Enforcement Conclusion

The current owned kind cluster **did not enforce the required F3 NetworkPolicy semantics for the tested flow matrix**. Both selected unwanted Service paths remained connected and returned HTTP 200 while both policies were admitted and selected the intended Pods. The kindnet nftables sync errors and absent policy table are correlated implementation evidence, not a demonstrated root cause of the netlink failure. No conclusion about every NetworkPolicy feature or another environment follows. D3 candidate acceptance failed; no formal Phase E remediation claim is made.

## 15. Compatibility Findings

The initial post-policy smoke stopped at the first failed negative result and incorrectly labeled otherwise successful fixture cleanup as failed because it reused the probe exit status. The script was corrected to collect both negative results and to report cleanup independently; the complete rerun showed both paths still reachable and cleanup PASS. The policy itself preserved observed functionality, DNS, health, F1 and F2. The material unresolved issue is current-cluster policy enforcement, documented above.

## 16. Trade-offs / Implementation Decisions

The selectors use admitted `app` labels, with their trust bounded to the deployment path. The DNS rule follows the observed Pod-backed CoreDNS path; namespace and Pod selectors are one AND peer. Both UDP and TCP DNS were directly queried, but successful queries cannot validate selective policy enforcement when the negative controls fail. The design leaves API ingress, backend egress and namespace-wide default deny unselected because the demonstrated F3 paths do not require them. Native NetworkPolicy remains the D0-selected control class. A different networking implementation is a separate environment-control decision only after the present sync failure is diagnosed; this run did not install one.

## 17. Files Created or Modified

Created `task1/hardened/network-policy.yaml`, `task1/hardened/scripts/deploy-f3.sh`, and `task1/hardened/scripts/smoke-f3.sh`. Created only `docs/evidence/phase-d/d3-*` evidence and this report outside those paths. The protected pre-existing D1/D2 hardened files, application source, insecure manifests, Services and CNI configuration remained unchanged. See [mutation verification](evidence/phase-d/d3-mutation-verification.txt).

## 18. Runtime State at Exit

Because D3 failed, the two D3 NetworkPolicies were deleted and the runtime returned to exact accepted D2 control state: zero NetworkPolicies, same Ready API/backend Pod UIDs and imageIDs, both ServiceAccounts automount=false, no projected credentials, no F2 grant, fixture ConfigMap marker `baseline`, and unchanged Services/CNI. All temporary D3 Pods and Services were removed. After rollback, `make task1-check`, F1 smoke and F2 smoke all passed. See [rollback](evidence/phase-d/d3-rollback.txt) and [rollback verification](evidence/phase-d/d3-rollback-verification.txt).

## 19. D3 Exit Decision

Concrete blocker: the current cluster admitted the two candidate policies but continued to allow both forbidden fresh TCP/8081 connections. Kindnet logged nftables sync errors; the deeper cause of its missing policy rules remains unresolved. D4 integration and Phase E proof cannot proceed from this candidate until the current-cluster enforcement issue is resolved and the full matrix passes.

D3 NOT READY
