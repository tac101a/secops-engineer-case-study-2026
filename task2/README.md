# Task 2 — IAM/SSO proof of concept

Status: **P1 partial — runtime gate pending.** The P1 configuration is present,
but the verified Keycloak image did not finish downloading during this
execution. No Task 2 container, network, volume, realm, or Flask application
was created. CP1 and CP2 therefore remain incomplete.

This directory implements the Task 2 Option A foundation selected in the
committed [architecture](architecture.md): Keycloak `26.7.4`, realm `ops`, and
an OIDC client named `ops-dashboard`. P1 proves an isolated identity-provider
runtime and provisions the provider configuration. Flask, callback handling,
application sessions, and application RBAC belong to P2.

## P1 tracked artifacts

P1 adds exactly:

- `task2/compose.yaml`
- `task2/.env.example`
- `task2/.gitignore`
- `task2/keycloak/ops-realm.json`
- `docs/evidence/task2/t2-p1-execution.txt`
- `docs/evidence/task2/t2-p1-scope-record.txt`

P1 also updates this README and [test-plan.md](test-plan.md). The P0
architecture, threat model, and P0 evidence remain unchanged.

## Prerequisites and image pins

The observed host is WSL2 on `linux/amd64`, with Docker Engine `29.3.0` and
Docker Compose `v5.1.0`. The Compose project is fixed as `task2-iam`; its only
network and persistent volume are `task2-iam-oidc` and
`task2-iam-keycloak-data`.

The tracked model pins platform-specific manifests:

- `quay.io/keycloak/keycloak:26.7.4@sha256:3d911baa186f352563854039b95f21a7e2c01c76b527fdc64f24a0885b927bdf`
  (`linux/amd64`; verified index digest
  `sha256:82a77884f3af238beab1e7afd63b5f530e1b5c0590bd7aa60b40a40463e29b2c`)
- `docker.io/library/alpine:3.22.1@sha256:eafc1edb577d2e9b458664a15f23ea1c370214193226069eb22921169fc7e43f`
  (`linux/amd64`; verified index digest
  `sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1`)

`start-dev` and the embedded database are acceptable only for this
loopback-bound local POC. This is not a production deployment.

## Runtime secret preparation

The following procedure was **not run in this blocked execution**. Run it from
`task2/` before the first startup:

```sh
install -d -m 700 .runtime
openssl rand -base64 48 -out .runtime/keycloak-bootstrap-admin-password
chmod 600 .runtime/keycloak-bootstrap-admin-password
git check-ignore -v .runtime/keycloak-bootstrap-admin-password
```

The file is mounted as a Compose secret and read inside the Keycloak process;
do not print it, add it to `.env`, or copy it into evidence. The tracked realm
JSON intentionally omits the confidential `ops-dashboard` client secret so it
can exist only in runtime state. CP2 must verify Keycloak's generated credential
after import without printing it. `.env.example` contains only an optional
non-secret username placeholder.

## Stage A — pre-realm runtime

The commands in this section are the required continuation procedure and are
**not yet observed as successful**. First finish the verified image pull and
confirm the exact local platform:

```sh
docker compose --profile '*' pull
docker image inspect 'quay.io/keycloak/keycloak:26.7.4@sha256:3d911baa186f352563854039b95f21a7e2c01c76b527fdc64f24a0885b927bdf' \
  --format 'ID={{.Id}} OS={{.Os}} ARCH={{.Architecture}} DIGESTS={{json .RepoDigests}}'
docker compose --profile '*' config --quiet
```

Start only Stage A and the bounded diagnostic service:

```sh
docker compose --profile stage-a --profile diagnostic up -d \
  keycloak-stage-a diagnostic
```

Stage A has no import mount or `--import-realm`; the `ops` realm must not
exist. It publishes only `127.0.0.1:18082:18082`. The diagnostic service has no
published port or host mount, joins only `task2-iam-oidc`, and exits after ten
minutes unless removed earlier.

### CP1 checks

Keep inspection limited to these exact Task 2 names. Do not inventory Docker
globally or query Kubernetes.

```sh
docker compose --profile '*' config --services
docker compose --profile '*' config --networks
docker compose --profile '*' config --volumes
docker container inspect task2-iam-keycloak-stage-a-1 \
  --format 'name={{.Name}} project={{index .Config.Labels "com.docker.compose.project"}} service={{index .Config.Labels "com.docker.compose.service"}} ports={{json .HostConfig.PortBindings}} networks={{json .NetworkSettings.Networks}}'
docker network inspect task2-iam-oidc \
  --format 'name={{.Name}} project={{index .Labels "com.docker.compose.project"}} internal={{.Internal}}'
docker volume inspect task2-iam-keycloak-data \
  --format 'name={{.Name}} project={{index .Labels "com.docker.compose.project"}}'
docker compose --profile stage-a logs --no-color keycloak-stage-a
docker compose --profile stage-a exec keycloak-stage-a \
  bash -ec 'exec 3<>/dev/tcp/127.0.0.1/18082'
docker compose --profile diagnostic exec diagnostic nslookup auth.localhost
docker compose --profile diagnostic exec diagnostic \
  wget -S -O /dev/null http://auth.localhost:18082/
ss -ltn 'sport = :18082 or sport = :18083'
curl --max-time 10 --resolve auth.localhost:18082:127.0.0.1 \
  -o /dev/null -sS -w '%{http_code}\n' http://auth.localhost:18082/
```

The `--resolve` probe is an explicit routing override, not proof of ordinary
WSL DNS. CP1 also requires confirmation that port `18083` has no conflict and
that no separate management/admin port is published. The Keycloak admin UI
shares the loopback-only `18082` endpoint.

### Owner-assisted Windows and LAN checks

While Stage A is actively running:

1. In a Windows browser, open `http://auth.localhost:18082`; record browser,
   version, requested URL, and the actual Keycloak page or failure.
2. In PowerShell, run
   `Get-NetTCPConnection -LocalPort 18082 -State Listen` and record the local
   address.
3. Run `Resolve-DnsName auth.localhost` and record the result separately from
   browser behavior.
4. From a separate LAN device or an approved technically equivalent external
   vantage point, request `http://<WINDOWS_LAN_IP>:18082` with a short timeout.
   It must not connect. Redact sensitive addresses from public evidence.

A request from the Windows host to its own LAN address and a WSL `ss` result do
not replace the independent exposure test.

If owner evidence is pending, remove the diagnostic container and stop only
Stage A while preserving the volume:

```sh
docker compose --profile diagnostic rm -sf diagnostic
docker compose --profile stage-a stop keycloak-stage-a
```

Resume with the Stage A `up` command above and recheck container identity,
digest, readiness, binding, diagnostic connectivity, Windows reachability, and
external exposure. Historical results do not pass the resumed checkpoint.

## Stage A to Stage B

Do not continue until every CP1 requirement passes. Then perform and record the
actual narrow transition:

```sh
docker compose --profile stage-a stop keycloak-stage-a
ss -ltn 'sport = :18082'
docker compose --profile stage-b up -d keycloak-stage-b
docker compose --profile stage-b logs --no-color keycloak-stage-b
```

Verify the Stage A container is stopped, port `18082` was released before the
start, and exactly one active Task 2 Keycloak service now owns the host publish
and `auth.localhost` alias. Stage B reuses `task2-iam-keycloak-data` and adds
the read-only import file at `/opt/keycloak/data/import/ops-realm.json`.
Keycloak startup import skips an already existing realm; never delete the
volume or realm to force a re-import.

## CP2 — provider and realm verification

Start or recreate the bounded diagnostic service if necessary, then fetch the
provider metadata from both paths:

```sh
docker compose --profile diagnostic up -d diagnostic
docker compose --profile diagnostic exec diagnostic \
  wget -qO- http://auth.localhost:18082/realms/ops/.well-known/openid-configuration
curl --max-time 10 --resolve auth.localhost:18082:127.0.0.1 \
  http://auth.localhost:18082/realms/ops/.well-known/openid-configuration
docker compose --profile diagnostic exec diagnostic \
  wget -qO- http://auth.localhost:18082/realms/ops/protocol/openid-connect/certs
```

Require exact issuer equality with
`http://auth.localhost:18082/realms/ops`. Authorization, token, JWKS, and any
advertised end-session endpoint must use the same canonical host and port.
JWKS must contain usable public asymmetric signing-key metadata; never retain
private material.

Use the container's `kcadm.sh` with a temporary config under `/tmp` to inspect,
without printing credentials or client secrets:

- `ops-dashboard` is confidential, code flow is enabled, PKCE is `S256`, the
  redirect list is the one exact callback, and implicit/direct/service-account
  grants are disabled;
- `asset-inventory` and `runbook-portal` exist but are disabled;
- all six client roles, four groups, and explicit group-role mappings match
  `ops-realm.json`;
- `ops-dashboard-roles` is a default scope only on `ops-dashboard`;
- its User Client Role mapper has `Client ID=ops-dashboard`, claim
  `ops_roles`, String/multivalued, ID token enabled, and access token,
  UserInfo, lightweight token, and introspection disabled;
- Full Scope Allowed is false and the client scope maps only the two
  `ops-dashboard` roles.

Reach the realm login page with a valid authorization-code request containing
an exact redirect URI, high-entropy state and nonce, and an S256 code
challenge. A successful Flask callback is not expected in P1.

Configuration inspection is only **CONFIGURED** evidence. Actual emitted
`ops_roles` output remains **UNVERIFIED — MANDATORY P2 ENTRY TEST** until P2
completes a real interactive authorization-code flow.

## Cleanup, shutdown, and restart

Remove only the temporary diagnostic service after active testing:

```sh
docker compose --profile diagnostic rm -sf diagnostic
```

Stop the active Keycloak stage without deleting persistent data:

```sh
docker compose --profile stage-a --profile stage-b stop \
  keycloak-stage-a keycloak-stage-b
```

Do not use global prune commands and do not pass `--volumes`. The named volume
is intentionally preserved.

After CP2 otherwise passes, optional restart/idempotency verification stops
only Stage B, restarts the same Stage B service with its import configuration,
and rechecks realm/client/group/scope state plus discovery. Startup import must
skip the existing realm without duplicates or overwrite. Record PASS, FAILED,
or NOT VERIFIED.

## Current limitations and P2 handoff

Observed in this execution:

- digest resolution and Compose/JSON validation passed;
- the Alpine diagnostic image was pulled and inspected as `linux/amd64`;
- the Keycloak tag resolved correctly, but its final image layer did not
  complete after several bounded cached attempts;
- no Stage A resource was created, so listener, Docker DNS/HTTP, browser, LAN,
  CP1, Stage B, realm import, discovery, and CP2 are unverified;
- no runtime secret file was created.

P2 must not begin until CP1 and CP2 are completed. Its entry checks must also
observe a real ID token and prove the exact `ops_roles` array, correct viewer
and admin output, and absence of unrelated client-role leakage. P2 then owns
the Flask callback, validation, ten-minute application session, server-side
route RBAC, logout/CSRF behavior, and all negative tests retained in the test
plan.
