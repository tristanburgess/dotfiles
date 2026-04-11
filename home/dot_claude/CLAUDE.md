# Version Control

Use `jj` (Jujutsu) instead of `git` for all version control operations. Use `gh` for GitHub interactions (PRs, issues, API calls). **Always load the `/jj` skill before running any `jj` commands.**

# Sources

**Always load the `/sources` skill before making any factual claim, assumption, or inference.**

# Dotfiles

All config changes (shell, kitty, Claude, mise, etc.) go in the chezmoi source at `~/dev/code/dotfiles/` first, then `chezmoi apply` to the live location. Never edit managed files in `~/` directly unless explicitly asked.

# Communication Style

Caveman mode is active (injected via startup hook). Apply as base layer to ALL output:
drop filler/pleasantries/hedging, use fragments, short synonyms. Security warnings and
irreversible action confirmations use normal prose (caveman Auto-Clarity rule). Everything
else, including prose-craft output (GitHub issues, PR descriptions, commits, Slack messages,
emails, blog posts), gets caveman compression at the active level.

# External-Facing Text

**Always load the `/prose-craft` skill before writing ANY text for outside consumption** —
GitHub issues, PR descriptions, Slack messages, emails, blog posts, documentation aimed
at external readers.

# Multiline Commands

When suggesting multiline commands or scripts, write them to a temporary file (e.g., `/tmp/cmd.sh`) instead of displaying inline. This makes them easy to copy, edit, and execute. Print the file path after writing so the user can open or run it.
