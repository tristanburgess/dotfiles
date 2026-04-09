#!/bin/bash
# PostToolUse hook: log all Bash commands for audit trail.
# Logs to ~/.claude/bash-commands.log with timestamps.

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

[ "$TOOL" = "Bash" ] || exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

LOG="$HOME/.claude/bash-commands.log"
echo "$(date -Iseconds) [$(pwd)] $CMD" >> "$LOG"

exit 0
