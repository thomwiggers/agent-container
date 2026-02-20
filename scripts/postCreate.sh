#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> claude-container: running postCreate setup"

# ── Claude Code config ────────────────────────────────────────────────────────
# settings.json is baked into the image at /etc/claude-container/ so the
# container gets a known, safe configuration without mounting host secrets.
# CLAUDE.md is copied from the host mount if available.
CLAUDE_HOST="${HOME}/.claude-host"
CLAUDE_HOME="${HOME}/.claude"
IMAGE_SETTINGS="/etc/claude-container/settings.json"
mkdir -p "${CLAUDE_HOME}"

# Copy image settings.json on first creation (volume may already have one)
if [[ -f "${IMAGE_SETTINGS}" && ! -f "${CLAUDE_HOME}/settings.json" ]]; then
    cp "${IMAGE_SETTINGS}" "${CLAUDE_HOME}/settings.json"
    echo "==> Copied settings.json from image defaults"
fi

# Copy host CLAUDE.md if mounted
if [[ -f "${CLAUDE_HOST}/CLAUDE.md" && ! -f "${CLAUDE_HOME}/CLAUDE.md" ]]; then
    cp "${CLAUDE_HOST}/CLAUDE.md" "${CLAUDE_HOME}/CLAUDE.md"
    echo "==> Copied CLAUDE.md from host config"
fi

# ── Claude Code permissions ──────────────────────────────────────────────────
# Container is the isolation boundary — allow --dangerously-skip-permissions.
CLAUDE_SETTINGS="${CLAUDE_HOME}/settings.json"
if [[ -f "${CLAUDE_SETTINGS}" ]]; then
    jq '. * {"permissions":{"defaultMode":"bypassPermissions"}, "skipDangerousModePermissionPrompt": true}' \
        "${CLAUDE_SETTINGS}" > "${CLAUDE_SETTINGS}.tmp" \
        && mv "${CLAUDE_SETTINGS}.tmp" "${CLAUDE_SETTINGS}"
else
    echo '{"permissions":{"defaultMode":"bypassPermissions"},' \
         '"skipDangerousModePermissionPrompt": true}' > "${CLAUDE_SETTINGS}"
fi
echo "==> Configured Claude Code to allow --dangerously-skip-permissions"

if [[ -f "$HOME/.claude.json" ]]; then
    jq '. * {"hasCompletedOnboarding": true}' $HOME/.claude.json > $HOME/.claude.json.tmp
    mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
else
cat > $HOME/.claude.json <<HERE
{
  "numStartups": 0,
  "theme": "dark",
  "preferredNotifChannel": "auto",
  "verbose": false,
  "editorMode": "normal",
  "autoCompactEnabled": true,
  "showTurnDuration": true,
  "hasSeenTasksHint": false,
  "hasCompletedOnboarding": true,
  "hasUsedStash": false,
  "queuedCommandUpHintCount": 0,
  "diffTool": "auto",
  "customApiKeyResponses": {
    "approved": [],
    "rejected": []
  },
  "env": {},
  "tipsHistory": {},
  "memoryUsageCount": 0,
  "promptQueueUseCount": 0,
  "btwUseCount": 0,
  "todoFeatureEnabled": true,
  "showExpandedTodos": false,
  "messageIdleNotifThresholdMs": 60000,
  "autoConnectIde": false,
  "autoInstallIdeExtension": true,
  "fileCheckpointingEnabled": true,
  "terminalProgressBarEnabled": true,
  "cachedStatsigGates": {},
  "cachedDynamicConfigs": {},
  "cachedGrowthBookFeatures": {},
  "respectGitignore": true
}%
HERE
fi

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

# ── Rust / Cargo PATH ────────────────────────────────────────────────────────
CARGO_ENV="${HOME}/.cargo/env"
if [[ -f "${CARGO_ENV}" ]] && ! grep -q "cargo/env" "${CONTAINER_ZSHRC}" 2>/dev/null; then
    echo "" >> "${CONTAINER_ZSHRC}"
    echo "# Source Cargo/Rust environment" >> "${CONTAINER_ZSHRC}"
    echo "[[ -f ${CARGO_ENV} ]] && source ${CARGO_ENV}" >> "${CONTAINER_ZSHRC}"
    echo "==> Configured .zshrc to source Cargo env"
fi

# ── Local env-file loader ────────────────────────────────────────────────────
# Parent repos can place a .devcontainer-local/env file with KEY=VALUE lines
# to inject runtime environment variables into the container shell.
LOCAL_ENV="${WORKSPACE_ROOT}/../.devcontainer-local/env"
if [[ -f "${LOCAL_ENV}" ]]; then
    echo "" >> "${CONTAINER_ZSHRC}"
    echo "# Environment from .devcontainer-local/env" >> "${CONTAINER_ZSHRC}"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        echo "export ${line}" >> "${CONTAINER_ZSHRC}"
    done < "${LOCAL_ENV}"
    echo "==> Loaded environment variables from .devcontainer-local/env"
fi

# ── Parent-repo customisation hook ────────────────────────────────────────────
# When this repo is used as a submodule at .devcontainer/, the parent project
# root is one level up from the workspace root.
PARENT_HOOK="${WORKSPACE_ROOT}/.devcontainer-local/postCreate.sh"

if [[ -f "${PARENT_HOOK}" ]]; then
    echo "==> Found .devcontainer-local/postCreate.sh — running parent hook"
    bash "${PARENT_HOOK}"
else
    echo "==> No .devcontainer-local/postCreate.sh found (that's fine)"
fi

echo "==> claude-container: postCreate complete"
