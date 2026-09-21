# Task 1 — Phase C Security Assessment Synthesis

## 1. Executive Summary

Phase C assesses the representative `secops-demo` baseline after **assumed** arbitrary code execution in the `demo-api` container. Independent review of Phase A/B requirements, C0–C3 raw evidence, and overlap yields **three final findings**. The compromised process has excess local authority and can write one nonessential application-directory path; its workload identity can read and patch one named synthetic ConfigMap; and its Pod can reach one selected unrelated Service. A separate unrelated source also reached the backend. These are bounded expansions of authority or reachability, not evidence of an initial exploit, host escape, or cluster compromise.

H4's observed `/app` write is retained within F1 because the tested directory is root-owned and the writing process ran as root. Counting that same observation as an independent standalone impact would double-count the local-authority result. Phase D can proceed against the three evidence-backed objectives and their verification requirements below. No control was implemented in C4.

## 2. Assessment Basis and Context

Synthesis started from Git commit `d5c91435982e268ea2923f2c7a1e11d85a137c81`, branch `temp/work-in-progress`, with a clean working tree. The [C4 context](evidence/phase-c/c4-synthesis-context.txt) records the UTC time, reviewed artifacts, integrity checks, and test decision.

[Phase A](architecture.md) supplies the assumed `demo-api` code-execution starting point and the distinction between demonstrated, possible, and conditional impact. The [Phase B contract](../task1/BASELINE.md) supplies the legitimate budgets: no root, extra capabilities, or escalation; no application Kubernetes API permissions; only the declared client/API/backend, DNS, and health/diagnostic flows; and only API `/tmp/demo-cache.json` as an application write. The [Phase B report](phase-b-report.md) and [C0+C1](phase-c-c0-c1-report.md), [C2](phase-c-c2-report.md), and [C3](phase-c-c3-report.md) reports supplied orientation and provenance. Their conclusions were checked against the raw evidence before C4 dispositions.

All 19 recorded Phase B workload-input SHA-256 values still match. Pre/post functional evidence for C0+C1, C2, and C3 reports `FUNCTIONALITY = PASS`, including health, backend data, repeated API `/data` calls, and the required `/tmp` cache. C2 independently verified semantic restoration of its synthetic ConfigMap; C3 verified fixture cleanup. No material unresolved contradiction required another runtime test.

## 3. Methodology

For each hypothesis, C4 compared the legitimate requirement with source and admitted configuration, then with direct runtime observations and test controls. It separated what was demonstrated from a possible consequence and from impacts requiring another condition. The sequence was **hypothesis → targeted assessment → observable evidence → independent cross-review → final finding or merger**. A C0–C3 `CONFIRMED` label was treated as an input for review, not as a finding ID or a priority. Scanner output supplied static context only.

The C4 status below answers whether a hypothesis survives evidence review. The final disposition separately asks whether its risk and Phase D objective are distinct enough for a standalone finding. No new exploit demonstration or runtime security test was performed.

## 4. Assumed Initial Compromise

Arbitrary code execution in the `demo-api` application container is the approved attacker **assumption**. The attacker starts with that process's actual identity and access, without operator `kubectl` credentials, permission to create Pods, node access, or administrator authority. The findings measure **incremental post-compromise authority and blast radius** supplied by workload conditions. They do not explain how the application was initially compromised.

## 5. Hypothesis Disposition Matrix

| Hypothesis | Key evidence reopened | C4 status | Final disposition | Rationale |
| --- | --- | --- | --- | --- |
| H1 — Weak Container Isolation | `h1-container-privilege.txt`: PID 1 `python app.py`, UID/GID 0, nonzero `CapEff`/`CapBnd`, `NoNewPrivs: 0`; `c0-static-review.txt`: API image `USER 0`, current context lacks privilege restrictions. | CONFIRMED | Standalone F1, with H4 evidence incorporated | Excess local process authority exceeds the zero-privilege budget. The demonstrated `/app` write is one concrete consequence in the same process context. |
| H2 — Excessive Workload Identity / RBAC | `h2-credential-exposure.txt`: readable projected token; `h2-authorization-model.txt`: named `get`/`patch` Role and modeled allowances; `h2-runtime-api.txt`: verified-TLS GET/PATCH HTTP 200, changed marker, restoration, LIST HTTP 403. | CONFIRMED | Standalone F2 | Exercised authority crosses from compromised application execution into a Kubernetes API-managed resource, beyond the zero-API budget. |
| H3 — Insufficiently Restricted East-West Connectivity | `h3-network-reachability.txt`: fresh API-to-unrelated-Service DNS/TCP/HTTP success and unrelated-source-to-backend success; `c3-fixture-lifecycle.txt`: healthy, uniquely wired target. | CONFIRMED | Reframed as bounded standalone F3 | Selected unintended Service paths were reachable; “unrestricted” would overstate two tests. |
| H4 — Unnecessary Filesystem Write Access | `h4-filesystem.txt`: `rw` overlay; `/app` root-owned `0755`; UID 0 probe created/read/removed a file under `/app`. | CONFIRMED | Merged into F1 | A nonessential write occurred, but this specific `/app` write was facilitated by H1's root process. Its observed impact is not sufficiently independent to count twice. |

## 6. Overlap and Independence Analysis

### H1 vs H4

H1 establishes that the assessed API application PID 1 runs as root with nonzero effective capabilities and no `NoNewPrivs` restriction. H4 establishes a separate configuration property, a writable root overlay, and a successful `/app` write. Yet the raw H4 probe used UID 0 with the same capability mask as the application, while `/app` is owned by UID 0 and mode `0755`. A non-root API process could be denied that specific write by directory permissions even if the overlay remained `rw`. The evidence does not demonstrate a nonessential write independent of root authority.

Thus H4 remains a **confirmed condition and defense-in-depth subcondition**, but its measured `/app` impact is incorporated into F1. This preserves the distinct Phase D write-confinement objective and its negative verification check without presenting two standalone risks for the same observed act. The result does not claim that every future writable-root risk disappears if process privilege is reduced. No such counterfactual was runtime-tested.

### Other overlaps

H2's API request required network reachability, but F2 rests on an accepted workload credential and authorized named-resource mutation. F3 rests on selected unintended application-Service flows and establishes no extra Kubernetes authorization. Neither the H2 API endpoint nor its grant is treated as another H3 network finding. H1's root state was present when H2 and F3 probes ran, but their demonstrated results depend on projected identity/RBAC and Service routing respectively; root is not used as evidence of API authorization or network policy behavior.

## 7. Final Finding Set

Finding IDs identify the locked C4 set; they are **not severity ranks**.

### F1 — Excessive `demo-api` local authority with nonessential `/app` write

#### Condition

The assessed `demo-api` application process runs as UID/GID 0 with nonzero effective, permitted, and bounding capability masks, and `NoNewPrivs: 0`. Its root overlay is writable, and the same root execution context can create a file in root-owned `/app`. Source and current Pod configuration do not impose non-root or capability restrictions; the container is not configured as privileged and has no requested host namespace or `hostPath`.

#### Legitimate Requirement

The Phase B contract requires neither root, extra Linux capabilities, nor privilege escalation. API runtime writes are required only for `/tmp/demo-cache.json`; `/app` needs no write.

#### Evidence

- **Evidence source:** `docs/evidence/phase-c/c0-static-review.txt`. **Observation relied upon:** API Dockerfile `USER 0`; source and current API container context has `readOnlyRootFilesystem: false` with no run-as, privilege-escalation, or capability restrictions; no host namespace or application data volume is requested.
- **Evidence source:** `docs/evidence/phase-c/h1-container-privilege.txt`. **Observation relied upon:** `/proc/1/cmdline` is `python app.py`; all UID/GID slots are 0; `CapEff=CapPrm=CapBnd=00000000a80425fb`, `NoNewPrivs: 0`. The mask was not decoded or exercised capability by capability.
- **Evidence source:** `docs/evidence/phase-c/h4-filesystem.txt`. **Observation relied upon:** `/` is an `rw` overlay, `/app` is on it and owned 0:0 mode `0755`; UID 0 probe created, read back, removed `/app/phase-c-h4-probe-d5601ad2`, and a later check found it absent. The required `/tmp` control also succeeded.

#### Threat

Given assumed arbitrary code execution in `demo-api`, attacker instructions execute with this process's excess local authority and can use the observed nonessential write surface.

#### Demonstrated Impact

The API application has root identity and nonzero effective capability authority beyond its budget. In the same process context, a controlled nonessential `/app` file create/read/remove succeeded. No capability-specific operation or privilege escalation was demonstrated.

#### Possible Impact

The attacker could perform other local actions available to the existing root process and may tamper with writable application-directory content during this container lifetime, subject to untested file permissions and application behavior.

#### Conditional Impact

Execution of modified files requires a path that the application later loads or executes. Privilege escalation, host impact, and survival across restart or Pod replacement require additional mechanisms or storage/lifecycle evidence not shown here.

#### Blast Radius

Additional authority and one proven write surface **inside the assessed `demo-api` container**. No host, backend-runtime, or cluster boundary crossing was demonstrated by F1.

#### Priority

**MEDIUM**.

#### Priority Rationale

The excess identity/capability state and `/app` write are direct, easy-to-exercise observations with a strong local-integrity consequence. Evidence is strong, but the assessed impact remains within an already compromised container; broader effects are conditional. H4 is not counted as a second risk to inflate this priority.

#### Claim Boundaries

No individual capability, successful escalation, host escape, arbitrary filesystem writability, code-file modification/execution, backend runtime privilege, or durable persistence was demonstrated. `NoNewPrivs: 0` describes an absent restriction, not a successful escalation. Static backend settings do not establish backend process state.

#### Phase D Security Objective

Reduce API process authority to its documented minimum **and** confine runtime filesystem writes to the documented application need.

#### Future Remediation Verification Requirement

Show continued health and client → API → backend `/data` behavior with the required `/tmp/demo-cache.json` write; measure the actual API PID 1 UID/GID, effective capabilities, and privilege-gain state against the budget; demonstrate denial of the previously successful nonessential `/app` write in the remediated process context. Check intended writable paths and mounts so a superficial configuration flag does not substitute for runtime proof.

### F2 — Unnecessary `demo-api` authority over one named ConfigMap

#### Condition

The API process can read a projected `demo-api` ServiceAccount token. A namespaced Role/RoleBinding authorizes that identity to `get` and `patch` core `configmaps/phase-c-fixture` in `secops-demo`. A verified-TLS API request using the workload credential exercised both verbs and changed the synthetic object's `data.marker`.

#### Legitimate Requirement

The Phase B contract grants both applications **no legitimate Kubernetes API operations**. DNS supplies backend discovery; the synthetic ConfigMap is neither mounted nor consumed by either application.

#### Evidence

- **Evidence source:** `docs/evidence/phase-c/h2-credential-exposure.txt`. **Observation relied upon:** the existing API container process could open the projected token, CA, and namespace files; contents were not recorded.
- **Evidence source:** `docs/evidence/phase-c/h2-authorization-model.txt`. **Observation relied upon:** live Role and RoleBinding match the source grant for `get`/`patch` only on `phase-c-fixture`; impersonated exact-action checks returned YES for those actions and NO for LIST ConfigMaps, `get secrets`, and `get` of another named ConfigMap. These are modeled checks, not runtime requests.
- **Evidence source:** `docs/evidence/phase-c/h2-runtime-api.txt`. **Observation relied upon:** from the existing API container, TLS verified against the projected CA; GET of the named ConfigMap returned HTTP 200 and `marker=baseline`; LIST returned HTTP 403; PATCH returned HTTP 200; a later GET showed `phase-c-h2-d5601ad2`; restoration PATCH and GET returned `baseline`.
- **Evidence source:** `docs/evidence/phase-c/c2-post-assessment-functional.txt`. **Observation relied upon:** independent operator read found the sole marker key restored to `baseline`, all 19 source hashes matched, and functionality passed.

#### Threat

Given assumed arbitrary code execution in `demo-api`, the attacker can reuse this process-readable workload identity to exercise the unnecessary named-resource API grant.

#### Demonstrated Impact

The workload credential authenticated over verified TLS and read/changed one named synthetic ConfigMap in `secops-demo`; the changed marker was observed, then its original semantic value was restored. The tested LIST operation was denied. The object `resourceVersion` advanced, as expected for writes.

#### Possible Impact

The authority could be reused to read or change that fixture again while the grant and credential remain usable. In an analogous deployment where the named resource is operationally significant, similar excess authority could affect that resource; this lab fixture is not application configuration.

#### Conditional Impact

Changing application behavior requires control of configuration an application consumes. Secret disclosure, other ConfigMap access, namespace ownership, or cluster effects require additional permissions or conditions not established here.

#### Blast Radius

Crosses from the compromised application's execution context into **Kubernetes API-managed resource authority**, demonstrated only for `get` and `patch` on the one named ConfigMap in `secops-demo`.

#### Priority

**MEDIUM**.

#### Priority Rationale

The trust-domain crossing and actual authorized mutation make F2 the strongest direct authority expansion in this set. Its tested grant is deliberately narrow and its target synthetic and unused, which limits assessed-baseline consequence and keeps the priority below HIGH. The HTTP 403 and modeled denials bound tested scope; they do not prove complete absence of other grants.

#### Claim Boundaries

No Secret was read, no arbitrary ConfigMap or cluster-wide permission was demonstrated, and the fixture change did not alter application behavior. Assessor `kubectl exec` was transport for the test, not attacker authority. The negative authorization queries are not an exhaustive effective-permission inventory.

#### Phase D Security Objective

Eliminate Kubernetes API credential exposure and authority unnecessary for the API application's documented behavior.

#### Future Remediation Verification Requirement

Show both applications still meet their functional contract while the API process no longer has usable authority to GET or PATCH the named synthetic ConfigMap. Verify effective identity exposure and authorization, and repeat bounded workload-context API checks rather than relying only on source RBAC or token-mount configuration.

### F3 — Selected unintended east-west Service reachability

#### Condition

With no NetworkPolicy in `secops-demo`, the existing API Pod established a fresh TCP/8081 connection to a healthy unrelated temporary Service and received HTTP 200. Separately, a temporary unrelated source Pod reached the existing backend Service on TCP/8081 and received HTTP 200. The first flow is primary for the assumed API compromise; the second shows the tested backend ingress exposure.

#### Legitimate Requirement

The Phase B traffic matrix requires API → backend TCP/8081, API → DNS, health probes, and declared client/operator checks. API → unrelated services and unrelated workload → backend are outside that matrix.

#### Evidence

- **Evidence source:** `docs/evidence/phase-c/h3-policy-network-inventory.txt`. **Observation relied upon:** zero NetworkPolicies in `secops-demo`; baseline Services and ready EndpointSlices mapped `demo-api` and `demo-backend` to their observed Pods. Policy absence alone is not treated as reachability proof.
- **Evidence source:** `docs/evidence/phase-c/c3-fixture-lifecycle.txt`. **Observation relied upon:** the temporary target answered Pod-local `/healthz` with HTTP 200; its Service selector, ready EndpointSlice, Pod UID/IP, and TCP/8081 port matched; all three temporary resources were later confirmed absent.
- **Evidence source:** `docs/evidence/phase-c/h3-network-reachability.txt`. **Observation relied upon:** primary TEST B from the existing API Pod resolved the target Service to `10.96.106.109`, opened a new TCP/8081 connection (`CONNECTED`), and received HTTP 200 from `/data`; corroborating TEST A from the unrelated source resolved backend Service `10.96.32.207`, connected on TCP/8081, and received HTTP 200. Both responses contained only synthetic data.
- **Evidence source:** `docs/evidence/phase-c/c3-pre-assessment-functional.txt` and `docs/evidence/phase-c/c3-post-assessment-functional.txt`. **Observation relied upon:** intended API → backend calls returned HTTP 200, backend logs identified the API Pod IP as caller, and functionality passed before and after probes.

#### Threat

Given assumed arbitrary code execution in `demo-api`, the attacker can initiate the demonstrated connection to this selected Service outside the API's intended dependency graph. The unrelated-source test characterizes a second exposed path; it does not grant the attacker that source Pod.

#### Demonstrated Impact

At the test time, the existing API network context reached one unrelated healthy listener through its Service and received synthetic `/data`; an assessor-created unrelated source independently reached the backend listener and received synthetic `/data`.

#### Possible Impact

Other reachable services could become additional interaction surfaces for a compromised workload, but no broader reachability survey was performed.

#### Conditional Impact

Meaningful lateral compromise or data access requires a reachable target with security-relevant functionality, trust, weak authorization, or another vulnerability. No such target compromise was demonstrated.

#### Blast Radius

Two **selected same-namespace Pod-to-Service TCP/8081 paths** outside the documented graph. The API-originating path extends the assumed attacker's reachable surface; the corroborating path shows one backend ingress gap.

#### Priority

**LOW**.

#### Priority Rationale

The DNS, fresh TCP, HTTP, target-health, and Service-wiring evidence is strong. The reached services returned only synthetic data, and any material lateral effect remains conditional. The tested network surface is narrower than universal east-west access; evidence strength does not raise the consequence or priority by itself.

#### Claim Boundaries

No every-Pod, every-port, cross-namespace, Internet, or production reachability claim is made. No NetworkPolicy enforcement test occurred. The target and source fixtures were assessor-created and deleted; the attacker is not assumed able to create them. No target compromise or application-level authorization conclusion follows from HTTP 200 on these synthetic endpoints.

#### Phase D Security Objective

Restrict workload communication to documented source, destination, protocol, and port dependencies while preserving required traffic.

#### Future Remediation Verification Requirement

Demonstrate that the required API → backend and DNS paths, health probes, and functional client path continue to work; then show the previously successful API → unrelated-target and unrelated-source → backend test flows are blocked in the actual runtime. Verify effective enforcement with fresh positive and negative connections, not policy objects alone.

## 8. Integrated Threat / Blast-Radius Narrative

From the **assumed** `demo-api` code-execution starting point, F1 gives the attacker the process's excess container-local authority and an observed nonessential `/app` write. Independently, F2 makes one named synthetic ConfigMap readable and mutable through the workload credential and Kubernetes API. F3 lets the same API network context reach one unrelated Service; a separate assessor source also reached backend. These are parallel dimensions, not a demonstrated sequential exploit chain. F2 crosses into API-managed resource authority; F1 stays local; F3 establishes selected reachability, with further target impact conditional.

## 9. Relative Risk Priority Summary

| ID | Finding | Priority | Main reason |
| --- | --- | --- | --- |
| F2 | Unnecessary `demo-api` authority over one named ConfigMap | MEDIUM | Direct, demonstrated API-managed resource mutation across an authority boundary, narrowly scoped to an unused synthetic object. |
| F1 | Excessive `demo-api` local authority with nonessential `/app` write | MEDIUM | Direct excess process authority and local write, with broader harm unproven. |
| F3 | Selected unintended east-west Service reachability | LOW | Selected path reached a healthy synthetic listener; material lateral effect is conditional. |

F2 has the strongest direct boundary crossing, then F1's direct local authority, then F3's tested reachability with conditional downstream impact. F1 and F2 share a priority band; **IDs are identifiers, not ranks**. These priorities judge security risk for the assessed baseline, not Phase D remediation order. Compatibility, prerequisites, rollout risk, and implementation effort may produce a different remediation sequence; none was used to raise or lower risk here. No Trivy severity or CVSS score was copied into these decisions.

## 10. Rejected / Merged / Reframed Hypotheses

H4 is **merged into F1**, not rejected: its nonessential `/app` write and writable overlay are real, but the observed write used the root identity established by H1. It remains a Phase D write-confinement objective and verification requirement within F1. H3 is **reframed** from the broad working label “Unrestricted East-West Connectivity” to selected unintended Service reachability because only two same-namespace TCP/8081 flows were tested. H1 and H2 remain standalone within their exact demonstrated scopes. No hypothesis was rejected or left inconclusive.

## 11. Evidence Traceability Matrix

| Finding | Evidence artifact | Specific observation relied upon | Supporting evidence |
| --- | --- | --- | --- |
| F1 | `docs/evidence/phase-c/h1-container-privilege.txt` | API PID 1 `python app.py`; UID/GID 0; `CapEff=00000000a80425fb`; `NoNewPrivs: 0`. | `c0-static-review.txt`: image `USER 0`, current security context lacks run-as/capability restrictions. |
| F1, merged H4 | `docs/evidence/phase-c/h4-filesystem.txt` | `/` overlay `rw`; `/app` root-owned `0755`; UID 0 probe create/read/remove under `/app` succeeded and cleanup was confirmed. | `c1-post-assessment-functional.txt`: required `/tmp` cache and functionality passed afterward. |
| F2 | `docs/evidence/phase-c/h2-credential-exposure.txt` | API process opened projected token/CA/namespace files without retaining contents. | `h2-authorization-model.txt`: exact named `get`/`patch` RoleBinding and modeled YES; LIST and other selected actions NO. |
| F2 | `docs/evidence/phase-c/h2-runtime-api.txt` | Verified-TLS named GET/PATCH HTTP 200, marker changed and restored; LIST HTTP 403. | `c2-post-assessment-functional.txt`: independent marker restoration and functional PASS. |
| F3 | `docs/evidence/phase-c/h3-network-reachability.txt` | TEST B API → unrelated Service fresh DNS/TCP `CONNECTED`/HTTP 200; TEST A unrelated source → backend same layers and HTTP 200. | `c3-fixture-lifecycle.txt`: target local health and unique ready Service endpoint; `h3-policy-network-inventory.txt`: zero policies; C3 pre/post functional PASS. |

The exact paths and observations above are the primary trace; earlier report prose and scanner output do not replace them. The [C4 context](evidence/phase-c/c4-synthesis-context.txt) lists every major raw file and functional control reviewed.

## 12. Security Claims Explicitly NOT Made

No initial application exploit was demonstrated. There is no claim of host or node compromise, container escape, cluster compromise, cluster-admin authority, Secret access, arbitrary ConfigMap authority, universal east-west reachability, cross-namespace reachability, successful lateral compromise, durable filesystem persistence, or production behavior. The API `/app` probe does not establish backend runtime writes or every path's writability. Source backend privilege settings do not prove backend runtime privilege. `NoNewPrivs: 0` does not prove escalation. Assessor `kubectl` access and temporary Pod creation are not attacker capabilities.

## 13. Scanner Interpretation

The [C0 Trivy output](evidence/phase-c/c0-trivy-baseline.txt) scanned four Kubernetes configuration files and reported privilege, writable-root, and bounded RBAC checks. It corroborates source review but does not measure PID 1 state, effective API actions, file permissions, or network reachability. Its HIGH `KSV-0014` and `KSV-0118` labels did not become C4 priorities. Seccomp and numeric UID/GID recommendations were not promoted: Phase C has no distinct runtime assessment and risk showing those as separate findings. Repeated capability checks also do not multiply findings. The initial scan command failed; the corrected command completed with exit 0 and is the scan relied on.

## 14. Evidence Limitations

The assessed environment is one local kind baseline and one observed API Pod/image revision, verified by source hashes and matching identity records through C3. C4 did not reread live cluster state. H1 did not exercise named capabilities or an escalation mechanism; H4 probed one nonessential `/app` path and no storage lifecycle; H2 executed only the named ConfigMap operations and one denied LIST; H3 tested two temporary, same-namespace Service flows on TCP/8081 and did not test policy enforcement. These limits narrow the findings but do not leave a material contradiction. The C3 target reused the backend image, so its returned `source=demo-backend` identifies payload code; unique Service/Pod wiring identifies the unrelated target. C2's later `resourceVersion` is compatible with the verified restoration of the original `marker` value.

## 15. Phase D Security Objectives

| Finding | Security objective | Future remediation verification |
| --- | --- | --- |
| F1, including H4 | Minimize API process authority and confine runtime writes to documented needs. | Actual UID/capabilities/privilege-gain state within budget; nonessential `/app` write denied; required `/tmp` cache and application flow work. |
| F2 | Remove unnecessary workload credential exposure and Kubernetes API authority. | No usable named-fixture GET/PATCH authority from API context; application function remains intact. |
| F3 | Limit communication to documented workload dependencies. | Required API/backend, DNS, health, and client flows work; both demonstrated unintended paths are blocked under effective runtime enforcement. |

These are security properties and evidence requirements only; Phase D will choose implementation and sequencing.

## 16. Documentation Cleanup Items

The reused Phase B functional script prints the historical footer “H1–H4 remain hypotheses” even in Phase C functional logs. Its HTTP and cache assertions remain valid; the footer does not supersede C1–C4 decisions. Earlier Phase B/C reports also say no commit occurred during their respective agent runs, while their artifacts were subsequently committed; the recorded run contexts and current Git history are consistent. Neither item is a security finding or blocks synthesis.

## 17. Files Created or Modified

Created `docs/evidence/phase-c/c4-synthesis-context.txt` and this canonical `docs/phase-c-report.md`. No separate finding matrix was needed. No Phase A/B source, `task1/**`, prior evidence, or earlier Phase C report was intentionally modified. No remediation, NetworkPolicy/CNI/RBAC/securityContext change, runtime security test, commit, push, or branch switch occurred in C4.

## 18. Phase C Exit Decision

All required reports and relevant raw evidence were reopened; four hypotheses have explicit C4 statuses; H1/H4 overlap and other interactions were considered; the final three findings have observation-level traceability, bounded impacts, priorities, and implementation-neutral Phase D objectives. Baseline hashes and final repository mutation checks passed. No unresolved evidence contradiction prevents Phase D.

PHASE C READY FOR HARDENING
