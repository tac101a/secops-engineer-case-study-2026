# Task 1 — Phase C0+C1 Assessment Report

## 1. Executive Summary

This run assessed baseline integrity, H1 local container authority, and H4 filesystem writes in the representative `demo-api` workload. The assessment is bounded to the current Pod and harmless probes. **H1 CONFIRMED:** the actual API process runs as UID/GID 0 with nonzero effective and bounding Linux capabilities, although its legitimate privilege budget requires neither. **H4 CONFIRMED:** that process created, read, and removed a file under `/app`, outside its documented `/tmp` write area, on a writable container root mount. Both functional controls passed.

H2, H3, remediation, and final finding selection were outside this run. These C1 decisions do not lock the final Task 1 finding set or priorities; Phase C4 must independently synthesize all Phase C evidence.

## 2. Assessment Context

The [assessment context](evidence/phase-c/assessment-context.txt) records the 2026-09-21 17:22:38 UTC start, assessment-start commit `fcc6251cbf4a1cd1998806ed7ea59f09162166a8`, branch `temp/work-in-progress`, clean starting working tree, and absence of a local `phase-b-baseline` tag. No tag was created or changed.

The owned `secops-lab` kind cluster was **reused**, not recreated. Its context is `kind-secops-lab`, namespace `secops-demo`, node `secops-lab-control-plane` Ready on Kubernetes v1.34.3; kind is v0.31.0 and kubectl client is v1.35.0. The current API Pod was `demo-api-b8dcfccdf-gnv9c`, UID `d5601ad2-6919-4d58-bedf-5b984f0be056`, image ID `sha256:80e1fd9bd1afe996dfb03d6b2839c88d00fc3bca1269a74b10b13acf777a6e1f`. The backend Pod was `demo-backend-549b8f665f-npfsp`, UID `71156c57-8a45-46aa-a365-7566292e6d61`, image ID `sha256:89a9dc8d230e5115be9a00823b47811002332014d46f09548b11d2931f876d41`. Both were Running/Ready with zero restarts. The checkout path and Docker node ID matched the Phase B ownership record before runtime assessment.

## 3. Source of Truth and Baseline Integrity

The [official case-study PDF](case-study-secops-engineer-2026.pdf) is the assignment authority; [Phase A architecture](architecture.md), [Phase B contract](../task1/BASELINE.md), and [Phase B execution report](phase-b-report.md) establish this lab's threat frame, legitimate budgets, and reviewed representative implementation. The PDF's Task 1 scope is described and reconciled in the Phase B report. This C0+C1 run applies those budgets without changing them.

At start, `git status --short --untracked-files=all` was empty. All 19 inputs listed in the Phase B [workload revision record](evidence/phase-b/workload-revision.txt) matched their recorded SHA-256 values before assessment and again afterward, including both Docker contexts, all manifests, `task1/kind.yaml`, scripts, `Makefile`, and the baseline contract. The current Pod names, UIDs, and image IDs matched the Phase B [cluster state](evidence/phase-b/cluster-state.txt); deployed `/app/app.py` hashes matched the source snapshot for both workloads. The protected architecture, application, manifest, and Phase B evidence paths have no tracked Git changes. See [context](evidence/phase-c/assessment-context.txt) and [static review](evidence/phase-c/c0-static-review.txt).

The existing cluster, node, Deployments, and Pods were healthy. The [pre-assessment functional control](evidence/phase-c/c0-pre-assessment-functional.txt) returned `FUNCTIONALITY = PASS` with expected health, backend data, repeated API-to-backend responses, and the legitimate cache content. No rebuild or redeployment was needed.

## 4. Assessment Scope

In scope: C0 baseline integrity, manual H1/H4 source and current Kubernetes configuration review, a focused Trivy Kubernetes misconfiguration scan, actual API process identity and privilege state, its root/mount context, and bounded harmless write probes.

Out of scope: H2 workload identity/RBAC testing; H3 network reachability; remediation or hardening; NetworkPolicy; admission or CI enforcement; and final finding prioritization. No workload token contents, Kubernetes API action by a workload, unintended network flow, or privilege escalation was tested.

## 5. Static Assessment

### 5.1 Manual configuration review

The [static review](evidence/phase-c/c0-static-review.txt) separates source configuration from admitted/current Deployment and Pod fields. Both Dockerfiles specify `USER 0`. The source Deployments set `readOnlyRootFilesystem: false` and omit `runAsUser`, `runAsNonRoot`, `privileged`, `allowPrivilegeEscalation`, and capability restrictions. Their Pod templates omit host namespace requests and application `hostPath` or data volumes. The admitted/current Deployments retain the same container security context and an empty Pod security context. The current Pods have no host namespace fields or `hostPath`; Kubernetes injected a projected service-account mount. That mount was identified only as mount context; its contents and permissions were not assessed here.

The Dockerfiles put `app.py` in `/app`, disable Python bytecode generation, and run ports 8080/8081. The Phase B contract requires API application writes only to `/tmp/demo-cache.json` (with `/tmp` the intended writable area) and no backend application writes. Static `readOnlyRootFilesystem: false` is a configuration observation, not by itself a proof that the API process can write a particular path.

### 5.2 Trivy result

Trivy was absent at discovery. Official Trivy **v0.74.0** was downloaded to `/tmp`, its published checksum file and archive SHA-256 were verified, and its Sigstore bundle was verified with cosign (`Verified OK`). Only the binary was installed to ignored `.local/bin/trivy`, without sudo or a system package change. The focused `trivy config --misconfig-scanners kubernetes` scan of `task1/insecure/` completed with exit code 0; [raw output and provenance](evidence/phase-c/c0-trivy-baseline.txt) are preserved. It detected four Kubernetes configuration files and reported 11 misconfigurations in each application manifest, zero in the namespace manifest, and one in the RBAC manifest.

For H1, KSV-0001, KSV-0003/KSV-0004/KSV-0106, KSV-0012, and KSV-0118 flag absent privilege-escalation, capability-drop, and non-root restrictions. For H4, KSV-0014 flags the explicitly writable root filesystem. These observations support manual configuration inspection; runtime identity and write results decide the C1 statuses. Scanner severity is not the assessment decision.

### 5.3 Scanner limitations

This scan covered `task1/insecure/` as Kubernetes IaC. It did not scan the Dockerfiles, the admitted Pods, the image contents, or the running process and mounts. It cannot establish actual UID, effective capability masks, `NoNewPrivs`, `/app` write permission, or persistence. Some scanner descriptions generalize potential consequences beyond what this runtime test demonstrates. Scanner silence would not reject either hypothesis.

### 5.4 Deferred scanner observations

KSV-0049 concerns the bounded ConfigMap Role in `rbac.yaml`; it is **deferred/untriaged for H2**, with no H2 decision here. KSV-0030 and KSV-0104 concern seccomp, and KSV-0020/KSV-0021 prescribe numeric UID/GID thresholds beyond the documented budget. They are recorded without promotion to new findings or a claim about runtime seccomp state. Multiple capability-drop checks describe overlapping configuration, not multiple C1 findings.

## 6. H1 — Weak Container Isolation

### Hypothesis

The compromised API process has local authority beyond its documented legitimate need.

### Legitimate privilege budget

The Phase B contract requires no root, privileged mode, additional Linux capabilities, privilege escalation, privileged ports, host namespaces, or host filesystem access. The API listens on 8080; no local privileged operation is in its application contract.

### Source configuration

`task1/app/demo-api/Dockerfile` says `USER 0`. Its Pod template sets only `readOnlyRootFilesystem: false` in the container security context; it does not request `privileged: true`, but it also does not specify non-root execution, capability drops, or `allowPrivilegeEscalation: false`. No host namespace or `hostPath` is requested. See [static review](evidence/phase-c/c0-static-review.txt).

### Admitted/current Kubernetes state

The current Deployment and Pod retain an empty Pod security context and a container security context containing only `readOnlyRootFilesystem: false`. `runAsUser`, `runAsNonRoot`, `privileged`, `allowPrivilegeEscalation`, and capabilities are absent. Host namespace fields and `hostPath` are absent. Thus privileged mode or host sharing was not configured; the absent privilege-escalation restriction must be interpreted with the process state.

### Actual runtime process state

In the current API Pod, `id` returned `uid=0(root) gid=0(root) groups=0(root)`. `/proc/1/cmdline` was `python app.py`, confirming PID 1 is the application; `/proc/1/status` reported all UID and GID slots as 0, `CapInh` and `CapAmb` zero, `CapPrm`, `CapEff`, and `CapBnd` each `00000000a80425fb`, and `NoNewPrivs: 0`. These are observations of the application process, not a separate debug container. See [H1 raw evidence](evidence/phase-c/h1-container-privilege.txt). Individual capabilities were not decoded or exercised.

### Comparison to budget

| Property | Required | Observed |
| --- | --- | --- |
| UID 0 | No | Yes; application PID 1 effective UID 0. |
| Extra effective capabilities | None required | `CapEff=00000000a80425fb`, nonzero; bounding/permitted also nonzero. |
| Privilege escalation | Not required | `allowPrivilegeEscalation` unset; `NoNewPrivs=0`. Restriction not established; no escalation attempt or result. |
| Privileged mode | No | `privileged` absent from source and current Pod, so no privileged mode requested. |
| Host namespace/filesystem | No | No host namespace request or `hostPath` in source/current Pod. |

### Demonstrated impact

The API process has root identity and nonzero effective local capability authority beyond the empty legitimate privilege budget. This is a local container-process authority finding.

### Possible impact

An attacker with the assumed code execution could use the process's existing local authority for operations the application does not need. No particular privileged operation was exercised in H1.

### Conditional impact

Successful privilege escalation needs a usable mechanism; host or cluster impact would need additional exposure or vulnerability and evidence. Neither follows from the observed UID, masks, or `NoNewPrivs` value alone.

### Claim boundaries

The nonzero masks are reported without naming capabilities. `NoNewPrivs=0` indicates the kernel restriction was not set for this process; it does not show a successful escalation. Root in the container does not establish a host escape. The H4 `/app` write is reported separately as a specific filesystem behavior, not counted again as an H1 exploit.

### Assessment decision

**H1 CONFIRMED** for the current `demo-api` process: demonstrated UID 0 and nonzero effective capabilities exceed documented need. This is a C1 status, not final finding numbering or priority.

## 7. H4 — Filesystem Write Surface

### Hypothesis

The actual API process can modify filesystem surfaces beyond its legitimate `/tmp` application write area.

### Legitimate filesystem budget

The API writes `/tmp/demo-cache.json` after successful backend requests; `/tmp` is the intended writable application area. It requires no runtime modification of `/app`. The backend has no legitimate application filesystem writes, but this C1 runtime probe targeted only the API.

### Mount context

Read-only inspection of `/proc/1/mountinfo`, `os.stat`, and `os.statvfs` preceded the probes. The container `/` is an **overlay filesystem mounted `rw`**. Neither `/app` nor `/tmp` is a separate mount; both resolve to `/` and report `statvfs_readonly=False`. Kubernetes current Pod fields show no application data volume mounted at either path. The only injected projected mount is under the service-account path, which was neither read nor probed. See [H4 raw evidence](evidence/phase-c/h4-filesystem.txt) and [static review](evidence/phase-c/c0-static-review.txt).

### Ownership/mode context

The application and probe process both had UID/GID 0; the probe process also matched the observed effective capability mask. `/app` is owned by 0:0 with mode `0755`, `/tmp` by 0:0 with mode `1777`, and `/` by 0:0 with mode `0755`. A non-root process could receive a Unix permission denial at `/app` even with a writable root mount; that counterfactual is not claimed as this runtime's result.

### Positive /tmp control

An exclusive create at `/tmp/phase-c-h4-probe-d5601ad2` succeeded. Deterministic content was read back exactly, and the probe file was removed. The pre/post functional checks also showed the legitimate `/tmp/demo-cache.json` behavior.

### Nonessential-path probes

An exclusive create at `/app/phase-c-h4-probe-d5601ad2` succeeded under the current API container security context. The deterministic content was read back exactly, then the file was removed. A separate post-probe check found both assessor probe paths absent in the same Pod. No application file, credential, system file, or real application data was modified. No further path crawl was needed once a nonessential write was demonstrated.

### Comparison to budget

| Path/surface | Legitimately required? | Mount and permission context | Process write result |
| --- | --- | --- | --- |
| `/tmp` | Yes, intended writable area for the cache | On `rw` root overlay; 0:0 mode `1777` | Probe create/read/remove succeeded. |
| `/app` | No runtime writes required | On same `rw` root overlay; 0:0 mode `0755`; process UID 0 | Probe create/read/remove succeeded. |

### Demonstrated impact

The current API container process can modify a named nonessential application-directory path during this Pod's runtime. This exceeds its `/tmp` write budget.

### Possible impact

The same writable directory and process authority could permit other runtime tampering under `/app`, subject to permissions and path details not exhaustively tested. This probe did not modify `app.py` or show that modified content would execute.

### Conditional impact

Execution of modified files depends on application behavior. Survival of a change after container restart or Pod replacement depends on storage lifecycle and was not tested; the observed root overlay write does not establish durable persistence.

### Claim boundaries

The evidence establishes `/app` writability for this process and Pod, not universal writability of every path. A `rw` mount alone is not an effective write-permission test; here it is interpreted with ownership, identity, and successful create/read/remove. No claim is made about backend runtime filesystem behavior.

### Assessment decision

**H4 CONFIRMED** for the current `demo-api` process: a successful nonessential `/app` write exceeded the legitimate `/tmp` area. This is a C1 status, not final finding numbering or priority.

## 8. Post-Assessment Functional Verification

The [post-assessment functional check](evidence/phase-c/c1-post-assessment-functional.txt) again returned `FUNCTIONALITY = PASS`: both health endpoints, backend data, two API data requests, and the API cache content matched the Phase B contract. The same two Pods remained Running/Ready with zero restarts. Both assessor probe files were removed and independently confirmed absent; all 19 Phase B input hashes still matched. No baseline source or manifest was changed.

## 9. Evidence Index

| Major claim | Phase C artifact |
| --- | --- |
| Commit, branch, clean start, tag absence, versions, ownership, cluster/Pod/image state, post-run source hashes | [assessment-context.txt](evidence/phase-c/assessment-context.txt) |
| Pre-assessment functionality | [c0-pre-assessment-functional.txt](evidence/phase-c/c0-pre-assessment-functional.txt) |
| Source vs admitted/current H1/H4 settings; deployed source hashes | [c0-static-review.txt](evidence/phase-c/c0-static-review.txt) |
| Verified Trivy installation, failed initial syntax, corrected focused scan and full scanner output | [c0-trivy-baseline.txt](evidence/phase-c/c0-trivy-baseline.txt) |
| API PID 1 UID/GID, capability masks, `NoNewPrivs` | [h1-container-privilege.txt](evidence/phase-c/h1-container-privilege.txt) |
| Root mount, `/app`/`/tmp` modes, probe results and cleanup | [h4-filesystem.txt](evidence/phase-c/h4-filesystem.txt) |
| Post-assessment functionality | [c1-post-assessment-functional.txt](evidence/phase-c/c1-post-assessment-functional.txt) |

## 10. Unexpected Observations

The existing cluster and Pod/image identities were unchanged from Phase B. The Trivy scan additionally flagged the bounded ConfigMap Role (KSV-0049) and seccomp/UID-threshold checks. Those are deferred/untriaged scanner observations, not new C1 findings. The scanner's `KSV-0118` wording about a “default security context” is a check description; the actual container context explicitly contains `readOnlyRootFilesystem: false` and otherwise lacks the restrictions at issue.

## 11. Problems Encountered and Resolutions

Sandboxed Docker-socket and loopback API access failed; scoped escalation enabled read/assessment access to the already owned local lab. The official Trivy archive download and checksum verification succeeded. The first cosign container attempt could not read the mode-0700 temporary download directory; public downloaded files were made readable and the signature verification then returned `Verified OK`. The first Trivy invocation used an unsupported `--scanners` flag and produced CLI help plus a fatal error; the corrected `config --misconfig-scanners kubernetes` command ran successfully. Both attempts remain in scanner evidence. None of these problems required a baseline workload change.

## 12. Files Created or Modified

Eight publishable files were created: this report and the seven Phase C evidence files indexed in Section 9. No tracked file was modified. The ignored `.local/bin/trivy` binary and `.local/trivy-cache` were added as local assessment tooling; a cosign container image was pulled for signature verification. Temporary assessor probe files and the Trivy download directory were removed. The protected Phase A/Phase B source, `task1/app/**`, `task1/insecure/**`, `task1/kind.yaml`, and existing Phase B evidence remained unchanged. Final `git status --short --untracked-files=all` shows only the eight Phase C files; see Section 3 and the context evidence for baseline reconciliation.

## 13. Security Claims Explicitly NOT Made

This run makes no claim of host compromise, cluster compromise, container escape, demonstrated privilege escalation, H2 conclusion, Kubernetes API abuse, H3 conclusion, lateral movement, or durable filesystem persistence. It does not claim every root-filesystem path is writable or that `/app/app.py` was modified or executed. It does not infer effective API permissions from Trivy's RBAC observation.

## 14. Open Questions

H2 still requires its independent exposed-identity, effective-authorization, authentication/reachability, and relevance assessment. H3 still requires selected controlled traffic tests and positive target checks. Phase C4 must compare all completed Phase C evidence before choosing final findings or priorities. Storage-lifecycle durability and hardened-workload compatibility remain for later authorized work if needed; neither is needed to decide this bounded H4 status.

## 15. Readiness for H2 Assessment

Baseline integrity and pre/post functionality passed, the owned cluster remains healthy, C0 static and Trivy evidence is preserved, and H1/H4 have evidence-bounded C1 decisions. No H2 or H3 test, remediation, policy change, or baseline mutation occurred. There is no C0+C1 blocker to a separate focused H2 run.

C0+C1 READY FOR H2 ASSESSMENT
