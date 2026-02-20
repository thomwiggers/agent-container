#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> claude-container: running postCreate setup"

# ── Claude Code config ────────────────────────────────────────────────────────
# Host config is mounted read-only at ~/.claude-host. Copy to ~/.claude
# so Claude Code can write session state without modifying host files.
CLAUDE_HOST="${HOME}/.claude-host"
CLAUDE_HOME="${HOME}/.claude"

if [[ -d "${CLAUDE_HOST}" ]]; then
    mkdir -p "${CLAUDE_HOME}"
    cp -a "${CLAUDE_HOST}/." "${CLAUDE_HOME}/"
    echo "==> Merged Claude host config into writable location"
fi

# ── Claude Code permissions ──────────────────────────────────────────────────
# Container is the isolation boundary — allow --dangerously-skip-permissions.
CLAUDE_SETTINGS="${CLAUDE_HOME}/settings.json"
mkdir -p "${CLAUDE_HOME}"
if [[ -f "${CLAUDE_SETTINGS}" ]]; then
    jq '. * {"permissions":{"defaultMode":"bypassPermissions"}}' \
        "${CLAUDE_SETTINGS}" > "${CLAUDE_SETTINGS}.tmp" \
        && mv "${CLAUDE_SETTINGS}.tmp" "${CLAUDE_SETTINGS}"
else
    echo '{"permissions":{"defaultMode":"bypassPermissions"}}' > "${CLAUDE_SETTINGS}"
fi
echo "==> Configured Claude Code to allow --dangerously-skip-permissions"

# ── Shell config ──────────────────────────────────────────────────────────────
# Source the host's .zshrc from inside the container
CONTAINER_ZSHRC="${HOME}/.zshrc"
HOST_ZSHRC="${HOME}/.zshrc.host"

if [[ -f "${HOST_ZSHRC}" ]]; then
    if ! grep -q "zshrc.host" "${CONTAINER_ZSHRC}" 2>/dev/null; then
        echo "" >> "${CONTAINER_ZSHRC}"
        echo "# Source host zshrc (read-only mount from host)" >> "${CONTAINER_ZSHRC}"
        echo "[[ -f ${HOST_ZSHRC} ]] && source ${HOST_ZSHRC}" >> "${CONTAINER_ZSHRC}"
        echo "==> Configured .zshrc to source host config"
    fi
fi

# ── Parent-repo customisation hook ────────────────────────────────────────────
# When this repo is used as a submodule at .devcontainer/, the parent project
# root is one level up from the workspace root.
PARENT_HOOK="${WORKSPACE_ROOT}/../.devcontainer-local/postCreate.sh"

if [[ -f "${PARENT_HOOK}" ]]; then
    echo "==> Found .devcontainer-local/postCreate.sh — running parent hook"
    bash "${PARENT_HOOK}"
else
    echo "==> No .devcontainer-local/postCreate.sh found (that's fine)"
fi

echo "==> claude-container: postCreate complete"
