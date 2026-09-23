# Task 2 P1/P2 verification and acceptance plan

Every result records UTC time, command or manual procedure, expected and actual
result, and a redacted artifact. Secrets, authorization codes, cookies, and raw
tokens are never retained. `PASS` requires observed behavior; configuration
inspection alone is insufficient. `UNVERIFIED` is not a pass.

## P1 checkpoint 1 — runtime feasibility before realm provisioning

| ID | Verification | Pass condition |
|---|---|---|
| R1 | Record Task 1 container, network, and volume identities before and after P1 setup. | No Task 1 object is changed, stopped, recreated, attached, or removed. Task 2 names are under the `task2-iam` project only. |
| R2 | Query Docker daemon and validate/render the P1 Compose model. | Daemon responds; model contains only intended services, the dedicated network/volume, and explicit loopback publishes. |
| R3 | Resolve and inspect image manifests. | Tags correspond to selected versions; immutable digests and the actual architecture are recorded before execution. |
| R4 | Start the minimal services without a realm and inspect Docker networks/DNS from the containers. | Both services join only the Task 2 network; `auth.localhost` resolves to Keycloak there; intended container ports answer; unrelated external destinations are unreachable if the network is configured internal. |
| R5 | Inspect WSL sockets and reach both services from WSL. | Actual host listeners for `18082/18083` are loopback only; HTTP probes succeed using canonical Host values. This proves WSL reachability only. |
| R6 | Test from the Windows browser and inspect Windows listeners/reservations. | Both canonical `.localhost` URLs load and Windows shows no non-loopback bind. Record browser/version and exact address. |
| R7 | Attempt access from a second LAN host or equivalent Windows-side interface test. | Neither published port is reachable through a LAN, Wi-Fi, VPN, or other non-loopback address. |
| R8 | Inspect Keycloak administration reachability. | Admin UI is available through the intended local Keycloak URL only; no separate admin/management port is published. |

Stop if any item fails. A WSL `ss` result cannot substitute for R6 or R7, and
P1 must not change firewall, WSL, Docker-daemon, DNS, or hosts-file settings to
manufacture a pass without a separately approved design revision.

## P1 checkpoint 2 — actual OIDC contract after minimal realm provisioning

| ID | Verification | Pass condition |
|---|---|---|
| O1 | Fetch discovery from WSL/browser path and from the Flask container. | Both documents are reachable and byte-equivalent for security-relevant metadata; `issuer` is exactly `http://auth.localhost:18082/realms/ops`. |
| O2 | Inspect advertised authorization, token, JWKS, and end-session URLs. | Every advertised URL follows the fixed hostname strategy and is reachable by its intended caller; no internal-only hostname leaks. |
| O3 | Fetch and inspect `jwks_uri`. | At least one supported asymmetric signing key is usable; key IDs are unique; no symmetric or `none` acceptance is configured. |
| O4 | Inspect the `ops-dashboard` client. | Exact callback only; code flow and PKCE S256 enabled; implicit/direct grants/service account disabled; client secret is runtime-only. |
| O5 | Evaluate client scopes for viewer, admin, and unrelated-role users. | Effective scope includes the dedicated mapper; full scope is off; only `ops-dashboard` roles can feed `ops_roles`. |
| O6 | Issue test ID tokens and decode redacted payloads only after validation. | Viewer gets `["viewer"]`; admin gets exactly `viewer` and `admin`; unrelated-only user has no `ops_roles`; claim is an array. Mapper output is proven on Keycloak `26.7.4`. |

The Flask callback must not be implemented until O1–O6 pass.

## P2 mandatory POC acceptance tests

| ID | Scenario | Required result |
|---|---|---|
| A1 | Unauthenticated request to dashboard/admin view. | No protected content; safe redirect to login or `401`. |
| A2 | Viewer completes code flow. | Valid state/nonce/PKCE and ID-token checks create a ten-minute app session; dashboard `200`, admin `403`. |
| A3 | Admin completes code flow. | Dashboard and read-only admin view return `200`. |
| A4 | User with only another application's role logs in. | Authentication may succeed, but both protected Ops views return `403`; unrelated role never enters `ops_roles`. |
| A5 | Missing, scalar, mixed-type, duplicate, unknown-only, or oversized `ops_roles`. | Callback fails closed or normalizes only the exact safe subset according to the architecture; malformed structure creates no authorized session. |
| A6 | Tampered signature; unknown `kid`; `alg=none`; wrong issuer; wrong/multiple audience; wrong `azp`; expired/future token; nonce mismatch. | Every case is rejected before session creation. Unknown `kid` permits only one bounded JWKS refresh. |
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
