#!/bin/bash
set -euo pipefail

# Add shell integrations to .bashrc (idempotent — skips if already present)

add_line() {
    local marker="$1" line="$2"
    if ! grep -q "$marker" "$HOME/.bashrc"; then
        echo "$line" >> "$HOME/.bashrc"
    fi
}

add_line 'mise activate bash'   'eval "$(mise activate bash)"'
add_line 'zoxide init bash'     'eval "$(zoxide init bash)"'
add_line 'starship init bash'   'eval "$(starship init bash)"'
add_line 'GOPATH.*bin'          'export PATH="$(go env GOPATH)/bin:$PATH"'
