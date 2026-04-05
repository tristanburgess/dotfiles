---
name: jj
description: Jujutsu (jj) version control workflows — bookmarks, squashing, rebasing, GitHub PR creation, and the golden rule about not rewriting pushed commits. Use when doing any version control operation.
---

# Jujutsu (jj) Version Control

Use `jj` instead of `git` for all version control operations. Use `gh` for GitHub interactions (PRs, issues, API calls).

## Key concepts

- No staging area — the working copy is automatically snapshotted into the current change.
- Branches are called "bookmarks" (`jj bookmark`).
- Start work with `jj new`, then `jj describe` to set intent before editing. `jj commit` is a shortcut for `jj describe` + `jj new` when you haven't set intent yet.
- Remote ops: `jj git push` / `jj git fetch`.
- View history: `jj log`, `jj diff`, `jj st`.
- Conflicts are materialized in the working copy — edit files directly to resolve.
- Every command is recorded in an operation log — `jj undo` reverses the last operation, `jj op log` shows history.
- No merge command — `jj new A B C` creates a change with multiple parents.

## Revsets quick reference

| Expression | Meaning |
|-----------|---------|
| `@` | Current working copy change |
| `@-` | Parent of `@` |
| `rev+` | First child of `rev` |
| `A..B` | Commits after A up to and including B |
| `::rev` | All ancestors of `rev` |
| `rev::` | All descendants of `rev` |
| `trunk()` | Main/master branch |
| `mutable()` | Non-immutable commits |
| `stack()` | Current stack of mutable changes |

## Golden rule: never rewrite already-pushed commits

Rewriting (squash, edit, rebase) changes the git hash -> force-push. Since repos typically squash-merge PRs, adding commits during review is fine.

| Command | When to use |
|---------|-------------|
| `jj new <rev>` | Most work — start a new change on top of an existing one |
| `jj squash` | Fold `@` into parent — **only for unpushed changes** |
| `jj rebase -d main` | Update base after main changes (unavoidable force-push) |
| `jj edit <rev>` | Quick fix to an unpushed change in-place |
| `jj split` | Interactively break `@` into multiple changes |
| `jj abandon` | Remove changes from history (defaults to `@`) |
| `jj restore --from <rev> <path>` | Restore a file from a previous change |
| `jj absorb` | Auto-distribute hunks in `@` into the ancestor that last touched those lines |

## GitHub PR workflow

### Adding commits to an existing PR (preferred — avoids force-push):
1. `jj git fetch`
2. `jj new <bookmark>` -> make changes -> `jj describe`
3. `jj bookmark set <name> -r @` (track first if needed: `jj bookmark track <name>@origin`)
4. `jj git push --bookmark <name>` (fast-forward; uses force-with-lease automatically)

### Creating PRs with `gh`

`jj` doesn't check out git branches, so always specify `--head` and `--base`:

```bash
gh pr create --head <bookmark-name> --base main --title "..." --body "..."
```
