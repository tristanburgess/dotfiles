#!/usr/bin/env bash
# Verify Claude Code and Codex permission lists are semantically equivalent.
# Extracts command names from both files and diffs them.
# Exit 0 = in sync. Exit 1 = drift detected.
#
# Usage:
#   ./check-permissions.sh
#   Wire into pre-commit or CI.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SETTINGS="${REPO_ROOT}/home/dot_claude/modify_settings.json.sh.tmpl"
RULES="${REPO_ROOT}/home/dot_codex/rules/default.rules.tmpl"

# Extract allowed command prefixes from Claude settings.json allow list.
# Parses the MANAGED JSON block, reads "allow" array, extracts first token of Bash(...) entries.
claude_allow() {
  python3 - "$SETTINGS" <<'PYEOF'
import sys, re, json

text = open(sys.argv[1]).read()
# Extract the JSON literal between MANAGED=' and the closing '
m = re.search(r"MANAGED='\s*(\{.*?\})\s*'", text, re.DOTALL)
if not m:
    sys.exit("Could not find MANAGED JSON block")
data = json.loads(m.group(1).replace("{{ $home }}", "/home/x"))
for entry in data.get("permissions", {}).get("allow", []):
    bm = re.match(r'Bash\(([^)*\s]+)', entry)
    if bm:
        print(bm.group(1))
PYEOF
}

# Extract allowed command prefixes from Codex prefix_rules.
# Reads lines containing both pattern = [...] and decision = "allow".
codex_allow() {
  python3 - "$RULES" <<'PYEOF'
import sys, re

for line in open(sys.argv[1]):
    if 'decision = "allow"' not in line:
        continue
    m = re.search(r'pattern\s*=\s*\[.*?"([^"]+)"', line)
    if m:
        print(m.group(1))
PYEOF
}

CLAUDE=$(claude_allow | sort -u)
CODEX=$(codex_allow | sort -u)

DIFF=$(diff <(echo "$CLAUDE") <(echo "$CODEX") || true)

if [[ -n "$DIFF" ]]; then
  echo "Permissions drift detected between settings.json and default.rules:" >&2
  echo "$DIFF" >&2
  echo "" >&2
  echo "Update home/dot_codex/rules/default.rules.tmpl to match" >&2
  echo "home/dot_claude/modify_settings.json.sh.tmpl (or vice versa)." >&2
  exit 1
fi

echo "Permissions in sync."
