# SecOps Engineer Case Study 2026

Engineering case study covering:

- Kubernetes workload security assessment and hardening
- Security detection and policy enforcement
- Secure access architecture and proof of concept

## Status

Phase A is approved. Task 1 Phase B provides an intentionally permissive
representative Kubernetes baseline. **H1–H4 are not yet confirmed findings;
security assessment occurs in Phase C.** See the [baseline contract](task1/BASELINE.md)
and [Phase B execution report](docs/phase-b-report.md) for requirements, actual
results and evidence. This is an intermediate deliverable toward the official
assignment, not the completed assessment or final submission PDF.

## Run Task 1 Phase B

Prerequisites: Linux with an available Docker daemon, Bash, curl, Python 3, Git,
GNU Make, kind **v0.31.0** and kubectl **v1.35.0**. Setup needs access to official
CLI downloads and Docker Hub; the running application has no external dependency.
The scripts find repository-local CLI binaries in `.local/bin` before `PATH`.
The node is pinned to Kubernetes **v1.34.3** for compatibility with this lab's
existing cgroup v1 host; kubectl v1.35.0 is one minor version newer.

If kind/kubectl are missing, download the matching binaries and verify their
published SHA-256 checksums using the official
[kind release](https://github.com/kubernetes-sigs/kind/releases/tag/v0.31.0) and
[kubectl installation instructions](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).
Place the executables in `.local/bin`; no sudo is needed. The reviewed run used
Linux amd64; exact URLs, checksums and installation results are in the
[installation evidence](docs/evidence/phase-b/tool-installation.txt).
Docker installation or daemon configuration is an operator prerequisite.

From the repository root:

```sh
make task1-cluster-up  # one node, secops-lab, pinned node image
make task1-build       # build both images and load them into kind
make task1-baseline    # apply representative manifests and await readiness
make task1-check       # health, deterministic end-to-end response, /tmp cache
make task1-clean       # delete this local lab cluster when finished
```

The same steps are available as scripts in `task1/scripts/`. The kubeconfig and
downloaded tools stay under ignored `.local/`; scripts use an explicit local
context. Keep the cluster until Phase C if continuing the exercise. Cleanup
removes the lab cluster, not Docker images or downloaded tools.

The two ClusterIP Services use ports 8080 and 8081. Functional checking opens
temporary loopback forwards on 18080/18081 and closes them on exit. Expected data:

```json
{"source":"demo-backend","value":"representative-data"}
```

Each API `/data` success requires a fresh backend request and a successful write
to `/tmp/demo-cache.json`. Both `/healthz` endpoints return `{"status":"ok"}`.
No NetworkPolicy, hardened variant, scanner, admission policy or CI security gate
is introduced in this phase. See the report before beginning assessment.
