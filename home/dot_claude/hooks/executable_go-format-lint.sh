#!/bin/bash
# PostToolUse: auto-format .go files and surface lint issues to Claude.
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -z "$FILE" ]] && exit 0
[[ "$FILE" == *.go ]] || exit 0
[[ -f "$FILE" ]] || exit 0

# Format in-place (gofmt is always available from the Go toolchain)
gofmt -w "$FILE" 2>/dev/null || true

# Run golangci-lint on the package; exit 2 surfaces stderr to Claude (non-blocking)
if command -v golangci-lint &>/dev/null; then
    PKG_DIR=$(dirname "$FILE")
    LINT_OUT=$(cd "$PKG_DIR" && golangci-lint run . 2>&1 || true)
    if [[ -n "$LINT_OUT" ]]; then
        printf "%s\n" "$LINT_OUT" >&2
        exit 2
    fi
fi

exit 0
