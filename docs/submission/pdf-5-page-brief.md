# Five-page Part 2 PDF writing brief

## Purpose and governing evidence

This is a writing blueprint, not the final report. The official assessment
requires one 3–5-page Part 2 PDF as the primary grading document; it does not
require a separate cover page. Use five content pages and place the title,
repository URL, frozen revision
`723625b5e9424dbd7fbbf83eb9eda1af8af98ef0`, and a one-sentence scope line in
the page-one header rather than consuming a cover page.

The authoritative claim source is
[`claim-evidence-matrix.md`](claim-evidence-matrix.md). Runtime observations
must carry their historical window. “Current” means current repository source,
not a currently observed cluster or container state.

## Page 1 — Task 1: findings, risk, and impact

### Page objective

Explain what was assessed, the assumed compromise boundary, the three accepted
findings, why they matter, and exactly what the evidence did—and did not—show.

### Required facts

- Representative topology: client → `demo-api:8080` →
  `demo-backend:8081` in `secops-demo`.
- Initial attacker condition is **assumed arbitrary code execution in
  `demo-api`**, without operator credentials, Pod-creation authority, node
  access, or administrator authority.
- F1, MEDIUM: root/nonzero capability authority and `NoNewPrivs: 0`; controlled
  nonessential `/app` write succeeded. H4 is incorporated into F1.
- F2, MEDIUM: readable workload credential plus actual verified-TLS GET/PATCH
  of only `configmaps/phase-c-fixture`; LIST denied; marker restored.
- F3, LOW: two selected unintended same-namespace Service TCP/8081 flows
  returned HTTP 200 with healthy targets and correct wiring.
- Legitimate budgets: no root/capabilities/escalation, no Kubernetes API use,
  API writes only `/tmp/demo-cache.json`, and only documented network flows.
- Demonstrated, possible, and conditional effects must remain separate.

### Proposed allocation

- Top 12%: compact title, scope, topology, and attacker assumption.
- Middle 58%: three-row findings table with columns **Finding / Priority /
  Direct observation / Demonstrated blast radius**.
- Bottom 30%: two short paragraphs—one on impact boundaries, one on risk
  prioritization.

The findings table should be the dominant element. Keep raw UIDs, Pod names,
ClusterIPs, and long capability masks out of the body; those belong in linked
evidence.

### Figure placement

Use a very small inline topology arrow or no figure. Do not reuse the Task 2
IAM diagram. If space is tight, the findings table alone is sufficient.

### Primary repository references

- `task1/BASELINE.md`
- `docs/phase-c-report.md`, §§4–10
- `docs/evidence/phase-c/h1-container-privilege.txt`
- `docs/evidence/phase-c/h4-filesystem.txt`
- `docs/evidence/phase-c/h2-runtime-api.txt`
- `docs/evidence/phase-c/h3-network-reachability.txt`
- Matrix rows B-F1 through B-05

### Must-include qualifications

- The application exploit is assumed, not demonstrated.
- F1 did not prove host escape, privilege escalation, or persistence.
- F2 affected one named synthetic ConfigMap; no Secret or broader cluster
  authority was demonstrated.
- F3 proves two selected flows, not universal east-west reachability or lateral
  compromise.

### Statements that must not be made

- “Root gave host or cluster control.”
- “The ServiceAccount was cluster-admin.”
- “All Pods/services were mutually reachable.”
- “H4 is a fourth independent finding.”
- “The baseline represents a real production breach.”

### Content awaiting later P2 evidence

None on this page.

## Page 2 — Task 1: detection and remediation

### Page objective

Show how each issue was found, map it to the intended control, report the
actual D1/D2/D3 outcomes, and direct readers to the complete before/after
manifest bundles.

### Required facts

- Detection combined source/manual semantic review with direct runtime probes;
  scanner findings were supporting context, not the verdict.
- F1 detection: image/manifest review, PID 1 UID/GID, capability masks,
  `NoNewPrivs`, mount flags/ownership, required `/tmp` write, and harmless
  `/app` write.
- F2 detection: projected credential path, exact RBAC model, supporting
  `can-i`, and actual bounded workload-token requests.
- F3 detection: fresh connections plus DNS, target health, Service and
  EndpointSlice identity, and positive controls.
- D1 historical candidate: non-root image user `65534:65534`,
  `runAsNonRoot`, no privilege escalation, drop `ALL`, read-only root, writable
  `/tmp`; all selected D1 checks passed.
- D2 historical candidate: both ServiceAccounts disable automount; exact
  fixture Role/RoleBinding removed; Pods recreated; credential and exact
  authorization checks plus functionality passed.
- D3 historical candidate: two policy objects were admitted, required traffic
  remained healthy, but both intended denials still returned HTTP 200;
  candidate rolled back and F3 remains blocked.
- `after.yaml` is target-state source, not an integrated runtime proof.

### Proposed allocation

- Left/top 60%: four-column table **Finding / Detection / Intended change /
  Verification status**.
- Right/bottom 25%: compact before/after control-difference callout.
- Footer 15%: links to the three manifest artifacts and one-sentence image
  prerequisite.

The control table should use status labels: **D1 historical candidate PASS**,
**D2 historical candidate PASS**, **F3 BLOCKED**.

### Figure placement

No large figure. A compact before/after table is preferable. Link to:

- `deliverables/task1-manifests/before.yaml`
- `deliverables/task1-manifests/after.yaml`
- `deliverables/task1-manifests/README.md`

### Primary repository references

- `docs/phase-d-control-plan.md`
- `docs/phase-d-d1-report.md`
- `docs/phase-d-d2-report.md`
- `docs/phase-d-d3-report.md`
- `docs/phase-d-d3r1-diagnosis.md`
- `docs/phase-d-d3r1b-exec-interruption-review.md`
- `task1/hardened/`
- Matrix sections C and E

### Must-include qualifications

- D1/D2 results are bounded historical candidate evidence, not present-state
  observations.
- F3 policy admission, correct selectors, and static success did not establish
  enforcement.
- Current Task 1 cluster state and possible interrupted-diagnostic residue are
  unknown.
- A new cluster needs the local images built/loaded; an in-place migration also
  needs explicit RBAC cleanup and Pod recreation.

### Statements that must not be made

- “All findings were remediated.”
- “The after manifests are a fully secure deployment.”
- “Network isolation was verified.”
- “`kubectl apply after.yaml` removes old RBAC.”
- “Token automount changes remove credentials from already-running Pods.”

### Content awaiting later P2 evidence

None on this page.

## Page 3 — Task 1: recurrence prevention and rollout

### Page objective

Demonstrate an operational prevention strategy while making the boundary
between implemented offline checks, hosted evidence, offline policy tests, and
future production controls unmistakable.

### Required facts

- Existing offline verifier: PyYAML safe parsing with duplicate-key/object
  checks; separate insecure fidelity and hardened F1/F2/F3 source checks;
  runtime mode refuses execution. Final suite: **24/24 self-tests passed**.
- Current GitHub workflow runs Bash syntax, hardened offline verification, and
  those self-tests for PRs to `main` and pushes to `temp/work-in-progress`.
- Hosted run 35757941160 succeeded with 24/24, but only for the pre-patch
  workflow/commit `f84f719`; the corrected workflow has local validation and a
  pending hosted run. Required status-check enforcement is unverified.
- Kyverno 1.19.1 policies use CEL `ValidatingPolicy` with
  `validationActions: [Audit]`; **50/50 offline assertions passed** (38 CREATE,
  12 UPDATE). No live policy or controller was deployed.
- Detection layers: desired-state drift, runtime observation, and behavioral
  enforcement; no layer substitutes for another.
- Production sequence: inventory → report-only checks/Audit → false-positive
  repair and exceptions → small canary/Deny cohort → wider rollout only after
  service and security gates pass.
- Ownership: application, identity, network/platform, security, and release
  owners; exceptions need reason, approver, compensating check, and expiry.
- Rollback: stop promotion, preserve evidence, revert only the affected cohort
  or rule through approved change control, and never call a failed security
  denial a successful rollout.

### Proposed allocation

- Top 35%: implemented-versus-proposed comparison table:
  **Control / Current evidence / What it does not prove**.
- Middle 40%: seven-step rollout arrow or concise numbered flow.
- Bottom 25%: ownership, promotion gates, rollback, and exception discipline.

### Figure placement

A narrow rollout flow is useful:

`source checks → hosted CI → Audit pilot → canary runtime behavior → Deny cohort → staged expansion`

Put “proposed” above Audit onward, and show F3 behavioral verification as a
hard promotion gate.

### Primary repository references

- `docs/phase-e-e1-verification.md`
- `task1/scripts/verify.sh`
- `task1/scripts/test-verify-offline.sh`
- `.github/workflows/task1-offline-security.yml`
- `docs/phase-f1-offline-ci.md`
- `docs/phase-f2-admission-policy-poc.md`
- `docs/phase-f0-detection-prevention-rollout.md`
- Matrix section D

### Must-include qualifications

- Offline verifier success is not runtime security verification.
- The only hosted success applies to an earlier workflow revision.
- Kyverno tests are offline; Audit reports and Deny enforcement are not live.
- No production thresholds or environment were invented.
- F3 must pass the full target-environment behavioral matrix before promotion.

### Statements that must not be made

- “CI is a required merge gate.”
- “The frozen HEAD passed hosted CI.”
- “Kyverno is deployed” or “Kyverno blocks noncompliant workloads.”
- “Admission policy proves runtime process state, zero effective RBAC, or
  NetworkPolicy enforcement.”
- “The rollout is production-ready or implemented.”

### Content awaiting later P2 evidence

None on this page.

## Page 4 — Task 2: tool selection and architecture

### Page objective

Explain why Keycloak fits this exact contract, show the centralized identity
and application-authorization boundaries, and distinguish verified P1 provider
scope from planned P2 and design-only applications.

### Required facts

- Selected assignment option: Option A, IAM/SSO.
- Alternatives considered: Keycloak, Authentik, and ZITADEL.
- Comparison criteria actually documented: OIDC, group/role modeling,
  per-application authorization, claim mapping, local reproducibility,
  operational dependencies, POC configuration fit, and expansion paths.
- Keycloak selection rationale: client-role namespaces, group inheritance,
  role-scope controls, dedicated protocol mapper, direct fit to `ops_roles`,
  and one-container local P1 dependency profile.
- Architecture boundary: browser reaches applications and Keycloak at their
  endpoints; Keycloak does not proxy ordinary application requests;
  applications validate tokens and enforce authorization.
- `ops-dashboard` is a confidential code-flow client with PKCE S256, exact
  callback, Full Scope Allowed off, and a dedicated ID-token-only role mapper.
- Keycloak owns users, four groups, six client roles, and mappings.
- Ops Dashboard is P2 planned and not implemented. Asset Inventory and Runbook
  Portal are design-only with disabled clients.
- `ops_roles` mapping is configured, but actual emitted claim output is
  unverified.

### Proposed allocation

- Left/top 30%: compact comparison table with one row per candidate and only
  the most decision-relevant differences.
- Remaining 70%: the generated current-state diagram with a short caption and
  a three-sentence explanation of trust and enforcement boundaries.

### Figure placement

Use [`../figures/task2-iam-architecture.svg`](../figures/task2-iam-architecture.svg)
at approximately 70–80% page width. Its source is
[`../figures/task2-iam-architecture.mmd`](../figures/task2-iam-architecture.mmd).
The caption must mention: **P1 provider verified under the single-host
exception; P2 application not implemented; R8 and emitted claim unverified.**
The SVG was rendered directly from the Mermaid source with pinned
`@mermaid-js/mermaid-cli` 11.12.0.

### Primary repository references

- `task2/architecture.md`
- `task2/threat-model.md`
- `task2/compose.yaml`
- `task2/keycloak/ops-realm.json`
- Matrix sections F and G

### Must-include qualifications

- Product-fit conclusions are project-specific judgments.
- Keycloak's local `start-dev`, HTTP, and embedded database are not production
  architecture.
- The claim mapper is configured and runtime-inspected, but token output is not
  verified.
- Solid and dashed diagram edges must retain their verified/planned meanings.

### Statements that must not be made

- “Keycloak is universally superior.”
- “Keycloak proxies the application.”
- “Ops Dashboard is running.”
- “Asset Inventory and Runbook Portal are deployed.”
- “`ops_roles` was observed in a token.”
- “Independent LAN isolation passed.”

### Content awaiting later P2 evidence

- Actual application/client container and endpoint.
- Real authorization-code callback/token exchange.
- Actual `ops_roles` claim values and application authorization result.

## Page 5 — Task 2: provider POC, residual risks, and demo

### Page objective

Present what P1 actually proved, disclose the exception and remaining gaps,
give a safe provider-only demo sequence, and reserve a clear slot for later P2
results without implying they already exist.

### Required facts

- Stage A passed exact image/runtime identity, dedicated resource isolation,
  Keycloak internal HTTP, Docker DNS/HTTP, WSL route, Windows Chrome, loopback
  listener, future app-port, and admin-boundary checks.
- Original CP1 remained incomplete because independent R8 was unavailable;
  the owner-authorized single-host exception gate passed. Same-host
  non-loopback checks observed no exposure but did not prove LAN isolation.
- Stage B imported realm `ops`; CP2 O1–O7 passed after a standard `profile`
  scope source/runtime correction.
- Discovery issuer/endpoints and JWKS were observed; confidential client,
  PKCE, exact callback, disabled grants, groups, roles, scope mapper, and exact
  role-scope mapping were observed.
- Same-volume restart/idempotency passed.
- The corrected source has not passed a separate new-empty-volume import.
- No actual `ops_roles` token output, Flask callback, application session,
  application RBAC, or end-to-end SSO exists.
- Latest recorded final state: diagnostic removed, both Keycloak stages
  stopped, provisioned volume and ignored bootstrap credential retained, and
  no final listeners. This is historical state.

### Proposed allocation

- Top 28%: P1/CP2 result table with **Gate / Result / Boundary**.
- Middle 24%: safe provider-demo sequence.
- Lower 28%: residual-risk and production-hardening table.
- Bottom 20%: visually distinct **P2 RESULTS — PLACEHOLDER, NOT YET
  AVAILABLE** box listing the exact evidence that must replace it later.

### Safe provider-demo sequence

Base the eventual demo on `task2/README.md`; do not execute it during writing:

1. Reconcile the exact Task 2 image, stopped container, network, volume, secret
   metadata, and listener state. Do not delete or reset the provisioned volume.
2. Validate the Compose model and realm JSON offline.
3. Start only `keycloak-stage-b` using the retained volume; verify the exact
   image/ownership, loopback publish, readiness, and no Stage A conflict.
4. From the bounded diagnostic service and the host path, show discovery with
   exact issuer and fetch public JWKS metadata.
5. Use the secret-safe temporary `kcadm.sh` procedure to show field-filtered
   client/scope/group/role configuration without printing the bootstrap
   password, client secret, tokens, or CLI config.
6. In Windows Chrome, open a valid authorization request and show the `ops`
   login page. Label this provider entry, not application SSO.
7. Remove the diagnostic resource and stop only the Task 2 Keycloak stages,
   preserving the provisioned volume.

### Residual risks and production follow-up

Include compact rows for:

- R8 independent LAN test: deferred/unverified.
- Corrected realm source fresh import: not independently tested.
- Actual `ops_roles`: unverified and mandatory P2 entry test.
- Flask relying party and end-to-end SSO: not implemented.
- HTTP and embedded DB: local POC only.
- Production: TLS/Secure cookies, external DB and recovery, HA/upgrades,
  revocation/logout, MFA/admin hardening, audit/monitoring, rate limiting, and
  dependency/vulnerability management.

### Figure placement

No second large architecture figure. Use the status and residual-risk tables.
If a screenshot is later added, it must be small, redacted, and supported by
new evidence; do not insert a historical login screenshot solely for decoration.

### Primary repository references

- `task2/README.md`
- `task2/test-plan.md`
- `task2/threat-model.md`
- `docs/evidence/task2/t2-p1-execution.txt`, final continuation
- `docs/evidence/task2/t2-p1-scope-record.txt`, final continuation
- Matrix sections G and H

### Must-include qualifications

- “P1 provider verified under documented single-host exception” is the maximum
  supported achievement statement.
- CP1 original contract is incomplete; R8 is deferred.
- CP2 configuration and provider entry do not prove emitted claims or app SSO.
- Same-volume restart does not prove fresh import.
- Historical shutdown state is not a current Docker observation.

### Statements that must not be made

- “Task 2 POC is complete.”
- “End-to-end SSO completed.”
- “The final realm JSON passed clean import.”
- “`ops_roles` issuance was verified.”
- “The Flask application enforces RBAC.”
- “The Keycloak service is currently running.”
- “The POC is production-ready.”

### Content awaiting later P2 evidence

The placeholder must request, at minimum:

- real viewer, admin, and unrelated-role authorization-code flows;
- validated ID-token signature/issuer/audience/time/nonce behavior;
- actual `ops_roles` array and leakage exclusions;
- Flask session/cookie, route RBAC, state/PKCE/replay, CSRF/logout, outage/key
  rotation, and log/secret negative tests A1–A15;
- exact code/config revision and observed test window.

## Reference and linking strategy

Keep citations compact and repository-relative. On first use, link the finding
synthesis, manifest README, Task 2 architecture, new SVG, Task 2 runbook, and
claim matrix. Use short footnote-style source labels in tables (for example,
`[C4 §7]`, `[D3 §9]`, `[P1 final/O5]`) and put one compact “Evidence index” line
in the final footer pointing to the matrix. Do not inline raw logs, full YAML,
Mermaid source, long digests, private addresses, tokens, credentials, or client
secrets. Full YAML stays in the manifest bundle; Mermaid stays in the figure
source; detailed evidence stays in `docs/evidence/`.

Before export, search the draft for unsupported absolutes including “fully
remediated,” “production-ready,” “network isolation verified,” “end-to-end SSO
completed,” and “all controls enforced.” Verify every hyperlink at the frozen
commit and ensure the report can still be read if external web links are
unavailable.

## NEXT DOCUMENTATION STEPS

1. Write and export the actual five-page PDF.
2. Prepare the Part 1 presentation using its separate infrastructure-security
   architecture.
3. Rewrite the repository root README to link to the completed deliverables and
   offer safe Quickstart paths.
4. Cross-check all links, artifact versions, claims, and evidence.
5. Return to Task 2 P2 after the documentation phase, if time permits.
6. Update the PDF with actual P2 results after they are verified.
