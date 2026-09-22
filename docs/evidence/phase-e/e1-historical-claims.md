# E1 curated historical claims

This file records reviewed *past* observations for `--historical-summary`.
Rendering these claims does not rerun a probe, establish current workload state,
accept D3 or D4, or complete the Phase E AFTER proof. A status change requires
review of the cited raw evidence and an explicit edit to this mapping.

## Machine-readable mapping

The verifier reads only the single JSON object between the exact BEGIN and END
markers below. The object has exactly `schema` and `claims`. `schema` must be
`e1-historical-claims/v1`. `claims` is a nonempty array of objects with exactly
`id`, `phase_profile`, `status`, `sources`, and `limitation`. IDs are `FUNC`,
`F1`, `F2`, or `F3`; the pair `(id, phase_profile)` is unique. Each `sources`
array contains one or more unique, existing, repository-relative canonical
paths under `docs/`. All strings are nonempty. Permitted statuses are
`FUNCTIONAL_PASS`, `WEAKNESS_CONFIRMED`, `CANDIDATE_PASS`, and
`CANDIDATE_FAIL`. The verifier rejects duplicate JSON keys, unknown fields,
invalid status and ID combinations, duplicate claims, unsafe source paths, and
missing source files as an infrastructure error. A missing mapping file is
BLOCKED. Neither the prose here nor arbitrary Markdown reports are parsed for
verdicts. Version 1 requires exactly the ten `(id, phase_profile)` pairs in the
mapping below; extra or missing pairs are inconsistent. `FUNC` rows require
`FUNCTIONAL_PASS`, Phase C finding rows require `WEAKNESS_CONFIRMED`, and Phase D
finding rows require `CANDIDATE_PASS` or `CANDIDATE_FAIL`.

<!-- E1-HISTORICAL-CLAIMS-JSON-BEGIN -->
```json
{
  "schema": "e1-historical-claims/v1",
  "claims": [
    {
      "id": "FUNC",
      "phase_profile": "B/insecure",
      "status": "FUNCTIONAL_PASS",
      "sources": ["docs/phase-b-report.md", "docs/evidence/phase-b/functional-baseline.txt"],
      "limitation": "Historical Phase B functional run only; no current health or runtime state inferred."
    },
    {
      "id": "F1",
      "phase_profile": "C/insecure",
      "status": "WEAKNESS_CONFIRMED",
      "sources": ["docs/phase-c-report.md", "docs/evidence/phase-c/h1-container-privilege.txt", "docs/evidence/phase-c/h4-filesystem.txt"],
      "limitation": "Historical API PID 1 authority and one /app write; no host escape or current baseline reproduction claimed."
    },
    {
      "id": "F2",
      "phase_profile": "C/insecure",
      "status": "WEAKNESS_CONFIRMED",
      "sources": ["docs/phase-c-report.md", "docs/evidence/phase-c/h2-credential-exposure.txt", "docs/evidence/phase-c/h2-runtime-api.txt"],
      "limitation": "Historical named ConfigMap GET/PATCH using the API workload token; fixture was restored; no current credential claim."
    },
    {
      "id": "F3",
      "phase_profile": "C/insecure",
      "status": "WEAKNESS_CONFIRMED",
      "sources": ["docs/phase-c-report.md", "docs/evidence/phase-c/h3-network-reachability.txt"],
      "limitation": "Historical reachability of two selected unintended Service paths; not a claim about all east-west traffic."
    },
    {
      "id": "FUNC",
      "phase_profile": "D1/hardened-candidate",
      "status": "FUNCTIONAL_PASS",
      "sources": ["docs/phase-d-d1-report.md", "docs/evidence/phase-d/d1-candidate-functional.txt"],
      "limitation": "Historical D1 candidate functionality; no integrated AFTER profile was tested."
    },
    {
      "id": "F1",
      "phase_profile": "D1/hardened-candidate",
      "status": "CANDIDATE_PASS",
      "sources": ["docs/phase-d-d1-report.md", "docs/evidence/phase-d/d1-runtime-f1.txt"],
      "limitation": "Historical D1 candidate smoke; formal same-oracle Phase E comparison remains unrun."
    },
    {
      "id": "FUNC",
      "phase_profile": "D2/hardened-candidate",
      "status": "FUNCTIONAL_PASS",
      "sources": ["docs/phase-d-d2-report.md", "docs/evidence/phase-d/d2-candidate-functional.txt"],
      "limitation": "Historical D2 candidate functionality; no integrated AFTER profile was tested."
    },
    {
      "id": "F2",
      "phase_profile": "D2/hardened-candidate",
      "status": "CANDIDATE_PASS",
      "sources": ["docs/phase-d-d2-report.md", "docs/evidence/phase-d/d2-runtime-f2.txt"],
      "limitation": "Historical absent projected credential and named grant. Impersonated can-i is authorization-model support only; no Phase E workload-context AFTER request was executed."
    },
    {
      "id": "FUNC",
      "phase_profile": "D3/hardened-candidate",
      "status": "FUNCTIONAL_PASS",
      "sources": ["docs/phase-d-d3-report.md", "docs/evidence/phase-d/d3-post-functional.txt"],
      "limitation": "Historical application function passed while F3 enforcement failed; this does not accept the D3 candidate."
    },
    {
      "id": "F3",
      "phase_profile": "D3/hardened-candidate",
      "status": "CANDIDATE_FAIL",
      "sources": ["docs/phase-d-d3-report.md", "docs/evidence/phase-d/d3-post-policy-reachability.txt"],
      "limitation": "Historical D3 candidate admitted policies but both required denials failed; current dataplane and D4 integration remain unverified."
    }
  ]
}
```
<!-- E1-HISTORICAL-CLAIMS-JSON-END -->
