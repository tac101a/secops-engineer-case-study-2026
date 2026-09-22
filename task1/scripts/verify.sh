#!/usr/bin/env bash
# E1 offline verifier. Runtime probes are deliberately fail-closed until a later phase.
set -u

usage='Usage: task1/scripts/verify.sh [--help | --offline [insecure|hardened] | --historical-summary | --runtime | insecure | hardened]'
case "${1-}" in
  --help)
    if (( $# != 1 )); then printf '%s\nARGUMENTS: INFRASTRUCTURE ERROR — invalid arguments\nMODE EXIT: 3\n' "$usage"; exit 3; fi
    printf '%s\n' "$usage"
    printf '%s\n' 'No arguments select --offline hardened. Offline results inspect source files only; they do not prove current runtime security.'
    printf '%s\n' 'Bare profiles are compatibility modes: offline static checks plus explicit runtime blockers.'
    exit 0
    ;;
  --runtime)
    if (( $# != 1 )); then printf '%s\nARGUMENTS: INFRASTRUCTURE ERROR — invalid arguments\nMODE EXIT: 3\n' "$usage"; exit 3; fi
    printf '%s\n' 'RUNTIME REQUEST: BLOCKED — no live probes are authorized in E1'
    printf '%s\n' 'PREREQUISITES: resolve D3 policy enforcement; complete D3 candidate acceptance; resolve D3R-1B-EXEC paused execution state and possible residue; establish a known owned-cluster state; complete D4 integration; authorize a bounded full Phase E runtime run with healthy fixtures and same-oracle BEFORE/AFTER checks.'
    printf '%s\n' 'CURRENT CLUSTER STATE: UNKNOWN' 'POSSIBLE DIAGNOSTIC RESIDUE: UNKNOWN' 'D3R-1B-EXEC: PAUSED — EXECUTION STATE UNKNOWN' 'D3: NOT READY' 'F3 ENFORCEMENT: BLOCKED / NOT VERIFIED' 'CURRENT RUNTIME VERIFICATION: NOT RUN' 'FULL AFTER RESULT: BLOCKED' 'MODE RESULT: BLOCKED' 'MODE EXIT: 2'
    exit 2
    ;;
esac

if (( $# == 0 )); then set -- --offline hardened; fi
case "$1:$#" in
  --offline:1|--offline:2|--historical-summary:1|insecure:1|hardened:1) ;;
  *) printf '%s\nARGUMENTS: INFRASTRUCTURE ERROR — invalid arguments\nMODE EXIT: 3\n' "$usage"; exit 3 ;;
esac
if [[ "$1" == --offline && $# == 2 && "$2" != insecure && "$2" != hardened ]]; then
  printf '%s\nARGUMENTS: INFRASTRUCTURE ERROR — invalid arguments\nMODE EXIT: 3\n' "$usage"
  exit 3
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'YAML PARSER: BLOCKED — python3 is required for structured YAML inspection and historical mapping rendering\n'
  printf 'FULL AFTER RESULT: BLOCKED\nMODE EXIT: 2\n'
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 3
repo_root="$(cd "$script_dir/../.." && pwd)" || exit 3
python3 -I -B - "$repo_root" "$@" <<'PY'
import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve()
ARGS = sys.argv[2:]
STATUS_RANK = {"PASS": 0, "BLOCKED": 1, "FAIL": 2, "INFRASTRUCTURE ERROR": 3}
EXIT_FOR_STATUS = {"PASS": 0, "BLOCKED": 2, "FAIL": 1, "INFRASTRUCTURE ERROR": 3}
results = []


def result(label, status, detail):
    results.append((label, status, detail))
    print(f"{label}: {status} — {detail}")


def finish(mode, rendered=False):
    status = max((item[1] for item in results), key=lambda value: STATUS_RANK[value], default="PASS")
    if rendered and status == "PASS":
        print("MODE RESULT: HISTORICAL SUMMARY RENDERED")
    else:
        print(f"MODE RESULT: {status}")
    print("CURRENT RUNTIME VERIFICATION: NOT RUN")
    print("FULL AFTER RESULT: BLOCKED")
    code = EXIT_FOR_STATUS[status]
    print(f"MODE EXIT: {code}")
    return code


def invalid_arguments():
    print("Usage: task1/scripts/verify.sh --offline [insecure|hardened] | --historical-summary | insecure | hardened")
    result("ARGUMENTS", "INFRASTRUCTURE ERROR", "invalid arguments")
    return finish("arguments")


def unique_pairs(pairs):
    output = {}
    for key, value in pairs:
        if key in output:
            raise ValueError(f"duplicate JSON key: {key}")
        output[key] = value
    return output


def historical_mapping():
    path = ROOT / "docs/evidence/phase-e/e1-historical-claims.md"
    if not path.is_file():
        result("HISTORICAL MAPPING", "BLOCKED", f"required curated mapping missing: {path.relative_to(ROOT)}")
        return None
    try:
        content = path.read_text(encoding="utf-8")
        begin = "<!-- E1-HISTORICAL-CLAIMS-JSON-BEGIN -->"
        end = "<!-- E1-HISTORICAL-CLAIMS-JSON-END -->"
        if content.count(begin) != 1 or content.count(end) != 1:
            raise ValueError("mapping delimiters must each occur exactly once")
        payload = content.split(begin, 1)[1].split(end, 1)[0].strip()
        if not payload.startswith("```json\n") or not payload.endswith("\n```"):
            raise ValueError("mapping must contain one fenced JSON object")
        data = json.loads(payload[len("```json\n"):-len("\n```")], object_pairs_hook=unique_pairs)
        if not isinstance(data, dict) or set(data) != {"schema", "claims"}:
            raise ValueError("mapping object fields must be schema and claims")
        if data["schema"] != "e1-historical-claims/v1":
            raise ValueError("unsupported historical mapping schema")
        claims = data["claims"]
        if not isinstance(claims, list) or not claims:
            raise ValueError("claims must be a nonempty array")
        expected = {
            ("FUNC", "B/insecure"): "FUNCTIONAL_PASS",
            ("F1", "C/insecure"): "WEAKNESS_CONFIRMED",
            ("F2", "C/insecure"): "WEAKNESS_CONFIRMED",
            ("F3", "C/insecure"): "WEAKNESS_CONFIRMED",
            ("FUNC", "D1/hardened-candidate"): "FUNCTIONAL_PASS",
            ("F1", "D1/hardened-candidate"): "CANDIDATE_PASS",
            ("FUNC", "D2/hardened-candidate"): "FUNCTIONAL_PASS",
            ("F2", "D2/hardened-candidate"): "CANDIDATE_PASS",
            ("FUNC", "D3/hardened-candidate"): "FUNCTIONAL_PASS",
            ("F3", "D3/hardened-candidate"): "CANDIDATE_FAIL",
        }
        seen = set()
        docs = (ROOT / "docs").resolve()
        for claim in claims:
            if not isinstance(claim, dict) or set(claim) != {"id", "phase_profile", "status", "sources", "limitation"}:
                raise ValueError("claim fields must be id, phase_profile, status, sources, limitation")
            claim_id, phase, status = claim["id"], claim["phase_profile"], claim["status"]
            if not all(isinstance(value, str) and value.strip() == value and value for value in (claim_id, phase, status, claim["limitation"])):
                raise ValueError("claim strings must be nonempty and trimmed")
            key = (claim_id, phase)
            if key not in expected or key in seen:
                raise ValueError(f"unknown or duplicate historical claim: {key}")
            seen.add(key)
            if status != expected[key]:
                raise ValueError(f"status contradicts the reviewed historical outcome for {key}")
            sources = claim["sources"]
            if not isinstance(sources, list) or not sources or len(sources) != len(set(map(str, sources))):
                raise ValueError(f"sources missing or duplicated for {key}")
            for source in sources:
                if not isinstance(source, str) or not re.fullmatch(r"docs/[A-Za-z0-9._/-]+", source):
                    raise ValueError(f"unsafe source path for {key}")
                source_path = (ROOT / source).resolve()
                if not source_path.is_relative_to(docs) or not source_path.is_file():
                    raise ValueError(f"canonical source unavailable or outside docs: {source}")
        if seen != set(expected):
            raise ValueError(f"missing curated claim(s): {sorted(set(expected) - seen)}")
        return claims
    except (OSError, UnicodeError, ValueError, TypeError) as exc:
        result("HISTORICAL MAPPING", "INFRASTRUCTURE ERROR", f"malformed or inconsistent mapping: {exc}")
        return None


def load_yaml(paths):
    try:
        import yaml
    except ImportError as exc:
        result("YAML PARSER", "BLOCKED", f"safe structured YAML loader missing ({exc}); install nothing during E1")
        return None

    class StrictSafeLoader(yaml.SafeLoader):
        pass

    def construct_mapping(loader, node):
        loader.flatten_mapping(node)
        mapping = {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=True)
            if key in mapping:
                raise yaml.constructor.ConstructorError(None, None, f"duplicate YAML key: {key}", key_node.start_mark)
            mapping[key] = loader.construct_object(value_node, deep=True)
        return mapping

    StrictSafeLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping)
    objects = {}
    try:
        for relative in paths:
            path = ROOT / relative
            if not path.is_file():
                result("SELECTED MANIFEST", "FAIL", f"INVALID SELECTED MANIFEST: missing {relative}")
                return None
            with path.open(encoding="utf-8") as stream:
                docs = list(yaml.load_all(stream, Loader=StrictSafeLoader))
            if not docs or any(not isinstance(doc, dict) for doc in docs):
                raise ValueError(f"{relative}: expected nonempty YAML objects")
            for doc in docs:
                metadata = doc.get("metadata")
                if not isinstance(metadata, dict):
                    raise ValueError(f"{relative}: metadata must be an object")
                namespace = metadata.get("namespace", "") if doc.get("kind") == "Namespace" else metadata.get("namespace")
                key = (doc.get("kind"), namespace, metadata.get("name"))
                if not isinstance(key[0], str) or not key[0] or not isinstance(key[2], str) or not key[2] or not isinstance(key[1], str) or (key[0] != "Namespace" and not key[1]):
                    raise ValueError(f"{relative}: kind, namespace, and name are required")
                if key in objects:
                    raise ValueError(f"duplicate selected object: {key}")
                objects[key] = doc
        return objects
    except (yaml.YAMLError, ValueError, TypeError, OSError, UnicodeError) as exc:
        result("SELECTED MANIFEST", "FAIL", f"INVALID SELECTED MANIFEST: {exc}")
        return None


def obj(objects, kind, name):
    return objects.get((kind, "secops-demo", name), {})


def as_dict(value):
    return value if isinstance(value, dict) else {}


def nested(value, *keys):
    for key in keys:
        if not isinstance(value, dict):
            return None
        value = value.get(key)
    return value


def check(label, assertions):
    failed = [name for name, condition in assertions if not condition]
    result(label, "FAIL" if failed else "PASS", "; ".join(failed) if failed else "selected source fields match reviewed profile")


def credential_mount_free(template, expected_mounts):
    volumes = template.get("volumes", [])
    if not isinstance(volumes, list):
        return False
    actual_volumes = set()
    for volume in volumes:
        if not isinstance(volume, dict) or not isinstance(volume.get("name"), str):
            return False
        actual_volumes.add(volume.get("name"))
        if "secret" in volume:
            return False
        projected = volume.get("projected")
        if projected is not None:
            sources = as_dict(projected).get("sources", [])
            if not isinstance(sources, list) or any(not isinstance(source, dict) or "serviceAccountToken" in source or "secret" in source for source in sources):
                return False
    actual_mounts = set()
    for field in ("containers", "initContainers", "ephemeralContainers"):
        containers = template.get(field, [])
        if not isinstance(containers, list):
            return False
        for container in containers:
            mounts = as_dict(container).get("volumeMounts", [])
            if not isinstance(mounts, list):
                return False
            if any(not isinstance(mount, dict) or not isinstance(mount.get("name"), str) or not isinstance(mount.get("mountPath"), str) or mount["mountPath"].startswith("/var/run/secrets") for mount in mounts):
                return False
            actual_mounts.update((mount.get("name"), mount.get("mountPath")) for mount in mounts)
    return actual_volumes == {name for name, _ in expected_mounts} and actual_mounts == expected_mounts


def exact_strings(value, expected):
    return isinstance(value, list) and len(value) == len(expected) and all(isinstance(item, str) for item in value) and set(value) == set(expected)


def baseline_role_valid(role):
    rules = role.get("rules")
    if role.get("apiVersion") != "rbac.authorization.k8s.io/v1" or not isinstance(rules, list) or len(rules) != 1 or not isinstance(rules[0], dict):
        return False
    rule = rules[0]
    return (set(rule) == {"apiGroups", "resources", "resourceNames", "verbs"}
            and exact_strings(rule.get("apiGroups"), [""])
            and exact_strings(rule.get("resources"), ["configmaps"])
            and exact_strings(rule.get("resourceNames"), ["phase-c-fixture"])
            and exact_strings(rule.get("verbs"), ["get", "patch"]))


def baseline_binding_valid(binding):
    return (binding.get("apiVersion") == "rbac.authorization.k8s.io/v1"
            and binding.get("subjects") == [{"kind": "ServiceAccount", "name": "demo-api", "namespace": "secops-demo"}]
            and binding.get("roleRef") == {"apiGroup": "rbac.authorization.k8s.io", "kind": "Role", "name": "demo-api-fixture-access"})


def static_checks(profile):
    # One level only: every top-level *.yaml and *.yml file, sorted by path.
    insecure_dir = ROOT / "task1/insecure"
    insecure = [str(path.relative_to(ROOT)) for path in sorted({path for pattern in ("*.yaml", "*.yml") for path in insecure_dir.glob(pattern) if path.is_file()})]
    hardened = ["task1/hardened/demo-api.yaml", "task1/hardened/identity.yaml", "task1/hardened/network-policy.yaml"]
    baseline = load_yaml(insecure)
    if baseline is None:
        for label in ("F1 BASELINE", "F2 BASELINE", "F3 BASELINE", "F1 STATIC", "F2 STATIC", "F3 STATIC"):
            result(label, "BLOCKED", "selected YAML could not be inspected")
        return
    baseline_api = obj(baseline, "Deployment", "demo-api")
    baseline_template = as_dict(nested(baseline_api, "spec", "template", "spec"))
    baseline_containers = baseline_template.get("containers", [])
    baseline_container = next((entry for entry in baseline_containers if isinstance(entry, dict) and entry.get("name") == "demo-api"), {}) if isinstance(baseline_containers, list) else {}
    baseline_context = as_dict(baseline_container.get("securityContext"))
    check("F1 BASELINE", [
        ("insecure API uses phase-b image", baseline_container.get("image") == "secops-demo-api:phase-b"),
        ("insecure API declares writable root", baseline_context.get("readOnlyRootFilesystem") is False),
        ("insecure API has no nonroot restriction", baseline_context.get("runAsNonRoot") is not True),
    ])
    check("F2 BASELINE", [
        ("insecure API ServiceAccount automount is true", obj(baseline, "ServiceAccount", "demo-api").get("automountServiceAccountToken") is True),
        ("insecure backend ServiceAccount automount is true", obj(baseline, "ServiceAccount", "demo-backend").get("automountServiceAccountToken") is True),
        ("insecure fixture ConfigMap marker is baseline", nested(obj(baseline, "ConfigMap", "phase-c-fixture"), "data") == {"marker": "baseline"}),
        ("insecure fixture Role has exact named GET/PATCH rule", baseline_role_valid(obj(baseline, "Role", "demo-api-fixture-access"))),
        ("insecure fixture RoleBinding has exact API ServiceAccount subject and roleRef", baseline_binding_valid(obj(baseline, "RoleBinding", "demo-api-fixture-access"))),
    ])
    baseline_policies = sorted(key[2] for key in baseline if key[0] == "NetworkPolicy")
    check("F3 BASELINE", [(f"discovered insecure source set declares no NetworkPolicy (found: {', '.join(baseline_policies) or 'none'})", not baseline_policies)])
    candidate = load_yaml(hardened) if profile == "hardened" else {}
    if candidate is None:
        for label in ("F1 STATIC", "F2 STATIC", "F3 STATIC"):
            result(label, "BLOCKED", "selected YAML could not be inspected")
        return
    objects = {**baseline, **candidate}
    api = obj(objects, "Deployment", "demo-api")
    backend = obj(objects, "Deployment", "demo-backend")
    api_template = as_dict(nested(api, "spec", "template", "spec"))
    api_containers = api_template.get("containers", [])
    api_container = next((entry for entry in api_containers if isinstance(entry, dict) and entry.get("name") == "demo-api"), {}) if isinstance(api_containers, list) else {}
    context = as_dict(api_container.get("securityContext"))
    if profile == "hardened":
        try:
            image_user = (ROOT / "task1/hardened/images/demo-api.Dockerfile").read_text(encoding="utf-8")
        except (OSError, UnicodeError):
            image_user = ""
        mounts = api_container.get("volumeMounts", [])
        volumes = api_template.get("volumes", [])
        tmp_mount = any(isinstance(m, dict) and m.get("name") == "api-tmp" and m.get("mountPath") == "/tmp" and m.get("readOnly") is not True for m in mounts) if isinstance(mounts, list) else False
        tmp_volume = any(isinstance(v, dict) and v.get("name") == "api-tmp" and isinstance(v.get("emptyDir"), dict) for v in volumes) if isinstance(volumes, list) else False
        check("F1 STATIC", [
            ("hardened image identity is distinct from phase-b", api_container.get("image") == "secops-demo-api:phase-d1"),
            ("image specifies nonroot USER 65534:65534", bool(re.search(r"(?m)^USER 65534:65534\s*$", image_user))),
            ("runAsNonRoot is true", nested(context, "runAsNonRoot") is True),
            ("allowPrivilegeEscalation is false", nested(context, "allowPrivilegeEscalation") is False),
            ("drop ALL capabilities", nested(context, "capabilities", "drop") == ["ALL"]),
            ("readOnlyRootFilesystem is true", nested(context, "readOnlyRootFilesystem") is True),
            ("writable ephemeral /tmp is declared", tmp_mount and tmp_volume),
        ])
        api_sa = obj(objects, "ServiceAccount", "demo-api")
        backend_sa = obj(objects, "ServiceAccount", "demo-backend")
        backend_template = as_dict(nested(backend, "spec", "template", "spec"))
        check("F2 STATIC", [
            ("API ServiceAccount automount is false", api_sa.get("automountServiceAccountToken") is False),
            ("backend ServiceAccount automount is false", backend_sa.get("automountServiceAccountToken") is False),
            ("API template uses dedicated ServiceAccount", api_template.get("serviceAccountName") == "demo-api"),
            ("backend template uses dedicated ServiceAccount", backend_template.get("serviceAccountName") == "demo-backend"),
            ("API Pod does not override automount to true", api_template.get("automountServiceAccountToken") is not True),
            ("backend Pod does not override automount to true", backend_template.get("automountServiceAccountToken") is not True),
            ("API template has no projected token or unintended credential mount", credential_mount_free(api_template, {("api-tmp", "/tmp")})),
            ("backend template has no projected token or unintended credential mount", credential_mount_free(backend_template, set())),
            ("fixture Role and any replacement Role absent from hardened set", not any(k[0] == "Role" for k in candidate)),
            ("fixture RoleBinding and any replacement RoleBinding absent from hardened set", not any(k[0] == "RoleBinding" for k in candidate)),
            ("original insecure fixture remains available", all(bool(obj(baseline, kind, name)) for kind, name in (("ConfigMap", "phase-c-fixture"), ("Role", "demo-api-fixture-access"), ("RoleBinding", "demo-api-fixture-access")))),
        ])
        egress = obj(objects, "NetworkPolicy", "demo-api-egress")
        ingress = obj(objects, "NetworkPolicy", "demo-backend-ingress")
        policy_keys = [key for key in objects if key[0] == "NetworkPolicy"]
        check("F3 STATIC", [
            ("exactly two selected policies", set(policy_keys) == {("NetworkPolicy", "secops-demo", "demo-api-egress"), ("NetworkPolicy", "secops-demo", "demo-backend-ingress")} and len([key for key in candidate if key[0] == "NetworkPolicy"]) == 2),
            ("API policy spec has no extra fields", set(as_dict(egress.get("spec"))) == {"podSelector", "policyTypes", "egress"}),
            ("backend policy spec has no extra fields", set(as_dict(ingress.get("spec"))) == {"podSelector", "policyTypes", "ingress"}),
            ("API egress selects API and Egress", nested(egress, "spec", "podSelector", "matchLabels") == {"app": "demo-api"} and nested(egress, "spec", "policyTypes") == ["Egress"]),
            ("backend ingress selects backend and Ingress", nested(ingress, "spec", "podSelector", "matchLabels") == {"app": "demo-backend"} and nested(ingress, "spec", "policyTypes") == ["Ingress"]),
            ("API allows only backend TCP/8081 and DNS UDP/TCP 53", nested(egress, "spec", "egress") == [
                {"to": [{"podSelector": {"matchLabels": {"app": "demo-backend"}}}], "ports": [{"protocol": "TCP", "port": 8081}]},
                {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}}, "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}], "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}]},
            ]),
            ("backend allows only API TCP/8081", nested(ingress, "spec", "ingress") == [{"from": [{"podSelector": {"matchLabels": {"app": "demo-api"}}}], "ports": [{"protocol": "TCP", "port": 8081}]}]),
        ])
        print("F3 ENFORCEMENT: BLOCKED / NOT VERIFIED — static policy fields cannot prove dataplane enforcement")
    else:
        print("INSECURE PROFILE: declarative baseline comparison completed; static PASS is not a hardened security PASS")
        print("F3 ENFORCEMENT: BLOCKED / NOT VERIFIED — historical reachability is not a current runtime probe")


def runtime_blockers(profile):
    for label, detail in [
        ("FUNCTIONAL RUNTIME", "health, backend data, repeated API data/cache and probe behavior not run"),
        ("F1 RUNTIME", "actual PID 1 authority, mounts and /app write not run"),
        ("F2 CREDENTIAL", "process-accessible workload credential projection not assessed"),
        ("F2 AUTHORIZATION", "applicable effective grants not assessed; impersonated can-i alone would be supporting authorization-model evidence"),
        ("F2 API BEHAVIOR", "bounded named GET/PATCH in the actual API workload context not run"),
        ("F3 ENFORCEMENT", "fresh positive and negative Pod-to-Service traffic and DNS not run"),
    ]:
        result(label, "BLOCKED", detail)


def main():
    if ARGS == ["--historical-summary"]:
        claims = historical_mapping()
        if claims is not None:
            for claim in claims:
                print(f"HISTORICAL {claim['id']} | {claim['phase_profile']} | {claim['status']}")
                for source in claim["sources"]:
                    print(f"  SOURCE: {source}")
                print(f"  LIMITATION: {claim['limitation']}")
            result("HISTORICAL MAPPING", "PASS", f"rendered {len(claims)} reviewed historical claims")
        return finish("historical-summary", rendered=True)

    if ARGS in (["--offline"], ["--offline", "insecure"], ["--offline", "hardened"]):
        profile = ARGS[1] if len(ARGS) == 2 else "hardened"
        static_checks(profile)
        return finish("offline")

    if ARGS in (["insecure"], ["hardened"]):
        static_checks(ARGS[0])
        runtime_blockers(ARGS[0])
        return finish(ARGS[0])

    return invalid_arguments()


try:
    sys.exit(main())
except Exception as exc:
    result("HARNESS", "INFRASTRUCTURE ERROR", f"unrecoverable internal error: {type(exc).__name__}: {exc}")
    sys.exit(finish("internal error"))
PY
