#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_tools docker kind kubectl
docker info --format '{{.ServerVersion}}' >/dev/null
[[ "$(kind version)" == 'kind v0.31.0 '* ]] || die 'This baseline requires kind v0.31.0; see README.md.'
umask 077
mkdir -p "$REPO_ROOT/.local"

if cluster_exists; then
  assert_owned_cluster
  printf 'Reusing owned cluster %s.\n' "$CLUSTER_NAME"
else
  kind create cluster --name "$CLUSTER_NAME" --config "$REPO_ROOT/task1/kind.yaml" \
    --kubeconfig "$KUBECONFIG" --wait 180s
  printf '%s\n' "$REPO_ROOT" "$(docker inspect --format '{{.Id}}' "$CLUSTER_NAME-control-plane")" > "$OWNER_FILE"
fi

kind export kubeconfig --name "$CLUSTER_NAME" --kubeconfig "$KUBECONFIG"
chmod 600 "$KUBECONFIG" "$OWNER_FILE"
k wait --for=condition=Ready nodes --all --timeout=180s
k get nodes -o wide
printf 'Cluster ready; operator kubeconfig: %s (context %s).\n' "$KUBECONFIG" "$CONTEXT"
