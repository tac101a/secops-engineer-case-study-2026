# F0 source inventory

Inspected offline on 2026-09-22. Paths are repository-relative unless linked externally. “Historical runtime” labels refer to earlier runs, not F0 observations.

| Source | Role and evidence limit |
| --- | --- |
| [D0 control plan](../../phase-d-control-plan.md) | Canonical accepted F1/F2/F3 classes, behavioral criteria, deferred CI/admission/CNI decisions. Design authority. |
| [Phase B contract](../../../task1/BASELINE.md) | Legitimate functionality, zero Kubernetes API budget, local authority and network budget. Design authority. |
| [Phase C synthesis](../../phase-c-report.md) | Confirmed finding scope and priorities; static Trivy coverage limits. Historical assessment. |
| [D1 report](../../phase-d-d1-report.md) and [F1 raw runtime evidence](../phase-d/d1-runtime-f1.txt) | Historical F1 candidate acceptance only. |
| [D2 report](../../phase-d-d2-report.md), [F2 raw runtime evidence](../phase-d/d2-runtime-f2.txt), and [functional evidence](../phase-d/d2-candidate-functional.txt) | Last historically verified functional remediation baseline; not current state. |
| [D3 report](../../phase-d-d3-report.md) and [post-policy reachability](../phase-d/d3-post-policy-reachability.txt) | Historical failure of both required F3 denials; policies rolled back. |
| [D3R-0 freeze](../../phase-d-d3r0-blocker-freeze.md), [D3R-1 diagnosis](../../phase-d-d3r1-diagnosis.md), and [D3R-1B report](../../phase-d-d3r1b-report.md) | Enforcement boundary and unresolved lower-layer cause; no recovery technology selected. |
| [EXEC interruption review](../../phase-d-d3r1b-exec-interruption-review.md) and [runtime access record](../phase-d/d3r1b-exec-interruption-runtime-state.txt) | Current live state and possible residue unknown after access restriction. |
| [Hardened API manifest](../../../task1/hardened/demo-api.yaml) and [Dockerfile](../../../task1/hardened/images/demo-api.Dockerfile) | Desired F1 fields and distinct image identity only. |
| [Hardened identity](../../../task1/hardened/identity.yaml) | Desired F2 ServiceAccount automount fields only. |
| [Hardened NetworkPolicy candidate](../../../task1/hardened/network-policy.yaml) | Desired F3 selectors and allow rules; no enforcement claim. |
| [Insecure API](../../../task1/insecure/demo-api.yaml), [backend](../../../task1/insecure/demo-backend.yaml), and [RBAC](../../../task1/insecure/rbac.yaml) | Protected BEFORE configuration and named assessment grant. |
| [kind config](../../../task1/kind.yaml) | Pinned local node image; not a present runtime observation. |
| [D2 deploy script](../../../task1/hardened/scripts/deploy-f2.sh), [D3 deploy script](../../../task1/hardened/scripts/deploy-f3.sh), and [D3 smoke script](../../../task1/hardened/scripts/smoke-f3.sh) | Read as source only. They include kubectl/Docker calls and mutations; none was executed. |
| [README](../../../README.md), [Makefile](../../../Makefile), tracked-path listing, and `git remote -v` | Repository context: GitHub origin, no tracked CI workflow, Make targets invoke scripts. No remote service state inspected. |
| [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/) | Official semantics for supporting plugin, additive policies, and limits of API object creation. Accessed 2026-09-22. |
| [Kubernetes ValidatingAdmissionPolicy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/) | Official stability and validation actions used to justify a proposed admission pilot. Accessed 2026-09-22. |
| [GitHub branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) | Official required-status-check capability, not proof it is configured here. Accessed 2026-09-22. |

No F0 CI workflow, admission object, production inventory, approved service threshold, or current runtime evidence exists in the inspected material. The F0 architecture is a proposal awaiting implementation review.
