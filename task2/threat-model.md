# Task 2 P0 threat model

## Assets, actors, and boundaries

Assets are Keycloak credentials and signing keys, the Ops Dashboard client
secret, Flask signing secret, validated identity/roles, application sessions,
and Keycloak realm data. Actors are an unauthenticated browser user, an
authenticated viewer, an authenticated admin, a malicious local process or LAN
host, and the POC operator.

Trust crosses four boundaries: browser to loopback-published services; Flask to
Keycloak over the isolated Compose network; untrusted OIDC messages into the
callback; and a validated ID token into a signed Flask session. Keycloak is the
identity and group/role authority. Flask is the enforcement point. Docker and
the Windows/WSL boundary are infrastructure, not implicit security controls.

## Priority threats and controls

| Threat | POC control | Residual risk / production follow-up |
|---|---|---|
| Forged token or role injection | Validate ID-token signature, issuer, audience/authorized party, time claims, nonce, and exact `ops_roles` schema; ignore all browser-supplied authorization data and other role claims. | P1/P2 must prove Authlib and the Keycloak mapper behavior with negative tokens. Pin algorithms and dependencies. |
| Authorization-code interception, login CSRF, or callback replay | Exact redirect URI, confidential client, state, nonce, PKCE S256, one-time callback processing, and session rotation. | Local HTTP permits local-machine observation; production requires HTTPS. |
| Cross-client privilege leakage | Dedicated client roles and mapper with `Client ID=ops-dashboard`; full scope off; allow-list `viewer`/`admin`; unrelated roles ignored. | Realm administrators can still misconfigure mappers; add configuration review and drift tests. |
| Stolen or tampered Flask cookie | High-entropy signing secret, signature/age validation, HttpOnly, SameSite, host-only scope, ten-minute absolute lifetime, no raw tokens or secrets. | Local HTTP prevents `Secure`; XSS or local malware can act as the user. Production uses HTTPS, `Secure`, CSP, and secret rotation. |
| Stale authorization after role removal or user disable | Short session and role revalidation on the next OIDC login. Documentation makes the delay explicit. | No immediate revocation in the POC. Production needs server-side sessions and a tested revocation/logout signal. |
| Logout CSRF or unsafe state-changing route | Logout is POST only with session-bound CSRF token and origin check; future mutations use the same pattern and server-side role checks. | Local logout does not end the Keycloak SSO session. Global logout is out of scope until implemented and tested. |
| Accidental LAN or admin-console exposure | Explicit `127.0.0.1` publishes only; no management port; mandatory Windows, WSL, container, and external-exposure tests. | Docker/WSL networking can differ by installation. P0 has no Windows-side evidence. |
| Lateral movement or Task 1 impact | Unique Compose project, dedicated bridge/network/volume names, no Task 1 attachment or cleanup, least inter-service connectivity. | A compromised Docker daemon is outside this POC boundary and controls all local containers. |
| Secret disclosure | Runtime-only secrets, ignored files, no token/secret logging, no secrets in images, repo, URLs, or client-side session. | Developer endpoints, shell history, and crash output still require care; use managed secrets in production. |
| IdP outage or compromise | Fail closed for new login and token validation; existing signed sessions last no more than ten minutes. | Keycloak is a high-value single point of failure. Production needs HA, database backup, monitoring, MFA for admins, and break-glass governance. |
| Vulnerable or mutable dependency | Exact versions, image digests resolved before use, lock/hashes for Python dependencies, vulnerability and license scanning in later phases. | P0 verifies release provenance, not artifact integrity or vulnerability status. Re-scan at build time. |

## Out of scope for the local POC

The POC is not a production IAM service. It does not establish enterprise MFA,
identity lifecycle automation, immediate session revocation, Keycloak HA,
database durability, TLS, centralized audit retention, a privileged-access
workflow, or cross-application single logout. Those omissions must not be
described as implemented controls in the final report.

