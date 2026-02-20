#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> claude-container: running postCreate setup"

# ── Claude Code config ────────────────────────────────────────────────────────
# Host config files are mounted read-only at ~/.claude-host/.
# Copy only safe files to ~/.claude so Claude Code can write session state
# without modifying host files and without exposing secrets.
CLAUDE_HOST="${HOME}/.claude-host"
CLAUDE_HOME="${HOME}/.claude"
mkdir -p "${CLAUDE_HOME}"

for SAFE_FILE in settings.json CLAUDE.md; do
    HOST_FILE="${CLAUDE_HOST}/${SAFE_FILE}"
    DEST_FILE="${CLAUDE_HOME}/${SAFE_FILE}"
    if [[ -f "${HOST_FILE}" && ! -f "${DEST_FILE}" ]]; then
        cp "${HOST_FILE}" "${DEST_FILE}"
        echo "==> Copied ${SAFE_FILE} from host config"
    fi
done

# ── MCP config forwarding (strip API keys) ───────────────────────────────────
# If MCP config files are mounted into ~/.claude-host/ (opt-in), copy them
# and strip env values so server definitions are available but keys are not.
for MCP_FILE_NAME in claude_desktop_config.json mcp_servers.json; do
    HOST_MCP="${CLAUDE_HOST}/${MCP_FILE_NAME}"
    DEST_MCP="${CLAUDE_HOME}/${MCP_FILE_NAME}"
    if [[ -f "${HOST_MCP}" && ! -f "${DEST_MCP}" ]]; then
        jq 'if .mcpServers then .mcpServers |= with_entries(
              .value.env |= if . then with_entries(.value = "") else . end
            ) else . end' "${HOST_MCP}" > "${DEST_MCP}"
        echo "==> Copied ${MCP_FILE_NAME} (API keys stripped)"
    fi
done

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
PARENT_HOOK="${WORKSPACE_ROOT}/../.devcontainer-local/postCreate.sh"

if [[ -f "${PARENT_HOOK}" ]]; then
    echo "==> Found .devcontainer-local/postCreate.sh — running parent hook"
    bash "${PARENT_HOOK}"
else
    echo "==> No .devcontainer-local/postCreate.sh found (that's fine)"
fi

echo "==> claude-container: postCreate complete"
