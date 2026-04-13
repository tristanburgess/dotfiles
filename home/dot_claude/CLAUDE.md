# Version Control

Use `jj` (Jujutsu) instead of `git` for all version control operations. Use `gh` for GitHub interactions (PRs, issues, API calls). **Always load the `/jj` skill before running any `jj` commands.**

# Sources

**Always load the `/sources` skill before making any factual claim, assumption, or inference.**

# Google Workspace

**Always load the `/gws` skill before any `gws` CLI operation** (Docs editing, Drive export, etc.).

# Dotfiles

All config changes (shell, kitty, Claude, mise, etc.) go in the chezmoi source at `~/dev/code/dotfiles/` first, then `chezmoi apply` to the live location. Never edit managed files in `~/` directly unless explicitly asked.

# Communication Style

Caveman mode active (injected via startup hook). Applies to ALL output. Security warnings
and irreversible action confirmations exempt (caveman Auto-Clarity rule).

# External-Facing Text

**Always load the `/prose-craft` skill before writing ANY text for outside consumption** —
GitHub issues, PR descriptions, design docs, Slack messages, emails, blog posts, and
any documentation with readers beyond myself (brag docs, runbooks, guides).

# Scratch & Working Files

**All temporary artifacts go in `/tmp/`, never in the repo working directory.** This includes:
- Multiline commands and scripts (`/tmp/cmd.sh`)
- Exported documents (design docs, Google Doc exports, etc.)
- Data dumps, query results, intermediate processing files
- Any file that is a working copy, not a deliverable

Why: `jj` auto-snapshots every untracked file in the repo into the current change. Writing
scratch files in the repo pollutes the working copy and commit history.

For tools that restrict output to CWD (e.g., `gws --output`), `cd /tmp` before running, then
`cd` back. Print the `/tmp/` file path after writing so it's easy to find.
