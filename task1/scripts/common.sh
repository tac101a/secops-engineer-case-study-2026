#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="$REPO_ROOT/.local/bin:$PATH"
export KUBECONFIG="$REPO_ROOT/.local/kubeconfig"
export KIND_EXPERIMENTAL_PROVIDER=docker
CLUSTER_NAME=secops-lab
CONTEXT=kind-secops-lab
NAMESPACE=secops-demo
OWNER_FILE="$REPO_ROOT/.local/secops-lab.owner"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null || die "Missing required tool: $tool (see README.md)."
  done
}

cluster_exists() {
  local clusters
  clusters="$(kind get clusters)" || die 'Could not list kind clusters.'
  [[ $'\n'"$clusters"$'\n' == *$'\n'"$CLUSTER_NAME"$'\n'* ]]
}

# A matching name alone never authorizes reusing or deleting an existing cluster.
assert_owned_cluster() {
  local node_id
  [[ -f "$OWNER_FILE" ]] || die "Cluster $CLUSTER_NAME lacks this checkout's ownership record. Refusing to use it."
  node_id="$(docker inspect --format '{{.Id}}' "$CLUSTER_NAME-control-plane")"
  [[ "$(cat "$OWNER_FILE")" == "$(printf '%s\n' "$REPO_ROOT" "$node_id")" ]] ||
    die "Cluster $CLUSTER_NAME does not match this checkout's ownership record."
}

require_cluster() {
  require_tools docker kind kubectl
  docker info --format '{{.ServerVersion}}' >/dev/null
  cluster_exists || die 'Run make task1-cluster-up first.'
  assert_owned_cluster
  [[ -f "$KUBECONFIG" ]] || die 'Local kubeconfig missing; run make task1-cluster-up.'
}

k() {
  kubectl --kubeconfig "$KUBECONFIG" --context "$CONTEXT" --namespace "$NAMESPACE" "$@"
}
