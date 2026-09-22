#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"

require_cluster
baseline_before="$(docker image inspect secops-demo-api:phase-b --format '{{.Id}}')"
candidate=secops-demo-api:phase-d1
docker build \
  -f "$REPO_ROOT/task1/hardened/images/demo-api.Dockerfile" \
  -t "$candidate" \
  "$REPO_ROOT/task1/app/demo-api"
docker image inspect "$candidate" --format 'Candidate tag={{index .RepoTags 0}} ID={{.Id}} Config.User={{.Config.User}}'
kind load docker-image --name "$CLUSTER_NAME" "$candidate"
baseline_after="$(docker image inspect secops-demo-api:phase-b --format '{{.Id}}')"
[[ "$baseline_before" == "$baseline_after" ]] || die 'Phase B API image identity changed.'
printf 'Phase B API image preserved: %s\n' "$baseline_after"
