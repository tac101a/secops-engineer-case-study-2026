# SecOps Engineer Case Study 2026

Repository này trình bày hai phần thực hành:

- **Task 1 — Kubernetes workload security:** triển khai một ứng dụng mẫu có chủ
  đích chưa an toàn, xác nhận ba finding, xây dựng control khắc phục và kiểm tra
  phòng ngừa bằng verifier/CI/admission-policy POC.
- **Task 2 — IAM/SSO:** thiết kế mô hình IAM tập trung và dựng Keycloak làm OIDC
  provider cho `ops-dashboard`.

> Đây là lab cục bộ phục vụ đánh giá kỹ thuật, không phải cấu hình production.
> README này luôn phân biệt rõ kết quả runtime đã quan sát, kiểm tra tĩnh và phần
> còn chưa được xác minh.

## Trạng thái hiện tại

| Hạng mục | Trạng thái có thể khẳng định |
|---|---|
| Task 1 baseline | Chạy và kiểm tra chức năng thành công trong môi trường kind đã ghi nhận |
| Task 1 F1 | Finding được xác nhận; candidate hardening đã vượt qua runtime smoke test lịch sử |
| Task 1 F2 | Finding được xác nhận; candidate loại bỏ token/RBAC đã vượt qua runtime smoke test lịch sử |
| Task 1 F3 | Finding được xác nhận; YAML NetworkPolicy hợp lệ về mặt tĩnh nhưng **runtime enforcement chưa được xác minh** |
| Task 1 full AFTER | **BLOCKED** cho đến khi F3, integration và cùng bộ runtime oracle đều đạt |
| Task 2 P1/CP2 | Keycloak provider, realm và client configuration đã được xác minh dưới single-host exception đã ghi nhận |
| Task 2 P2 | **Chưa triển khai** Flask callback, token validation, session, RBAC, logout và end-to-end SSO |

Các finding Task 1 được chốt là:

- **F1 — Medium:** `demo-api` có local authority quá mức và ghi được vào `/app`
  dù ứng dụng chỉ cần ghi `/tmp/demo-cache.json`.
- **F2 — Medium:** `demo-api` có token và quyền `get`/`patch` không cần thiết trên
  một ConfigMap được chỉ định.
- **F3 — Low:** tồn tại một số đường east-west Service ngoài communication budget.

## Lộ trình demo khuyến nghị cho người chấm

1. Chạy verifier offline của Task 1 để xem nhanh before/after và trạng thái từng
   control.
2. Nếu có Docker + kind, chạy baseline Task 1 và live demo F1.
3. Đọc manifest bundle để đối chiếu đầy đủ before/after của F1–F3.
4. Chạy Task 2 P1 để xem Keycloak discovery, realm `ops`, client OIDC và trang
   đăng nhập.
5. Dừng đúng các resource của từng task theo phần cleanup; không dùng lệnh prune
   toàn cục.

---

## Task 1 — Kubernetes workload security

### Kiến trúc demo

```text
máy người chấm
  └─ kubectl port-forward 127.0.0.1:18080
       └─ demo-api:8080
            └─ demo-backend:8081
```

Hai workload chạy trong namespace `secops-demo` trên cluster kind một node tên
`secops-lab`. Ứng dụng chỉ dùng dữ liệu tổng hợp, không cần Internet, database,
Secret hay persistent volume khi chạy.

### Yêu cầu môi trường

- Linux hoặc WSL2 với Docker daemon đang hoạt động.
- Bash, `curl`, Python 3, Git và GNU Make.
- kind **v0.31.0** và kubectl **v1.35.0**. Script ưu tiên binary trong
  `.local/bin/` trước `PATH`.
- PyYAML cho verifier offline. Nếu thiếu, verifier sẽ trả về `BLOCKED` thay vì
  tự cài dependency.
- Cluster dùng node image Kubernetes **v1.34.3** đã pin trong `task1/kind.yaml`.

Kubeconfig được tạo tại `.local/kubeconfig`; mọi script đều khóa vào context
`kind-secops-lab` và namespace `secops-demo`. Nếu đã có cluster cùng tên nhưng
không có ownership record của checkout hiện tại, script sẽ từ chối sử dụng hoặc
xóa cluster đó.

### Demo nhanh, không cần cluster: verifier offline

Chạy từ root repository:

```sh
bash task1/scripts/verify.sh --offline hardened
bash task1/scripts/test-verify-offline.sh
```

Kết quả mong đợi:

- `F1 STATIC`, `F2 STATIC`, `F3 STATIC`: `PASS`;
- `F3 ENFORCEMENT`: `BLOCKED / NOT VERIFIED`;
- `CURRENT RUNTIME VERIFICATION`: `NOT RUN`;
- `FULL AFTER RESULT`: `BLOCKED`;
- verifier self-test: `24 passed`, `0 failed`, và runtime guard không phát hiện
  lệnh Docker/Kubernetes ngoài ý muốn.

`STATIC PASS` chỉ chứng minh source manifest khớp control đã review; nó không
chứng minh trạng thái cluster hoặc NetworkPolicy dataplane.

### Demo live baseline

Từ root repository:

```sh
make task1-cluster-up
make task1-build
make task1-baseline
make task1-check
```

`make task1-check` mở hai port-forward loopback tạm thời, kiểm tra health và data,
sau đó tự đóng chúng. Kết quả dữ liệu mong đợi:

```json
{"source":"demo-backend","value":"representative-data"}
```

Hai health endpoint phải trả về:

```json
{"status":"ok"}
```

Nếu `18080` hoặc `18081` đang được dùng, chọn hai cổng khác nhau trong khoảng
1024–65535:

```sh
API_PORT=28080 BACKEND_PORT=28081 make task1-check
```

### Demo live control F1

Sau khi baseline ở trên đã `PASS`, tiếp tục:

```sh
./task1/hardened/scripts/build-f1.sh
./task1/hardened/scripts/deploy-f1.sh
make task1-check
./task1/hardened/scripts/smoke-f1.sh
```

Smoke test kiểm tra trực tiếp các thuộc tính chính:

- PID 1 chạy với UID/GID `65534:65534`;
- toàn bộ Linux capability set bằng `0` và `NoNewPrivs=1`;
- root filesystem và `/app` là read-only;
- `/tmp` vẫn ghi được và ứng dụng vẫn cập nhật cache;
- thử ghi vô hại vào `/app` bị từ chối;
- luồng API → backend vẫn trả đúng dữ liệu.

Đây là **F1 candidate runtime test**, không phải bằng chứng full AFTER.

### Review F2/F3 và before/after

Không chạy `deploy-f2.sh` hoặc `deploy-f3.sh` như một quickstart chung. Các script
này có safety gate gắn với pre-state/evidence lịch sử cụ thể; F3 còn có blocker
dataplane chưa giải quyết. Người chấm có thể review an toàn qua:

- [manifest bundle before/after](deliverables/task1/README.md);
- [before.yaml](deliverables/task1/before.yaml);
- [after.yaml](deliverables/task1/after.yaml);
- [báo cáo finding](docs/phase-c-report.md);
- [F1 runtime report](docs/phase-d-d1-report.md);
- [F2 runtime report](docs/phase-d-d2-report.md);
- [F3 blocker report](docs/phase-d-d3-report.md);
- [offline verification report](docs/phase-e-e1-verification.md);
- [CI prevention report](docs/phase-f1-offline-ci.md);
- [Kyverno policy POC](docs/phase-f2-admission-policy-poc.md).

`after.yaml` là **target-state bundle cho môi trường sạch**, không phải bằng chứng
đã deploy thành công. Không tự động apply bundle này vào cluster đang có sẵn:
việc bỏ một Role/RoleBinding/ConfigMap khỏi YAML không tự xóa object cũ, Pod cũ
có thể vẫn giữ projected token, và hai NetworkPolicy chưa có runtime acceptance.

### Cleanup Task 1

```sh
make task1-clean
```

Lệnh chỉ xóa cluster `secops-lab` khi ownership record khớp checkout hiện tại;
nó không xóa Docker image hay tool đã tải vào `.local/bin`.

---

## Task 2 — IAM/SSO với Keycloak

### Phạm vi demo thực tế

Task 2 hiện demo **OIDC provider P1**, gồm:

- Keycloak **26.7.4** với realm `ops`;
- confidential client `ops-dashboard`;
- Authorization Code Flow và PKCE `S256`;
- callback chính xác `http://ops.localhost:18083/oidc/callback`;
- client roles, groups, group-role mappings và mapper `ops_roles`;
- hai client thiết kế mở rộng `asset-inventory` và `runbook-portal`, nhưng đang
  disabled.

Repository **không có ứng dụng Ops Dashboard đang chạy**, không tạo listener ở
port `18083`, không seed user/password demo, và chưa chứng minh claim `ops_roles`
thực tế trong ID token. Trang login chỉ chứng minh authorization endpoint hoạt
động; callback/end-to-end SSO thuộc P2 và chưa triển khai.

Sơ đồ hiện trạng: [Mermaid source](docs/figures/task2-iam-architecture.mmd) ·
[SVG dùng để nộp](deliverables/task2/task2-iam-architecture.svg).

### Yêu cầu môi trường

- Docker Engine và Docker Compose có hỗ trợ Compose profiles/secrets.
- Host `linux/amd64`; Compose pin image theo đúng platform và digest.
- `openssl`, `curl`, Python 3 và trình duyệt trên máy local.
- Port `18082` phải trống. Port `18083` phải không có listener vì ứng dụng P2
  chưa tồn tại.

Keycloak dùng `start-dev`, HTTP và database nhúng trong volume cục bộ. Cấu hình
này chỉ phù hợp POC loopback, không phù hợp production.

### 1. Tạo runtime credential

Từ root repository:

```sh
cd task2
install -d -m 700 .runtime
openssl rand -base64 -out .runtime/keycloak-bootstrap-admin-password 48
chmod 600 .runtime/keycloak-bootstrap-admin-password
git check-ignore -v .runtime/keycloak-bootstrap-admin-password
```

Không ghi đè file đã tồn tại nếu chưa xác minh provenance/quyền sở hữu. Không
in credential, đưa nó vào `.env`, evidence hoặc commit. Nếu cần đổi username
bootstrap, copy `.env.example` thành `.env` và chỉ thay username không nhạy cảm.

### 2. Validate Compose và tải image đã pin

```sh
docker compose --profile '*' config --quiet
docker compose --profile '*' pull
```

Nếu volume `task2-iam-keycloak-data` đã tồn tại từ lần chạy trước, không xóa hoặc
reset để ép import lại. Hãy đọc [hướng dẫn Task 2 chi tiết](task2/README.md) và
xác minh trạng thái volume trước khi tiếp tục. Luồng dưới đây dành cho môi trường
mới hoặc volume có provenance tin cậy.

### 3. Stage A — kiểm tra provider trước khi import realm

```sh
docker compose --profile stage-a --profile diagnostic up -d \
  keycloak-stage-a diagnostic
docker compose --profile stage-a logs --no-color --tail=100 keycloak-stage-a
```

Chờ log cho biết Keycloak đã start, rồi kiểm tra endpoint loopback và xác nhận
realm `ops` chưa tồn tại:

```sh
curl --max-time 10 --resolve auth.localhost:18082:127.0.0.1 \
  -o /dev/null -sS -w 'Keycloak HTTP %{http_code}\n' \
  http://auth.localhost:18082/

curl --max-time 10 --resolve auth.localhost:18082:127.0.0.1 \
  -o /dev/null -sS -w 'realm ops trước import: HTTP %{http_code}\n' \
  http://auth.localhost:18082/realms/ops
```

Endpoint đầu phải trả phản hồi HTTP của Keycloak; realm `ops` phải trả `404` ở
Stage A. Chỉ port `127.0.0.1:18082` được publish.

### 4. Chuyển sang Stage B và import realm

Không chạy Stage A và Stage B đồng thời:

```sh
docker compose --profile stage-a stop keycloak-stage-a
docker compose --profile stage-b up -d keycloak-stage-b
docker compose --profile stage-b logs --no-color --tail=120 keycloak-stage-b
```

Chờ Keycloak start, sau đó kiểm tra discovery document:

```sh
curl --fail --silent --show-error --max-time 10 \
  --resolve auth.localhost:18082:127.0.0.1 \
  http://auth.localhost:18082/realms/ops/.well-known/openid-configuration \
  | python3 -c '
import json, sys
d = json.load(sys.stdin)
expected = "http://auth.localhost:18082/realms/ops"
assert d["issuer"] == expected
assert d["authorization_endpoint"].startswith(expected + "/")
assert d["token_endpoint"].startswith(expected + "/")
assert d["jwks_uri"].startswith(expected + "/")
print("OIDC discovery PASS; issuer=" + d["issuer"])
'
```

Kiểm tra cùng endpoint từ diagnostic container trong network riêng:

```sh
docker compose --profile diagnostic exec diagnostic \
  wget -qO- \
  http://auth.localhost:18082/realms/ops/.well-known/openid-configuration \
  >/dev/null && echo 'Container-side discovery PASS'
```

### 5. Mở trang đăng nhập OIDC

Lệnh sau tạo authorization URL có state, nonce và PKCE challenge mới rồi in URL
để mở bằng trình duyệt local:

```sh
python3 - <<'PY'
import base64
import hashlib
import secrets
import urllib.parse

issuer = "http://auth.localhost:18082/realms/ops"
verifier = secrets.token_urlsafe(64)
challenge = base64.urlsafe_b64encode(
    hashlib.sha256(verifier.encode()).digest()
).rstrip(b"=").decode()
query = urllib.parse.urlencode({
    "client_id": "ops-dashboard",
    "redirect_uri": "http://ops.localhost:18083/oidc/callback",
    "response_type": "code",
    "scope": "openid profile",
    "state": secrets.token_urlsafe(32),
    "nonce": secrets.token_urlsafe(32),
    "code_challenge": challenge,
    "code_challenge_method": "S256",
})
print(f"{issuer}/protocol/openid-connect/auth?{query}")
PY
```

Kết quả mong đợi là trang login của realm `ops`. Không có tài khoản demo được
seed và không có ứng dụng nhận callback ở `18083`; không diễn giải bước này là
end-to-end SSO hoặc emitted-claim verification.

### Cleanup Task 2

Xóa diagnostic container và dừng đúng hai Keycloak service, nhưng giữ volume:

```sh
docker compose --profile diagnostic rm -sf diagnostic
docker compose --profile stage-a --profile stage-b stop \
  keycloak-stage-a keycloak-stage-b
cd ..
```

Không dùng `docker system prune`, không dùng global prune và không thêm
`--volumes`. Volume `task2-iam-keycloak-data` chứa realm đã provision và được
giữ lại có chủ đích.

Tài liệu sâu hơn:

- [Task 2 README](task2/README.md)
- [kiến trúc và lựa chọn công cụ](task2/architecture.md)
- [threat model](task2/threat-model.md)
- [test plan P1/P2](task2/test-plan.md)
- [runtime evidence P1](docs/evidence/task2/t2-p1-execution.txt)

---

## Artifact chính để review

- [Claim–evidence matrix](docs/submission/claim-evidence-matrix.md)
- [Brief cho PDF năm trang](docs/submission/pdf-5-page-brief.md)
- [Task 1 before/after manifest bundle](deliverables/task1/README.md)
- [Task 2 IAM architecture SVG](deliverables/task2/task2-iam-architecture.svg)

## Giới hạn cần giữ nguyên khi trình bày

- Không nói Task 1 đã “fully remediated”: F3 runtime enforcement và full AFTER
  vẫn bị chặn.
- Không nói Kyverno đang enforce live: policy POC hiện ở `Audit` và chỉ có kết
  quả test offline.
- Không nói corrected CI workflow đã là required gate: hosted run sau patch và
  branch protection chưa được xác minh.
- Không nói Task 2 đã hoàn tất end-to-end SSO: P2 chưa được triển khai.
- Không nói port loopback chứng minh LAN isolation: independent R8 vẫn deferred.
- Không dùng cấu hình local POC này làm mẫu production nếu chưa bổ sung TLS,
  external database/recovery, HA, MFA/admin hardening, monitoring/audit, rate
  limiting, rotation/revocation và quy trình upgrade.
