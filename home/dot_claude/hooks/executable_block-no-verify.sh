#!/bin/bash
# PreToolUse hook: block --no-verify and --no-gpg-sign flags.
# These bypass pre-commit, commit-msg, and pre-push hooks which are
# a security boundary.

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

[ "$TOOL" = "Bash" ] || exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

if echo "$CMD" | grep -qE -- '--no-verify|--no-gpg-sign'; then
  echo "Blocked: --no-verify and --no-gpg-sign bypass security hooks. Fix the underlying issue instead."
  exit 2
fi

exit 0
