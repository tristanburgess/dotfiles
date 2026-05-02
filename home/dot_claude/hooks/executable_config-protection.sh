#!/bin/bash
# PreToolUse hook: block edits to linter/formatter/build config files.
# Claude will weaken configs to pass instead of fixing actual violations.

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only check Edit and Write tools
case "$TOOL" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

BASENAME=$(basename "$FILE")

# Protected config files — add to this list as needed
PROTECTED=(
  .eslintrc .eslintrc.js .eslintrc.json .eslintrc.yml .eslintrc.yaml
  eslint.config.js eslint.config.mjs eslint.config.ts
  .prettierrc .prettierrc.js .prettierrc.json .prettierrc.yml .prettierrc.yaml
  prettier.config.js prettier.config.mjs
  biome.json biome.jsonc
  .ruff.toml ruff.toml pyproject.toml
  .shellcheckrc
  .golangci.yml .golangci.yaml golangci-lint.yml
  tsconfig.json tsconfig.*.json
  .stylelintrc .stylelintrc.json .stylelintrc.yml
  .editorconfig
  .flake8 setup.cfg
  Makefile
)

for P in "${PROTECTED[@]}"; do
  # `[[ == $P ]]` performs glob matching so patterns like tsconfig.*.json
  # cover tsconfig.build.json, tsconfig.test.json, etc.
  # shellcheck disable=SC2053
  if [[ "$BASENAME" == $P ]]; then
    echo "Blocked: editing $BASENAME is not allowed. Fix the code to comply with the existing config instead of weakening the config."
    exit 2
  fi
done

exit 0
