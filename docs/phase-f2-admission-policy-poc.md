# Task 1 — F2 Kyverno Admission-Policy PoC

## Decision and evidence boundary

**TASK1-F2-PATCH OFFLINE VERIFIED.** The checksum-verified Kyverno CLI
v1.19.1 evaluated the corrected CREATE and UPDATE declarations: all 50
assertions matched their expected policy-evaluation outcomes. The policies
remain report-only with `validationActions: [Audit]`; no Kyverno component or
policy was deployed, and no Kubernetes runtime API was accessed. Offline
evaluation does not establish live Audit reporting, admission denial,
workload isolation, zero API authority, application behavior, or network
dataplane enforcement.

The previous reviewed F2 execution remains historical: its CREATE suite
reported 17 passed and its UPDATE suite seven passed, for 24/24 assertions.
Those results are not relabeled as patch results. The appended F2-PATCH
chronology in the [execution record](evidence/phase-f/f2-offline-validation.txt)
records the new 38 CREATE and 12 UPDATE assertions separately.

## Selected API and compatibility boundary

F2 retains Kyverno v1.19.1 and the stable CEL-based
`policies.kyverno.io/v1` `ValidatingPolicy` API. All three policies use
`validationActions: [Audit]`, explicit Pod and Deployment rules where
applicable, and CREATE/UPDATE operations. They do not use legacy
`ClusterPolicy`, `validate.pattern`, or `validate.deny` syntax and do not rely
on controller auto-generation.

The official v1.19.1 Linux x86_64 binary reported commit
`40ec788d48bb28d83dbf85538e962a59db9d45c6`. The official release-page digest
for `checksums.txt` and the archive digest inside that verified file matched
before extraction. Version-specific testing retained `isValidatingPolicy:
true`, the Values mechanism for `request.operation: UPDATE`, and the supported
`resourceSpecs` selector for same-named resources. CLI v1.19.1 requires an
explicit empty `resources: []` for `resourceSpecs` processing; that bounded
test declaration workaround is documented in the execution record.

Official references:

- [ValidatingPolicy](https://kyverno.io/docs/policy-types/validating-policy/)
- [CEL policy migration](https://kyverno.io/docs/guides/migration-to-cel/)
- [Kyverno CLI tests](https://kyverno.io/docs/subprojects/kyverno-cli/)
- [Kyverno releases and compatibility](https://kyverno.io/docs/installation/releases/)
- [Kyverno v1.19.1 release](https://github.com/kyverno/kyverno/releases/tag/v1.19.1)

The repository target Kubernetes version remains within Kyverno v1.19's
documented compatibility range. No live CRD, webhook, controller, or
Kubernetes-version compatibility check occurred.

## Admission coverage matrix

| Policy | Selected resource kind | Matching identity | CREATE / UPDATE coverage | Selected property | Positive / negative offline tests | Known bypasses | Actual evidence limitation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `f1-demo-api-process-security` — process | Pod and Deployment | Namespace `secops-demo`; Pod or template uses `serviceAccountName: demo-api` | Both operations; direct forms, no autogen | Every regular, init, and represented ephemeral container declares non-root, no privilege escalation, drop ALL, add none, and read-only root | Compliant Deployment and renamed Pod pass; isolated negatives cover each field plus init and sidecar violations | Changing the ServiceAccount removes a non-canonical object from F1 scope; F2 separately catches the canonical API Deployment substitution | CEL evaluates submitted fields only; it does not observe PID 1 UID/GID, capabilities, `NoNewPrivs`, or effective mounts |
| `f1-demo-api-process-security` — filesystem | Pod and Deployment | Same F1 identity; the accepted regular application container is exactly `demo-api` | Both; writable `/app` introduction has an UPDATE assertion | `api-tmp` must be `emptyDir`; exactly one `demo-api` regular container directly mounts it writable at `/tmp` with no `subPath` or `subPathExpr`; no regular, init, or represented ephemeral container has a writable mount at or below `/app` | Accepted API and read-only `/app` mount pass; isolated missing/wrong volume, missing/read-only mount, writable `/app`, and ephemeral writable `/app` fail | Other writable paths are outside the selected control; Kubernetes schema validity is separate from the synthetic missing-volume CEL unit fixture | A pass does not prove repeated `/data`, writes to `/tmp/demo-cache.json`, or denial of an actual `/app` write |
| `f2-workload-credentials` — ServiceAccount | ServiceAccount | Exact names `demo-api` and `demo-backend` in `secops-demo` | Both | `automountServiceAccountToken: false` is explicit | Backend ServiceAccount passes; API ServiceAccount with `true` fails on CREATE and UPDATE | Existing Pods keep already-projected credentials until recreated | Offline desired-state evaluation does not inspect admitted Pods or process-visible paths |
| `f2-workload-credentials` — workload credentials | Pod and Deployment | Protected ServiceAccount identity, plus exact canonical Deployment names | Both; ordinary and projected Secret introduction have UPDATE assertions | No Pod-level automount `true`, ordinary Secret volume, projected Secret source, explicit `serviceAccountToken` projection, or mount at/below `/var/run/secrets/kubernetes.io/serviceaccount`; every volume, projected source, and represented container is inspected | API `api-tmp` and backend pass; isolated ordinary Secret, second projected Secret source, second token projection source, and init-container token-path mount fail | Secret-backed `env`/`envFrom`, `imagePullSecrets`, CSI/external secret delivery, and credentials embedded in images/config are not covered | A pass does not prove token absence in an admitted Pod, process isolation, or effective RBAC |
| `f2-workload-credentials` — canonical identity | Deployment | Exact `secops-demo/demo-api` and `secops-demo/demo-backend`, independent of labels or selected ServiceAccount | Both | Canonical API must use `demo-api`; canonical backend must use `demo-backend` | Both canonical ServiceAccount substitutions fail on CREATE and UPDATE | A new object that changes name, labels, and ServiceAccount together may be indistinguishable from unrelated work | This is bounded name/namespace identity, not a production ownership boundary |
| `f2-direct-rbac-grants` | RoleBinding and ClusterRoleBinding | Any direct subject for `ServiceAccount/secops-demo/demo-api` or `demo-backend` | Both; existing binding gaining a subject is tested on UPDATE | Every direct subject is inspected regardless of binding name or other subjects | Unrelated direct subject passes; arbitrary-name multi-subject RoleBinding and direct ClusterRoleBinding fail; group fixture passes only at the rule boundary | ServiceAccount groups, existing grants, Role/ClusterRole permission changes, aggregation, and other indirect grants are outside the rule | A pass does not prove effective zero Kubernetes API permissions |

## Test semantics and actual results

The CREATE declaration produced 38/38 passing assertions. Its expected policy
evaluations were nine PASS, 26 FAIL, and three intentional SKIPs. The UPDATE
declaration produced 12/12 passing assertions; all 12 expected a policy FAIL
because each resource intentionally introduced or retained a prohibited
configuration. Combined accounting is:

- Expected policy-evaluation PASS: 9.
- Expected policy-evaluation FAIL: 38.
- Intentional policy-evaluation SKIP: 3.
- Unexpected SKIP: 0.
- Overall test assertions passed: 50.
- Overall test assertions failed: 0.

A negative fixture is successful when the CLI reports the assertion as Pass
because the expected policy FAIL occurred with the intended validation
message. It does not mean the resource is compliant or that Audit mode denied
an API-server request. The three intentional SKIPs are F1 against the backend,
F2 against a completely unrelated Deployment, and the explicit fully renamed,
relabeled, different-ServiceAccount identity boundary.

The independent F1 failures report the expected messages for
`runAsNonRoot`, privilege escalation, capabilities, writable root, missing or
wrong `api-tmp`, missing or read-only `/tmp`, writable `/app`, and additional
container violations. F2 failures separately report ordinary Secret,
projected Secret, explicit token projection, token-path mount, and both
canonical identity substitutions. UPDATE independently covers canonical
substitution, both Secret forms, writable `/app`, protected ServiceAccount,
explicit token projection, Pod automount, and direct RBAC subject addition.

An UPDATE-only temporary policy copy passed all 12 UPDATE assertions. Running
the CREATE declaration against that copy showed the policies excluded under
CREATE and returned nonzero for the direct-RBAC expectations. This establishes
that the Values-supplied UPDATE operation was honored. The cross-check did not
contact an API server, persist an old object, or prove webhook behavior.

## Scope and bypass boundaries

F1 remains limited to the accepted API identity and does not impose API
process hardening on the backend. The `demo-api` container name is part of the
accepted workload contract solely for the required `/tmp` mount. Sidecars and
init containers retain all selected process restrictions but do not need their
own writable `/tmp` mount. A read-only mount at or below `/app` is permitted;
the explicit positive fixture distinguishes it from a writable mount.

F2 continues to cover renamed and relabeled Pods when they retain a protected
ServiceAccount. The canonical Deployment name/namespace rule closes simple
ServiceAccount substitution even when labels change. It does not solve the
unavoidable bounded-PoC case where a new object simultaneously changes its
name, labels, and ServiceAccount. Production needs a reviewed namespace,
workload-ownership, or other stable identity strategy; this patch does not
invent a namespace-wide restriction.

The Pod rules inspect `spec.ephemeralContainers` when that field is present in
a submitted Pod object. The resource rules match `pods`, not
`pods/ephemeralcontainers`. Therefore this PoC does **not** claim enforcement
of the ephemeral-container subresource. It also does not mutate existing Pods,
remove existing projected credentials, inventory existing grants, or assess
the union of effective RBAC.

The group-subject ClusterRoleBinding is intentionally a direct-rule-boundary
PASS, not a security-compliance result. Groups such as
`system:serviceaccounts:secops-demo` or `system:serviceaccounts`, existing
bindings, and changes to already-bound Roles or ClusterRoles remain outside
the direct-subject rule. Effective zero API authority needs a separately
authorized live inventory and credential assessment.

## Audit-to-Enforce (Deny) production pilot

This is an ordered future plan, not an executed rollout:

1. Application, identity, security, and platform owners inventory actual
   workloads, ServiceAccounts, direct bindings, group grants, Role/ClusterRole
   permissions, existing Pods, and credential delivery paths.
2. Those owners establish an approved configuration baseline, including the
   legitimate API `/tmp` requirement and explicit exceptions.
3. The platform owner installs Kyverno only in an authorized isolated pilot
   environment.
4. Platform and security owners verify the installed version, CRDs, webhook
   configurations, policy-controller availability, failure behavior, and
   compatibility with the pilot Kubernetes version.
5. Security deploys the reviewed policies in Audit mode without silently
   widening their match scope.
6. Platform collects actual admission violations while application and
   identity owners review representative legacy resources.
7. Owners classify false positives, legitimate exceptions, stale resources,
   and actual violations; each exception gets a resource, reason, owner,
   approver, compensating check, and expiry.
8. Security verifies actual Pod, Deployment, ServiceAccount, RoleBinding, and
   ClusterRoleBinding CREATE and UPDATE matching, including direct Pods,
   canonical identity substitution, and the explicit non-covered cases.
9. Application owners confirm health, API-to-backend access, repeated `/data`,
   real `/tmp/demo-cache.json` writes, and failed unauthorized `/app` writes.
10. After reviewed Audit acceptance, security proposes a controlled
    `validationActions: [Deny]` change for a small owned cohort.
11. Platform and application owners measure rejected admission requests,
    readiness, restarts, error signals, and operational impact against
    pre-agreed thresholds; this report invents no production numbers.
12. Expansion proceeds cohort by cohort only after pilot acceptance and owner
    sign-off.
13. Security owns exception policy; application or identity owners request
    exceptions, platform implements approved scope, and every exception has an
    approval and expiration.
14. Platform continuously inventories drift while security measures policy
    compliance and reviews expiring exceptions and policy changes.

Audit reports violations; it does not deny requests. Promotion to Deny is a
reviewed policy change plus a live admission test, not an inference from this
offline suite.

## Rollback and failure response

**Policy failure:** if a rule falsely reports a legitimate resource, matches
the wrong scope, or causes admission availability problems, stop expansion and
preserve policy and admission evidence. Return only the affected pilot rule to
Audit, or narrow it through an approved change, then correct and rerun the
offline and live pilot tests. Do not automatically disable all admission
protections.

**Application failure:** if the hardened application loses readiness, backend
access, or required `/tmp` cache writes, stop deployment promotion. Roll back
the affected Deployment or application configuration through the approved
release process and preserve application and admission evidence. Do not weaken
a correct security rule to disguise an application regression.

**Security-control failure:** if NetworkPolicy is admitted but intended
forbidden connections remain reachable, keep D3 **NOT READY**. An admission
PASS cannot prove network dataplane enforcement. Handle D3 only through a
separately authorized runtime investigation.

## Regression, artifacts, and current state

Both E1 Bash syntax checks exited 0. `verify.sh --offline hardened` exited 0
with F1/F2/F3 static PASS while retaining F3 enforcement and full AFTER as
blocked. `test-verify-offline.sh` exited 0 with its runtime-tool guard clear and
24/24 self-tests passing. E1 was not modified and these results do not broaden
F2 admission evidence.

The corrected inventory contains the original eight F2 artifacts plus the
approved standalone [scope record](evidence/phase-f/f2-scope-record.txt).
Separate CREATE and UPDATE declarations are retained because they are the
reviewed working architecture and make operation evidence explicit. The
direct-RBAC policy required no correction and remains byte-for-byte unchanged
in this patch. No F0, F1 CI, E1, application, image, workload manifest, or
historical non-F2 evidence file was modified.

The final detailed chronology, intermediate failures, checksums, cleanup, and
Git mutation set are recorded in the execution and scope records. Live Audit
reporting and Deny enforcement remain pending a separately authorized pilot.

TASK1-F2-PATCH OFFLINE VERIFIED — LIVE ADMISSION VERIFICATION PENDING
