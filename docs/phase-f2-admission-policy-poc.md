# Task 1 — F2 Kyverno Admission-Policy PoC

## Decision

**TASK1-F2 OFFLINE VERIFIED.** The checksum-verified Kyverno CLI v1.19.1
evaluated the committed CREATE and UPDATE test declarations: all 24 resource
assertions matched their expected policy-evaluation outcomes. The policies
remain report-only with `validationActions: [Audit]`; no Kyverno component or
policy was deployed. Audit-mode admission and future Deny behavior remain live
unverified.

## Selected API and compatibility boundary

F2 deliberately selects Kyverno v1.19.1 and its stable CEL-based
`policies.kyverno.io/v1` `ValidatingPolicy` API. Kyverno 1.19 deprecates the
legacy `kyverno.io/v1` `Policy` and `ClusterPolicy` types, so introducing those
legacy resources in a new PoC would create avoidable migration debt. The
policies use `matchConstraints.resourceRules`, `matchConditions` where needed,
and CEL `validations`; they do not use legacy `validate.pattern` or
`validate.deny` syntax.

Official references:

- [ValidatingPolicy](https://kyverno.io/docs/policy-types/validating-policy/)
- [CEL policy migration](https://kyverno.io/docs/guides/migration-to-cel/)
- [Kyverno CLI tests](https://kyverno.io/docs/subprojects/kyverno-cli/)
- [Kyverno releases and compatibility](https://kyverno.io/docs/installation/releases/)
- [Kyverno v1.19.1 release](https://github.com/kyverno/kyverno/releases/tag/v1.19.1)

The repository target is Kubernetes v1.34.3. Kyverno's v1.19 compatibility
matrix documents support for Kubernetes v1.33 through v1.35, which establishes
documented version compatibility only. The live cluster version, installed
CRDs, webhook behavior, and actual compatibility were not inspected because F2
prohibits cluster access.

## Policy coverage

| Policy | Selected resources | Identity and property |
| --- | --- | --- |
| `f1-demo-api-process-security` | Pods and Deployments on CREATE/UPDATE | In `secops-demo`, selects `serviceAccountName: demo-api`, independent of object name or labels. Checks all regular, init, and ephemeral containers for non-root, no privilege escalation, drop ALL with no capabilities added back, and read-only root filesystem. |
| `f2-workload-credentials` | ServiceAccounts, Pods, and Deployments on CREATE/UPDATE | Protects `demo-api` and `demo-backend`. ServiceAccounts must disable automount; selected workload specs must not enable automount or declare an explicit projected ServiceAccount token. |
| `f2-direct-rbac-grants` | RoleBindings and ClusterRoleBindings on CREATE/UPDATE | Inspects every subject and reports a direct ServiceAccount subject for `secops-demo/demo-api` or `secops-demo/demo-backend`, regardless of binding name or other subjects. |

Pod and Deployment forms are declared and tested independently; the PoC does
not rely on controller auto-generation. F1 is identity-scoped to `demo-api`, so
the deliberately permissive backend fixture is an expected SKIP. A renamed,
relabeled direct Pod using the API ServiceAccount is evaluated by both F1 and
F2, demonstrating that object names and application labels are not the scope
key.

The F1 declarations are desired-state checks. They do not prove PID 1's
effective UID, capability masks, `NoNewPrivs`, actual root-filesystem denial,
or successful `/tmp` behavior. Those remain runtime/behavioral gates.

## Evaluation semantics

Every test result uses `isValidatingPolicy: true`, as required for CEL-based
ValidatingPolicy tests. A declared `result: fail` is a successful self-test
only when policy evaluation identifies the intended prohibited configuration.
It does not establish API-server admission blocking. A declared `skip` is used
only for the intentional F1/backend non-match; an unexpected SKIP cannot
satisfy a negative case.

The CLI defaults the main resource suite to CREATE. A separate test declaration
uses the v1.19 Values mechanism to set `request.operation: UPDATE` for an
existing RoleBinding's submitted new object, which introduces a protected
ServiceAccount subject. The CREATE suite passed 17 assertions and the UPDATE
suite passed seven. As an operation cross-check, temporary policy copies
limited all three policies to CREATE-only and UPDATE-only; the corresponding
suites passed 17 and seven assertions respectively. This verifies that the CLI
operation mechanism was honored across the selected resource forms and that
Policy C evaluates the prohibited resulting binding on both operations. The
offline UPDATE test does not persist an old object, execute an API-server
request, or prove webhook behavior.

## Direct-RBAC boundary

Policy C is intentionally narrow. It detects direct protected
ServiceAccount subjects, including a protected subject hidden among several
subjects and bindings with arbitrary names. It does **not** prove effective
zero Kubernetes API permissions. Remaining paths include:

- Group subjects such as `system:serviceaccounts:secops-demo` and the broader
  `system:serviceaccounts` group;
- pre-existing grants and other applicable grants;
- permission changes to already-bound Roles or ClusterRoles;
- existing workload credentials; and
- existing Pods carrying projected tokens.

The synthetic group-subject fixture therefore evaluates PASS only at this
direct-subject rule's coverage boundary; it is not reported as a
security-compliance PASS. Full zero-API authority requires a future authorized
inventory of effective grants plus a separate workload-credential assessment.

## Three distinct outcomes

- **OFFLINE POLICY VIOLATION DETECTED:** VERIFIED with Kyverno CLI v1.19.1.
- **AUDIT-MODE ADMISSION BEHAVIOR:** NOT LIVE VERIFIED.
- **FUTURE DENY/ENFORCE BEHAVIOR:** NOT LIVE VERIFIED.

Audit mode reports violations rather than blocking admission. A future,
separately approved revision may change `validationActions` to `Deny` after an
inventory, false-positive review, isolated CREATE/UPDATE admission pilot, and
rollback review. Changing that field alone would not prove live denial.

## Scope and rollout boundary

F2 adds policy code and offline fixtures only. It does not alter F0, F1, E1,
existing Kubernetes manifests, or the workflow; deploy Kyverno; access the
cluster; expand F3 remediation; or attempt D3 diagnostics. A live pilot must
verify exact resource/operation matching, Audit reports, legacy violations,
controller and CRD compatibility, and then separately test any approved Deny
revision. Until that authorization exists, live admission and future
enforcement stay unverified.

## Offline results and provenance

The official Linux x86_64 v1.19.1 archive was downloaded into an isolated task
directory only after no compatible installed CLI was found. The official
`checksums.txt` asset matched release-page SHA-256
`ef46faa1cbf507fcfd9326dfc595c1ecd67df5af0247c064fc20bc974b01acf1`.
Before extraction, the archive matched its published SHA-256
`b38228f367fc0fdc2b08f4c83ea50ac5f16c60ff8d62d76a66157c33c47b70ae`.
The binary reported version 1.19.1 and commit
`40ec788d48bb28d83dbf85538e962a59db9d45c6`.

Across both invocations, the declarations contained eight policy-evaluation
PASS assertions, 15 intended FAIL assertions, and one intentional SKIP. All
24 matched; no assertion failed and no negative case unexpectedly skipped.
The intended FAIL results include Deployment and direct Pod F1/F2 violations,
renamed and relabeled API Pods, explicit token projection, arbitrary-name and
multi-subject direct bindings, both binding kinds, and an UPDATE introducing a
protected subject. The group fixture produced the documented rule-boundary
PASS, not a security-compliance result. See the [execution record](evidence/phase-f/f2-offline-validation.txt).

The existing hardened offline verifier still returned 0, and all 24 existing
self-tests passed with the runtime-tool guard clear. These are regression checks
only and do not broaden F2's admission evidence.

## Artifacts and exit decision

Exactly eight F2 artifacts were created: three policy files; the shared
resource/Values bundle; separate CREATE and UPDATE test declarations; one
detailed offline execution record; and this report. F0, F1, E1, existing
Kubernetes manifests, and the existing workflow were not modified.

The successful compatible-CLI path selects the original **TASK1-F2 OFFLINE
VERIFIED** decision. The fallback **POLICY CODE READY** path is not selected
because the pinned CLI ran successfully; the blocked path is not selected
because no actual version conflict or policy-test failure was found.

**F2 LIVE ADMISSION VERIFIED remains pending** a separately authorized cluster
pilot.

TASK1-F2 OFFLINE VERIFIED
