# dotfiles

Dev environment bootstrap for Linux Mint. One script installs and configures everything.

## What's included

- **Kitty** terminal with Adventure Time theme, tiling layouts, and tuned performance
- **Starship** prompt with Jujutsu (jj) change/bookmark display, git fallback, k8s context, and language version indicators
- **JetBrainsMono Nerd Font** for ligatures and icons
- **Jujutsu (jj)** version control
- **Git** + **GitHub CLI** (gh)
- **Go**, **Rust**, **Python 3**, **Node.js** (via nvm)
- **Claude Code** with custom notification hooks (click-to-focus, auto-dismiss, sound) and per-project tab coloring

## Usage

```bash
git clone <this-repo> ~/dev/code/dotfiles
cd ~/dev/code/dotfiles
chmod +x install.sh
./install.sh
```

After install, complete the manual steps:

```bash
gh auth login
claude  # authenticate Claude Code
```

Then open a new Kitty terminal.

## Updating configs

Edit the files under `configs/`, then re-run `./install.sh` — it will overwrite the deployed copies. Tool installations are skipped if already present.
