#!/bin/bash
set -euo pipefail

# renovate: packageName=aaddrick/claude-desktop-debian datasource=github-releases
CLAUDE_DESKTOP_VERSION="1.3.27+claude1.1617.0"

ARCH=$(dpkg --print-architecture)

echo "Installing claude-desktop v${CLAUDE_DESKTOP_VERSION}..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

eval "$("$HOME/.local/bin/mise" activate bash)"

gh release download "v${CLAUDE_DESKTOP_VERSION}" \
    --repo aaddrick/claude-desktop-debian \
    --pattern "claude-desktop_*_${ARCH}.deb" \
    --dir "${TMPDIR}"

DEB_FILE=$(find "${TMPDIR}" -name "*.deb" -print -quit)
if [ -z "${DEB_FILE}" ]; then
    echo "Error: Failed to download claude-desktop .deb"
    exit 1
fi

sudo dpkg -i "${DEB_FILE}" || sudo apt-get install -f -y

echo "claude-desktop ${CLAUDE_DESKTOP_VERSION} installed successfully"
