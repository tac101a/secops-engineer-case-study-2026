#!/usr/bin/env bash
# E1 offline verifier. Runtime probes are deliberately fail-closed until a later phase.
set -u

if ! command -v python3 >/dev/null 2>&1; then
  printf 'PARSER UNAVAILABLE: BLOCKED (python3 is required for structured YAML inspection)\n'
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
            ("FUNC", "B/insecure"), ("F1", "C/insecure"),
            ("F2", "C/insecure"), ("F3", "C/insecure"),
            ("FUNC", "D1/hardened-candidate"), ("F1", "D1/hardened-candidate"),
            ("FUNC", "D2/hardened-candidate"), ("F2", "D2/hardened-candidate"),
            ("FUNC", "D3/hardened-candidate"), ("F3", "D3/hardened-candidate"),
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
            if claim_id == "FUNC" and status != "FUNCTIONAL_PASS":
                raise ValueError(f"invalid functional status for {key}")
            if phase == "C/insecure" and status != "WEAKNESS_CONFIRMED":
                raise ValueError(f"invalid Phase C status for {key}")
            if claim_id != "FUNC" and phase.startswith("D") and status not in {"CANDIDATE_PASS", "CANDIDATE_FAIL"}:
                raise ValueError(f"invalid candidate status for {key}")
            sources = claim["sources"]
            if not isinstance(sources, list) or not sources or len(sources) != len(set(map(str, sources))):
                raise ValueError(f"sources missing or duplicated for {key}")
            for source in sources:
                if not isinstance(source, str) or not re.fullmatch(r"docs/[A-Za-z0-9._/-]+", source):
                    raise ValueError(f"unsafe source path for {key}")
                source_path = (ROOT / source).resolve()
                if not source_path.is_relative_to(docs) or not source_path.is_file():
                    raise ValueError(f"canonical source unavailable or outside docs: {source}")
        if seen != expected:
            raise ValueError(f"missing curated claim(s): {sorted(expected - seen)}")
        return claims
    except (OSError, UnicodeError, ValueError, TypeError) as exc:
        result("HISTORICAL MAPPING", "INFRASTRUCTURE ERROR", f"malformed or inconsistent mapping: {exc}")
        return None


def load_yaml(paths):
    try:
        import yaml
    except ImportError as exc:
        result("YAML PARSER", "BLOCKED", f"PARSER UNAVAILABLE: safe structured YAML loader missing ({exc}); install nothing during E1")
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


def static_checks(profile):
    insecure = [
        "task1/insecure/namespace.yaml", "task1/insecure/rbac.yaml",
        "task1/insecure/demo-api.yaml", "task1/insecure/demo-backend.yaml",
    ]
    hardened = ["task1/hardened/demo-api.yaml", "task1/hardened/identity.yaml", "task1/hardened/network-policy.yaml"]
    baseline = load_yaml(insecure)
    if baseline is None:
        for label in ("F1 STATIC", "F2 STATIC", "F3 STATIC"):
            result(label, "BLOCKED", "selected YAML could not be inspected")
        return
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
        tmp_mount = any(isinstance(m, dict) and m.get("name") == "api-tmp" and m.get("mountPath") == "/tmp" for m in mounts) if isinstance(mounts, list) else False
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
            ("API Pod does not override automount to true", api_template.get("automountServiceAccountToken") is not True),
            ("backend Pod does not override automount to true", backend_template.get("automountServiceAccountToken") is not True),
            ("named fixture Role absent from hardened set", not any(k[0] == "Role" and k[2] == "demo-api-fixture-access" for k in candidate)),
            ("named fixture RoleBinding absent from hardened set", not any(k[0] == "RoleBinding" and k[2] == "demo-api-fixture-access" for k in candidate)),
        ])
        egress = obj(objects, "NetworkPolicy", "demo-api-egress")
        ingress = obj(objects, "NetworkPolicy", "demo-backend-ingress")
        policy_keys = [key for key in objects if key[0] == "NetworkPolicy"]
        check("F3 STATIC", [
            ("exactly two selected policies", set(policy_keys) == {("NetworkPolicy", "secops-demo", "demo-api-egress"), ("NetworkPolicy", "secops-demo", "demo-backend-ingress")}),
            ("API egress selects API and Egress", nested(egress, "spec", "podSelector", "matchLabels") == {"app": "demo-api"} and nested(egress, "spec", "policyTypes") == ["Egress"]),
            ("backend ingress selects backend and Ingress", nested(ingress, "spec", "podSelector", "matchLabels") == {"app": "demo-backend"} and nested(ingress, "spec", "policyTypes") == ["Ingress"]),
            ("API allows only backend TCP/8081 and DNS UDP/TCP 53", nested(egress, "spec", "egress") == [
                {"to": [{"podSelector": {"matchLabels": {"app": "demo-backend"}}}], "ports": [{"protocol": "TCP", "port": 8081}]},
                {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}}, "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}], "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}]},
            ]),
            ("backend allows only API TCP/8081", nested(ingress, "spec", "ingress") == [{"from": [{"podSelector": {"matchLabels": {"app": "demo-api"}}}], "ports": [{"protocol": "TCP", "port": 8081}]}]),
        ])
    else:
        check("F1 STATIC", [
            ("insecure API uses phase-b image", api_container.get("image") == "secops-demo-api:phase-b"),
            ("insecure API declares writable root", nested(context, "readOnlyRootFilesystem") is False),
            ("insecure API has no nonroot restriction", nested(context, "runAsNonRoot") is not True),
        ])
        check("F2 STATIC", [
            ("insecure API ServiceAccount automounts token", obj(objects, "ServiceAccount", "demo-api").get("automountServiceAccountToken") is True),
            ("insecure fixture Role exists", bool(obj(objects, "Role", "demo-api-fixture-access"))),
            ("insecure fixture RoleBinding exists", bool(obj(objects, "RoleBinding", "demo-api-fixture-access"))),
        ])
        check("F3 STATIC", [("insecure profile declares no NetworkPolicy", not any(key[0] == "NetworkPolicy" for key in objects))])


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
