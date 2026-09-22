#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"

require_cluster
[[ "$NAMESPACE" == secops-demo && "$CONTEXT" == kind-secops-lab ]] || die 'Unexpected deployment scope.'
pre="$REPO_ROOT/docs/evidence/phase-d/d2-pre-state.txt"
[[ -f "$pre" ]] || die 'D2 pre-state evidence is required before deployment.'

# The D2 snapshot is the rollback and preservation reference. Check that this is
# still the exact D1 runtime we inspected, rather than an unknown intermediate.
snapshot="$(python3 - "$pre" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for name in ("demo-api", "demo-backend"):
    section = text.split(f"\n{name} Deployment and Pod:\n", 1)[1].split("\n\n", 1)[0]
    pod = re.search(r"pod=(\S+) UID=(\S+) ready=(\S+) image=(\S+) imageID=(\S+)", section)
    assert pod, f"Missing {name} Pod identity in D2 pre-state"
    print(name, *pod.groups())
PY
)"
api_line="$(printf '%s\n' "$snapshot" | sed -n '1p')"
backend_line="$(printf '%s\n' "$snapshot" | sed -n '2p')"
read -r _ api_pod api_uid api_phase api_image api_image_id <<< "$api_line"
read -r _ backend_pod backend_uid backend_phase backend_image backend_image_id <<< "$backend_line"
[[ "$api_phase" == Running && "$backend_phase" == Running ]] || die 'D2 snapshot Pods were not Running.'
[[ "$api_image" == "$(python3 - "$REPO_ROOT/task1/hardened/demo-api.yaml" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
print(re.search(r"(?m)^\s+image: (\S+)$", text).group(1))
PY
)" ]] || die 'API image differs from accepted D1 hardened manifest.'
grep -Fq "$api_image" "$REPO_ROOT/docs/phase-d-d1-report.md" || die 'API image missing from accepted D1 report.'

check_current() {
  local name="$1" expected_pod="$2" expected_uid="$3" expected_image="$4" expected_id="$5"
  k get deployment "$name" -o json | python3 -c 'import json,sys; d=json.load(sys.stdin); n,image=sys.argv[1:]; t=d["spec"]["template"]["spec"]; c=t["containers"][0]; assert c["image"]==image and t["serviceAccountName"]==n and t.get("automountServiceAccountToken") is None; assert d["status"].get("readyReplicas")==1' "$name" "$expected_image"
  k get pod "$expected_pod" -o json | python3 -c 'import json,sys; p=json.load(sys.stdin); n,uid,image,image_id=sys.argv[1:]; assert p["metadata"]["uid"]==uid and p["status"]["phase"]=="Running"; assert p["spec"]["serviceAccountName"]==n and p["spec"].get("automountServiceAccountToken") is None; assert p["spec"]["containers"][0]["image"]==image and p["status"]["containerStatuses"][0]["imageID"]==image_id' "$name" "$expected_uid" "$expected_image" "$expected_id"
}
check_current demo-api "$api_pod" "$api_uid" "$api_image" "$api_image_id"
check_current demo-backend "$backend_pod" "$backend_uid" "$backend_image" "$backend_image_id"
k get deployment demo-api -o json | python3 -c 'import json,sys; t=json.load(sys.stdin)["spec"]["template"]["spec"]; c=t["containers"][0]; assert c["securityContext"]=={"runAsNonRoot":True,"allowPrivilegeEscalation":False,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":True}; assert t["volumes"]==[{"name":"api-tmp","emptyDir":{}}]; assert c["volumeMounts"]==[{"name":"api-tmp","mountPath":"/tmp"}]'
k get deployment demo-backend -o json | python3 -c 'import json,sys; t=json.load(sys.stdin)["spec"]["template"]["spec"]; c=t["containers"][0]; assert c["securityContext"]=={"readOnlyRootFilesystem":False}; assert c.get("command") is None and c.get("volumeMounts") is None and t.get("volumes") is None; assert c["resources"]=={"requests":{"cpu":"25m","memory":"32Mi"},"limits":{"cpu":"250m","memory":"128Mi"}}'
for name in demo-api demo-backend; do
  k get serviceaccount "$name" -o json | python3 -c 'import json,sys; assert json.load(sys.stdin).get("automountServiceAccountToken") is True'
done
k get role demo-api-fixture-access -o name >/dev/null
k get rolebinding demo-api-fixture-access -o name >/dev/null
k get configmap phase-c-fixture -o jsonpath='{.data.marker}' | grep -qx baseline
[[ "$(k get networkpolicies -o json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["items"]))')" == 0 ]] || die 'Unexpected NetworkPolicy before D2.'

# k always carries this checkout's verified context and explicit namespace.
k apply -f "$REPO_ROOT/task1/hardened/identity.yaml"
k delete role/demo-api-fixture-access
k delete rolebinding/demo-api-fixture-access
k rollout restart deployment/demo-api deployment/demo-backend
k rollout status deployment/demo-api --timeout=180s
k rollout status deployment/demo-backend --timeout=180s
k get deployments demo-api demo-backend -o wide
k get pods -l 'app in (demo-api,demo-backend)' -o wide
for name in demo-api demo-backend; do
  k get pods -l "app=$name" -o json | python3 -c 'import json,sys; p=[x for x in json.load(sys.stdin)["items"] if not x["metadata"].get("deletionTimestamp")]; assert len(p)==1 and p[0]["status"]["phase"]=="Running"; x=p[0]; print("%s Pod=%s UID=%s image=%s imageID=%s"%(sys.argv[1],x["metadata"]["name"],x["metadata"]["uid"],x["spec"]["containers"][0]["image"],x["status"]["containerStatuses"][0]["imageID"]))' "$name"
done
