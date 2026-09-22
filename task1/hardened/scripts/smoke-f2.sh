#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"

require_cluster
[[ "$NAMESPACE" == secops-demo && "$CONTEXT" == kind-secops-lab ]] || die 'Unexpected smoke scope.'
pre="$REPO_ROOT/docs/evidence/phase-d/d2-pre-state.txt"
[[ -f "$pre" ]] || die 'D2 pre-state evidence is missing.'
printf 'UTC: %s\n' "$(date -u +%FT%TZ)"

for name in demo-api demo-backend; do
  printf '\n%s effective identity:\n' "$name"
  k get serviceaccount "$name" -o json | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["metadata"]["name"]==sys.argv[1] and x.get("automountServiceAccountToken") is False; print("ServiceAccount=%s automount=false"%sys.argv[1])' "$name"
  k get deployment "$name" -o json | python3 -c 'import json,sys; x=json.load(sys.stdin)["spec"]["template"]["spec"]; assert x["serviceAccountName"]==sys.argv[1] and x.get("automountServiceAccountToken") is None; print("Deployment serviceAccount=%s Pod-template automount=unset; no true override"%sys.argv[1])' "$name"
  k get pods -l "app=$name" -o json | python3 -c 'import json,sys; name=sys.argv[1]; p=[x for x in json.load(sys.stdin)["items"] if not x["metadata"].get("deletionTimestamp")]; assert len(p)==1, p; p=p[0]; s=p["spec"]; c=s["containers"][0]; assert p["status"]["phase"]=="Running" and all(z["ready"] for z in p["status"]["containerStatuses"]); assert s["serviceAccountName"]==name and s.get("automountServiceAccountToken") is None; assert not any(v["name"].startswith("kube-api-access-") or "serviceAccountToken" in str(v.get("projected",{})) for v in s.get("volumes",[])); assert not any(m["mountPath"].startswith("/var/run/secrets/kubernetes.io/serviceaccount") for m in c.get("volumeMounts",[])); print("Pod=%s UID=%s image=%s imageID=%s Pod automount=unset projected kube-api-access volume=absent SA mount=absent volumes=%s mounts=%s securityContext=%s"%(p["metadata"]["name"],p["metadata"]["uid"],c["image"],p["status"]["containerStatuses"][0]["imageID"],[(v["name"],list(v.keys())) for v in s.get("volumes",[])],c.get("volumeMounts",[]),c.get("securityContext")))' "$name"
  k exec "deployment/$name" -- python3 -c 'import os; from pathlib import Path; d=Path("/var/run/secrets/kubernetes.io/serviceaccount"); assert not d.exists() and not (d/"token").exists() and not (d/"ca.crt").exists() and not (d/"namespace").exists(); print("Application-context SA directory=absent token=absent CA=absent namespace bundle=absent; former workload credential prerequisite unavailable; credential contents collected=NO")'
done

snapshot="$(python3 - "$pre" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for name in ("demo-api", "demo-backend"):
    section = text.split(f"\n{name} Deployment and Pod:\n", 1)[1].split("\n\n", 1)[0]
    match = re.search(r"pod=(\S+) UID=(\S+) ready=(\S+) image=(\S+) imageID=(\S+)", section)
    assert match, f"Missing pre-state identity for {name}"
    print(name, *match.groups())
PY
)"
read -r _ api_old_pod api_old_uid _ api_image api_image_id <<< "$(printf '%s\n' "$snapshot" | sed -n '1p')"
read -r _ backend_old_pod backend_old_uid _ backend_image backend_image_id <<< "$(printf '%s\n' "$snapshot" | sed -n '2p')"
for row in "demo-api $api_old_uid $api_image $api_image_id" "demo-backend $backend_old_uid $backend_image $backend_image_id"; do
  read -r name old_uid image image_id <<< "$row"
  k get pods -l "app=$name" -o json | python3 -c 'import json,sys; name,old_uid,image,image_id=sys.argv[1:]; p=[x for x in json.load(sys.stdin)["items"] if not x["metadata"].get("deletionTimestamp")]; assert len(p)==1; x=p[0]; assert x["metadata"]["uid"]!=old_uid, "Pod was not recreated"; assert x["spec"]["containers"][0]["image"]==image and x["status"]["containerStatuses"][0]["imageID"]==image_id; print("%s: new UID=%s; accepted D1 image/imageID preserved"%(name,x["metadata"]["uid"]))' "$name" "$old_uid" "$image" "$image_id"
done
k get deployment demo-api -o json | python3 -c 'import json,sys; x=json.load(sys.stdin)["spec"]["template"]["spec"]; c=x["containers"][0]; assert c["image"]==sys.argv[1]; assert c["securityContext"]=={"runAsNonRoot":True,"allowPrivilegeEscalation":False,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":True}; assert x["volumes"]==[{"name":"api-tmp","emptyDir":{}}]; print("API D1 image and F1 deployment controls preserved")' "$api_image"
k get deployment demo-backend -o json | python3 -c 'import json,sys; x=json.load(sys.stdin)["spec"]["template"]["spec"]; c=x["containers"][0]; assert c["image"]==sys.argv[1] and c["securityContext"]=={"readOnlyRootFilesystem":False}; assert c.get("command") is None and c.get("volumeMounts") is None and x.get("volumes") is None; assert c["resources"]=={"requests":{"cpu":"25m","memory":"32Mi"},"limits":{"cpu":"250m","memory":"128Mi"}}; print("Backend accepted D1 image and local-security configuration preserved")' "$backend_image"

[[ -z "$(k get role demo-api-fixture-access --ignore-not-found -o name)" ]] || die 'F2 Role remains.'
[[ -z "$(k get rolebinding demo-api-fixture-access --ignore-not-found -o name)" ]] || die 'F2 RoleBinding remains.'
printf '\nRole=absent RoleBinding=absent\n'
for verb in get patch; do
  if result="$(k auth can-i "$verb" configmap/phase-c-fixture --as=system:serviceaccount:secops-demo:demo-api --as-group=system:serviceaccounts --as-group=system:serviceaccounts:secops-demo --as-group=system:authenticated)"; then
    status=0
  else
    status=$?
  fi
  printf 'Exact demo-api ServiceAccount %s configmap/phase-c-fixture can-i=%s\n' "$verb" "$result"
  [[ "$result" == no && "$status" == 1 ]] || die "Unexpected effective $verb authorization or query failure; inspect exact alternative grant."
done
k get configmap phase-c-fixture -o json | python3 -c 'import json,sys; x=json.load(sys.stdin); assert x["metadata"]["name"]=="phase-c-fixture" and x["data"]=={"marker":"baseline"}; print("Fixture exists; marker=baseline; data unchanged")'
printf 'Former workload-identity GET/PATCH path unavailable: credential absent and exact identity authorization NO.\nF2 CANDIDATE RUNTIME SMOKE = PASS\n'
