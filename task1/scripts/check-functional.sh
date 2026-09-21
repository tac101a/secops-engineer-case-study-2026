#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cluster
require_tools curl python3
k rollout status deployment/demo-backend --timeout=180s
k rollout status deployment/demo-api --timeout=180s
k get pods -o wide

API_PORT="${API_PORT:-18080}"
BACKEND_PORT="${BACKEND_PORT:-18081}"
python3 - "$API_PORT" "$BACKEND_PORT" <<'PY'
import sys
ports = [int(value) for value in sys.argv[1:]]
if len(set(ports)) != 2 or any(not 1024 <= port <= 65535 for port in ports):
    raise SystemExit("API_PORT and BACKEND_PORT must be distinct ports from 1024 to 65535")
PY

TEMP_DIR="$(mktemp -d "$REPO_ROOT/.local/functional.XXXXXX")"
forward_pids=()
cleanup() {
  local pid
  for pid in "${forward_pids[@]}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

kubectl --kubeconfig "$KUBECONFIG" --context "$CONTEXT" --namespace "$NAMESPACE" \
  port-forward --address 127.0.0.1 service/demo-api "$API_PORT:8080" >"$TEMP_DIR/api-forward.log" 2>&1 &
forward_pids+=("$!")
kubectl --kubeconfig "$KUBECONFIG" --context "$CONTEXT" --namespace "$NAMESPACE" \
  port-forward --address 127.0.0.1 service/demo-backend "$BACKEND_PORT:8081" >"$TEMP_DIR/backend-forward.log" 2>&1 &
forward_pids+=("$!")
ready=false
for attempt in {1..50}; do
  for pid in "${forward_pids[@]}"; do
    if ! kill -0 "$pid" 2>/dev/null; then
      cat "$TEMP_DIR/"*-forward.log >&2
      die 'Port-forward exited before checks; choose free API_PORT/BACKEND_PORT values.'
    fi
  done
  if grep -q "Forwarding from 127.0.0.1:$API_PORT " "$TEMP_DIR/api-forward.log" &&
     grep -q "Forwarding from 127.0.0.1:$BACKEND_PORT " "$TEMP_DIR/backend-forward.log"; then
    ready=true
    break
  fi
  sleep 0.2
done
if [[ "$ready" != true ]]; then
  cat "$TEMP_DIR/"*-forward.log >&2
  die 'Timed out waiting for loopback port-forwards.'
fi

check_json() {
  local label="$1" url="$2" expected="$3" status
  status="$(curl --silent --show-error --noproxy '*' --connect-timeout 2 --max-time 5 \
    --output "$TEMP_DIR/response.json" --write-out '%{http_code}' "$url")"
  [[ "$status" == 200 ]] || die "$label returned HTTP $status; expected 200."
  python3 - "$TEMP_DIR/response.json" "$expected" "$label" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as response:
    actual = json.load(response)
expected = json.loads(sys.argv[2])
if actual != expected:
    raise SystemExit(f"{sys.argv[3]} payload mismatch: {actual!r}")
print(f"{sys.argv[3]}: HTTP 200, {json.dumps(actual, sort_keys=True)}")
PY
}

health='{"status":"ok"}'
data='{"source":"demo-backend","value":"representative-data"}'
check_json 'backend /healthz' "http://127.0.0.1:$BACKEND_PORT/healthz" "$health"
check_json 'backend /data' "http://127.0.0.1:$BACKEND_PORT/data" "$data"
check_json 'api /healthz' "http://127.0.0.1:$API_PORT/healthz" "$health"
check_json 'api /data (first)' "http://127.0.0.1:$API_PORT/data" "$data"
check_json 'api /data (repeat)' "http://127.0.0.1:$API_PORT/data" "$data"

# Operator inspection of the legitimate cache only; no Phase C write probes.
k exec deployment/demo-api -- python3 -c '
import json
with open("/tmp/demo-cache.json", encoding="utf-8") as cache:
    actual = json.load(cache)
expected = {"source": "demo-backend", "value": "representative-data"}
if actual != expected:
    raise SystemExit("Legitimate cache payload mismatch")
print("/tmp/demo-cache.json: " + json.dumps(actual, sort_keys=True))
'
printf 'Recent backend request logs:\n'
k logs deployment/demo-backend --since=2m --tail=12
printf '\nFUNCTIONALITY = PASS\nH1–H4 remain hypotheses; security assessment occurs in Phase C.\n'
