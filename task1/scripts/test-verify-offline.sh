#!/usr/bin/env bash
# Exercises the real verifier against copies of its selected source files.
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" || exit 3
real_python="$(command -v python3)" || { printf 'SELF-TEST BLOCKED: python3 unavailable\n'; exit 2; }
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/e1-offline-test.XXXXXXXX")" || exit 3
trap 'rm -rf -- "$tmp_root"' EXIT
base="$tmp_root/base"
guard_log="$tmp_root/runtime-calls.txt"
mkdir -p "$base/task1/scripts" "$base/task1/insecure" "$base/task1/hardened/images" "$base/docs/evidence/phase-e" "$tmp_root/shims" "$tmp_root/parser-shim"
: > "$guard_log"
cp "$repo_root/task1/scripts/verify.sh" "$base/task1/scripts/verify.sh"
for source in namespace.yaml rbac.yaml demo-api.yaml demo-backend.yaml; do
  cp "$repo_root/task1/insecure/$source" "$base/task1/insecure/$source"
done
for source in demo-api.yaml identity.yaml network-policy.yaml; do
  cp "$repo_root/task1/hardened/$source" "$base/task1/hardened/$source"
done
cp "$repo_root/task1/hardened/images/demo-api.Dockerfile" "$base/task1/hardened/images/demo-api.Dockerfile"
cp "$repo_root/docs/evidence/phase-e/e1-historical-claims.md" "$base/docs/evidence/phase-e/e1-historical-claims.md"
"$real_python" -I -B - "$repo_root" "$base" <<'PY'
import json
import shutil
import sys
from pathlib import Path
source_root, fixture_root = map(Path, sys.argv[1:])
content = (fixture_root / "docs/evidence/phase-e/e1-historical-claims.md").read_text()
payload = content.split("<!-- E1-HISTORICAL-CLAIMS-JSON-BEGIN -->", 1)[1].split("<!-- E1-HISTORICAL-CLAIMS-JSON-END -->", 1)[0].strip()
claims = json.loads(payload[len("```json\n"):-len("\n```")])["claims"]
for relative in {item for claim in claims for item in claim["sources"]}:
    destination = fixture_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source_root / relative, destination)
PY
if (( $? != 0 )); then printf 'SELF-TEST BLOCKED: fixture setup failed\n'; exit 2; fi

cat > "$tmp_root/shims/runtime-tool" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "UNEXPECTED RUNTIME CALL: ${0##*/} $*" >> "$E1_GUARD_LOG"
exit 99
SH
for tool in docker kubectl nft node kind iptables; do
  cp "$tmp_root/shims/runtime-tool" "$tmp_root/shims/$tool"
done
chmod +x "$tmp_root/shims/"*

# This wrapper injects an import failure for yaml into the verifier's stdin program.
# It is used only for the parser-unavailable case and never contacts a runtime tool.
cat > "$tmp_root/parser-shim/python3" <<'SH'
#!/usr/bin/env bash
{
  printf '%s\n' 'import builtins' '_e1_import = builtins.__import__' 'def _e1_no_yaml(name, *args, **kwargs):' '    if name == "yaml" or name.startswith("yaml."):' '        raise ImportError("simulated unavailable YAML parser")' '    return _e1_import(name, *args, **kwargs)' 'builtins.__import__ = _e1_no_yaml'
  cat
} | "$E1_REAL_PYTHON" "$@"
SH
chmod +x "$tmp_root/parser-shim/python3"

export E1_GUARD_LOG="$guard_log" E1_REAL_PYTHON="$real_python"
safe_path="$tmp_root/shims:$PATH"
parser_missing_path="$tmp_root/parser-shim:$safe_path"
failures=0
passed=0
OUTPUT=''
RC=0

invoke() {
  local fixture="$1" path="$2"
  shift 2
  OUTPUT="$(PATH="$path" "$fixture/task1/scripts/verify.sh" "$@" 2>&1)"
  RC=$?
}

contains() { [[ "$OUTPUT" == *"$1"* ]]; }
guard_clear() { [[ ! -s "$guard_log" ]]; }

record() {
  local id="$1" name="$2" outcome="$3" line
  if [[ "$outcome" == PASS ]]; then ((passed += 1)); else ((failures += 1)); fi
  printf '%s %s — %s (exit %s)\n' "$id" "$name" "$outcome" "$RC"
  while IFS= read -r line; do
    case "$line" in
      'F1 STATIC:'*|'F2 STATIC:'*|'F3 STATIC:'*|'F3 ENFORCEMENT:'*|'YAML PARSER:'*|'HISTORICAL MAPPING:'*|'RUNTIME REQUEST:'*|'INSECURE PROFILE:'*|'CURRENT CLUSTER STATE:'*|'POSSIBLE DIAGNOSTIC RESIDUE:'*|'CURRENT RUNTIME VERIFICATION:'*|'FULL AFTER RESULT:'*|'MODE RESULT:'*|'MODE EXIT:'*) printf '  %s\n' "$line" ;;
    esac
  done <<< "$OUTPUT"
  if [[ "$outcome" != PASS ]]; then printf '  FULL OUTPUT: %s\n' "$OUTPUT"; fi
}

copy_fixture() { cp -R "$base" "$tmp_root/$1"; }

mutate_yaml() {
  "$real_python" -I -B - "$1" "$2" <<'PY'
import sys
from pathlib import Path
import yaml
path, variant = Path(sys.argv[1]), sys.argv[2]
documents = list(yaml.safe_load_all(path.read_text()))
if variant == "f1":
    documents[0]["spec"]["template"]["spec"]["containers"][0]["securityContext"]["runAsNonRoot"] = False
elif variant == "f2":
    documents[0]["automountServiceAccountToken"] = True
elif variant == "f3":
    documents[0]["spec"]["egress"][0]["to"] = [{}]
elif variant == "token":
    spec = documents[0]["spec"]["template"]["spec"]
    spec["volumes"].append({"name": "injected-token", "projected": {"sources": [{"serviceAccountToken": {"path": "token"}}]}})
    spec["containers"][0]["volumeMounts"].append({"name": "injected-token", "mountPath": "/var/run/secrets/kubernetes.io/serviceaccount"})
else:
    raise ValueError(variant)
path.write_text(yaml.safe_dump_all(documents, sort_keys=False))
PY
}

invoke "$base" "$parser_missing_path" --help
if (( RC == 0 )) && contains 'No arguments select --offline hardened' && guard_clear; then record 01 'help is offline' PASS; else record 01 'help is offline' FAIL; fi

invoke "$base" "$safe_path"
if (( RC == 0 )) && contains 'F1 STATIC: PASS' && contains 'F2 STATIC: PASS' && contains 'F3 STATIC: PASS' && contains 'FULL AFTER RESULT: BLOCKED' && guard_clear; then record 02 'no arguments use safe offline mode' PASS; else record 02 'no arguments use safe offline mode' FAIL; fi

invoke "$base" "$safe_path" --offline hardened
if (( RC == 0 )) && contains 'F1 STATIC: PASS' && contains 'F2 STATIC: PASS' && contains 'F3 STATIC: PASS'; then record 03 'valid hardened static set' PASS; else record 03 'valid hardened static set' FAIL; fi

copy_fixture weak_f1
mutate_yaml "$tmp_root/weak_f1/task1/hardened/demo-api.yaml" f1
invoke "$tmp_root/weak_f1" "$safe_path" --offline hardened
f1_rc="$RC"
if (( RC == 1 )) && contains 'F1 STATIC: FAIL' && contains 'runAsNonRoot is true'; then record 04 'weakened F1' PASS; else record 04 'weakened F1' FAIL; fi

copy_fixture weak_f2
mutate_yaml "$tmp_root/weak_f2/task1/hardened/identity.yaml" f2
invoke "$tmp_root/weak_f2" "$safe_path" --offline hardened
if (( RC == 1 )) && contains 'F2 STATIC: FAIL' && contains 'API ServiceAccount automount is false'; then record 05 'weakened F2' PASS; else record 05 'weakened F2' FAIL; fi

copy_fixture weak_f3
mutate_yaml "$tmp_root/weak_f3/task1/hardened/network-policy.yaml" f3
invoke "$tmp_root/weak_f3" "$safe_path" --offline hardened
if (( RC == 1 )) && contains 'F3 STATIC: FAIL' && contains 'API allows only backend TCP/8081 and DNS UDP/TCP 53'; then record 06 'broadened F3 policy' PASS; else record 06 'broadened F3 policy' FAIL; fi

invoke "$base" "$safe_path" --offline hardened
normal_output="$OUTPUT" normal_rc="$RC"
invoke "$base" "$parser_missing_path" --offline hardened
# The PATH here contains the Python shim; its import hook makes PyYAML unavailable.
if (( RC == 2 )) && contains 'YAML PARSER: BLOCKED' && contains 'F1 STATIC: BLOCKED' && contains 'FULL AFTER RESULT: BLOCKED' && guard_clear; then record 07 'unavailable safe YAML parser' PASS; else record 07 'unavailable safe YAML parser' FAIL; fi

printf '\nCURRENT RUNTIME VERIFICATION: PASS\nHISTORICAL F3 | D3/hardened-candidate | CANDIDATE_PASS\n' >> "$base/docs/phase-b-report.md"
invoke "$base" "$safe_path" --historical-summary
if (( RC == 0 )) && contains 'HISTORICAL F3 | D3/hardened-candidate | CANDIDATE_FAIL' && contains 'HISTORICAL F1 | D1/hardened-candidate | CANDIDATE_PASS' && contains 'MODE RESULT: HISTORICAL SUMMARY RENDERED' && contains 'CURRENT RUNTIME VERIFICATION: NOT RUN' && [[ "$OUTPUT" != *'CURRENT RUNTIME VERIFICATION: PASS'* && "$OUTPUT" != *'HISTORICAL F3 | D3/hardened-candidate | CANDIDATE_PASS'* ]]; then record 08 'curated historical summary' PASS; else record 08 'curated historical summary' FAIL; fi
historical_output="$OUTPUT"
historical_rc="$RC"

invoke "$base" "$parser_missing_path" --runtime
if (( RC == 2 )) && contains 'CURRENT CLUSTER STATE: UNKNOWN' && contains 'POSSIBLE DIAGNOSTIC RESIDUE: UNKNOWN' && contains 'FULL AFTER RESULT: BLOCKED' && guard_clear; then record 09 'runtime fails closed' PASS; else record 09 'runtime fails closed' FAIL; fi
runtime_rc="$RC"

invoke "$base" "$safe_path" --not-a-mode
if (( normal_rc == 0 && f1_rc == 1 && runtime_rc == 2 && RC == 3 && historical_rc == 0 )) && [[ "$normal_output" == *'MODE RESULT: PASS'* ]] && [[ "$historical_output" == *'HISTORICAL MAPPING: PASS'* ]]; then record 10 'distinct PASS FAIL BLOCKED invalid exit codes' PASS; else record 10 'distinct PASS FAIL BLOCKED invalid exit codes' FAIL; fi

OUTPUT="$normal_output" RC="$normal_rc"
if contains 'F3 STATIC: PASS' && contains 'F3 ENFORCEMENT: BLOCKED / NOT VERIFIED' && contains 'FULL AFTER RESULT: BLOCKED'; then record 11 'static F3 cannot become full PASS' PASS; else record 11 'static F3 cannot become full PASS' FAIL; fi

invoke "$tmp_root/weak_f1" "$safe_path" hardened
if (( RC == 1 )) && contains 'F1 STATIC: FAIL' && contains 'F3 ENFORCEMENT: BLOCKED' && contains 'MODE RESULT: FAIL'; then record 12 'FAIL outranks BLOCKED and both remain visible' PASS; else record 12 'FAIL outranks BLOCKED and both remain visible' FAIL; fi

OUTPUT="$historical_output" RC="$historical_rc"
if (( RC == 0 )) && contains 'MODE RESULT: HISTORICAL SUMMARY RENDERED' && contains 'CURRENT RUNTIME VERIFICATION: NOT RUN' && contains 'FULL AFTER RESULT: BLOCKED' && [[ "$OUTPUT" != *'CURRENT RUNTIME VERIFICATION: PASS'* ]]; then record 13 'historical mode is not current PASS' PASS; else record 13 'historical mode is not current PASS' FAIL; fi

invoke "$base" "$safe_path" --offline insecure
if (( RC == 0 )) && contains 'INSECURE PROFILE: baseline configuration identified' && contains 'F1 STATIC: PASS' && contains 'FULL AFTER RESULT: BLOCKED'; then record 14 'insecure profile correctly labeled' PASS; else record 14 'insecure profile correctly labeled' FAIL; fi

copy_fixture token_projection
mutate_yaml "$tmp_root/token_projection/task1/hardened/demo-api.yaml" token
invoke "$tmp_root/token_projection" "$safe_path" --offline hardened
if (( RC == 1 )) && contains 'F2 STATIC: FAIL' && contains 'API template has no projected token or unintended credential mount'; then record 15 'explicit token projection rejected' PASS; else record 15 'explicit token projection rejected' FAIL; fi

copy_fixture missing_mapping
rm -- "$tmp_root/missing_mapping/docs/evidence/phase-e/e1-historical-claims.md"
invoke "$tmp_root/missing_mapping" "$safe_path" --historical-summary
if (( RC == 2 )) && contains 'HISTORICAL MAPPING: BLOCKED'; then record 16 'missing curated mapping blocks' PASS; else record 16 'missing curated mapping blocks' FAIL; fi

copy_fixture malformed_mapping
"$real_python" -I -B - "$tmp_root/malformed_mapping/docs/evidence/phase-e/e1-historical-claims.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(path.read_text().replace('"schema": "e1-historical-claims/v1"', '"schema": "corrupt"', 1))
PY
invoke "$tmp_root/malformed_mapping" "$safe_path" --historical-summary
if (( RC == 3 )) && contains 'HISTORICAL MAPPING: INFRASTRUCTURE ERROR'; then record 17 'malformed curated mapping errors' PASS; else record 17 'malformed curated mapping errors' FAIL; fi

copy_fixture inconsistent_mapping
"$real_python" -I -B - "$tmp_root/inconsistent_mapping/docs/evidence/phase-e/e1-historical-claims.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(path.read_text().replace('"status": "CANDIDATE_FAIL"', '"status": "CANDIDATE_PASS"', 1))
PY
invoke "$tmp_root/inconsistent_mapping" "$safe_path" --historical-summary
if (( RC == 3 )) && contains 'HISTORICAL MAPPING: INFRASTRUCTURE ERROR' && contains 'status contradicts the reviewed historical outcome'; then record 18 'historically inconsistent mapping errors' PASS; else record 18 'historically inconsistent mapping errors' FAIL; fi

if guard_clear; then printf 'RUNTIME GUARD: PASS — no shimmed runtime tool was invoked\n'; else printf 'RUNTIME GUARD: FAIL — %s\n' "$(cat "$guard_log")"; ((failures += 1)); fi
printf 'SELF-TEST SUMMARY: %s passed, %s failed\n' "$passed" "$failures"
if (( failures != 0 )); then exit 1; fi
exit 0
