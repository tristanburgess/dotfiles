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
MAX_SIZE=10485760  # 10 MiB

# Rotate when the live log exceeds MAX_SIZE. Single-generation rotation
# (.1) is enough for incident review; older history lives in `git` /
# project-level audit if needed.
if [ -f "$LOG" ]; then
    SIZE=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
    if [ "$SIZE" -gt "$MAX_SIZE" ]; then
        mv "$LOG" "$LOG.1"
    fi
fi

echo "$(date -Iseconds) [$(pwd)] $CMD" >> "$LOG"

exit 0
