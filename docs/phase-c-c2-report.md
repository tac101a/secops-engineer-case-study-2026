# Task 1 — Phase C2 Workload Identity / RBAC Assessment

## 1. Executive Summary

**H2 CONFIRMED.** Code running in the existing `demo-api` container can read its projected ServiceAccount credential and use it over verified TLS to reach the Kubernetes API. The API accepted that credential: a GET of the synthetic `ConfigMap/phase-c-fixture` returned HTTP 200. A merge PATCH of only `data.marker` returned HTTP 200, the changed value was observed by a second GET, and the original value was restored and verified. A ConfigMap LIST returned HTTP 403. These actual operations exceed the application's legitimate Kubernetes API budget of **NONE**, within a narrow grant for one named ConfigMap in `secops-demo`.

The fixture is not consumed by either application. This assessment demonstrates unnecessary Kubernetes API read and write authority on that fixture, not an application behavior change, broader resource access, or cluster compromise. Both functional checks passed. No RBAC, baseline source, or C0+C1 evidence was changed. Final Task 1 finding numbering and priority remain for C4.

## 2. Assessment Context

Assessment-start Git commit: `8b82eade2fbdff125aa340fa76ff470ffdd1bfb7`; branch: `temp/work-in-progress`; starting working tree: clean. The owned `secops-lab` kind cluster was reused, with context `kind-secops-lab` and namespace `secops-demo`. kind was v0.31.0, kubectl client v1.35.0, and Kubernetes server v1.34.3. The target was `demo-api-b8dcfccdf-gnv9c`, UID `d5601ad2-6919-4d58-bedf-5b984f0be056`, ServiceAccount `demo-api`, image ID `sha256:80e1fd9bd1afe996dfb03d6b2839c88d00fc3bca1269a74b10b13acf777a6e1f`. The backend remained `demo-backend-549b8f665f-npfsp`, Ready. See the [C2 context record](evidence/phase-c/c2-assessment-context.txt).

The [official assignment](case-study-secops-engineer-2026.pdf), [Phase A assessment frame](architecture.md), [Phase B contract](../task1/BASELINE.md), [Phase B report](phase-b-report.md), and [C0+C1 report](phase-c-c0-c1-report.md) supply scope and provenance. The Phase B report reconciles the assignment's Task 1 requirements with this representative lab. This run assessed H2 only; C0+C1 already made evidence-bounded H1 and H4 decisions. H3 and final synthesis remain separate.

## 3. Baseline Integrity and Pre-Assessment Functionality

All 19 Phase B workload inputs matched the SHA-256 values in the [Phase B revision record](evidence/phase-b/workload-revision.txt), including application source, manifests, scripts, and kind configuration. Git showed no tracked changes to the protected baseline or existing C0+C1 artifacts. The current API Pod UID and image ID matched the prior [cluster record](evidence/phase-b/cluster-state.txt) and [C0+C1 context](evidence/phase-c/assessment-context.txt); no recreation or redeployment was needed. The current Role, RoleBinding, ServiceAccounts, Pod identity fields, and fixture were compared with the source manifests before runtime testing.

The required pre-assessment `make task1-check` returned **FUNCTIONALITY = PASS**: both health endpoints, backend data, two API data requests, and `/tmp/demo-cache.json` matched the contract. The first attempt inside the workspace sandbox could not access the Docker socket. A scoped rerun against the existing owned lab passed; the failed attempt did not change the cluster. See [pre-assessment evidence](evidence/phase-c/c2-pre-assessment-functional.txt).

## 4. H2 Hypothesis and Legitimate API Budget

H2 asks whether the compromised `demo-api` execution context can exercise Kubernetes API authority beyond its legitimate needs. The approved [baseline contract](../task1/BASELINE.md) gives **both applications zero legitimate Kubernetes API permissions**. DNS supplies backend discovery; neither application reads a workload token or consumes `phase-c-fixture`. The H2 fixture intentionally grants `demo-api` only `get` and `patch` on that one synthetic ConfigMap. The grant is an assessment hypothesis until credential exposure, API reachability, authentication, authorization, and actual execution are checked.

## 5. Current Workload Identity Architecture

### 5.1 ServiceAccount Configuration

Source and live `ServiceAccount/demo-api` and `ServiceAccount/demo-backend` both specify `automountServiceAccountToken: true`. The Pods use their respective ServiceAccounts and contain no Pod-level automount override. `demo-backend` has no application RoleBinding in the approved fixture. The C2 runtime API test targeted only `demo-api`.

### 5.2 Credential Projection

The live API Pod has a read-only projected volume mounted at `/var/run/secrets/kubernetes.io/serviceaccount`, containing a ServiceAccount token, cluster CA, and namespace projection. The backend Pod has the analogous projection. These are Pod metadata observations; the separate process-level readability check is in Section 6. No token value or token-derived identifier was recorded.

### 5.3 Role

The source and live `Role/demo-api-fixture-access` agree: namespace `secops-demo`, core API group `""`, resource `configmaps`, `resourceNames: [phase-c-fixture]`, verbs `get` and `patch`. No wildcard, Secret, or cluster-scoped grant appears in this Role.

### 5.4 RoleBinding

The source and live namespaced `RoleBinding/demo-api-fixture-access` agree: its subject is `ServiceAccount/demo-api` in `secops-demo` and its `roleRef` is `Role/demo-api-fixture-access`. This binds the named workload identity to the named Role in the same namespace.

### 5.5 Synthetic ConfigMap Fixture

Before testing, the live `ConfigMap/phase-c-fixture` in `secops-demo` contained exactly `data.marker: baseline`, with no other data keys. It is not mounted or otherwise used by the applications. Its runtime value and keys were checked before mutation. See [authorization and live-state evidence](evidence/phase-c/h2-authorization-model.txt).

## 6. Credential Exposure Assessment

An assessor `kubectl exec -i` ran a Python standard-library metadata probe inside the existing API container. It observed effective UID/GID 0, a mounted ServiceAccount path, and existing, readable `token`, `ca.crt`, and `namespace` files. It opened each file only to verify readability; it printed no contents, JWT details, header, hash, or length. This establishes process access to a credential source. **Credential present does not itself establish useful permission**; the later authorization and runtime checks supply that evidence. See [credential exposure evidence](evidence/phase-c/h2-credential-exposure.txt).

## 7. Authorization Model Assessment

### 7.1 kubectl auth can-i Results

The assessor used operator credentials to impersonate username `system:serviceaccount:secops-demo:demo-api` with explicit groups `system:serviceaccounts`, `system:serviceaccounts:secops-demo`, and `system:authenticated`. All checks were in `secops-demo`:

| Modeled operation | Result |
| --- | --- |
| `get configmaps/phase-c-fixture` | YES |
| `patch configmaps/phase-c-fixture` | YES |
| `list configmaps` | NO |
| `get secrets` | NO |
| `get configmaps/demo-api-other` | NO |

The exact commands, groups, results, and filtered live RBAC configuration are in [authorization-model evidence](evidence/phase-c/h2-authorization-model.txt). `get secrets` was a policy query; no Secret object was read.

### 7.2 Interpretation and Limitations

`kubectl auth can-i` is **authorization-model evidence** for a modeled identity and group set. It is not evidence that the attacker or workload successfully sent an API request. It also does not exhaustively enumerate every possible grant. The live Role/RoleBinding comparison and bounded negative checks support the described scope; the in-container HTTP results in Section 8 establish actual execution for the tested operations. **Authorization allowed does not by itself mean runtime execution succeeded.**

## 8. Runtime Kubernetes API Assessment

### 8.1 Assessor Transport

The assessor sent an ephemeral Python program over stdin with `kubectl exec -i` into the existing `demo-api` container. `kubectl exec` was transport for this test. The assumed attacker has arbitrary code execution inside that container, **not** assessor `kubectl` access or administrator credentials. The probe read the mounted token only into process memory, used Python `urllib` and an SSL context built from the mounted CA, and discarded the token when the process exited. No software was installed in the container, and no token or Authorization header was printed or saved. See [runtime API evidence](evidence/phase-c/h2-runtime-api.txt).

### 8.2 API Reachability and Authentication

The probe used `https://kubernetes.default.svc` with TLS certificate verification. Its successful authenticated GET shows that this tested API endpoint was reachable from the API container, the mounted credential was accepted, and the request was authorized. These layers are logically distinct even though the HTTP 200 supplies combined runtime evidence for this path.

### 8.3 Allowed GET

`GET /api/v1/namespaces/secops-demo/configmaps/phase-c-fixture` returned **HTTP 200**, kind `ConfigMap`, name `phase-c-fixture`, namespace `secops-demo`, and marker `baseline`. The original `resourceVersion` was `834`. Only those selected safe fields were retained.

### 8.4 Bounded Negative Operation

`GET /api/v1/namespaces/secops-demo/configmaps`, a ConfigMap LIST, returned **HTTP 403 Forbidden** with the same workload credential. This characterizes a tested boundary; it does not undo the unnecessary named-object authority. No Secret runtime request was made.

### 8.5 Controlled PATCH

After confirming the object's exact synthetic data, the probe sent `Content-Type: application/merge-patch+json` with only `{"data":{"marker":"phase-c-h2-d5601ad2"}}` to the named fixture. PATCH returned **HTTP 200** and the synthetic marker. No metadata, RBAC, application configuration, or other ConfigMap key was intentionally changed.

### 8.6 Mutation Verification

A fresh workload-credential GET returned **HTTP 200** with `data.marker: phase-c-h2-d5601ad2`. This demonstrates that the write took effect on the synthetic object.

### 8.7 Fixture Restoration

The probe PATCHed `data.marker` back to the original `baseline` value and a fresh GET returned **HTTP 200** with `baseline`. Independent operator inspection also found only the original `marker` key with that value. The restored `resourceVersion` was `7526`; Kubernetes writes create new revisions, so semantic restoration does not mean metadata revision equality. No operator cleanup was needed.

## 9. Comparison to Legitimate API Budget

| Property | Legitimate requirement | Observed |
| --- | --- | --- |
| Workload credential for application behavior | None | Automatically projected and process-readable. |
| Kubernetes API access | None | Verified TLS request to the API succeeded. |
| Named fixture GET | None | Authorized in model; actual HTTP 200. |
| Named fixture PATCH | None | Authorized in model; actual HTTP 200 and verified mutation. |
| ConfigMap LIST | None | Denied in model; actual HTTP 403. |
| Secret access | None | `can-i` denied `get secrets`; no Secret runtime access tested. |

The finding rests on exercised unnecessary API authority, not on token mounting alone. The [Phase B contract](../task1/BASELINE.md) is the source of the legitimate zero-permission budget.

## 10. H2 Assessment Decision

### Demonstrated Impact

The compromised API execution context can reuse its mounted workload identity to read and change `data.marker` on the specifically authorized synthetic ConfigMap in `secops-demo`. The changed value was observed and restored. The tested LIST operation was denied.

### Possible Impact

If a production workload had analogous grants on a resource it actually used, code execution in that workload could use those grants to affect that resource. That production effect was not demonstrated by this fixture.

### Conditional Impact

Changing application behavior would require authority over configuration an application consumes. Secret disclosure requires Secret permission. Broader namespace or cluster impact requires corresponding additional authorization and reachable targets. Those conditions were not established in C2.

### Blast-Radius Interpretation

The observed excess is a namespaced `get`/`patch` grant on **one named ConfigMap** beyond the application's empty budget. The HTTP 403 LIST and modeled denial on another named ConfigMap support a bounded tested scope. They are not a complete proof that no other RBAC path exists; no broader authority is claimed.

### Claim Boundaries

Credential presence is distinct from useful authority. A modeled `can-i` allowance is distinct from an actual request; here both were tested. The synthetic PATCH is distinct from compromise of Kubernetes as a whole, and restoration of data is distinct from restoration of `resourceVersion`. The fixture is not consumed by the application, so no application behavior change is inferred.

### Decision

**Decision: CONFIRMED — H2.** Process-readable credential, verified API reachability, accepted authentication, modeled authorization beyond the legitimate budget, and successful named-object GET/PATCH with observed effect establish unnecessary Kubernetes API authority for this Pod. This is a Phase C2 decision only; no final finding number or priority is assigned.

## 11. Post-Assessment Functional Verification

An independent operator read found the fixture's sole data key and `marker: baseline`. The same two original Pods were Running/Ready, with no assessment-created Pod. All 19 Phase B source hashes still matched. The post-assessment `make task1-check` again returned **FUNCTIONALITY = PASS** for both health endpoints, backend data, repeated API data, and the legitimate cache. See [post-assessment evidence](evidence/phase-c/c2-post-assessment-functional.txt). The assessment-created synthetic marker was removed by restoration.

## 12. Evidence Index

| Artifact | Primary claim |
| --- | --- |
| [c2-assessment-context.txt](evidence/phase-c/c2-assessment-context.txt) | Commit, branch, versions, reused owned cluster, Pod/image identity, baseline hashes. |
| [c2-pre-assessment-functional.txt](evidence/phase-c/c2-pre-assessment-functional.txt) | Required pre-assessment functional PASS. |
| [h2-credential-exposure.txt](evidence/phase-c/h2-credential-exposure.txt) | Projected mount and credential/CA/namespace file readability without contents. |
| [h2-authorization-model.txt](evidence/phase-c/h2-authorization-model.txt) | Filtered live identity/RBAC/fixture state and exact impersonated policy checks. |
| [h2-runtime-api.txt](evidence/phase-c/h2-runtime-api.txt) | Actual workload-credential GET, denied LIST, PATCH, mutation, restoration. |
| [c2-post-assessment-functional.txt](evidence/phase-c/c2-post-assessment-functional.txt) | Independent restoration/source checks and required post-assessment functional PASS. |

The existing C0 [Trivy evidence](evidence/phase-c/c0-trivy-baseline.txt) reports KSV-0049 on the Role as supplementary static context. Trivy was not rerun and did not decide H2.

## 13. Unexpected Observations

The fixture's `resourceVersion` changed from `834` before PATCH to `7526` after restoration. The semantic data was independently verified as restored; revision equality was never an exit condition. The unchanged Pod UID and image ID confirm this test used the same API workload previously assessed in C0+C1. The reused Phase B functional script still prints its historical “H1–H4 remain hypotheses” footer; the Phase C reports carry the later H1/H4 and H2 decisions. No unexpected RBAC or fixture data was found.

## 14. Problems Encountered and Resolutions

The first `make task1-check` attempt was blocked by the workspace sandbox's Docker socket restriction. Scoped access to the already owned local lab allowed the required check and read-only inventory; no cluster recreation or baseline change was needed. The runtime probe completed its restore path, and independent operator verification confirmed the result. No credential handling or fixture cleanup failure occurred.

## 15. Files Created or Modified

Created this report and the six C2 evidence files listed in Section 12. No tracked file, Phase B baseline source, Phase B evidence, or C0+C1 evidence was modified. No RBAC, ServiceAccount, application, network policy, branch, commit, or remote state was changed. The only Kubernetes mutation was the authorized synthetic marker PATCH followed by restoration; Kubernetes assigned a new object revision.

## 16. Security Claims Explicitly NOT Made

No claim is made of cluster compromise, cluster-admin access, Secret access, arbitrary Kubernetes resource modification, application behavior change, node/host access, durable persistence, or universal denial of every untested API operation. The negative `can-i get secrets` query did not access Secret data. No H3 reachability assessment or remediation was performed.

## 17. Open Questions

The separately scoped H3 assessment must test selected network paths under its own controls. C4 must independently synthesize H1–H4 evidence before assigning final finding numbers or priorities. A later remediation phase may assess least-privilege compatibility and detection/prevention coverage; this C2 run did not implement those changes.

## 18. Readiness for H3 Assessment

H2 has a bounded decision supported by credential, authorization-model, and actual workload API evidence. The fixture's original semantic state is restored, source hashes and functionality pass, and no C2-created runtime state remains. No C2 blocker prevents a separate H3 assessment.

C2 READY FOR H3 ASSESSMENT
