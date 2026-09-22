# Task 1 — D3R-1 Read-Only NetworkPolicy Enforcement Diagnosis

## 1. Executive Summary

**D3 remains NOT READY.** This D3R-1 run made no runtime mutation and did not reapply the failed NetworkPolicies. Historical D3 behavior establishes two failed denials. Retained kindnet logs place the observed implementation failure at its nftables/netlink synchronization boundary, but neither those logs nor current read-only inspection identify the failing message or prove whether its cause is controller/userspace behavior or host/kernel behavior. Primary classification: **D — Insufficient Evidence / Unresolved Cause**, confidence **MEDIUM**. A future, separately authorized **D3R-1B is required** to test one bounded transaction after confirming the best available binary/source provenance. Recovery decision: **ROOT CAUSE INSUFFICIENTLY ISOLATED**; no repair or replacement networking implementation is selected.

## 2. Starting State

D3R began from clean commit `c62577f1e8e6d50c131676a5e5d219feb467d3e4` on `temp/work-in-progress`; [D3R-0 context](evidence/phase-d/d3r0-context.txt) records the initial Git status, source review and read-only ownership check. The official [assignment](case-study-secops-engineer-2026.pdf), Task 1 on pages 1–3, was reviewed directly: it assumes a representative Kubernetes workload and secure underlying platform for the exercise, asks for assessment and risk priority, safer manifests with working functionality, detection/prevention reasoning, and a rollout approach that limits production outages. This investigation addresses only the D3 enforcement blocker.

Historical rollback evidence plus current read-only Kubernetes inventory agree on the accepted D2 runtime: exactly **0 NetworkPolicies**, no D3 temporary Pods or Services, the same Ready API and backend Pods/imageIDs with zero restarts, both dedicated ServiceAccounts `automountServiceAccountToken=false`, no exact F2 Role or RoleBinding, and `phase-c-fixture` present with `marker=baseline`. The current cluster is `secops-lab`, context `kind-secops-lab`, namespace `secops-demo`. This verifies the D2 control state; it does not rerun functionality or F1/F2 smoke.

## 3. Frozen D3 Evidence

The substantively immutable [D3R-0 freeze](phase-d-d3r0-blocker-freeze.md) preserves the prior finding. Clerical correction after D3R-1 began: the freeze's opening timestamp field was changed from `Freeze boundary: 2026-09-22T08:54:43Z` to `Last pre-freeze clock observation: 2026-09-22T08:54:43Z; the exact file-write instant was not captured`, because the prior wording incorrectly implied an exact file-write time. The blocker, uncertainty and open questions were unchanged. **HISTORICAL DURING FAILED D3:** at 08:11:53Z on 2026-09-22, both policies were admitted and selected their intended Pods; no unrelated selecting policy existed. Fresh API → unrelated target TCP/8081 and unrelated source → backend TCP/8081 each connected and returned HTTP 200, so both required denials failed. API → backend TCP/8081, normal DNS and explicit UDP/TCP 53 DNS, unrelated source → unrelated target, target health/Service wiring, functionality, readiness/liveness, F1 and F2 remained healthy. Kindnet logged nftables sync errors and queue drops; the intended table was absent while policies still existed. [D3 report](phase-d-d3-report.md), [reachability](evidence/phase-d/d3-post-policy-reachability.txt), and [historical diagnosis](evidence/phase-d/d3-enforcement-diagnosis.txt) support these statements. D3 ended `D3 NOT READY` and the policies were removed.

## 4. Host / Virtualization Context

**CURRENT READ-ONLY D3R OBSERVATION:** the host is Ubuntu 24.04.3 LTS under kernel `5.15.167.4-microsoft-standard-WSL2` (`LAPTOP-92J1MGF7`); `/proc/version` agrees. Docker client/server each report 29.3.0. The owned `secops-lab-control-plane` Docker container uses the pinned node image ID `sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48`, is privileged, has Docker network mode `kind`, and reports unconfined seccomp/AppArmor settings. It is a container sharing the host kernel. WSL2 is observed context, **not a demonstrated cause**. [Host/node evidence](evidence/phase-d/d3r1-host-node-context.txt).

## 5. Kind Node / Kernel Context

The Debian 12 kind node reports the **same** `5.15.167.4-microsoft-standard-WSL2` kernel and containerd `v2.2.0`. Node `nft` is v1.0.6; `iptables` is v1.8.9 using the `nf_tables` backend. `nft list tables`, `nft list ruleset`, `iptables-save`, and `ip6tables-save` each exited 0. Current tables are ip/ip6 nat, mangle and filter; the [raw current inventory](evidence/phase-d/d3r1-nft-runtime.txt) includes the ruleset and save output. These are **current post-rollback reads**, not a reproduction of the policy-applied failure. They prove listing works and existing netfilter state is readable, not that kindnet's write transaction works.

Targeted read-only checks found `net.bridge.bridge-nf-call-iptables=1`, `net.bridge.bridge-nf-call-ip6tables=1`, `net.ipv4.ip_forward=1`, `net.netfilter.nf_conntrack_max=262144`, ordinary pod routes and veth interfaces. The node's readable `/proc/config.gz` reports `CONFIG_NETFILTER=y`, `CONFIG_NETFILTER_NETLINK=y`, `CONFIG_NETFILTER_NETLINK_QUEUE=y`, `CONFIG_NF_TABLES=y`, `CONFIG_NF_TABLES_INET=y`, `CONFIG_NFT_CT=y`, and related options. This weakens a broad claim that nftables/netfilter is absent; it cannot validate every kernel operation in the controller's batch. No broad `sysctl -a` was needed.

## 6. Kernel / Module Claim Boundary

A targeted `/proc/modules` search yielded no relevant module names; `/sys/module` showed some `nf_conntrack` entries. **Absence from `lsmod` or `/proc/modules` is not proof that functionality is unsupported**, because code may be built into the kernel. `/boot/config-$(uname -r)` was unavailable, but `/proc/config.gz` was readable. **Missing kernel configuration evidence is not proof that an option is disabled**. No host/kernel incompatibility is established by the WSL string, module visibility, or current read success.

## 7. Kindnet Runtime Configuration

The live kindnet DaemonSet has desired/ready **1/1**. Pod `kindnet-n2pj4` has UID `6e4afac8-6fc5-491d-9a0d-f96b7007c540`, is Ready on `secops-lab-control-plane`, and uses image `docker.io/kindest/kindnetd:v20251212-v0.29.0-alpha-105-g20ccfc88` with runtime imageID `sha256:4921d7a6dffa922dd679732ba4797085c4f39e9a53bee8b6fdb1d463e8571251`. No command or args override is set; CRI metadata shows default `Cmd=[/bin/kindnetd]`. Environment includes downward-API `HOST_IP`/`POD_IP`, `POD_SUBNET=10.244.0.0/16`, and `CONTROL_PLANE_ENDPOINT=secops-lab-control-plane:6443`. It runs with `hostNetwork=true`, ServiceAccount `kindnet`, non-privileged container security context with added `NET_RAW` and `NET_ADMIN`, and recorded host mounts for CNI config, xtables lock, read-only modules and NRI. These settings, plus the historical sync log, are consistent with an operating NetworkPolicy reconciliation path; configuration alone does not show successful enforcement.

Current restart count is **4**, with last termination at `03:41:05Z` and current container start at `03:41:12Z`, before the D3 policy apply at `08:11:53Z`. The present evidence shows no restart during D3. The prior restarts are context, not attributed to this failure. [Kindnet state](evidence/phase-d/d3r1-kindnet-state.txt).

## 8. Kindnet Failure Log Analysis

Retained logs cover the historical window. The first relevant log at `08:11:53.744Z` is `controller.go:711 "Syncing nftables rules"`, immediately after policy admission. At `08:11:53.983Z`, `controller.go:925 "syncing nftables rules"` reports `conn.Receive: netlink receive: no such file or directory` with repeated ENOENT lines. The controller then logs `"syncing"` errors, retries sync several times, emits `"Unhandled Error"`, and `"Dropping out of the queue"` for `dummy-key`. The selected log window records 24 sync starts, 24 sync errors, four unhandled errors and four queue drops; another cluster of failures appears around `08:19:02–08:19:04Z` near policy removal. The log does **not** name either NetworkPolicy object; the relationship to application comes from the apply timestamp and historical object evidence. No successful policy-table recovery appears in the captured applied-policy interval. Nearby recurring `main.go` node handling is observed, without a demonstrated causal role. [Bounded log analysis](evidence/phase-d/d3r1-kindnet-log-analysis.txt).

## 9. Source / Binary Provenance

Local CRI metadata binds the running kindnet to its imageID but supplies **no repoDigest, source revision label, or embedded build commit**. The tag's `g20ccfc88` suffix alone is insufficient to establish an exact source commit or the precise `kube-network-policies` dependency revision. Exact binary/source provenance is **INSUFFICIENT**. The authoritative current upstream [kindnet entrypoint](https://github.com/kubernetes-sigs/kind/blob/main/images/kindnetd/cmd/kindnetd/main.go) and [dataplane controller](https://github.com/kubernetes-sigs/kube-network-policies/blob/main/pkg/dataplane/controller.go) provide **approximate source-path correlation**, not an exact binary mapping. No similar upstream issue is treated as proof by resemblance.

## 10. Failing Operation / Source Correlation

The historical log directly supports a failed kindnet nftables synchronization call returning a netlink ENOENT family and a queue drop. In current upstream source, `syncNFTablesRules` queues an `inet` table **add/delete/add** sequence, sets, chains and rules, then calls `nft.Flush()`; the `"syncing nftables rules"` error is emitted when that Flush fails. This aligns with the log string and source location family and suggests a **composite nftables/netlink transaction boundary**. Because exact source provenance and per-message extended error data are absent, **the individual failing primitive is UNKNOWN**: table lifecycle, set, chain, rule/queue expression, transaction ordering or another request cannot be singled out. The upstream code path is supporting inference only. [Source and log correlation](evidence/phase-d/d3r1-kindnet-log-analysis.txt).

## 11. NetworkPolicy Static Reassessment

Static review of the unchanged [candidate](../task1/hardened/network-policy.yaml) found **no concrete semantic defect**. The API `app=demo-api` policy selects Egress and allows only same-namespace backend `app=demo-backend` TCP/8081 plus one peer combining `kube-system` namespace selector **AND** `k8s-app=kube-dns` Pod selector on UDP/TCP 53. The backend `app=demo-backend` policy selects Ingress and permits same-namespace API `app=demo-api` TCP/8081. Historical D3 observed matching admitted labels and no broader additive selecting policy. [Kubernetes NetworkPolicy semantics](https://kubernetes.io/docs/concepts/services-networking/network-policies/) support this reading. The policy is plausible for the tested matrix; it is not formally proven correct, and no policy object was reapplied or edited here.

## 12. Layered Diagnosis

### Layer 1 — Policy / Configuration

Admission, selected Pods, direction, peer, protocol and port checks weaken a policy-design explanation. The policy remains a failed candidate because behavior did not match intent. No specific selector or additive-policy defect explains both HTTP 200 outcomes.

### Layer 2 — Networking Component / Runtime

Historical logs show kindnet entered sync, retried and dropped queued work; current configuration and Pod state show the component exists with expected permissions and no D3-time restart. This is the **observed failing boundary**. It does not isolate a kindnet bug rather than a failed lower-layer request.

### Layer 3 — nftables / netlink Interaction

The historical `conn.Receive` ENOENT family occurred during nftables sync, plausibly at a composite Flush. Current read-only nft/iptables commands work. The exact message and whether userspace constructed an invalid transaction remain unknown. A successful `nft list` cannot prove successful mutation.

### Layer 4 — Host / Kernel Capability or Compatibility

Host and kind node share a WSL2 kernel and relevant options are configured. Those facts neither prove nor exclude a narrower incompatibility in the requested transaction. There is **no direct evidence** establishing an unsupported required primitive, so classification C is not justified.

## 13. Historical Enforcement Consistency

**HISTORICAL DURING FAILED D3:** both forbidden fresh flows returned HTTP 200, the intended policy table was absent while both policies were applied, and kindnet logged a failed sync and queue drop. Together with admitted selection and no broader additive policy, this more strongly supports **rules failing to materialize/enforce** than fully installed rules that semantically allowed both flows. The table observation was a point-in-time read and the log is a correlated failure path; neither proves which lower-level operation failed. **CURRENT D3R:** zero policies and no policy table after rollback cannot reproduce the historical failure.

## 14. Root-Cause Classification

**D — Insufficient Evidence / Unresolved Cause.** Direct evidence proves the two enforcement failures and kindnet's nftables sync error; it does not distinguish a controller/library transaction defect from a kernel/netlink compatibility or dependency issue. The [root-cause matrix](evidence/phase-d/d3r1-root-cause-matrix.txt) separates direct, supporting and correlated observations. A is weakened; B is the observed boundary but not an established underlying cause; C lacks required direct primitive evidence.

## 15. Confidence and Competing Hypotheses

**MEDIUM** confidence in D. The failure is well localized to the controller's sync boundary, but exact binary provenance and the failed member of its composite transaction are missing. Material alternatives are a kindnet/controller or nftables library request/ordering defect; a specific host/kernel netlink operation incompatibility; and a narrower environmental dependency affecting NFQUEUE/conntrack related objects. Broad claims that WSL, kind, or nftables in general cannot support NetworkPolicy are not supported.

## 16. D3R-1B Requirement

**YES**, in a separately authorized, mutating diagnostic run. **Single question:** does a collision-resistant, isolated `inet` table **add/delete/add in one batch**, matching the first known upstream sync sequence, itself return ENOENT on this node? The suspected primitive is the **batched inet table lifecycle**; the actual failing member of kindnet's larger batch remains UNKNOWN. A failure would implicate the base transaction/netlink environment; a success would shift attention to later set, chain, rule/queue or Go library operations. It would **not** prove the complete kindnet batch works. Before that run, confirm the closest available binary/dependency provenance so the test stays tied to the controller path; if the sequence cannot be confirmed, defer mutation and refine the question instead of substituting a generic `nft add table` probe.

The least powerful proposed future mutation is one temporary, **unhooked** uniquely named `inet` table transaction, with no policy application or CNI restart. It must check exact name absence first, capture pre-state, touch no existing table/chain/set/rule, capture the exact result/error, delete only the created diagnostic table if present, capture post-state and prove zero residual object. No persistence, component restart or NetworkPolicy reapply is allowed in that later safety contract. **No D3R-1B mutation was executed now.**

## 17. Recovery Decision

**ROOT CAUSE INSUFFICIENTLY ISOLATED.** No minimal repair is justified without knowing whether the request or its environment failed, and no environment revision class is justified by WSL context or a similar upstream issue. D3R-1B is the next bounded diagnostic gate; it is not permission to execute a repair.

## 18. Future Runtime Evidence Invalidation

If a future phase recreates the cluster, changes networking implementation, or materially changes the host environment, historical D1/D2 runtime smoke, D3 pre/post-policy reachability, Pod UID/IP/imageID, CNI/DNS inventory and health observations do **not** automatically apply to that environment. Phase A/B/C reasoning, D0 control objectives and declarative F1/F2/F3 design may remain as source/design inputs if still applicable. A revised environment must deploy accepted F1 artifacts and pass F1 runtime smoke, apply accepted F2 artifacts and pass F2 smoke, pass functionality, **reproduce the F3 pre-policy weakness again**, then apply the F3 candidate and rerun the **full D3** positive/negative, DNS, health and noninterference matrix. Only a passing full matrix could later change D3 readiness.

## 19. Files Created or Modified

Created `docs/phase-d-d3r0-blocker-freeze.md`, this report, `docs/evidence/phase-d/d3r0-context.txt`, `d3r1-host-node-context.txt`, `d3r1-nft-runtime.txt`, `d3r1-kindnet-state.txt`, `d3r1-kindnet-log-analysis.txt`, `d3r1-root-cause-matrix.txt`, and `d3r1-readonly-compliance.txt`. No pre-existing source, manifest, script, report or evidence file was modified.

## 20. Read-Only Compliance

The [current-run command/evidence audit](evidence/phase-d/d3r1-readonly-compliance.txt) records **no Kubernetes mutation, NetworkPolicy reapply, nftables or iptables mutation, route/link/tc mutation, sysctl/module mutation, process/component restart, CNI replacement or cluster recreation**. Docker/kubectl calls were reads; repository writes were limited to the D3R allowlist. No unrelated shell history was inspected.

## 21. D3R-1 Exit Decision

Read-only diagnosis identified the kindnet synchronization boundary and bounded the unresolved cause. D3 remains `D3 NOT READY`; neither F3 acceptance nor a recovery technology follows from this run.

D3R NOT READY — ROOT CAUSE INSUFFICIENTLY ISOLATED
