# dotfiles

Dev environment bootstrap for Ubuntu-compatible x64 distros and Windows 11 + WSL2, managed by [chezmoi](https://www.chezmoi.io/). One source tree drives three targets: Linux bare metal, WSL2 Ubuntu, and Windows-native Git Bash.

![Kitty terminal with tiling layout, Starship prompt, and Claude Code with status bar](assets/dotfiles.png)

## Highlights

- **Click-to-focus notifications**: Claude Code tasks fire desktop notifications that jump to the correct terminal window on click and auto-dismiss when you're already looking at it

  ![Claude Code notification with click-to-focus](assets/claude-noti.png)

- **Smart VCS prompt**: Starship shows jj change IDs with nearest ancestor bookmark (or git branch fallback). Modified status at a glance, no duplicate indicators in colocated repos
- **Per-project tab coloring**: each Claude Code session gets a unique Kitty tab color for instant project identification
- **Rich status line**: VCS state, context window usage with blue-to-red gradient, rate limit indicators, monthly budget tracking. Adapted from [andrewburgess/dotfiles](https://github.com/andrewburgess/dotfiles)

  ![Claude Code status bar with VCS state, context gradient, and budget tracking](assets/statusbar.png)

## What's included

[mise](https://mise.jdx.dev/) pins and installs developer tools on both Linux and Windows. Versions live in [`mise/config.toml`](home/dot_config/mise/config.toml), auto-updated by [Renovate](https://docs.renovatebot.com/) (patch/minor auto-merge, major requires review).

| Category | Tools |
|----------|-------|
| Terminal & prompt | [Kitty](https://sw.kovidgoyal.net/kitty/) (Linux), [Starship](https://starship.rs/), [zoxide](https://github.com/ajeetdsouza/zoxide) |
| Version control | [Jujutsu](https://jj-vcs.github.io/jj/), [GitHub CLI](https://cli.github.com/), [difftastic](https://difftastic.wilfred.me/) |
| Editor | [Neovim](https://neovim.io/) + [kitty-scrollback.nvim](https://github.com/mikesmithgh/kitty-scrollback.nvim) |
| Languages | [Go](https://go.dev/), [Rust](https://www.rust-lang.org/) (Linux), [Node.js](https://nodejs.org/) LTS, [Bun](https://bun.sh/), Java |
| AI | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with hooks, notifications, status line |
| Cloud CLIs | AWS CLI, Azure CLI, gcloud (mise on Linux, winget on Windows) |
| Infra | [Terraform](https://www.terraform.io/), [jq](https://jqlang.github.io/jq/) |

**Also configured:** [JetBrainsMono Nerd Font](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/JetBrainsMono), Claude Code hooks (config protection, bash audit log, `--no-verify` blocking, session tab coloring, verify-nudge), Kitty Adventure Time theme with tiling layouts.

## Usage

OS gating is automatic. Each script checks `.chezmoi.os` and derived flags (`isWSL`, `isLinuxBaremetal`) then no-ops on the wrong target.

| Target | Shell | Tool management | Notes |
|---|---|---|---|
| **Linux bare metal** | bash + Kitty | mise + apt | Full setup including desktop apps via snap/deb |
| **WSL2 Ubuntu** | bash + Kitty (WSLg) | mise + apt | Desktop apps installed via winget on Windows side |
| **Windows 11 native** | Git Bash | mise + winget | Thin layer for native filesystem builds |

### Linux bare metal / WSL2

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply tristanburgess/dotfiles
```

Installs chezmoi, prompts for name + email, then runs the full bootstrap: apt repos/packages, mise + all pinned tools, JetBrainsMono Nerd Font, shell integrations (mise, zoxide, starship, jj completions), Neovim plugins.

**Bare-metal extras:** pcspkr disable, Kitty `.desktop` patching, Claude Desktop `.deb`, Cinnamon DND shortcut, snap packages (Slack/Spotify/Notion/Foliate), Discord/Zoom `.deb`s.

**WSL2 note:** after applying, launch Kitty via WSLg (`nohup kitty &`). Search "kitty" in Windows Start, right-click **Pin to taskbar**.

### Windows 11 native

Thin Windows-native layer for builds where filesystem-heavy operations (cargo, npm, bun) over `/mnt/c` from WSL are 5-20x slower than native. The daily-driver shell stays Kitty-in-WSLg.

**winget handles:** bootstrap deps (Git, chezmoi, Rustup-MSVC, mise), cloud CLIs (AWS/Azure/gcloud), desktop apps (Claude Desktop, Slack, Spotify, Notion, Discord, Zoom, SumatraPDF).
**mise handles:** all other dev tools — same pinned versions as Linux.

**Prerequisites:** Windows 11 (or 10 build 19044+) with [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/).

#### Step 1: Bootstrap

```powershell
winget install Git.Git twpayne.chezmoi
```

chezmoi needs Git Bash to run `.sh` modify scripts and body-wrapped chezmoiscripts. The repo's [`[interpreters.sh]`](home/.chezmoi.toml.tmpl) points chezmoi at `C:/Program Files/Git/bin/bash.exe`.

#### Step 2: Apply

Open **Git Bash**:

```bash
chezmoi init --apply tristanburgess/dotfiles
```

Installs mise + winget packages, sets up Git Bash shell integrations (mise, zoxide, starship, jj/gh completions), JetBrainsMono Nerd Font, bootstraps WSL2 + Ubuntu if absent (may require reboot).

#### Step 3: Bootstrap WSL

After reboot (if prompted):

```powershell
wsl -d Ubuntu
# set username/password on first launch, then:
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply tristanburgess/dotfiles
```

Then follow the WSL2 note above to pin Kitty to taskbar.

#### Optional: BurntToast notifications

```powershell
Install-Module -Name BurntToast -Scope CurrentUser
```

Manual step — needs an interactive trust prompt. Without BurntToast, Windows-native Claude notifications silently no-op.

#### Trade-offs

- **Kitty isn't the Windows default terminal.** It's a WSLg GUI app, not ConHost-compatible. The trade-off buys kitty-scrollback.nvim, auto-tiling layouts, and `kitty @` remote control.
- **Run `claude` from Git Bash for native Windows builds**, not WSL Kitty. Anything filesystem-heavy over `/mnt/c` is 5-20x slower.

### Post-install

```bash
source ~/.bashrc
gh auth login
claude  # authenticate Claude Code
```

For [signed commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification):

```bash
ssh-keygen -t ed25519 -C "your@email.com"
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "signing key"
chezmoi apply  # re-apply to pick up signing config in jj
```

### Testing a branch

```bash
git clone https://github.com/tristanburgess/dotfiles.git ~/dev/code/dotfiles
cd ~/dev/code/dotfiles && git checkout some-branch-name
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin   # skip if chezmoi on PATH
~/.local/bin/chezmoi init --source ~/dev/code/dotfiles/home
~/.local/bin/chezmoi diff     # preview
~/.local/bin/chezmoi apply    # apply when ready
```

On Windows: `chezmoi init --source 'C:/Users/<you>/dev/code/dotfiles/home'` from Git Bash.

### Updating configs

```bash
chezmoi diff     # preview changes
chezmoi apply    # deploy to ~
chezmoi re-add   # pull edits from deployed files back to source
```

## Tool updates

Versions pinned in [`mise/config.toml`](home/dot_config/mise/config.toml). [Renovate](https://docs.renovatebot.com/modules/manager/mise/) watches upstream releases. When you pull a version bump, chezmoi detects the config change and re-runs `mise install`.

To install Renovate on your fork, add the [Mend Renovate GitHub App](https://github.com/apps/renovate).

## Structure

```
dotfiles/
├── .chezmoiroot                # points chezmoi to home/ as source root
├── home/                       # chezmoi source state
│   ├── .chezmoi.toml.tmpl      # chezmoi config (prompts + OS detection)
│   ├── .chezmoiignore.tmpl     # OS-conditional file gating
│   ├── .chezmoiscripts/        # bootstrap scripts (.sh.tmpl → Linux/WSL, .ps1.tmpl → Windows)
│   ├── dot_config/             # → ~/.config/ (kitty, starship, jj, nvim, mise)
│   ├── dot_claude/             # → ~/.claude/ (settings, hooks, skills)
│   └── bin/                    # → ~/bin/
├── assets/                     # README screenshots
└── README.md
```
