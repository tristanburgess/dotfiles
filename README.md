# dotfiles

Dev environment bootstrap for Linux Mint. One script installs and configures everything.

![Kitty terminal with tiling layout, Starship prompt, and Claude Code](assets/dotfiles.png)

## Highlights

- **Click-to-focus notifications** -- Claude Code tasks send desktop notifications that jump to the correct terminal window when clicked, and auto-dismiss when you're already looking at it

  ![Claude Code notification with click-to-focus](assets/claude-noti.png)

- **Smart VCS prompt** -- Starship shows jj change IDs with nearest ancestor bookmark, or git branch with short hash on detached HEAD. Modified status at a glance, no duplicate indicators in colocated repos
- **Per-project tab coloring** -- each Claude Code session gets a unique Kitty tab color so you can tell projects apart instantly

## What's included

- **[Kitty](https://sw.kovidgoyal.net/kitty/)** terminal with Adventure Time theme, tiling layouts, and tuned performance
- **[Starship](https://starship.rs/)** prompt with [Jujutsu (jj)](https://jj-vcs.github.io/jj/) change/bookmark display, git fallback, k8s context, and language version indicators
- **[Neovim](https://neovim.io/)** with [kitty-scrollback.nvim](https://github.com/mikesmithgh/kitty-scrollback.nvim) for easy copy/paste from terminal scrollback
- **[JetBrainsMono Nerd Font](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/JetBrainsMono)** for ligatures and icons
- **[Jujutsu (jj)](https://jj-vcs.github.io/jj/)** version control
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

Edit the files under `configs/`, then re-run `./install.sh` -- it will overwrite the deployed copies. Tool installations are skipped if already present.
