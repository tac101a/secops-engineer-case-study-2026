#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cluster
k apply -f "$REPO_ROOT/task1/insecure/namespace.yaml"
k apply -f "$REPO_ROOT/task1/insecure/"
# Refresh Pods after a rebuild of the fixed local image tags.
k rollout restart deployment/demo-api deployment/demo-backend
k rollout status deployment/demo-backend --timeout=180s
k rollout status deployment/demo-api --timeout=180s
k get deployments,pods,services
printf 'Representative permissive baseline deployed; run make task1-check.\n'
