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

# Extract just the first line / actual command, ignoring heredoc body content.
# Commands like `gh pr create --body "$(cat <<'EOF' ... --no-verify ... EOF)"`
# should not be blocked — only actual git/jj flags matter.
FIRST_LINE=$(echo "$CMD" | head -1)

if echo "$FIRST_LINE" | grep -qE '(git|jj|gh|pre-commit)\b.*--no-verify'; then
  echo "Blocked: --no-verify bypasses security hooks. Fix the underlying issue instead."
  exit 2
fi

if echo "$FIRST_LINE" | grep -qE '(git|jj)\b.*--no-gpg-sign'; then
  echo "Blocked: --no-gpg-sign bypasses commit signing. Fix the underlying issue instead."
  exit 2
fi

exit 0
