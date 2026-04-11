# Version Control

Use `jj` (Jujutsu) instead of `git` for all version control operations. Use `gh` for GitHub interactions (PRs, issues, API calls). **Always load the `/jj` skill before running any `jj` commands.**

# Sources

**Always load the `/sources` skill before making any factual claim, assumption, or inference.**

# Dotfiles

All config changes (shell, kitty, Claude, mise, etc.) go in the chezmoi source at `~/dev/code/dotfiles/` first, then `chezmoi apply` to the live location. Never edit managed files in `~/` directly unless explicitly asked.

# Multiline Commands

When suggesting multiline commands or scripts, write them to a temporary file (e.g., `/tmp/cmd.sh`) instead of displaying inline. This makes them easy to copy, edit, and execute. Print the file path after writing so the user can open or run it.
