#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/common.sh"

mode="${1:-}"
[[ "$mode" == pre-policy || "$mode" == candidate ]] || die 'Usage: smoke-f3.sh pre-policy|candidate'
require_cluster
[[ "$CONTEXT" == kind-secops-lab && "$NAMESPACE" == secops-demo ]] || die 'Unexpected D3 scope.'
[[ "$(kubectl --kubeconfig "$KUBECONFIG" config current-context)" == "$CONTEXT" ]] || die 'Unexpected kubeconfig context.'
[[ "$(k get namespace "$NAMESPACE" -o jsonpath='{.metadata.name}')" == "$NAMESPACE" ]] || die 'Namespace missing.'
if [[ "$mode" == pre-policy ]]; then
  [[ "$(k get networkpolicies -o json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["items"]))')" == 0 ]] || die 'Pre-policy run requires zero NetworkPolicies.'
else
  [[ "$(k get networkpolicies -o json | python3 -c 'import json,sys; print(" ".join(sorted(x["metadata"]["name"] for x in json.load(sys.stdin)["items"])))')" == 'demo-api-egress demo-backend-ingress' ]] || die 'Candidate requires exactly the two D3 policies.'
fi
for image in secops-demo-api:phase-b secops-demo-backend:phase-b; do
  docker image inspect "$image" --format '{{.Id}}' || die "Local fixture image missing: $image"
done

run_id="$(python3 -c 'import uuid; print(uuid.uuid4().hex[:10])')"
source_pod="phase-d3-source-$run_id"
target_pod="phase-d3-target-$run_id"
for name in "$source_pod" "$target_pod"; do
  [[ -z "$(k get pod "$name" --ignore-not-found -o name)" ]] || die "Fixture Pod name collision: $name"
done
[[ -z "$(k get service "$target_pod" --ignore-not-found -o name)" ]] || die "Fixture Service name collision: $target_pod"
cleanup() {
  rc=$?
  cleanup_rc=0
  trap - EXIT INT TERM
  printf 'Cleanup UTC: %s\n' "$(date -u +%FT%TZ)"
  k delete service "$target_pod" --ignore-not-found --wait=true --timeout=90s || cleanup_rc=1
  k delete pod "$source_pod" "$target_pod" --ignore-not-found --wait=true --timeout=90s || cleanup_rc=1
  for name in "$source_pod" "$target_pod"; do
    [[ -z "$(k get pod "$name" --ignore-not-found -o name)" ]] || cleanup_rc=1
  done
  [[ -z "$(k get service "$target_pod" --ignore-not-found -o name)" ]] || cleanup_rc=1
  printf 'Fixture cleanup: %s\n' "$([[ $cleanup_rc == 0 ]] && echo PASS || echo FAIL)"
  [[ $cleanup_rc == 0 ]] || rc=1
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'D3 mode=%s UTC=%s context=%s namespace=%s run_id=%s\n' "$mode" "$(date -u +%FT%TZ)" "$CONTEXT" "$NAMESPACE" "$run_id"
printf 'Fixture names: source=%s targetPod=%s targetService=%s\n' "$source_pod" "$target_pod" "$target_pod"

python3 - "$source_pod" "$target_pod" <<'PY' | k apply -f -
import json,sys
source,target=sys.argv[1:]
def pod(name,role,image,container,command=None):
    c={"name":container,"image":image,"imagePullPolicy":"Never"}
    if command: c["command"]=command
    else:
        c["ports"]=[{"name":"http","containerPort":8081}]
        c["readinessProbe"]={"httpGet":{"path":"/healthz","port":8081},"periodSeconds":2}
    return {"apiVersion":"v1","kind":"Pod","metadata":{"name":name,"namespace":"secops-demo","labels":{"assessment.phase":"d3","assessment.id":target.split("-")[-1],"assessment.role":role}},"spec":{"automountServiceAccountToken":False,"containers":[c]}}
objects=[pod(source,"unrelated-source","secops-demo-api:phase-b","source",["python","-c","import time; time.sleep(3600)"]),pod(target,"unrelated-target","secops-demo-backend:phase-b","target"),{"apiVersion":"v1","kind":"Service","metadata":{"name":target,"namespace":"secops-demo","labels":{"assessment.phase":"d3","assessment.id":target.split("-")[-1]}},"spec":{"selector":{"assessment.phase":"d3","assessment.id":target.split("-")[-1],"assessment.role":"unrelated-target"},"ports":[{"name":"http","port":8081,"targetPort":8081,"protocol":"TCP"}]}}]
for i,obj in enumerate(objects):
    if i: print("---")
    print(json.dumps(obj))
PY
k wait --for=condition=Ready "pod/$source_pod" "pod/$target_pod" --timeout=90s
api_pod="$(k get pods -l app=demo-api -o json | python3 -c 'import json,sys; p=[x for x in json.load(sys.stdin)["items"] if not x["metadata"].get("deletionTimestamp")]; assert len(p)==1 and p[0]["status"]["phase"]=="Running"; print(p[0]["metadata"]["name"])')"
backend_pod="$(k get pods -l app=demo-backend -o json | python3 -c 'import json,sys; p=[x for x in json.load(sys.stdin)["items"] if not x["metadata"].get("deletionTimestamp")]; assert len(p)==1 and p[0]["status"]["phase"]=="Running"; print(p[0]["metadata"]["name"])')"
for name in "$api_pod" "$backend_pod" "$source_pod" "$target_pod"; do
  k get pod "$name" -o json | python3 -c 'import json,sys; p=json.load(sys.stdin); m=p["metadata"]; s=p["spec"]; c=s["containers"][0]; print("Pod=%s UID=%s IP=%s labels=%s image=%s imageID=%s ready=%s automount=%s"%(m["name"],m["uid"],p["status"]["podIP"],m["labels"],c["image"],p["status"]["containerStatuses"][0]["imageID"],p["status"]["containerStatuses"][0]["ready"],s.get("automountServiceAccountToken")))'
done
for name in demo-backend "$target_pod"; do
  k get service "$name" -o json | python3 -c 'import json,sys; s=json.load(sys.stdin); print("Service=%s IP=%s selector=%s ports=%s"%(s["metadata"]["name"],s["spec"]["clusterIP"],s["spec"]["selector"],s["spec"]["ports"]))'
done
target_uid="$(k get pod "$target_pod" -o jsonpath='{.metadata.uid}')"
target_ip="$(k get pod "$target_pod" -o jsonpath='{.status.podIP}')"
k get endpointslices -l "kubernetes.io/service-name=$target_pod" -o json | python3 -c 'import json,sys; x=json.load(sys.stdin)["items"]; name,uid,ip=sys.argv[1:]; assert len(x)==1 and len(x[0]["endpoints"])==1 and x[0]["ports"][0]["port"]==8081; e=x[0]["endpoints"][0]; assert e["conditions"]["ready"] and e["targetRef"]["name"]==name and e["targetRef"]["uid"]==uid and e["addresses"]==[ip]; print("Target EndpointSlice=%s endpoint=%s ports=%s"%(x[0]["metadata"]["name"],x[0]["endpoints"],x[0]["ports"]))' "$target_pod" "$target_uid" "$target_ip"
k exec "$target_pod" -- python3 -c 'import json,urllib.request; r=urllib.request.urlopen("http://127.0.0.1:8081/healthz",timeout=3); assert r.status==200 and json.load(r)=={"status":"ok"}; print("Target Pod-local /healthz: HTTP 200")'

probe() {
  local from="$1" host="$2" label="$3" expectation="$4" result
  result="$(k exec -i "$from" -- python3 - "$host" <<'PY'
import datetime,http.client,json,socket,sys
host=sys.argv[1]; out={"utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"host":host,"port":8081,"dns":None,"tcp":None,"http":None}
try:
    infos=socket.getaddrinfo(host,8081,type=socket.SOCK_STREAM)
    out["dns"]={"result":"RESOLVED","addresses":sorted(set(i[4][0] for i in infos))}
    family,kind,proto,_,address=infos[0]
    with socket.socket(family,kind,proto) as sock:
        sock.settimeout(3)
        try:
            sock.connect(address)
            out["tcp"]={"result":"CONNECTED","peer":sock.getpeername()[:2]}
            sock.sendall(("GET /data HTTP/1.1\r\nHost: "+host+"\r\nConnection: close\r\n\r\n").encode())
            response=http.client.HTTPResponse(sock); response.begin()
            out["http"]={"status":response.status,"body":json.loads(response.read(4096))}
        except Exception as exc:
            out["tcp"]={"result":"NOT CONNECTED" if out["tcp"] is None else "CONNECTED","error":type(exc).__name__+": "+str(exc)}
except Exception as exc:
    out["dns"]={"result":"FAILED","error":type(exc).__name__+": "+str(exc)}
print(json.dumps(out,sort_keys=True))
PY
)"
  printf '%s source=%s result=%s\n' "$label" "$from" "$result"
  python3 - "$expectation" "$result" <<'PY'
import json,sys
expectation=sys.argv[1]; r=json.loads(sys.argv[2]); assert r["dns"]["result"]=="RESOLVED",r
if expectation=="allow":
    assert r["tcp"]["result"]=="CONNECTED" and r["http"]["status"]==200,r
    assert r["http"]["body"]=={"source":"demo-backend","value":"representative-data"},r
else:
    assert r["tcp"]["result"]=="NOT CONNECTED" and r["http"] is None,r
print("Probe classification:", expectation.upper(),"PASS")
PY
}
backend_fqdn="demo-backend.secops-demo.svc.cluster.local"
target_fqdn="$target_pod.secops-demo.svc.cluster.local"
failures=0
probe "$api_pod" "$backend_fqdn" 'API to backend' allow || failures=$((failures+1))
probe "$source_pod" "$target_fqdn" 'Source to unrelated target' allow || failures=$((failures+1))
if [[ "$mode" == pre-policy ]]; then expected=allow; else expected=deny; fi
probe "$api_pod" "$target_fqdn" 'API to unrelated target' "$expected" || failures=$((failures+1))
probe "$source_pod" "$backend_fqdn" 'Source to backend' "$expected" || failures=$((failures+1))

# Query the observed kube-dns ClusterIP over both transports from the API Pod.
k exec -i "$api_pod" -- python3 - 10.96.0.10 <<'PY'
import random,socket,struct,sys
server=sys.argv[1]; name="demo-backend.secops-demo.svc.cluster.local"; qid=random.randrange(65536)
question=b"".join(bytes([len(p)])+p.encode() for p in name.split("."))+b"\0"+struct.pack("!HH",1,1)
request=struct.pack("!HHHHHH",qid,0x100,1,0,0,0)+question
for proto in ("UDP","TCP"):
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM if proto=="UDP" else socket.SOCK_STREAM) as s:
        s.settimeout(3)
        if proto=="UDP":
            s.sendto(request,(server,53)); response,_=s.recvfrom(4096)
        else:
            s.connect((server,53)); s.sendall(struct.pack("!H",len(request))+request)
            def exact(n):
                data=b""
                while len(data)<n:
                    chunk=s.recv(n-len(data))
                    if not chunk: raise RuntimeError("Short DNS TCP response")
                    data+=chunk
                return data
            response=exact(struct.unpack("!H",exact(2))[0])
        rid,flags,queries,answers,_,_=struct.unpack("!HHHHHH",response[:12])
        assert rid==qid and flags&0x8000 and flags&0xf==0 and queries==1 and answers>=1
        print("API DNS %s/53 server=%s name=%s rcode=0 answers=%s PASS"%(proto,server,name,answers))
PY
[[ "$failures" == 0 ]] || die "F3 $mode smoke: $failures flow classification(s) failed."
printf 'F3 %s SMOKE = PASS\n' "$mode"
