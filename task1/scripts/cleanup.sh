#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_tools docker kind
docker info --format '{{.ServerVersion}}' >/dev/null
if cluster_exists; then
  assert_owned_cluster
  kind delete cluster --name "$CLUSTER_NAME" --kubeconfig "$KUBECONFIG"
else
  printf 'Cluster %s is already absent.\n' "$CLUSTER_NAME"
fi
rm -f "$KUBECONFIG" "$OWNER_FILE"
printf 'Removed only the dedicated cluster and its local credentials/ownership record. Docker images remain.\n'
