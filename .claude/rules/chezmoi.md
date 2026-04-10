---
globs: "home/**,**/.chezmoiscripts/**"
description: Chezmoi dotfiles conventions
---

- Files targeting `~/.foo` live at `home/dot_foo` (chezmoi `dot_` prefix)
- Executable scripts use `executable_` prefix (e.g., `executable_notify.sh`)
- Modify scripts (like `modify_settings.json`) read current target from stdin and write merged result to stdout
- Templates use `.tmpl` suffix and Go template syntax with chezmoi's data/functions
- Run scripts in `.chezmoiscripts/` use `run_onchange_` or `run_once_` prefixes
- Test changes with `chezmoi diff` before `chezmoi apply`
- Never edit files in `~/.claude/` directly when a chezmoi source exists — edit the source in this repo instead
