#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cluster
for component in demo-api demo-backend; do
  image="secops-$component:phase-b"
  docker build --tag "$image" "$REPO_ROOT/task1/app/$component"
  kind load docker-image --name "$CLUSTER_NAME" "$image"
  docker image inspect --format 'Built {{.RepoTags}} image ID {{.Id}}' "$image"
done
