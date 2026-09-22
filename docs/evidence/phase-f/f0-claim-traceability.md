# F0 claim traceability

| F0 claim / decision | Direct basis | Classification and limit |
| --- | --- | --- |
| F1/F2/F3 accepted control classes; CI/admission and CNI product selection deferred | [D0 §§4–7, 12](../../phase-d-control-plan.md) | Accepted design, not product selection. |
| D2 last historically verified functional remediation baseline | [D2 §§8, 11, 16](../../phase-d-d2-report.md), [D3 §§18–19](../../phase-d-d3-report.md) | Historical candidate state; no current-state inference. |
| Current cluster and possible EXEC residue unknown | [EXEC review §§9–11](../../phase-d-d3r1b-exec-interruption-review.md), [runtime access](../phase-d/d3r1b-exec-interruption-runtime-state.txt) | Unknown after interrupted attempt. |
| F1 candidate actual non-root, zero capabilities, `NoNewPrivs: 1`, read-only root, `/app` denial and `/tmp` write | [D1 §§3–7](../../phase-d-d1-report.md), [raw F1](../phase-d/d1-runtime-f1.txt) | Historical behavioral/runtime evidence, not F0 observation. |
| F2 candidate no projected token or named grant and healthy function | [D2 §§3–11](../../phase-d-d2-report.md), [raw F2](../phase-d/d2-runtime-f2.txt) | Historical runtime/candidate evidence; formal Phase E request oracle pending. |
| F3 candidate admitted but two forbidden fresh flows returned HTTP 200 | [D3 §§8–10, 19](../../phase-d-d3-report.md), [raw reachability](../phase-d/d3-post-policy-reachability.txt) | Historical behavioral enforcement failure. |
| Kindnet nftables/netlink sync failure unresolved; no CNI selected | [D3R-1 §§8–18](../../phase-d-d3r1-diagnosis.md), [D3R-1B §§11–18](../../phase-d-d3r1b-report.md) | Observed boundary, unresolved cause. |
| Checked-in F1/F2/F3 source fields match accepted candidate shape | [F0 static output](f0-static-checks.txt), [hardened files](../../../task1/hardened/) | Current repository desired-state check only. |
| GitHub remote present, no tracked CI workflow | [F0 scope record](f0-scope-record.txt) | Local Git evidence; no hosted settings queried. |
| GitHub Actions + VAP is one proposed CI/admission architecture | [GitHub status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), [VAP](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/) | F0 proposal; neither selected nor deployed. |
| NetworkPolicy manifest/admission alone cannot prove restriction | [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/), [D3 failed flows](../../phase-d-d3-report.md) | Platform semantics plus direct historical failure; behavioral gate required. |
| Proposed rollout and rollback thresholds require owner calibration | [Phase A operational boundary](../../architecture.md), [Phase B contract](../../../task1/BASELINE.md) | Design recommendation, no actual production thresholds or rollout. |

The nine detection IDs in the [main matrix](../../phase-f0-detection-prevention-rollout.md) each have one primary evidence category. Proposed checks are not reported as performed F0 runtime tests.
