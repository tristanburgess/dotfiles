#!/bin/bash
# Stop hook: nudge Claude to verify work before ending a turn.
# Prints a reminder that gets injected into context if Claude
# made edits during this turn.

set -euo pipefail

INPUT=$(cat)
STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // empty')

# Only nudge on end_turn (Claude chose to stop), not on user interrupt
[ "$STOP_REASON" = "end_turn" ] || exit 0

# Check if any files were modified in the last 2 minutes (proxy for "this turn")
MARKER="$HOME/.claude/.claude-turn-marker"
RECENT_EDITS=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 3 -newer "$MARKER" -name '*.go' -o -name '*.py' -o -name '*.ts' -o -name '*.js' -o -name '*.sh' 2>/dev/null | head -5)

# Refresh the marker for next turn
touch "$MARKER"

if [ -n "$RECENT_EDITS" ]; then
  printf "Reminder: verify your changes compile/pass before finishing — run build, lint, or tests if you haven't already."
fi

exit 0
