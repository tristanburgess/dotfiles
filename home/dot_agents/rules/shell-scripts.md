---
globs: "*.sh,*.bash,.chezmoiscripts/**"
description: Shell script conventions
---

- Always start scripts with `set -euo pipefail`
- Quote all variable expansions: `"$VAR"`, not `$VAR`
- Use `[[ ]]` over `[ ]` for conditionals in bash scripts
- Prefer `printf` over `echo` for portable output
- Run `shellcheck` mentally before finalizing — avoid SC2086, SC2046, SC2035
- Use `local` for function variables to avoid leaking into global scope
- Prefer `$(command)` over backticks
