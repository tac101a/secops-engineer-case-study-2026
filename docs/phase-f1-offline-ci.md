# Task 1 — F1 Offline CI Gate Implementation

## Decision and scope

**F1 LOCAL IMPLEMENTATION READY** for the current working tree. The [workflow](../.github/workflows/task1-offline-security.yml) runs the existing E1 hardened offline verifier and its complete current self-test suite on pull requests, pushes, and manual dispatches. The workflow is a source check only. The [F0 design](phase-f0-detection-prevention-rollout.md) is the canonical prevention and rollout proposal; this F1 implementation supplies its first local CI artifact, not its proposed admission pilot or runtime release gate.

The starting HEAD was `e29c03976eb8bcbf76898da69873cf85652738b1`, the last reviewed E1 snapshot, with no intervening commits and a clean working tree. The current [`verify.sh`](../task1/scripts/verify.sh), [`test-verify-offline.sh`](../task1/scripts/test-verify-offline.sh), [E1 report](phase-e-e1-verification.md), and [E1 execution record](evidence/phase-e/e1-offline-tests.txt) were read before implementation. The suite remains 24 tests at this revision. The previously reported E1 run was treated as historical evidence; the F1 checks were executed again locally and all 24 passed. See [F1 local validation](evidence/phase-f/f1-local-validation.txt) and [scope record](evidence/phase-f/f1-scope-record.txt).

## Workflow behavior

The job is named **Task 1 offline security** (`offline-security`). It uses `ubuntu-24.04`, Python `3.12`, and `PyYAML==6.0.1`, with repository contents read permission only. The official checkout and setup-python actions are pinned to their verified release commits: [`checkout` v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1) at `3d3c42e5aac5ba805825da76410c181273ba90b1` and [`setup-python` v7.0.0](https://github.com/actions/setup-python/releases/tag/v7.0.0) at `5fda3b95a4ea91299a34e894583c3862153e4b97`. Checkout does not persist credentials.

The mandatory steps have unique IDs `bash_syntax`, `hardened_verify`, and `offline_self_tests`. They run `bash -n` on both E1 scripts, `task1/scripts/verify.sh --offline hardened`, and `task1/scripts/test-verify-offline.sh` directly. Explicit Bash shell selection uses GitHub's `-e -o pipefail` invocation; a nonzero command exit fails its step and job. No mandatory command is piped through a reporting tool or suppressed with `continue-on-error` or `|| true`. [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) specifies the Bash invocation and [GitHub's exit-code guidance](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/set-exit-codes) describes nonzero failure handling.

The final summary uses `if: always()` and reads the three mandatory `steps.<id>.outcome` values. It prints the actual `success`, `failure`, `skipped`, or `cancelled` value, where applicable; it never calls an unexecuted check a pass. It reports **OFFLINE STATIC VERIFICATION** separately from **CURRENT RUNTIME SECURITY VERIFICATION: NOT RUN** and keeps F3 enforcement and full integrated AFTER verification **BLOCKED / NOT VERIFIED**. The summary step does not change a failed mandatory step into a successful job. [GitHub's context reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts) defines these outcome values.

## Current E1 acceptance contract and limit

The hardened offline verifier currently returns 0 with F1, F2, and F3 STATIC PASS and with F3 enforcement still blocked. The self-test suite includes negative fixtures for weakened F1/F2/F3 sources, a projected token, historical mapping failures, and insecure-baseline drift. All 24 self-tests passed locally with zero failed and the runtime-tool guard passed.

The proposed insecure-baseline **EXPECTED-WEAK** label has not been added to E1: the current verifier emits F1/F2/F3 `BASELINE: PASS` for source fidelity and describes that profile as a declarative baseline comparison. This is an existing E1 presentation limitation. It does not turn insecure controls into hardened security results, and F1 does not alter E1 files.

## Acceptance milestones

| Milestone | Current status | Evidence needed to advance |
| --- | --- | --- |
| F1 LOCAL IMPLEMENTATION READY | **Achieved for this working tree** | Four F1 files exist; local structural validation, Bash syntax, current hardened verifier, and 24/24 current self-tests pass. |
| F1 HOSTED VERIFIED | **NOT VERIFIED** | GitHub Actions must execute this workflow successfully on an identified commit; record the run URL and job outcome. |
| F1 REQUIRED MERGE GATE | **NOT VERIFIED** | A branch ruleset or branch-protection rule must require the exact security job and a pull request must demonstrate enforcement. |

GitHub [documents required status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), but no rule is claimed from a local workflow file. F3 remains **NOT READY** after the historical [D3 failure](phase-d-d3-report.md); D4 and the full Phase E same-oracle BEFORE/AFTER runtime verification remain blocked. The current cluster and possible diagnostic residue remain unknown after the [interrupted EXEC review](phase-d-d3r1b-exec-interruption-review.md). No live cluster action occurred in F1.
