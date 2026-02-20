#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> claude-container: running postCreate setup"

# ── Claude Code config ────────────────────────────────────────────────────────
# Host config is mounted read-only at /root/.claude-host. Copy to /root/.claude
# so Claude Code can write session state without modifying host files.
CLAUDE_HOST="/root/.claude-host"
CLAUDE_HOME="/root/.claude"

if [[ -d "${CLAUDE_HOST}" ]]; then
    cp -a "${CLAUDE_HOST}" "${CLAUDE_HOME}"
    echo "==> Copied Claude config to writable location"
fi

# ── Shell config ──────────────────────────────────────────────────────────────
# Source the host's .zshrc from inside the container
CONTAINER_ZSHRC="/root/.zshrc"
HOST_ZSHRC="/root/.zshrc.host"

if [[ -f "${HOST_ZSHRC}" ]]; then
    if ! grep -q "zshrc.host" "${CONTAINER_ZSHRC}" 2>/dev/null; then
        echo "" >> "${CONTAINER_ZSHRC}"
        echo "# Source host zshrc (read-only mount from host)" >> "${CONTAINER_ZSHRC}"
        echo "[[ -f ${HOST_ZSHRC} ]] && source ${HOST_ZSHRC}" >> "${CONTAINER_ZSHRC}"
        echo "==> Configured .zshrc to source host config"
    fi
fi

# ── nvm / Claude Code PATH ─────────────────────────────────────────────────────
NVM_SH="/usr/local/share/nvm/nvm.sh"
if [[ -f "${NVM_SH}" ]]; then
    # Ensure nvm is sourced in .zshrc so claude is on PATH
    if ! grep -q "nvm.sh" "${CONTAINER_ZSHRC}" 2>/dev/null; then
        echo "" >> "${CONTAINER_ZSHRC}"
        echo "# nvm (installed by claude-container)" >> "${CONTAINER_ZSHRC}"
        echo "export NVM_DIR=\"/usr/local/share/nvm\"" >> "${CONTAINER_ZSHRC}"
        echo "[[ -s \"${NVM_SH}\" ]] && source \"${NVM_SH}\"" >> "${CONTAINER_ZSHRC}"
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
