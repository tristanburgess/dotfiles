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

This repo supports three targets, all from a single source tree:

| Target | Shell | Package manager | Bootstrap |
|---|---|---|---|
| **Linux bare metal** | bash + Kitty | apt + mise | curl one-liner |
| **WSL2 Ubuntu** | bash + Kitty (WSLg GUI) | apt + mise | curl one-liner |
| **Windows 11 native** | Git Bash | winget | Manual chezmoi install + Git Bash |

OS gating happens automatically — each script checks `.chezmoi.os` (and a derived `isWSL` flag) and no-ops on the wrong target.

### Linux bare metal

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply tristanburgess/dotfiles
```

This installs chezmoi to `~/.local/bin/chezmoi`, fetches this repo, prompts for name + email, and runs the full `.chezmoiscripts/` chain: apt repos and packages, mise + pinned tools, JetBrainsMono Nerd Font, pcspkr kernel-module disable, GNOME `.desktop` patching for the mise-managed Kitty, the Cinnamon DND shortcut, the Anthropic Claude Desktop `.deb`, snap packages (Slack/Spotify/Notion/Foliate), and the Discord/Zoom `.deb`s. First run takes a while.

### WSL2 Ubuntu

Same one-liner, run inside the WSL distro (after `wsl -d Ubuntu`):

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply tristanburgess/dotfiles
```

The following scripts are **gated off automatically** because they don't work or aren't useful in WSL2:

- `pcspkr-disable` — kernel module changes don't persist in WSL2
- `dnd-shortcut` and `bin/toggle-dnd.sh` — Cinnamon `gsettings` keys don't exist in WSLg
- `kitty-desktop` — WSLg auto-registers `kitty.desktop` from the Linux side, no GNOME patching needed
- `claude-desktop` (`.deb` installer) — use the Windows-native installer instead
- `snap-packages` — snapd is not supported in WSL2 by default
- `standalone-debs` (Discord/Zoom) — use the Windows-native versions

After applying, launch Kitty as a WSLg GUI app:

```bash
nohup kitty &
```

WSLg auto-creates a Start menu entry — search "kitty" in Windows Start, right-click → **Pin to taskbar**. The `.lnk` lives at `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Ubuntu\kitty.lnk`.

### Windows 11 native

A thin Windows-native side that hosts Claude Code, rustup-MSVC, neovim, jj, gh, bun, and JetBrainsMono Nerd Font for native Windows builds (e.g. Rust/MSVC desktop apps where building over `/mnt/c` from WSL is 5-20× slower than the native Windows filesystem). The daily-driver shell stays Kitty-in-WSLg from the section above.

#### Prerequisites

- Windows 11 (or Windows 10 build 19044+) with the vGPU driver for WSLg
- [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (preinstalled on Win10/11)

#### Step 1 — Install Git for Windows + chezmoi

```powershell
winget install Git.Git twpayne.chezmoi
```

This bootstrap step is unavoidable: chezmoi needs Git Bash to execute the `.sh` modify scripts (`modify_settings.json.tmpl`) and the body-wrapped `.sh.tmpl` chezmoiscripts. The repo's [`[interpreters.sh]`](home/.chezmoi.toml.tmpl) entry points chezmoi at `C:/Program Files/Git/bin/bash.exe` after that.

#### Step 2 — Apply Windows-native dotfiles

Open **Git Bash**:

```bash
chezmoi init --apply tristanburgess/dotfiles
```

This runs:
- `run_once_before_00-winget-packages.ps1` — Rustup-MSVC, Neovim, Starship, GitHub CLI, jj, Bun, Claude Code, JetBrainsMono Nerd Font
- `run_once_after_00-wsl-bootstrap.ps1` — installs WSL2 + Ubuntu if absent (may require reboot)
- `run_once_after_00-git-bash-profile.sh` — writes a Git Bash `~/.bashrc` with starship + gh + jj completions

#### Step 3 — Bootstrap WSL Ubuntu

After step 2 (and reboot if Windows prompted):

```powershell
wsl -d Ubuntu
# set username/password on first launch, then inside Ubuntu:
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply tristanburgess/dotfiles
```

Then follow the [WSL2 Ubuntu](#wsl2-ubuntu) section above for pinning Kitty to the taskbar.

#### Step 4 (optional) — BurntToast for Windows-native Claude notifications

In a regular PowerShell window:

```powershell
Install-Module -Name BurntToast -Scope CurrentUser
```

Manual one-time step — PowerShell module install needs an interactive trust prompt that chezmoi can't drive. Without BurntToast, the `notify.sh` Windows branch silently no-ops.

#### Trade-offs to know

- **Kitty is not the Windows 11 default-terminal handler.** It's a WSLg GUI app, not a ConHost-compatible terminal, so File Explorer "Open in Terminal" still goes to Windows Terminal / conhost. The trade-off bought back kitty-scrollback.nvim, auto-tiling layouts, and `kitty @` remote control.
- **For native Windows builds, run `claude` from Windows-native Git Bash**, not from WSL Kitty. Anything filesystem-heavy (cargo, npm install, bun install) over `/mnt/c` is 5-20× slower than building on the native Windows filesystem.
- **mise is Linux-only** in this repo. Windows tool versions are pinned by winget. Revisit if version pinning matters for native Windows projects.

### Testing a branch

To preview a feature branch (like a Renovate PR or a refactor branch) before merging — either on Linux bare metal or inside WSL2:

```bash
# Clone explicitly so you control which ref is checked out
git clone https://github.com/tristanburgess/dotfiles.git ~/dev/code/dotfiles
cd ~/dev/code/dotfiles
git checkout claude/some-branch-name

# Install chezmoi (skip if you already have it on PATH)
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

# Init chezmoi pointing at the LOCAL clone's source state directory (home/ per
# .chezmoiroot) — without this step, `chezmoi diff` and `chezmoi apply` silently
# no-op because chezmoi has no source dir registered.
~/.local/bin/chezmoi init --source ~/dev/code/dotfiles/home

# Sanity-check OS gating evaluates the way you expect
~/.local/bin/chezmoi execute-template '{{ .chezmoi.os }} wsl={{ .isWSL }} bm={{ .isLinuxBaremetal }}'
# linux wsl=false bm=true   ← bare metal
# linux wsl=true  bm=false  ← WSL
# windows wsl=false bm=false ← Git Bash on Windows

# Preview without writing anything
~/.local/bin/chezmoi diff

# Apply when it looks right
~/.local/bin/chezmoi apply
```

On Windows-native, the equivalent flow uses `winget install twpayne.chezmoi` + Git Bash, then `chezmoi init --source 'C:/Users/<you>/dev/code/dotfiles/home'` from Git Bash.

### Post-install

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
