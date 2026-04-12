# dotfiles

Dev environment bootstrap for Ubuntu-compatible x64 distros and Windows 11 + WSL2, managed by [chezmoi](https://www.chezmoi.io/). One source tree drives three targets: Linux bare metal, WSL2 Ubuntu, and Windows-native Git Bash.

![Kitty terminal with tiling layout, Starship prompt, and Claude Code with status bar](assets/dotfiles.png)

## Highlights

- **Click-to-focus notifications**: Claude Code tasks fire desktop notifications that jump to the correct terminal window on click and auto-dismiss when you're already looking at it

  ![Claude Code notification with click-to-focus](assets/claude-noti.png)

- **Smart VCS prompt**: Starship shows jj change IDs with nearest ancestor bookmark (or git branch with short hash on detached HEAD). Modified status at a glance, no duplicate indicators in colocated repos
- **Per-project tab coloring**: each Claude Code session gets a unique Kitty tab color for instant project identification
- **Rich status line**: VCS state, context window usage with blue-to-red gradient, rate limit indicators, monthly budget tracking. Adapted from [andrewburgess/dotfiles](https://github.com/andrewburgess/dotfiles)

  ![Claude Code status bar with VCS state, context gradient, and budget tracking](assets/statusbar.png)

## What's included

### Tools (via [mise](https://mise.jdx.dev/))

[mise](https://mise.jdx.dev/) installs and pins all developer tools:

- **[Kitty](https://sw.kovidgoyal.net/kitty/)** terminal with Adventure Time theme, tiling layouts, tuned performance
- **[Starship](https://starship.rs/)** prompt with [Jujutsu (jj)](https://jj-vcs.github.io/jj/) change/bookmark display, git fallback, k8s context, language indicators
- **[Neovim](https://neovim.io/)** with [kitty-scrollback.nvim](https://github.com/mikesmithgh/kitty-scrollback.nvim) for terminal scrollback copy/paste
- **[Jujutsu (jj)](https://jj-vcs.github.io/jj/)** version control with [difftastic](https://difftastic.wilfred.me/) structural diffs
- **[GitHub CLI (gh)](https://cli.github.com/)** for PRs, issues, API calls
- **[zoxide](https://github.com/ajr-f0/zoxide)** for fast directory jumping (`z`)
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** AI coding assistant
- **[Bun](https://bun.sh/)** JavaScript runtime (powers the Claude Code status line)
- **[Go](https://go.dev/)**, **[Rust](https://www.rust-lang.org/)**, **[Python 3](https://www.python.org/)**, **[Node.js](https://nodejs.org/)** (LTS)
- **[jq](https://jqlang.github.io/jq/)** for JSON processing

### Configs

- **[JetBrainsMono Nerd Font](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/JetBrainsMono)** for ligatures and icons
- **Claude Code** hooks and customizations:
  - `/jj` skill: Jujutsu workflow reference, loaded automatically during version control operations
  - Click-to-focus desktop notifications with response preview and auto-dismiss
  - Per-project Kitty tab coloring on session start
  - Status line with VCS info, context window gradient bar, rate limit dots, monthly budget tracker
- **Automated dependency updates** via [Renovate](https://docs.renovatebot.com/): tool versions pinned in [`mise config`](home/dot_config/mise/config.toml), Renovate opens PRs with changelogs on new releases. Patch/minor auto-merge; major requires review

## Usage

Three targets, one source tree:

| Target | Shell | Package manager | Bootstrap |
|---|---|---|---|
| **Linux bare metal** | bash + Kitty | apt + mise | curl one-liner |
| **WSL2 Ubuntu** | bash + Kitty (WSLg GUI) | apt + mise | curl one-liner |
| **Windows 11 native** | Git Bash | winget | manual chezmoi + Git Bash |

OS gating is automatic. Each script checks `.chezmoi.os` (and a derived `isWSL` flag) and no-ops on the wrong target.

### Linux bare metal

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply tristanburgess/dotfiles
```

This installs chezmoi to `~/.local/bin/chezmoi`, fetches the repo, prompts for name + email, then runs the full `.chezmoiscripts/` chain: apt repos and packages, mise + pinned tools, JetBrainsMono Nerd Font, pcspkr disable, GNOME `.desktop` patching for mise-managed Kitty, Cinnamon DND shortcut, Claude Desktop `.deb`, snap packages (Slack/Spotify/Notion/Foliate), Discord/Zoom `.deb`s. First run takes a while.

### WSL2 Ubuntu

Same one-liner inside the WSL distro (after `wsl -d Ubuntu`):

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply tristanburgess/dotfiles
```

These scripts gate off automatically (they don't work or aren't useful in WSL2):

- `pcspkr-disable`: kernel module changes don't persist in WSL2
- `dnd-shortcut` + `bin/toggle-dnd.sh`: Cinnamon `gsettings` keys don't exist in WSLg
- `kitty-desktop`: WSLg auto-registers `kitty.desktop`, no GNOME patching needed
- `claude-desktop` (`.deb` installer): installed via `winget` on Windows instead
- `snap-packages`: snapd not supported in WSL2 by default; Slack, Spotify, Notion installed via `winget` on Windows; Foliate replaced by SumatraPDF via `winget`
- `standalone-debs` (Discord/Zoom): installed via `winget` on Windows instead

After applying, launch Kitty as a WSLg GUI app:

```bash
nohup kitty &
```

WSLg creates a Start menu entry. Search "kitty" in Windows Start, right-click → **Pin to taskbar**. The `.lnk` lives at `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Ubuntu\kitty.lnk`.

### Windows 11 native

Thin Windows-native layer: Claude Code, rustup-MSVC, neovim, jj, gh, bun, JetBrainsMono Nerd Font. Exists for native Windows builds where filesystem-heavy operations (cargo, npm install, bun install) over `/mnt/c` from WSL are 5-20x slower than native. The daily-driver shell stays Kitty-in-WSLg.

#### Prerequisites

- Windows 11 (or Windows 10 build 19044+) with vGPU driver for WSLg
- [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (preinstalled on Win10/11)

#### Step 1: Bootstrap from PowerShell

Run these in a **regular PowerShell window** (not Git Bash):

```powershell
# Allow locally-created scripts to run — Windows ships with Restricted which
# blocks all .ps1 execution. RemoteSigned is the standard dev-machine setting.
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install Git for Windows + chezmoi
winget install Git.Git twpayne.chezmoi
```

chezmoi needs Git Bash to execute the `.sh` modify scripts and body-wrapped `.sh.tmpl` chezmoiscripts. The repo's [`[interpreters.sh]`](home/.chezmoi.toml.tmpl) entry points chezmoi at `C:/Program Files/Git/bin/bash.exe`.

#### Step 2: Apply Windows-native dotfiles

Open **Git Bash**:

```bash
chezmoi init --apply tristanburgess/dotfiles
```

This runs:
- `run_once_before_00-winget-packages.ps1`: Rustup-MSVC, Neovim, Starship, GitHub CLI, jj, Bun, Claude Code, JetBrainsMono Nerd Font, plus desktop apps (Claude Desktop, Slack, Spotify, Notion, Discord, Zoom, SumatraPDF)
- `run_once_after_00-wsl-bootstrap.ps1`: installs WSL2 + Ubuntu if absent (may require reboot)
- `run_once_after_00-git-bash-profile.sh`: writes Git Bash `~/.bashrc` with starship + gh + jj completions

#### Step 3: Bootstrap WSL Ubuntu

After step 2 (reboot if Windows prompted):

```powershell
wsl -d Ubuntu
# set username/password on first launch, then inside Ubuntu:
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply tristanburgess/dotfiles
```

Then follow [WSL2 Ubuntu](#wsl2-ubuntu) above for pinning Kitty to taskbar.

#### Step 4 (optional): BurntToast for Windows-native Claude notifications

In a regular PowerShell window:

```powershell
Install-Module -Name BurntToast -Scope CurrentUser
```

Manual step: PowerShell module install needs an interactive trust prompt that chezmoi can't drive. Without BurntToast, `notify.sh` Windows path silently no-ops.

#### Trade-offs

- **Kitty isn't the Windows 11 default terminal.** It's a WSLg GUI app, not ConHost-compatible, so File Explorer "Open in Terminal" still hits Windows Terminal / conhost. The trade-off buys kitty-scrollback.nvim, auto-tiling layouts, and `kitty @` remote control.
- **Run `claude` from Git Bash for native Windows builds**, not WSL Kitty. Anything filesystem-heavy over `/mnt/c` is 5-20x slower than native filesystem.
- **mise is Linux-only** in this repo. Windows tool versions are pinned by winget.

### Testing a branch

Preview a feature branch (Renovate PR, refactor branch) before merging, on Linux bare metal or WSL2:

```bash
# Clone explicitly to control which ref is checked out
git clone https://github.com/tristanburgess/dotfiles.git ~/dev/code/dotfiles
cd ~/dev/code/dotfiles
git checkout claude/some-branch-name

# Install chezmoi (skip if already on PATH)
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

# Init chezmoi pointing at LOCAL clone's source state directory (home/ per
# .chezmoiroot). Without this, `chezmoi diff` and `chezmoi apply` silently
# no-op because chezmoi has no source dir registered.
~/.local/bin/chezmoi init --source ~/dev/code/dotfiles/home

# Verify OS gating evaluates correctly
~/.local/bin/chezmoi execute-template '{{ .chezmoi.os }} wsl={{ .isWSL }} bm={{ .isLinuxBaremetal }}'
# linux wsl=false bm=true   ← bare metal
# linux wsl=true  bm=false  ← WSL
# windows wsl=false bm=false ← Git Bash on Windows

# Preview without writing
~/.local/bin/chezmoi diff

# Apply when it looks right
~/.local/bin/chezmoi apply
```

On Windows-native: `winget install twpayne.chezmoi` + Git Bash, then `chezmoi init --source 'C:/Users/<you>/dev/code/dotfiles/home'` from Git Bash.

### Post-install

```bash
source ~/.bashrc
gh auth login
claude  # authenticate Claude Code
```

For [signed commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification) (required by branch protection), generate an SSH key and add it as a signing key:

```bash
ssh-keygen -t ed25519 -C "your@email.com"
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "signing key"
chezmoi apply  # re-apply to pick up signing config in jj
```

If `~/.ssh/id_ed25519.pub` exists when chezmoi runs, jj auto-configures commit signing.

Then open a new Kitty terminal.

### Updating configs

Edit files under `home/` using chezmoi naming conventions:

```bash
chezmoi apply    # deploy changes to ~
chezmoi diff     # preview what would change
```

Or edit deployed files directly and pull changes back:

```bash
chezmoi re-add   # update source from deployed files
```

## Tool updates

Tool versions are pinned in [`home/dot_config/mise/config.toml`](home/dot_config/mise/config.toml) and deployed by chezmoi. [Renovate](https://docs.renovatebot.com/modules/manager/mise/) watches upstream releases and opens PRs with changelogs. Patch/minor auto-merge; major bumps require review.

When you pull a version bump (via `chezmoi update` or merging a Renovate PR), chezmoi detects the config change and re-runs `mise install` to upgrade the affected tools.

To install Renovate on your fork, add the [Mend Renovate GitHub App](https://github.com/apps/renovate).

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
