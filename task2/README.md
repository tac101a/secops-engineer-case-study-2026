# Task 2 — IAM/SSO proof of concept

Status: **P1 provider verified; P2 authorized under the documented R8
exception.** The original CP1 contract remains incomplete because no
independent LAN vantage was available. All other CP1 checks passed, the
owner-authorized single-host exception gate passed, and actual Stage B import
plus CP2 O1–O7 passed. Independent LAN isolation and actual emitted
`ops_roles` output remain unverified; the latter is a mandatory P2 entry test.

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

This continuation created the ignored runtime credential without printing it.
When the file is absent on a fresh environment, run this from `task2/`:

```sh
install -d -m 700 .runtime
openssl rand -base64 -out .runtime/keycloak-bootstrap-admin-password 48
chmod 600 .runtime/keycloak-bootstrap-admin-password
git check-ignore -v .runtime/keycloak-bootstrap-admin-password
```

Do not overwrite an existing credential blindly. Reconcile its provenance,
ownership, and mode first. This host observed directory mode `0700`, file mode
`0600`, and host UID/GID `1000:1000`; the exact Keycloak image is configured as
UID `1000` and a networkless read-only probe proved that user could read the
mounted file without exposing its value. Repeat the access proof when host or
container ownership semantics differ rather than assuming mode `0600` alone is
sufficient.

The file is mounted as a Compose secret and read inside the Keycloak process;
do not print it, add it to `.env`, or copy it into evidence. The tracked realm
JSON intentionally omits the confidential `ops-dashboard` client secret so it
can exist only in runtime state. CP2 must verify Keycloak's generated credential
after import without printing it. `.env.example` contains only an optional
non-secret username placeholder.

## Stage A — pre-realm runtime

The exact pinned image and Stage A were observed successfully in both P1
runtime continuations. In the latest continuation, realm `ops` still returned
HTTP `404` before the controlled Stage A to Stage B transition. Both Keycloak
containers are now stopped, and the retained named volume contains the
verified provisioned `ops` realm. Before a later restart, revalidate the exact
image, resource identities, volume disposition, and current host state:

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

### Owner-authorized single-host R8 exception

The original R8 test above is preserved and remains outstanding. For the
2026-09-24 continuation only, the owner explicitly authorized proceeding when
no genuinely independent endpoint was available, provided R1–R7, R9, R10, and
all useful host-local exposure checks passed and no unintended exposure was
observed. The resulting dispositions are intentionally different:

```text
CP1 ORIGINAL CONTRACT:
INCOMPLETE — R8 INDEPENDENT LAN TEST DEFERRED

CP1 SINGLE-HOST EXCEPTION GATE:
PASS

R8:
DEFERRED UNDER EXPLICIT OWNER AUTHORIZATION
```

Windows listened only on `127.0.0.1:18082`; the Windows host's active
non-loopback addresses and WSL non-loopback interfaces did not accept port
`18082`. These are host-local observations, not proof that every LAN device is
unable to reach the service. A future independent LAN test must still execute
R8 without changing firewall, Docker, WSL, DNS, or host networking merely to
obtain a result.

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

Continue only after the original CP1 contract passes or the documented
single-host exception gate passes. Then perform and record the actual narrow
transition:

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

The verified Keycloak 26.7.4 procedure uses its documented `KC_CLI_PASSWORD`
environment variable. Run the following shell body inside the intended active
Keycloak container. The password is read from the mounted secret inside the
container, never supplied as a command argument or Docker exec environment
argument. The configuration contains tokens and must remain mode `0600` and be
removed on success, failure, or interruption:

```sh
set +x
set -euo pipefail
umask 077
cfg_dir="$(mktemp -d /tmp/task2-p1-kcadm.XXXXXX)"
cfg_file="$cfg_dir/kcadm.config"
cleanup() {
  rc=$?
  trap - EXIT HUP INT TERM
  unset KC_CLI_PASSWORD
  rm -f -- "$cfg_file"
  rmdir -- "$cfg_dir"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
export KC_CLI_PASSWORD="$(< /run/secrets/keycloak_bootstrap_admin_password)"
/opt/keycloak/bin/kcadm.sh config credentials \
  --config "$cfg_file" \
  --server http://auth.localhost:18082 \
  --realm master \
  --user "$KC_BOOTSTRAP_ADMIN_USERNAME"
unset KC_CLI_PASSWORD
test "$(stat -c %a "$cfg_file")" = 600
/opt/keycloak/bin/kcadm.sh get realms/master \
  --config "$cfg_file" >/dev/null
```

Use field-filtered Admin REST reads and never print the client-secret endpoint,
raw CLI config, access token, or refresh token. The latest execution verified
authentication, a read-only master-realm GET, and cleanup using this pattern.

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

- both immutable images were re-inspected as `linux/amd64`; the Keycloak image
  ID equals the pinned platform digest and its configured user is UID `1000`;
- Stage A passed current Docker, internal HTTP, diagnostic DNS/HTTP, WSL,
  Windows Chrome, listener, port `18083`, and administration-boundary checks;
- Windows Chrome `153.0.8010.53` rendered the Keycloak landing page, and all
  tested Windows/WSL non-loopback host addresses rejected port `18082`;
- independent R8 is **DEFERRED** under the explicit owner authorization, the
  original CP1 contract remains **INCOMPLETE**, and the single-host exception
  gate is **PASS**;
- Stage B imported realm `ops`, and live inspection verified the confidential
  client, runtime credential presence, PKCE S256, exact callback, disabled
  grants, six roles, four groups, group mappings, mapper, and exact live
  `ops-dashboard:viewer,admin` role-scope mapping;
- the first import exposed a reproducible missing-`profile`-scope defect: the
  import warned that `profile` did not exist and a valid `openid profile`
  request returned `invalid_scope`. The allowlisted source now includes the
  exact Keycloak 26.7.4 standard scope. The same scope was created in the known
  runtime realm and attached through the dedicated Admin REST endpoint; source,
  master-realm reference, and runtime representations matched, after which the
  Windows authorization request rendered `Sign in to SecOps Operations`;
- a same-volume Stage B restart skipped the existing realm as expected and
  preserved discovery, clients, roles, groups, scopes, mappers, and mappings
  without duplication. The updated source's `profile` object was not exercised
  by a destructive fresh-volume import because resetting the retained volume
  was prohibited; current runtime/source parity was verified instead;
- CP2 O1–O7 and restart/idempotency are **PASS**. Actual emitted `ops_roles`
  output is **UNVERIFIED — MANDATORY P2 ENTRY TEST**; and
- cleanup removed the diagnostic container and temporary browser/Admin CLI
  state. Stage A and Stage B are stopped, the provisioned
  `task2-iam-keycloak-data` volume and ignored bootstrap credential are retained,
  and ports `18082`/`18083` have no final WSL or Windows listener.

P2 is **AUTHORIZED UNDER THE DOCUMENTED R8 EXCEPTION**. Its first integration
test must complete a real authorization-code flow and prove viewer
`["viewer"]`, admin exactly `viewer` plus `admin`, multivalued-array shape, and
absence of unrelated client-role leakage before the application trusts
`ops_roles`. P2 then owns the Flask callback, complete ID-token validation,
ten-minute application session, server-side RBAC, logout/CSRF behavior, and all
negative tests retained in the test plan. Independent LAN isolation remains
unverified and R8 must be completed when a separate authorized vantage becomes
available.
