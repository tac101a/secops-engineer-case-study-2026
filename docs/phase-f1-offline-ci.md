# Task 1 — F1 Offline CI Gate Implementation

## Decision and scope

**F1-PATCH LOCAL READY** for the current working tree. The [workflow](../.github/workflows/task1-offline-security.yml) runs the existing E1 hardened offline verifier and its complete current self-test suite only for pull requests targeting `main` and pushes to `temp/work-in-progress`. The workflow is a source check only. The [F0 design](phase-f0-detection-prevention-rollout.md) is the canonical prevention and rollout proposal; this F1 implementation supplies its first local CI artifact, not its proposed admission pilot or runtime release gate.

The starting HEAD was `e29c03976eb8bcbf76898da69873cf85652738b1`, the last reviewed E1 snapshot, with no intervening commits and a clean working tree. The current [`verify.sh`](../task1/scripts/verify.sh), [`test-verify-offline.sh`](../task1/scripts/test-verify-offline.sh), [E1 report](phase-e-e1-verification.md), and [E1 execution record](evidence/phase-e/e1-offline-tests.txt) were read before implementation. The suite remains 24 tests at this revision. The previously reported E1 run was treated as historical evidence; the F1 checks were executed again locally and all 24 passed. See [F1 local validation](evidence/phase-f/f1-local-validation.txt) and [scope record](evidence/phase-f/f1-scope-record.txt).

## Workflow behavior

The only events are `pull_request` with `branches: [main]` and `push` with `branches: [temp/work-in-progress]`. There is no manual dispatch, path filter, or `pull_request_target`. The job ID remains `offline-security` and its display name remains **Task 1 offline security**. It uses `ubuntu-24.04`, Python `3.12`, and `PyYAML==6.0.1`, with repository contents read permission only. The official checkout and setup-python actions are pinned to their verified release commits: [`checkout` v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1) at `3d3c42e5aac5ba805825da76410c181273ba90b1` and [`setup-python` v7.0.0](https://github.com/actions/setup-python/releases/tag/v7.0.0) at `5fda3b95a4ea91299a34e894583c3862153e4b97`. Checkout does not persist credentials.

The mandatory steps have unique IDs `bash_syntax`, `hardened_verify`, and `offline_self_tests`. They run `bash -n` on both E1 scripts, `task1/scripts/verify.sh --offline hardened`, and `task1/scripts/test-verify-offline.sh` directly. Explicit Bash shell selection uses GitHub's `-e -o pipefail` invocation; a nonzero command exit fails its step and job. No mandatory command is piped through a reporting tool or suppressed with `continue-on-error` or `|| true`. [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) specifies the Bash invocation and [GitHub's exit-code guidance](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/set-exit-codes) describes nonzero failure handling.

The final summary uses `if: always()` and reads the three mandatory `steps.<id>.outcome` values. It prints the actual `success`, `failure`, `skipped`, or `cancelled` value, where applicable; it never calls an unexecuted check a pass. It reports **OFFLINE STATIC VERIFICATION** separately from **CURRENT RUNTIME SECURITY VERIFICATION: NOT RUN** and keeps F3 enforcement and full integrated AFTER verification **BLOCKED / NOT VERIFIED**. The summary step does not change a failed mandatory step into a successful job. [GitHub's context reference](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts) defines these outcome values.

## Current E1 acceptance contract and limit

The hardened offline verifier currently returns 0 with F1, F2, and F3 STATIC PASS and with F3 enforcement still blocked. The self-test suite includes negative fixtures for weakened F1/F2/F3 sources, a projected token, historical mapping failures, and insecure-baseline drift. All 24 self-tests passed locally with zero failed and the runtime-tool guard passed.

The proposed insecure-baseline **EXPECTED-WEAK** label has not been added to E1: the current verifier emits F1/F2/F3 `BASELINE: PASS` for source fidelity and describes that profile as a declarative baseline comparison. This is an existing E1 presentation limitation. It does not turn insecure controls into hardened security results, and F1 does not alter E1 files.

## Validation chronology

### Stage A — Original F1 local validation

The original local validation on 2026-09-22 was **LOCAL PASS**. Bash syntax and the hardened verifier exited 0; 24 current self-tests passed and zero failed. Hosted verification had **NOT YET EXECUTED**. The original transcript remains intact at the beginning of the [local validation record](evidence/phase-f/f1-local-validation.txt).

### Stage B — Pre-patch hosted verification

[GitHub Actions run 35757941160](https://github.com/tac101a/secops-engineer-case-study-2026/actions/runs/35757941160) executed the original workflow before this trigger correction. Its event was `push`, tested commit `f84f719db788736c620af37b0c466c923331c02c`, and conclusion was **SUCCESS**. Job **Task 1 offline security** succeeded, and its log reports 24 self-tests passed, zero failed. This run verifies only the original workflow.

### Stage C — Post-patch local validation

The corrected workflow received **LOCAL STRUCTURAL VALIDATION ONLY: PASS** using PyYAML `BaseLoader`, which preserves `on` as a string under YAML 1.1. The parsed event map was compared for exact equality with the two allowed events and branch filters. Actionlint was unavailable and was not installed. Bash syntax and the hardened verifier exited 0; the current self-test suite executed 24 tests, with 24 passed and zero failed. The appended transcript records the commands, output, and exit codes.

### Stage D — Post-patch hosted verification

**PENDING OWNER COMMIT, PUSH AND NEW GITHUB ACTIONS RUN.** The Stage B run cannot verify the corrected workflow. Each future hosted record must state its actual event and tested SHA. A push to `temp/work-in-progress` checks the branch commit, while an open pull request may also run against GitHub's synthetic merge result; those SHAs can differ, so a push result does not automatically verify the pull-request merge result.

### Stage E — Required merge gate

**NOT VERIFIED.** GitHub [documents required status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), but no branch protection was configured here. After a successful post-patch run, the owner must select the exact observed check-run name; the YAML job ID is not assumed to be that displayed context. A pull request must show that selected check and demonstrate enforcement before this milestone can advance.

## Exit decision

Exactly four F1 files contain the patch. The job identity and mandatory checks are unchanged, command failures propagate, and the corrected two-event map passed actual local validation. E1 and runtime sources were not modified, and no Kubernetes, Docker, kind, or nftables access occurred. F3 remains **NOT READY** after the historical [D3 failure](phase-d-d3-report.md); D4 and the full Phase E same-oracle BEFORE/AFTER runtime verification remain blocked. The current cluster and possible diagnostic residue remain unknown after the [interrupted EXEC review](phase-d-d3r1b-exec-interruption-review.md).

TASK1-F1-PATCH LOCAL READY
