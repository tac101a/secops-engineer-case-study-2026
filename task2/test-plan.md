# Task 2 P1/P2 verification and acceptance plan

Every result records UTC time, command or manual procedure, expected and actual
result, and a redacted artifact. Secrets, authorization codes, cookies, and raw
tokens are never retained. `PASS` requires observed behavior; configuration
inspection alone is insufficient. `UNVERIFIED` is not a pass.

## P1 checkpoint 1 — Stage A runtime feasibility before realm provisioning

Stage A starts Keycloak without importing realm `ops`. CP1 requires no Flask
application, callback, ID token, or target realm.

| ID | Verification | Pass condition |
|---|---|---|
| R1 | Validate the rendered Compose model and inspect only the exact Task 2 service, network, and volume names plus their Compose ownership labels. | The model is project `task2-iam`, contains only the two mutually exclusive Keycloak stages and bounded diagnostic service, uses only `task2-iam-oidc` and `task2-iam-keycloak-data`, has no external network, and publishes only `127.0.0.1:18082:18082`. No command inventories or targets Task 1. |
| R2 | Query the Docker daemon, validate Compose, and start only Stage A. | Daemon and Compose respond; Stage A starts successfully. No Flask service or `ops` import is present. |
| R3 | Resolve and inspect both image manifests before use. | Explicit tags correspond to the selected versions; immutable index and `linux/amd64` manifest digests are recorded and the pulled local images match the host platform. |
| R4 | Observe Keycloak readiness and its real internal listener. | The process answers the intended HTTP path on internal `0.0.0.0:18082`; running-container state alone is insufficient. |
| R5 | From the bounded Task-2-owned diagnostic container, resolve and reach `auth.localhost:18082`. | The alias resolves to the active Stage A container and the HTTP request receives an actual Keycloak response. The diagnostic service joins only `task2-iam-oidc`, has no published port/host mount/socket/privilege, and is removed after active testing. |
| R6 | Test the WSL host path and record ordinary DNS separately from any `curl --resolve` override. | The loopback-published canonical Host value answers; the override, if used, is not reported as normal DNS success. The WSL listener observation is recorded but is not used as Windows or LAN evidence. |
| R7 | Use an actual Windows browser and inspect Windows listeners. | `http://auth.localhost:18082` loads a Keycloak page; browser/version, requested URL, actual behavior, and Windows listener address are recorded. |
| R8 | Attempt access from a separate LAN host or technically equivalent independent external vantage. | `http://<WINDOWS_LAN_IP>:18082` is not reachable within a bounded timeout. A request from the same Windows host to its own LAN IP is not sufficient. |
| R9 | Check the future Flask port without creating Flask. | Port `18083` has no detected WSL/Windows conflict where observable; it is not required to listen or answer. |
| R10 | Inspect the administration boundary. | The admin UI shares the intended loopback Keycloak endpoint and no separate management/admin port is published. |

General Internet egress denial, including an `internal: true` network, is
**OPTIONAL HARDENING** rather than an IAM/SSO acceptance condition. If attempted,
record it separately and prove that it does not break Docker DNS, Keycloak,
discovery, JWKS, or browser access.

Stop if any item fails. A WSL `ss` result cannot substitute for R7 or R8, and
P1 must not change firewall, WSL, Docker-daemon, DNS, or hosts-file settings to
manufacture a pass without a separately approved design revision.

If owner-assisted R7/R8 evidence is pending, stop only Stage A when active
testing ends, preserve `task2-iam-keycloak-data`, and record CP1 INCOMPLETE.
On resume, historical observations do not pass the current checkpoint; repeat
identity, digest, readiness, binding, diagnostic, Windows, and exposure checks.

### Mandatory Stage A to Stage B transition

Only after CP1 passes: identify and stop the exact Stage A service, prove port
`18082` is released and no active Stage A container owns `auth.localhost`,
preserve the named data volume, and start only Stage B. Verify Stage B uses the
same pinned image, network, alias, port, and volume, and that exactly one active
Keycloak service serves the path. Starting a Stage B profile does not
implicitly stop Stage A.

## P1 checkpoint 2 — Stage B actual OIDC provider after realm provisioning

| ID | Verification | Pass condition |
|---|---|---|
| O1 | Fetch discovery from the WSL/browser path and from the authorized Task-2-owned diagnostic container. | Both documents are reachable and equivalent for security-relevant metadata; `issuer` is exactly `http://auth.localhost:18082/realms/ops`. No Flask callback is required. |
| O2 | Inspect advertised authorization, token, JWKS, and end-session URLs. | Every advertised URL follows the fixed hostname strategy and is reachable by its intended caller; no internal-only hostname leaks. |
| O3 | Fetch and inspect `jwks_uri`. | At least one supported asymmetric signing key is usable; key IDs are unique; no symmetric or `none` acceptance is configured. |
| O4 | Inspect the `ops-dashboard` client and its intended scopes. | Exact callback only; code flow and PKCE S256 enabled; implicit/direct grants/service account disabled; client secret is runtime-only. |
| O5 | Inspect client scopes, the role mapper, groups, client roles, and group-to-role mappings for viewer, admin, and unrelated-role users. | The dedicated mapper is **CONFIGURED**, full scope is off, and only `ops-dashboard` roles are configured to feed `ops_roles`. Record this as configuration evidence, not observed token output. |
| O6 | Record the issued-token verification disposition. If a separate bounded OIDC test client is expressly included in P1, use an interactive authorization-code flow and validate redacted ID-token evidence; otherwise defer this check to P2. | Either validated evidence shows viewer `["viewer"]`, admin exactly `viewer` and `admin`, and no unrelated role leakage, or actual output is explicitly **UNVERIFIED** with a mandatory P2 entry check. A configured mapper alone never passes token-output verification, and direct-access password grants remain disabled. |
| O7 | Construct a valid authorization-code request for `ops-dashboard`. | The realm login page is reachable with the exact redirect and PKCE S256 request. No Flask callback or end-to-end application SSO is claimed. |

P1 checkpoint 2 accepts O1–O5 plus an explicit O6 disposition and O7; it does
not depend on a completed Flask callback. If O6 is deferred, P2 must complete a
real authorization-code flow and validate an issued ID token before the RBAC
integration can be accepted.

## P2 mandatory POC acceptance tests

| ID | Scenario | Required result |
|---|---|---|
| A1 | Unauthenticated request to dashboard/admin view. | No protected content; safe redirect to login or `401`. |
| A2 | Viewer completes code flow. | Valid state/nonce/PKCE and ID-token checks create a ten-minute app session; dashboard `200`, admin `403`. |
| A3 | Admin completes code flow. | Dashboard and read-only admin view return `200`. |
| A4 | User with only another application's role logs in. | Authentication may succeed, but both protected Ops views return `403`; unrelated role never enters `ops_roles`. |
| A5 | Missing, scalar, mixed-type, duplicate, unknown-only, or oversized `ops_roles`. | Callback fails closed or normalizes only the exact safe subset according to the architecture; malformed structure creates no authorized session. |
| A6 | Tampered signature; unknown `kid`; `alg=none`; wrong issuer; missing/wrong/empty `aud`; an `aud` array with any value other than exactly one `ops-dashboard` entry; multiple audiences; a present wrong `azp`; expired/future token; nonce mismatch. Also exercise the protocol-valid single-audience string and singleton-array forms. | The exact string and singleton-array forms are accepted only when every other validation succeeds; every negative case is rejected before session creation. Unknown `kid` permits only one bounded JWKS refresh. |
| A7 | Missing/mismatched/replayed state, code, nonce, or PKCE verifier. | Callback rejects; no partial identity or session remains. |
| A8 | Inspect the Flask cookie after successful login. | It contains only the documented minimal fields; signature and age are enforced; no raw token, code, secret, password, or arbitrary claim exists. |
| A9 | Tamper with the cookie and wait beyond 600 seconds without activity. | Tampered cookie is rejected; expired cookie no longer authorizes. Requests do not slide the absolute expiry. |
| A10 | Remove viewer/admin group membership while the app session is active. | Documented stale access lasts no longer than the remaining app-session lifetime; after expiry or local logout and fresh login, removed permission is denied. Do not claim immediate revocation. |
| A11 | `GET /logout`, CSRF-free POST, bad token, and cross-origin POST. | GET is `404/405`; every invalid POST is rejected. Valid same-origin CSRF-protected POST clears only the Flask session. |
| A12 | Valid local logout followed by login. | App cookie is gone, but Keycloak may silently SSO the user again. Evidence labels this local logout, not global logout. |
| A13 | Stop Keycloak, rotate signing key, and restore it. | New login fails closed during outage; an unseen valid `kid` works only after bounded JWKS refresh; no unverified fallback occurs. |
| A14 | Probe `0.0.0.0`, WSL addresses, Windows interfaces, and a second LAN host while POC runs. | Only intended loopback browser endpoints are reachable; container listeners are not confused with host exposure. |
| A15 | Review logs and tracked files after all tests. | No secret, code, raw token, cookie, password, or unredacted sensitive payload appears. |

## Later production-validation items

TLS and `Secure` cookies, external database recovery, Keycloak upgrades/HA,
server-side revocation, RP-initiated and back-channel logout, MFA/admin
hardening, audit export, rate limiting, dependency scanning, and multi-app SSO
remain future work. They are not POC acceptance claims.
