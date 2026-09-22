# Task 1 — D3R-1B Bounded nftables Transaction Diagnosis

## 1. Executive Summary

**D3 remains NOT READY.** The single question was whether a version-correlated, isolated `inet` AddTable/DelTable/AddTable/Flush transaction in the owned kind node namespace independently reproduces the historical netlink ENOENT family. **No nftables mutation or primary Flush was executed:** the required locally installed Go toolchain is absent, and installation is prohibited. Upstream source provenance is **VERSION-CORRELATED**; the proposed default `nftables.New()` matches the pinned source design, but actual connection and privilege comparability are **DEGRADED / untested** because no helper ran. The result is **DIAGNOSTIC NOT EXECUTABLE**. There was no temporary object to clean up. The historical D3 failure remains unexplained below kindnet's synchronization boundary; recovery remains **ROOT CAUSE INSUFFICIENTLY ISOLATED**.

## 2. Starting State

The clean starting commit was `7b9c7e933d24794db7503374a603ca94e5d6bb1f` on `temp/work-in-progress` (initial `git status --short --untracked-files=all` empty). The owned cluster/context/namespace are `secops-lab` / `kind-secops-lab` / `secops-demo`. Read-only inspection found the accepted D2 API and backend Pods both Ready with zero restarts, the two application Services, both dedicated ServiceAccounts with automount disabled, no Role/RoleBinding, and `phase-c-fixture` marker `baseline`. NetworkPolicy count was **0**; D3 temporary Pods and Services were absent. Kindnet `kindnet-n2pj4` was Ready on `secops-lab-control-plane`, UID `6e4afac8-6fc5-491d-9a0d-f96b7007c540`, restartCount **4**, current container started `2026-09-22T03:41:12Z`. [Context](evidence/phase-d/d3r1b-context.txt) records these observations.

## 3. D3R-1 Input

The [D3R-1 diagnosis](phase-d-d3r1-diagnosis.md) ends exactly `D3R NOT READY — ROOT CAUSE INSUFFICIENTLY ISOLATED`. Its classification is **D — Insufficient Evidence / Unresolved Cause**, confidence **MEDIUM**, and it requires D3R-1B. Historical D3 admitted the two NetworkPolicies and selected their Pods, but both required fresh TCP/8081 denials still returned HTTP 200. Kindnet logged repeated `conn.Receive: netlink receive: no such file or directory` during nftables synchronization and dropped queued work. Competing causes remain controller request construction, the google/nftables userspace path, kernel/netlink transaction handling, privilege/context, or another member of the composite batch. The [D3R-0 freeze](phase-d-d3r0-blocker-freeze.md) and [failed D3 report](phase-d-d3-report.md) remain unchanged.

## 4. Provenance Preflight

The running image tag is `docker.io/kindest/kindnetd:v20251212-v0.29.0-alpha-105-g20ccfc88`; imageID is `sha256:4921d7a6dffa922dd679732ba4797085c4f39e9a53bee8b6fdb1d463e8571251`. The suffix resolves to [kind commit `20ccfc88055ce538b79b1685d6a497d35311d7d1`](https://github.com/kubernetes-sigs/kind/commit/20ccfc88055ce538b79b1685d6a497d35311d7d1). Its [kindnet entrypoint](https://github.com/kubernetes-sigs/kind/blob/20ccfc88055ce538b79b1685d6a497d35311d7d1/images/kindnetd/cmd/kindnetd/main.go) creates and runs the NetworkPolicy controller, and its [kindnet go.mod](https://github.com/kubernetes-sigs/kind/blob/20ccfc88055ce538b79b1685d6a497d35311d7d1/images/kindnetd/go.mod) pins `sigs.k8s.io/kube-network-policies v0.8.0` and `github.com/google/nftables v0.3.0`. The [v0.8.0 controller](https://github.com/kubernetes-sigs/kube-network-policies/blob/v0.8.0/pkg/networkpolicy/controller.go), tag commit `d661fc1da10423068b97136e00e43fe819fe1e00`, queues the exact selected table sequence and later objects before Flush; its [go.mod](https://github.com/kubernetes-sigs/kube-network-policies/blob/v0.8.0/go.mod) directly pins nftables v0.3.0. Local CRI metadata has no repo digest or embedded build/source revision, so provenance is **VERSION-CORRELATED**, not EXACT. [Provenance evidence](evidence/phase-d/d3r1b-provenance.txt) records precise paths and line locations.

## 5. Connection Construction Equivalence

The tagged controller calls `nftables.New()` with **no options**. In [google/nftables v0.3.0](https://github.com/google/nftables/blob/v0.3.0/conn.go), the default connection is transient, uses `NETLINK_NETFILTER` with no explicit network namespace fd, and has no custom socket options or lasting mode. The controller's table is `TableFamilyINet` with no nonzero table flags. The reviewed helper design would call the same constructor and use the same family/zero flags. No helper was built, so observed helper construction is unavailable: **DEGRADED** comparability for this unexecuted test. [Connection semantics](evidence/phase-d/d3r1b-connection-semantics.txt).

## 6. Execution Context Comparison

CRI and live `/proc/1675/status` identify the kindnet process. A read-only Docker-exec shell on the node was used solely as a proxy for a possible helper process; it was not the diagnostic helper.

| Property | kindnet | helper / node-exec proxy | Comparable? |
| --- | --- | --- | --- |
| UID/GID | 0/0 effective | Helper N/A; proxy 0/0 | Planned identity only |
| CapEff | `00000000a80435fb` | Helper N/A; proxy `000001ffffffffff` | No, proxy broader |
| CapBnd | `00000000a80435fb` | Helper N/A; proxy `000001ffffffffff` | No, proxy broader |
| NET_ADMIN | Present | Helper N/A; proxy present | Authority level differs |
| NET_RAW | Present | Helper N/A; proxy present | Authority level differs |
| privileged | Pod container false | Helper N/A; node container true | No |
| network namespace | `net:[4026532326]` | Helper N/A; proxy `net:[4026532326]` | Proxy matched |
| node | `secops-lab-control-plane` | Helper N/A; proxy same node | Proxy matched |

Kindnet's CapPrm is also `00000000a80435fb`; configured additions are NET_RAW and NET_ADMIN. The proxy's broader capabilities would constrain interpretation even if a future helper passed: such a PASS would not prove kindnet itself had sufficient authority. Actual helper privilege-context comparability is **DEGRADED / untested**. [Execution-context evidence](evidence/phase-d/d3r1b-execution-context.txt).

## 7. Architecture and Build

Host and node each report `x86_64`, mapping to intended `GOOS=linux`, `GOARCH=amd64`. Host `go version` and `go env GOOS GOARCH` both exited **127** with `zsh:1: command not found: go`; a search of installed executable locations found no Go binary. No compiler/toolchain may be installed or auto-downloaded. `GOTOOLCHAIN=local`, isolated `/tmp` build/cache paths, temporary go.mod/go.sum, helper binary, `file`, `go version -m`, and SHA-256 are therefore **N/A**. The selected dependency remains `github.com/google/nftables v0.3.0`; tagged source was inspected read-only, and no module download/build took place. [Build evidence](evidence/phase-d/d3r1b-helper-build.txt); [source non-creation record](evidence/phase-d/d3r1b-helper-source.txt).

## 8. Selected Primitive

The source-selected primitive is exactly:

```text
inet table
AddTable
DelTable
AddTable
Flush
```

The tagged controller queues sets, chains, rules, NFQUEUE and DNS workaround operations later in the same full batch. They were excluded to test only whether its initial table lifecycle is independently sufficient for the historical error. None was executed here.

## 9. Cleanup Prepared Before Mutation

**N/A.** The missing-toolchain gate prevented selection of a table name, helper creation, and all nftables mutation. No cleanup wrapper/trap was needed or created. In any later run, exact `nft list table inet <unique-name>` and `nft delete table inet <unique-name>` must be established before the first diagnostic Flush; only that table may be deleted. This is a future safety condition, not a cleanup operation performed here.

## 10. Pre-Mutation Safety Check

No primary mutation was reached, so no immediately preceding exact-name absence check was performed. The read-only [pre-state](evidence/phase-d/d3r1b-pre-state.txt) records **0** NetworkPolicies and the complete table-name set: `ip/nat`, `ip/mangle`, `ip/filter`, `ip6/mangle`, `ip6/nat`, `ip6/filter`; no `inet` table appears. Unique diagnostic table name: **N/A**. No pre-existing table was eligible to be touched.

## 11. Primary Execution

Primary helper executions: **0**. Primary Flush executions: **0**. Flush result: **NOT EXECUTED**. Helper exit status, Go error type and text, exact `errors.Is(..., syscall.ENOENT)` result, and text-family match: **N/A**. [Execution evidence](evidence/phase-d/d3r1b-execution.txt).

## 12. Result Classification

**DIAGNOSTIC NOT EXECUTABLE.** Provenance was sufficient to select a version-correlated primitive; the required already-installed Go toolchain was unavailable. This is an executability stop, not a provenance stop and not an observed transaction result.

## 13. Diagnostic Interpretation

The source lineage and default connection behavior are now better isolated than in D3R-1. The authoritative question remains **unanswered** because no library transaction ran. No evidence from this run supports a PASS, exact ENOENT reproduction, text-only match, or different nftables error.

### What This Experiment Does NOT Establish

It does not identify the historical failing netlink message or prove a google/nftables, kindnet, kernel/WSL, privilege, or NetworkPolicy semantic root cause. The Docker-exec proxy has broader authority than kindnet, and no helper result exists to interpret. It does not establish F3 acceptance or D3 readiness.

## 14. Updated Root-Cause Boundary

| Layer | Status | Reason |
| --- | --- | --- |
| Policy/configuration | WEAKENED | Historical admission/selection and both forbidden HTTP 200 flows remain; no new policy test occurred. |
| Controller/runtime | SUPPORTED as observed boundary; root cause UNRESOLVED | The tagged source now matches historical controller log lines and Flush location, but no member of the batch was isolated. |
| google/nftables userspace | UNRESOLVED | Version pinned to v0.3.0; no diagnostic call ran. |
| Kernel/netlink | UNRESOLVED | Historical ENOENT family persists as prior evidence; no direct base transaction result. |
| Privilege/execution context | UNRESOLVED | Kindnet has NET_ADMIN; possible Docker-exec helper authority is broader and actual helper was absent. |

Classification D and MEDIUM confidence remain appropriate.

## 15. Cleanup Verification

No diagnostic table, helper, wrapper or build tree was created, so removal checks for those objects are **N/A**. Final read-only `nft list tables` returned the same six pre-existing ip/ip6 names. Kindnet retained its UID, Ready state, restart count **4**, and container start time; NetworkPolicy count stayed zero, D3 fixtures stayed absent, and the original application Pods remained Ready with zero restarts. [Cleanup record](evidence/phase-d/d3r1b-cleanup.txt) keeps this distinct from primary diagnostic evidence.

## 16. Mutation Scope Compliance

**PASS for this non-mutating preflight.** Kubernetes mutations **NONE**; NetworkPolicy reapply **NO**; existing nftables objects modified **NONE**; diagnostic object **NOT CREATED**; other network/runtime mutations **NONE**. Only new D3R-1B documentation/evidence files were written. [Mutation-scope evidence](evidence/phase-d/d3r1b-mutation-scope.txt).

## 17. Recovery Decision

**ROOT CAUSE INSUFFICIENTLY ISOLATED.** No repair or replacement networking technology is selected. D3 remains NOT READY.

## 18. Next Diagnostic Recommendation

With an already installed, compatible local Go toolchain, does the single v0.3.0 `nftables.New()` inet AddTable/DelTable/AddTable/Flush transaction return exact ENOENT in the owned node network namespace under a recorded helper authority profile?

This is one future diagnostic question only; it was not executed or approved as a continuation of this run.

## 19. Files Created or Modified

Created this report and the ten `docs/evidence/phase-d/d3r1b-*` files: context, provenance, connection-semantics, execution-context, helper-source, helper-build, pre-state, execution, cleanup, and mutation-scope. `task1/**` and all existing D0/D1/D2/D3/D3R-0/D3R-1 artifacts remained unchanged. No commit, push, or branch switch was made.

## 20. D3R-1B Exit Decision

The one permitted diagnostic transaction could not be built under the local-toolchain and no-install requirements. The provenance gate passed; the executability gate stopped all nftables mutation. D3 remains NOT READY.

D3R-1B NOT READY — VERSION-CORRELATED DIAGNOSTIC NOT EXECUTABLE
