# Task 2 — IAM/SSO proof of concept

Status: **P0 design and host preflight complete; runtime and OIDC are not yet
verified.**

This directory selects Task 2 Option A: a Keycloak identity provider and a
Flask Ops Dashboard using the OIDC authorization-code flow. P0 is documentation
and read-only host observation only. It did not contact the Docker daemon,
create containers or networks, provision a realm, or exercise login.

The four original reviewed P0 artifacts are:

- [architecture.md](architecture.md) — fixed implementation decisions, host
  observations, role/session contracts, and phase gates;
- [threat-model.md](threat-model.md) — concise trust-boundary and risk review;
- [test-plan.md](test-plan.md) — P1 gates and P2 acceptance matrix;
- this file — scope and navigation only.

The correction patch adds two evidence artifacts, bringing the approved P0
inventory to exactly six files:

- [t2-p0-preflight.txt](../docs/evidence/task2/t2-p0-preflight.txt) —
  historical reported observations, repeated read-only checks, limitations, and
  phase-separated readiness;
- [t2-p0-scope-record.txt](../docs/evidence/task2/t2-p0-scope-record.txt) —
  starting gate, acknowledged artifact/design deviations, mutation inventory,
  and execution-boundary attestations.

P1 must stop at its first gate unless the isolated Compose runtime, bindings,
networking, DNS, and Windows/WSL reachability are demonstrated without changing
Task 1 resources. After minimal realm import, P1 must stop at its second gate
unless discovery, issuer, and JWKS behavior match the architecture. Only then
may P2 implement the callback and application session.

No POC run command is provided yet because the POC does not exist in P0.

