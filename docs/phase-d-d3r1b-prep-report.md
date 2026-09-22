# Task 1 — D3R-1B-PREP Isolated Go Toolchain Preparation

## 1. Executive Summary

**D3 remains NOT READY.** D3R-1B previously stopped before its diagnostic transaction because no compatible local Go compiler was available. This PREP run selected the version-correlated **Go 1.25.5 linux/amd64** release, verified its official archive SHA-256, installed it only in an ignored, persistent repository-local toolchain root, resolved and verified the full `github.com/google/nftables v0.3.0` module graph, and built a trivial non-nftables program to verify compiler/linker operation. The diagnostic helper was neither created nor run. No nftables or Kubernetes mutation occurred. This is only a tooling handoff; it does not resolve the D3 cause or authorize D3R-1B-EXEC.

## 2. Starting State

The clean starting commit was `bc49d7e46ce733d2f43c9419be3f3831ad2eb86b` on `temp/work-in-progress`. The prior [D3R-1B report](phase-d-d3r1b-report.md) ends exactly `D3R-1B NOT READY — VERSION-CORRELATED DIAGNOSTIC NOT EXECUTABLE`. F1 and F2 remain accepted, F3 remains unaccepted, and D3 remains NOT READY. The owned `secops-lab` cluster, `kind-secops-lab` context, and `secops-demo` namespace held the accepted D2 runtime: two Ready application Pods with zero restarts, their two Services, dedicated ServiceAccounts with automount disabled, no namespace Role or RoleBinding, baseline fixture marker, **zero NetworkPolicies**, and no D3 temporary Pods or Services. Kindnet `kindnet-n2pj4` was Ready, UID `6e4afac8-6fc5-491d-9a0d-f96b7007c540`, restartCount **4**, current container started `2026-09-22T03:41:12Z`. [Context evidence](evidence/phase-d/d3r1b-prep-context.txt).

## 3. Toolchain Version Selection

At exact kind correlation commit [`20ccfc88055ce538b79b1685d6a497d35311d7d1`](https://github.com/kubernetes-sigs/kind/commit/20ccfc88055ce538b79b1685d6a497d35311d7d1), [`.go-version`](https://raw.githubusercontent.com/kubernetes-sigs/kind/20ccfc88055ce538b79b1685d6a497d35311d7d1/.go-version) reads `1.25.5`; [`images/kindnetd/go.mod`](https://raw.githubusercontent.com/kubernetes-sigs/kind/20ccfc88055ce538b79b1685d6a497d35311d7d1/images/kindnetd/go.mod) declares `go 1.24.0`. Go 1.25.5 was selected for `linux/amd64` because it matches that exact source's requested toolchain and satisfies kindnet's Go requirement. Both host and kind node report `x86_64`, which maps to `amd64`. This is a **version-correlated toolchain**; the historical kindnet binary is not proven to have been built with Go 1.25.5. [Version evidence](evidence/phase-d/d3r1b-prep-version-selection.txt).

## 4. Workspace and Ownership Model

`STAGING_ROOT` was `/home/tac/projects/secops-engineer-case-study-2026/.local/d3r1b-prep-staging.PssaZjsV`; the run ID was `PssaZjsV`, with an ownership marker recording the start commit, UTC creation, and intended destination. `CANONICAL_ROOT` is `/home/tac/projects/secops-engineer-case-study-2026/.local/d3r1b-toolchain`. It **did not exist** at the start. The existing `.gitignore` rule `/.local/` covers the final root; `git check-ignore -v` confirmed the exact READY path is ignored. The root lives in this persistent checkout rather than a temporary directory, and no ignore rule was added. The staging tree was moved, leaving no staging path behind. [Context evidence](evidence/phase-d/d3r1b-prep-context.txt).

## 5. Official Toolchain Provenance

The selected entry came from [official Go release metadata](https://go.dev/dl/?mode=json&include=all): `go1.25.5.linux-amd64.tar.gz`, 59,768,009 bytes. The archive was requested from [go.dev](https://go.dev/dl/go1.25.5.linux-amd64.tar.gz) and the official redirect resolved to `https://dl.google.com/go/go1.25.5.linux-amd64.tar.gz`. Metadata expected SHA-256 `9e9b755d63b36acf30c12a9a3fc379243714c1c6d3dd72861da637f336ebb35b`; the locally downloaded archive's SHA-256 was identical. Checksum and size comparisons **passed before extraction**. No third-party mirror was used. [Provenance evidence](evidence/phase-d/d3r1b-prep-toolchain-provenance.txt).

## 6. Isolated Environment

All Go commands used the isolated `GOROOT` and `PATH`, `GOENV=off`, `GOTOOLCHAIN=local`, `GOWORK=off`, isolated `GOCACHE`, `GOMODCACHE`, and `GOPATH` under the active staging or canonical root, `GOPROXY=https://proxy.golang.org`, and `GOSUMDB=sum.golang.org`. No `go env -w` or global Go cache was used. [Environment evidence](evidence/phase-d/d3r1b-prep-toolchain-env.txt) records the actual post-promotion values and env.sh hash.

**GOENV display discrepancy:** the Go 1.25.5 process environment was confirmed as `GOENV=off`, while `go env GOENV` exited 0 and printed an empty string, not the literal `off` anticipated by the PREP specification. The checksum-verified Go source explains this: `cfg.EnvFile` returns an empty path for `GOENV=off`, and `envcmd.MkEnv` prints that path. Thus the user Go environment file is disabled. This discrepancy was understood without changing persistent user settings; it is recorded rather than hidden or represented as literal output `off`.

## 7. Toolchain Verification

The isolated binary reported `go version go1.25.5 linux/amd64`; `go tool compile -V=full` reported `compile version go1.25.5`. Effective `GOOS=linux`, `GOARCH=amd64`, and `GOROOT=/home/tac/projects/secops-engineer-case-study-2026/.local/d3r1b-toolchain/go` matched the intended target and location. The final `go` binary SHA-256 is `d29b19f04e57fa2f35d4725a8743b663289ac29832128a235c4a3f76f885b150`, matching its staging hash. Host and node are both `x86_64`; the future diagnostic helper target is `linux/amd64`. [Toolchain provenance](evidence/phase-d/d3r1b-prep-toolchain-provenance.txt) and [environment evidence](evidence/phase-d/d3r1b-prep-toolchain-env.txt).

## 8. Full Module Graph Verification

The isolated probe `go.mod` requests `github.com/google/nftables v0.3.0` and is outside repository source. The resolved direct version is exactly `v0.3.0`, with `Sum=h1:bkyZ0cbpVeMHXOrtlFc8ISmfVqq5gPJukoYieyVmITg=` and `GoModSum=h1:BCp9FsrbF1Fn/Yu6CLUc9GGZFw/+hsxfluNXXmxBfRM=`. `go mod download all`, `go list -m all`, and `go mod verify` each exited 0; verification printed `all modules verified`. Nine external module zip files are present in the isolated cache. [Module evidence](evidence/phase-d/d3r1b-prep-module-resolution.txt) records the probe and full list:

```text
github.com/google/go-cmp v0.6.0
github.com/google/nftables v0.3.0
github.com/mdlayher/netlink v1.7.3-0.20250113171957-fbb4dce95f42
github.com/mdlayher/socket v0.5.0
github.com/vishvananda/netlink v1.3.0
github.com/vishvananda/netns v0.0.4
golang.org/x/net v0.33.0
golang.org/x/sync v0.6.0
golang.org/x/sys v0.28.0
```

The initial sandboxed download failed on DNS/socket access; the same official-proxy command succeeded with network access. Neither the proxy nor checksum service was disabled.

## 9. Generic Build/Link Smoke

The sole executable PREP source was `package main` followed by `func main() {}`. It imported neither nftables nor networking libraries. With the isolated Go binary and staging caches, `go build -o build-smoke main.go` exited 0 and produced a statically linked x86-64 ELF executable. Its SHA-256 was `2c62424d769026626e4e6a9c399a3f4d7b4464f7fbb1de4df77b5636bb79b95c`; `go version -m` reported `go1.25.5`, `GOOS=linux`, and `GOARCH=amd64`. The binary was **not executed** and was removed, along with the trivial source, before promotion. This proves only generic command/compiler/linker operation. [Build evidence](evidence/phase-d/d3r1b-prep-build-smoke.txt).

## 10. Promotion to Persistent Root

The official checksum, isolated binary/environment/architecture checks, full module download and verification, and generic build smoke all passed in staging. The run then used a same-filesystem `mv -T` from the exact run-owned staging path to the initially absent canonical root. The source path no longer existed afterward. The final Go binary hash and full module graph were rechecked under the canonical root; `go mod verify` again printed `all modules verified`. No READY marker existed during these checks.

## 11. Handoff Artifacts

Only after promotion and post-promotion checks, the run created [`env.sh`](../.local/d3r1b-toolchain/env.sh) with the scoped exports, verified it in a subprocess, and recorded SHA-256 `10f736ea5ab9aa8f256d1fd7d32b0c7960cede15e223e09315737ca5862473ec`. The [`READY`](../.local/d3r1b-toolchain/READY) marker was created **last** within the canonical handoff root at `2026-09-22T10:27:54Z`; it records the root, hashes, version, isolation values, module verification, and build smoke. READY is metadata for review, not authority by itself.

## 12. Diagnostic Boundary

D3R diagnostic helper source **NOT CREATED**; diagnostic helper **NOT BUILT**; diagnostic helper **NOT EXECUTED**. Primary Flush count **0**. No `google/nftables` runtime call and **no nftables mutation** occurred. The module probe contained only a `go.mod`, not a `.go` import of nftables. D3R-1B-EXEC, D3R-2, and D4 were not started.

## 13. System-under-Test Noninterference

Kubernetes mutations **NONE**; NetworkPolicy reapply **NO**. A final read-only check at `2026-09-22T10:28:23Z` found NetworkPolicy count still **0**, D3 fixtures absent, both original application Pods Ready with zero restarts, accepted F2 identity state preserved, and kindnet Ready with the same UID, restartCount **4**, and container start time. No network component restart, CNI change, system package installation, or host network configuration change occurred. [Scope evidence](evidence/phase-d/d3r1b-prep-scope.txt).

## 14. D3R-1B-EXEC Handoff

Before sourcing env.sh or building anything, a separately authorized EXEC run must independently inspect READY and the canonical root path, check the recorded env.sh and Go binary hashes, run the absolute `<CANONICAL_ROOT>/go/bin/go version`, verify process `GOENV=off` with the documented empty `go env GOENV` display, verify effective `GOTOOLCHAIN=local` and isolated `GOCACHE`/`GOMODCACHE`/`GOPATH`, and confirm `github.com/google/nftables v0.3.0` plus the full module graph and `go mod verify` state. It must not treat READY alone as proof or blindly source env.sh before validating its path and hash. This PREP run grants no authority to execute the diagnostic transaction.

## 15. Repository Mutation Verification

Only this report and the seven `docs/evidence/phase-d/d3r1b-prep-*` files were created. The final `git status --short --untracked-files=all`, `git diff --name-only`, and `git diff --stat` checks are recorded by the run; the toolchain is hidden by the pre-existing `.local/` ignore rule. `task1/**`, `.gitignore`, and existing D0/D1/D2/D3/D3R artifacts remained unchanged. No commit, push, or branch change occurred.

## 16. PREP Exit Decision

The missing tooling prerequisite is prepared in a persistent isolated root with official release checksum verification, a resolved and verified direct/transitive module graph, and a generic compiler/linker smoke. The GOENV display behavior is explicitly explained above. D3 remains NOT READY; the unresolved nftables diagnostic remains for a separate EXEC run.

D3R-1B-PREP READY — VERIFIED ISOLATED TOOLCHAIN AVAILABLE
