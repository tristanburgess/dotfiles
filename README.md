# dotfiles

Dev environment bootstrap for Ubuntu-compatible x64 distros (Ubuntu, Linux Mint, Pop!_OS, elementary OS, etc.) and Windows 11 (with WSL2 Ubuntu). Managed by [chezmoi](https://www.chezmoi.io/).

![Kitty terminal with tiling layout, Starship prompt, and Claude Code with status bar](assets/dotfiles.png)

## Highlights

- **Click-to-focus notifications** -- Claude Code tasks send desktop notifications that jump to the correct terminal window when clicked, and auto-dismiss when you're already looking at it

  ![Claude Code notification with click-to-focus](assets/claude-noti.png)

- **Smart VCS prompt** -- Starship shows jj change IDs with nearest ancestor bookmark, or git branch with short hash on detached HEAD. Modified status at a glance, no duplicate indicators in colocated repos
- **Per-project tab coloring** -- each Claude Code session gets a unique Kitty tab color so you can tell projects apart instantly
- **Rich status line** -- Claude Code status bar shows VCS state, context window usage with blue-to-red gradient, rate limit indicators, and monthly budget tracking. Adapted from [andrewburgess/dotfiles](https://github.com/andrewburgess/dotfiles)

  ![Claude Code status bar with VCS state, context gradient, and budget tracking](assets/statusbar.png)

## What's included

### Tools (managed by [mise](https://mise.jdx.dev/))

All developer tools are installed and kept up to date by [mise](https://mise.jdx.dev/), a polyglot runtime/tool version manager:

- **[Kitty](https://sw.kovidgoyal.net/kitty/)** terminal with Adventure Time theme, tiling layouts, and tuned performance
- **[Starship](https://starship.rs/)** prompt with [Jujutsu (jj)](https://jj-vcs.github.io/jj/) change/bookmark display, git fallback, k8s context, and language version indicators
- **[Neovim](https://neovim.io/)** with [kitty-scrollback.nvim](https://github.com/mikesmithgh/kitty-scrollback.nvim) for easy copy/paste from terminal scrollback
- **[Jujutsu (jj)](https://jj-vcs.github.io/jj/)** version control with [difftastic](https://difftastic.wilfred.me/) structural diffs
- **[GitHub CLI (gh)](https://cli.github.com/)** for PRs, issues, and API calls
- **[zoxide](https://github.com/ajr-f0/zoxide)** for fast directory jumping (`z`)
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** AI coding assistant
- **[Bun](https://bun.sh/)** JavaScript runtime (used by Claude Code status line)
- **[Go](https://go.dev/)**, **[Rust](https://www.rust-lang.org/)**, **[Python 3](https://www.python.org/)**, **[Node.js](https://nodejs.org/)** (LTS)
- **[jq](https://jqlang.github.io/jq/)** for JSON processing

### Configs

- **[JetBrainsMono Nerd Font](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/JetBrainsMono)** for ligatures and icons
- **Claude Code** hooks and customizations:
  - `/jj` skill -- Jujutsu workflow reference loaded automatically during version control operations
  - Click-to-focus desktop notifications with response preview and auto-dismiss
  - Per-project Kitty tab coloring on session start
  - Status line with VCS info, context window gradient bar, rate limit dots, and monthly budget tracker
- **Automated dependency updates** via [Renovate](https://docs.renovatebot.com/) -- tool versions are pinned in [`mise config`](home/dot_config/mise/config.toml) and Renovate opens PRs with changelogs when new releases are available. Patch/minor updates auto-merge; major updates require manual review

## Usage

### Fresh install

```bash
# Install chezmoi and apply dotfiles in one command
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply tristanburgess/dotfiles
```

Or if you prefer to clone manually:

```bash
git clone git@github.com:tristanburgess/dotfiles.git
chezmoi init --source dotfiles/ --apply
```

On first run, chezmoi prompts for your name and email (used in jj/git config). After install:

```bash
source ~/.bashrc
gh auth login
claude  # authenticate Claude Code
```

To enable [signed commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification) (required by branch protection), generate an SSH key and add it to GitHub as a signing key:

```bash
ssh-keygen -t ed25519 -C "your@email.com"
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "signing key"
chezmoi apply  # re-apply to pick up the signing config in jj
```

If `~/.ssh/id_ed25519.pub` exists when chezmoi runs, jj is automatically configured to sign all commits.

Then open a new Kitty terminal.

### Windows 11 setup

This repo supports three targets: Linux bare metal, WSL2 Ubuntu, and Windows-native (Git Bash + winget). On Windows the daily-driver shell is **Kitty running as a WSLg GUI app inside WSL2 Ubuntu** — pinned to the Windows taskbar — so the existing kitty-scrollback, auto-tiling, and `kitty @` setup all keep working. A thin Windows-native side hosts Claude Code, rustup-MSVC, and the rest for the **energybeam** Rust/MSVC desktop app, where building over `/mnt/c` from WSL would be 5-20× slower than building on the native Windows filesystem.

#### Prerequisites

- Windows 11 (or Windows 10 build 19044+) with vGPU driver for WSLg
- [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (preinstalled on Win10/11)
- Git for Windows: `winget install Git.Git`
- chezmoi: `winget install twpayne.chezmoi`

The chicken/egg above is unavoidable — chezmoi needs Git Bash to run `.sh` modify scripts.

#### Step 1 — Apply Windows-native dotfiles

Open Git Bash:

```bash
chezmoi init --apply tristanburgess/dotfiles
```

This runs the winget package installer, the WSL bootstrap, and writes a Git Bash `~/.bashrc` with starship/gh/jj integrations.

#### Step 2 — Initialize WSL Ubuntu

If WSL was newly installed, reboot first. Then:

```powershell
wsl -d Ubuntu
# set username/password on first launch, then inside Ubuntu:
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply tristanburgess/dotfiles
```

This runs the full Linux setup (apt, mise, kitty, fonts, starship) — WSL-specific items like the kernel-module pcspkr disable and the Cinnamon DND shortcut are gated off automatically.

#### Step 3 — Pin Kitty to the Windows taskbar

WSLg auto-registers `kitty.desktop` as a Start menu entry. Search "kitty" in the Start menu, right-click → Pin to taskbar. The .lnk lives at `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Ubuntu\kitty.lnk`.

#### Step 4 (optional) — BurntToast for Windows-native Claude notifications

In a regular PowerShell window:

```powershell
Install-Module -Name BurntToast -Scope CurrentUser
```

This is a one-time manual step — module install requires an interactive trust prompt that chezmoi can't drive.

#### Trade-offs to know

- **Kitty is not the Windows 11 default-terminal handler.** It's a WSLg GUI app, not a ConHost-compatible terminal, so File Explorer "Open in Terminal" still goes to Windows Terminal/conhost. The trade-off bought back kitty-scrollback.nvim, auto-tiling layouts, and `kitty @` remote control.
- **For energybeam, run `claude` from Windows-native Git Bash**, not from WSL Kitty. Building `cargo` over `/mnt/c` is 5-20× slower than building on the native Windows filesystem.
- **mise is Linux-only.** Windows version pinning is handled by winget. Revisit if energybeam needs strict toolchain pinning.

### Updating configs

Edit files under `home/` using chezmoi naming conventions, then:

```bash
chezmoi apply    # deploy changes to ~
chezmoi diff     # preview what would change
```

Or edit deployed files directly and pull changes back:

```bash
chezmoi re-add   # update source from deployed files
```

## Tool updates

Tool versions are pinned in [`home/dot_config/mise/config.toml`](home/dot_config/mise/config.toml) and deployed by chezmoi. [Renovate](https://docs.renovatebot.com/modules/manager/mise/) monitors upstream releases and opens PRs with changelogs and release notes. Patch and minor updates auto-merge; major version bumps require manual review.

When you pull a version bump (via `chezmoi update` or merging a Renovate PR), chezmoi detects the config change and re-runs `mise install` to upgrade the affected tools.

To install Renovate on your fork, add the free [Mend Renovate GitHub App](https://github.com/apps/renovate).

## Structure

```
dotfiles/
├── .chezmoiroot                # points chezmoi to home/ as source root
├── home/                       # chezmoi source state
│   ├── .chezmoi.toml.tmpl      # chezmoi config (prompts + OS detection vars)
│   ├── .chezmoiignore.tmpl     # OS-conditional whole-file gating
│   ├── .chezmoiscripts/        # setup scripts (packages, fonts, shell integrations)
│   │                           # .sh.tmpl → Linux/WSL, .ps1.tmpl → Windows
│   ├── dot_config/             # → ~/.config/ (kitty, starship, jj, nvim, mise)
│   ├── dot_claude/             # → ~/.claude/ (settings, hooks, skills)
│   └── bin/                    # → ~/bin/
├── assets/                     # README screenshots
└── README.md
```
