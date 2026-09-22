#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"

require_cluster
k apply -f "$REPO_ROOT/task1/hardened/demo-api.yaml"
k rollout status deployment/demo-api --timeout=180s
k get deployment/demo-api -o wide
k get pods -l app=demo-api -o wide
