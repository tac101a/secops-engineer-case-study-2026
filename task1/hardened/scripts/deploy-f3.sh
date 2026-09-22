#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"

require_cluster
[[ "$CONTEXT" == kind-secops-lab && "$NAMESPACE" == secops-demo ]] || die 'Unexpected D3 scope.'
[[ "$(kubectl --kubeconfig "$KUBECONFIG" config current-context)" == "$CONTEXT" ]] || die 'Unexpected kubeconfig context.'
[[ "$(k get namespace "$NAMESPACE" -o jsonpath='{.metadata.name}')" == "$NAMESPACE" ]] || die 'Namespace missing.'
"$REPO_ROOT/task1/hardened/scripts/smoke-f2.sh"

policy="$REPO_ROOT/task1/hardened/network-policy.yaml"
[[ -f "$policy" ]] || die 'D3 policy artifact missing.'
names="$(k get networkpolicies -o json | python3 -c 'import json,sys; print(" ".join(sorted(x["metadata"]["name"] for x in json.load(sys.stdin)["items"])))')"
case "$names" in
  ''|'demo-api-egress demo-backend-ingress') ;;
  *) die "Unexpected pre-D3 NetworkPolicy set: $names" ;;
esac
printf 'Pre-apply NetworkPolicies: %s\n' "${names:-none}"

# Server dry-run confirms admission and lets us reject changes to the intended scope.
k apply --dry-run=server -f "$policy" -o json | python3 -c '
import json, sys
x=json.load(sys.stdin)
items=x.get("items",[x])
expected={"demo-api-egress":("demo-api","Egress"),"demo-backend-ingress":("demo-backend","Ingress")}
assert len(items)==2
for p in items:
    m,s=p["metadata"],p["spec"]
    assert p["kind"]=="NetworkPolicy" and m["namespace"]=="secops-demo"
    assert m["name"] in expected
    label,direction=expected[m["name"]]
    assert s["podSelector"]=={"matchLabels":{"app":label}} and s["policyTypes"]==[direction]
print("D3 policy object scope: PASS")
'
k apply -f "$policy"
k get networkpolicies -o wide
k get pods -l 'app in (demo-api,demo-backend)' -o wide --show-labels
