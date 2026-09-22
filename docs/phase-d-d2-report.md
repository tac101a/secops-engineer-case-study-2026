# Task 1 — Phase D2 F2 Hardened Candidate

## 1. Executive Summary

The F2 candidate prevents automatic Kubernetes API credential projection for the dedicated `demo-api` ServiceAccount and removes its unnecessary named ConfigMap Role and RoleBinding. The newly admitted API Pod has no projected credential bundle or token path, and exact impersonated GET and PATCH authorization checks return `no` while `phase-c-fixture` remains present with `marker=baseline`. `demo-api` is the workload on which F2 was demonstrated in Phase C. The backend received consistent credential minimization under its zero Kubernetes API budget; this is not additional demonstrated F2 assessment evidence. [F2 candidate smoke](evidence/phase-d/d2-runtime-f2.txt), [application functionality](evidence/phase-d/d2-candidate-functional.txt), and [F1/F3 non-interference](evidence/phase-d/d2-noninterference.txt) passed. This is D2 candidate acceptance; formal same-oracle BEFORE/AFTER proof remains Phase E.

## 2. Starting Context and Integrity

D2 began from commit `10d54964152acf2859a5e1b313e8206b1743ec03` on `temp/work-in-progress` with a clean working tree. The owned `secops-lab` kind cluster, `kind-secops-lab` context, and `secops-demo` namespace passed the repository ownership check. Every artifact row in the canonical Phase B [integrity record](evidence/phase-b/workload-revision.txt) passed SHA-256 verification before mutation; the check derived its set from the record. There was no starting-state contradiction. See [D2 context](evidence/phase-d/d2-context.txt) and [exact pre-state](evidence/phase-d/d2-pre-state.txt).

The accepted D1 API Pod was `demo-api-79fb54f895-xwdfz`, UID `e84b6903-2da2-4b39-a22a-ea3c2d6cd3cc`, image `secops-demo-api:phase-d1`, runtime imageID `sha256:cb82d20063553272d86db019ed015e599633f616535c8ffbed98eae1b5224e25`, with the accepted F1 security context and writable `/tmp` mount. The backend was `demo-backend-549b8f665f-npfsp`, UID `71156c57-8a45-46aa-a365-7566292e6d61`, image `secops-demo-backend:phase-b`, runtime imageID `sha256:89a9dc8d230e5115be9a00823b47811002332014d46f09548b11d2931f876d41`, with its D1 exit command, local security context, resources, and filesystem state. Both ServiceAccounts had automount `true`; neither Pod specified an override; both Pods had readable projected token bundles. The exact fixture Role and RoleBinding were present, the fixture marker was `baseline`, and impersonated exact GET and PATCH both returned `yes`. No NetworkPolicy existed. Pre-change `make task1-check` returned `FUNCTIONALITY = PASS`, and D1 F1 smoke passed again; see [pre-functional evidence](evidence/phase-d/d2-pre-functional.txt).

## 3. F2 Implementation Decision

### Credential Exposure Control

Both workloads have a documented Kubernetes API budget of **NONE** and use dedicated ServiceAccounts. The candidate sets `automountServiceAccountToken: false` on those ServiceAccounts. [Kubernetes documents](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) that a Pod setting takes precedence when both levels specify automount. The D2 pre-state showed the field unset on both Deployment templates and both Pods; the post-state confirms it is still unset, with no `true` override. This gives the ServiceAccount setting effect for newly admitted Pods. The existing Pods had already received projected bundles, so the deployment script restarted both Deployments and verified new Pod UIDs, admitted volumes, mounts, and process-visible paths. No credential contents were read, hashed, or recorded.

### Authorization Control

The deployment script explicitly deleted only `role/demo-api-fixture-access` and `rolebinding/demo-api-fixture-access` in the verified namespace. Both are absent in the effective cluster. It did not prune RBAC or alter any unrelated Role or RoleBinding. Omitting these objects from a manifest alone would not remove the live grant, so the exact deletion is part of deployment.

## 4. Hardened Identity / Workload Artifact Model

[identity.yaml](../task1/hardened/identity.yaml) defines only the two dedicated ServiceAccounts with automount disabled. The [D1 API workload manifest](../task1/hardened/demo-api.yaml) was not changed; no backend workload manifest was changed. This artifact model implements the chosen ServiceAccount-level policy without duplicating the control at Pod level or changing D1 image, process, or filesystem settings. The synthetic ConfigMap remains the unchanged verification target. [deploy-f2.sh](../task1/hardened/scripts/deploy-f2.sh) applies the identity objects, removes only the exact RBAC objects, restarts the affected Pods, waits for rollout, and checks image continuity.

## 5. demo-api Runtime Credential Evidence

The new Ready API Pod is `demo-api-6d49d5c8bd-nmjr5`, UID `67e10621-03de-45f3-a6f2-8bcc30f0d9d4`, image `secops-demo-api:phase-d1`, with the same runtime imageID as D1. It retains `serviceAccountName: demo-api`; that ServiceAccount has automount `false`, while Pod and Deployment template automount are unset. The admitted volumes contain only the D1 `api-tmp` `emptyDir`; no `kube-api-access` or other ServiceAccount-token projection is present. The sole mount is `/tmp`. Inside the application container, the ServiceAccount directory, token, CA, and namespace bundle paths are absent. Thus the former workload-identity GET/PATCH route lacks its credential prerequisite; D2 did not manufacture an authenticated request with another credential. See [runtime F2 smoke](evidence/phase-d/d2-runtime-f2.txt).

## 6. Effective Authorization Evidence

The named Role and RoleBinding are absent. Impersonating `system:serviceaccount:secops-demo:demo-api` with its standard ServiceAccount groups returned `no` for both `get configmap/phase-c-fixture` and `patch configmap/phase-c-fixture`; the `can-i` denial exit status was checked too. These are authorization-model checks supporting the missing-credential runtime observation, not a Phase E workload-token request. No alternative grant investigation was needed because neither exact action remained authorized. Operator read-only inspection confirmed the fixture exists with data exactly `{"marker":"baseline"}`. The target was not deleted or mutated during D2.

## 7. Backend Consistent Credential Minimization

The backend has no legitimate Kubernetes API operations. Its new Ready Pod, `demo-backend-5d4449cb58-vzhs2`, UID `65aa8380-cd09-4da0-85af-4ec762f68f37`, retains the accepted D1 `secops-demo-backend:phase-b` image and imageID. Its command remains unset, `readOnlyRootFilesystem: false` remains the recorded local security context, resources are unchanged, and it has no application volume. Its dedicated ServiceAccount has automount `false`, no Pod-level override exists, and the new Pod has no projected token volume, mount, or process-visible ServiceAccount path. This is consistent zero-API-budget hardening, **not** additional runtime-demonstrated F2 evidence.

## 8. Functional Smoke

After rollout, [the Phase B functional oracle](evidence/phase-d/d2-candidate-functional.txt) returned `FUNCTIONALITY = PASS`: backend `/healthz` and `/data`, API `/healthz`, first and repeated API `/data`, and expected `/tmp/demo-cache.json` readback all succeeded. Backend logs showed GET `/data` from the new API Pod IP `10.244.0.9`, supporting the required DNS/Service path. Both Pods were Ready and probes remained effective. The reused functional script's historical H1–H4 footer is Phase B text, not D2 security status.

## 9. F1 Non-Interference

The accepted API image and runtime imageID were preserved through recreation. [Post-D2 F1 smoke](evidence/phase-d/d2-noninterference.txt) observed actual PID 1 UID/GID `65534:65534`, all five capability masks zero, and `NoNewPrivs: 1`. `/` and `/app` resolve to the read-only root overlay; a harmless `/app` create was denied with `EROFS`. The distinct `/tmp` mount remained read-write, and a normal repeated API request updated the expected cache file. These checks show D1 F1 candidate continuity, not a new F1 remediation proof.

## 10. F3 Non-Interference

The namespace still has zero NetworkPolicies. The kindnet image and imageID match the recorded pre-state. Both Services retain their ClusterIPs, selectors, and TCP ports, and the required API → backend request path works. No CNI or NetworkPolicy change, F3 negative reachability test, or F3 remediation occurred in D2. See [non-interference evidence](evidence/phase-d/d2-noninterference.txt).

## 11. F2 Candidate Acceptance

| D0 D-stage criterion | D2 observation | Evidence |
| --- | --- | --- |
| Both workloads start and remain healthy | Both new Pods Ready; health HTTP 200 | [functional](evidence/phase-d/d2-candidate-functional.txt) |
| Required API → backend and cache work | First/repeated `/data` HTTP 200; backend logs API IP; cache content and later mtime update | [functional](evidence/phase-d/d2-candidate-functional.txt), [F1 regression](evidence/phase-d/d2-noninterference.txt) |
| No selected automatic ServiceAccount credential projection | Both SAs false, no Pod override, new Pods have no projected bundle or process-visible token path | [F2 runtime](evidence/phase-d/d2-runtime-f2.txt) |
| Fixture grant absent from effective candidate | Exact Role and RoleBinding absent; exact GET/PATCH `can-i=no` | [F2 runtime](evidence/phase-d/d2-runtime-f2.txt) |
| Synthetic target retained | ConfigMap exists; only marker key has value `baseline` | [F2 runtime](evidence/phase-d/d2-runtime-f2.txt) |

F2 D2 candidate acceptance passed. The formal same-property BEFORE/AFTER workload-context proof remains Phase E after D3 and D4.

## 12. Compatibility Findings

The first F2 smoke run treated the expected nonzero `kubectl auth can-i` exit status for `no` as a script failure after correctly observing Role and RoleBinding absence. The smoke script was corrected to require both `no` output and denial exit status; rerun passed. A shell quoting error interrupted the first CNI evidence command after the functional and F1 checks had passed; the read-only CNI capture was corrected and completed, matching pre-state. Neither issue affected the workloads or changed the selected controls.

## 13. Trade-offs / Implementation Decisions

ServiceAccount-level automount policy covers future Pods using the two dedicated identities without editing the accepted D1 workload manifests. Pod-level `true` would override it, so the candidate checks templates and admitted Pods for that conflict. Pod recreation was required to remove credentials from existing Pods; it also replaced their ephemeral `/tmp` state, which normal requests repopulated. The explicit exact RBAC deletion handles live-state cleanup without a broad prune. Retaining the harmless fixture keeps denial distinguishable from a missing target. If the candidate needed rollback, the target would be the recorded D2 pre-state: protected `task1/insecure/rbac.yaml` contains the exact original ServiceAccounts and grant, while the recorded D1 API and backend workload identities define the accepted images and security state. Rollback was not needed.

## 14. Files Created or Modified

- `task1/hardened/identity.yaml`
- `task1/hardened/scripts/deploy-f2.sh`, `task1/hardened/scripts/smoke-f2.sh`
- `docs/evidence/phase-d/d2-context.txt`, `d2-pre-state.txt`, `d2-pre-functional.txt`, `d2-candidate-functional.txt`, `d2-runtime-f2.txt`, `d2-noninterference.txt`
- `docs/phase-d-d2-report.md`

No application source, insecure manifest, D1 Dockerfile/workload manifest, prior evidence, or canonical earlier report was changed.

## 15. Runtime State at Exit

The owned `secops-lab` cluster remains on `kind-secops-lab`/`secops-demo`. The Ready API Pod is `demo-api-6d49d5c8bd-nmjr5`, UID `67e10621-03de-45f3-a6f2-8bcc30f0d9d4`, image `secops-demo-api:phase-d1`, imageID `sha256:cb82d20063553272d86db019ed015e599633f616535c8ffbed98eae1b5224e25`. The Ready backend Pod is `demo-backend-5d4449cb58-vzhs2`, UID `65aa8380-cd09-4da0-85af-4ec762f68f37`, image `secops-demo-backend:phase-b`, imageID `sha256:89a9dc8d230e5115be9a00823b47811002332014d46f09548b11d2931f876d41`. Both dedicated ServiceAccounts remain with automount disabled; neither new Pod has a projected credential. The fixture exists unchanged, both F2 grant objects are absent, exact API ServiceAccount GET/PATCH authorization is `no`, and no NetworkPolicy exists. D1 F1 runtime state and required functionality pass.

## 16. D2 Exit Decision

Every canonical Phase B input hash matched again at exit. Protected BEFORE artifacts and historical D1 evidence are unchanged; repository mutations are limited to the selected D2 identity, scripts, evidence, and this report. The D0 F2 candidate criteria, F1 regression checks, and F3 non-interference checks passed. No unexplained compatibility issue remains. This accepts the D2 candidate only; D3 owns F3 policy hardening and Phase E owns formal comparison.

D2 READY FOR F3 HARDENING
