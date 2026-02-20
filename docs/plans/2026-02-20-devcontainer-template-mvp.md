# Devcontainer Template MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create the minimum viable devcontainer template that opens this repo
(`claude-container`) inside a working container, with Claude Code installed,
user config mounted read-only, and a clean hook for parent-repo customisation.

**Architecture:** Multi-stage Dockerfile on the upstream devcontainer base image
(ubuntu-24.04). Root `devcontainer.json` is used when the repo is consumed as a
`.devcontainer/` submodule; `.devcontainer/devcontainer.json` is for
self-hosting this repo. `scripts/postCreate.sh` handles one-time setup and
sources `.devcontainer-local/postCreate.sh` from the parent repo if present.

**Tech Stack:** Docker, VS Code Dev Containers spec, Node.js (for Claude Code),
Bash (lifecycle scripts), GitHub Actions (future CI).

**Design doc:** `docs/plans/2026-02-20-devcontainer-template-design.md`

---

## Task 1: CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

**Step 1: Write CLAUDE.md**

```markdown
# claude-container

A reusable `.devcontainer` template for isolated AI-assisted development.
Designed to be consumed as a git submodule at `.devcontainer/` in any project.

## Project Goals

- Provide a working devcontainer with Claude Code pre-installed
- Mount user identity (git config, shell config, Claude config) read-only
- Keep API keys and secrets off the container
- Allow parent repos to extend setup via `.devcontainer-local/`
- Be usable without modification for most general software development

## Key Files

| File | Purpose |
|------|---------|
| `devcontainer.json` | Root config — used when consumed as a submodule |
| `Dockerfile` | Multi-stage image definition |
| `scripts/postCreate.sh` | One-time post-creation setup |
| `.devcontainer/devcontainer.json` | Self-hosting config for this repo |

## Adding as a Submodule

```bash
git submodule add https://github.com/thomwiggers/claude-container.git .devcontainer
```

## Parent-Repo Customisation

Place `.devcontainer-local/postCreate.sh` at your project root to run
project-specific setup (install toolchains, configure env, etc.) after the
container is created.

## What is NOT Implemented (Future Work)

- Gemini CLI install (ARG-gated)
- Podman runtime support
- MCP forwarding without API keys
- Language toolchain stage (Rust, Go, Python/uv)
- devcontainer.local.json JSON override mechanism
- CI to test container builds on push

## Host Assumptions

See `README.md` for the full list of host requirements.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md with project goals and structure"
```

---

## Task 2: README

**Files:**
- Create: `README.md`

**Step 1: Write README.md**

```markdown
# claude-container

A reusable `.devcontainer` template optimised for AI-assisted development
(Claude Code, Gemini CLI). Designed to be consumed as a git submodule.

## What This Provides

- Ubuntu 24.04 base with common dev tools
- Claude Code pre-installed (latest via npm)
- Your `~/.claude` config mounted read-only
- Your `~/.gitconfig` mounted read-only
- Your `~/.zshrc` sourced inside the container
- SSH agent forwarding via VS Code
- A hook for project-specific setup (`.devcontainer-local/`)

## Host Requirements

Before using this devcontainer you need:

1. **Docker Desktop or Docker Engine** installed and running
2. **VS Code** with the
   [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
   (or another devcontainer-compatible IDE)
3. **SSH agent** running on the host — either `ssh-agent` or the
   1Password SSH agent. VS Code forwards the agent socket automatically.
4. **`~/.claude` configured** — Claude Code installed on the host and
   authenticated at least once so the config directory exists
5. **`~/.gitconfig` present** with your name and email

> **Podman users:** VS Code does not automatically forward the SSH agent
> socket for Podman. You must bind-mount the socket manually. See
> [Podman docs](https://podman.io) for the socket path on your OS.
> This is a known limitation; full Podman support is a future feature.

## Usage: As a Submodule

```bash
# Add to any project
git submodule add https://github.com/thomwiggers/claude-container.git .devcontainer

# Open in VS Code — Dev Containers picks it up automatically
code .
# Then: "Reopen in Container"
```

## Usage: Standalone (this repo)

```bash
git clone https://github.com/thomwiggers/claude-container.git
cd claude-container
code .
# Then: "Reopen in Container"
```

## Parent-Repo Customisation

Create `.devcontainer-local/postCreate.sh` at your project root:

```bash
#!/usr/bin/env bash
# .devcontainer-local/postCreate.sh
# Runs inside the container after creation

# Example: install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Example: install Python deps with uv
pip install uv
uv sync
```

The devcontainer's `postCreate.sh` sources this file automatically.

## Build Arguments

Pass these via `devcontainer.json`'s `build.args` in your project:

| ARG | Default | Description |
|-----|---------|-------------|
| `USERNAME` | `vscode` | Container user name |
| `NODE_VERSION` | `lts/*` | Node.js version for Claude Code |

Example override in parent repo's `devcontainer.json`:
```json
{
  "build": {
    "context": ".devcontainer",
    "dockerfile": ".devcontainer/Dockerfile",
    "args": { "NODE_VERSION": "22" }
  }
}
```

## What Is Not Yet Implemented

| Feature | Notes |
|---------|-------|
| Gemini CLI | Planned as ARG-gated install |
| Podman support | Manual socket steps documented above |
| MCP forwarding without API keys | Future: proxy or filtered config |
| Language toolchain stage | Future: optional Dockerfile stage |
| JSON override mechanism | Future: devcontainer.local.json pattern |
| CI for container builds | Future: GitHub Actions |

## Security Notes

- API keys (`ANTHROPIC_API_KEY` etc.) are **not** forwarded into the container
- `~/.claude` is mounted **read-only** — the container cannot modify your config
- MCP server configurations that require API keys will not function inside
  the container (this is intentional)
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with usage, host requirements, and future work"
```

---

## Task 3: Dockerfile

**Files:**
- Create: `Dockerfile`

**Step 1: Write Dockerfile**

```dockerfile
# syntax=docker/dockerfile:1

# ─── Stage 1: base ────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 AS base

ARG USERNAME=vscode
ARG NODE_VERSION=lts/*

# Install common dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        git \
        zsh \
        vim \
        jq \
        make \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

# ─── Stage 2: agents ──────────────────────────────────────────────────────────
FROM base AS agents

# Switch to the container user for nvm/npm installs
USER ${USERNAME}

# Install Node.js via nvm (already available in devcontainers/base)
# hadolint ignore=SC1091
RUN . /usr/local/share/nvm/nvm.sh \
    && nvm install "${NODE_VERSION}" \
    && nvm use "${NODE_VERSION}" \
    && nvm alias default "${NODE_VERSION}" \
    && npm install -g @anthropic-ai/claude-code

# Back to root for any remaining system-level setup
USER root

# Container opens in the workspace
WORKDIR /workspaces
```

**Step 2: Verify the Dockerfile builds**

```bash
docker build --target agents -t claude-container:test .
```

Expected: build completes without errors. If nvm sourcing fails, check that
`/usr/local/share/nvm/nvm.sh` exists in the base image (it does as of
`devcontainers/base:ubuntu-24.04`).

**Step 3: Verify Claude Code is installed in the image**

```bash
docker run --rm claude-container:test bash -c \
  "source /usr/local/share/nvm/nvm.sh && claude --version"
```

Expected: prints a claude version string (e.g., `1.x.x`).

**Step 4: Commit**

```bash
git add Dockerfile
git commit -m "feat: add multi-stage Dockerfile with Claude Code install"
```

---

## Task 4: Root devcontainer.json (submodule consumer config)

**Files:**
- Create: `devcontainer.json`

**Step 1: Write devcontainer.json**

```json
{
  "name": "claude-container",
  "build": {
    "context": ".",
    "dockerfile": "Dockerfile",
    "target": "agents",
    "args": {
      "USERNAME": "vscode",
      "NODE_VERSION": "lts/*"
    }
  },
  "features": {
    "ghcr.io/devcontainers/features/sshd:1": {}
  },
  "mounts": [
    {
      "source": "${localEnv:HOME}/.claude",
      "target": "/root/.claude",
      "type": "bind",
      "readonly": true
    },
    {
      "source": "${localEnv:HOME}/.gitconfig",
      "target": "/root/.gitconfig",
      "type": "bind",
      "readonly": true
    },
    {
      "source": "${localEnv:HOME}/.zshrc",
      "target": "/root/.zshrc.host",
      "type": "bind",
      "readonly": true
    }
  ],
  "postCreateCommand": "bash .devcontainer/scripts/postCreate.sh",
  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.defaultProfile.linux": "zsh"
      }
    }
  },
  "remoteUser": "root"
}
```

> **Note on `postCreateCommand` path:** When this repo is the `.devcontainer/`
> folder, scripts live at `.devcontainer/scripts/postCreate.sh` relative to the
> workspace root. When developing this repo itself, scripts live at
> `scripts/postCreate.sh` — the self-hosting config (Task 6) corrects this path.

**Step 2: Commit**

```bash
git add devcontainer.json
git commit -m "feat: add root devcontainer.json for submodule consumers"
```

---

## Task 5: postCreate.sh

**Files:**
- Create: `scripts/postCreate.sh`

**Step 1: Create scripts directory and write postCreate.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> claude-container: running postCreate setup"

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
```

**Step 2: Make it executable**

```bash
chmod +x /Users/thom/git/claude-container/scripts/postCreate.sh
```

**Step 3: Commit**

```bash
git add scripts/postCreate.sh
git commit -m "feat: add postCreate.sh with shell config and parent-repo hook"
```

---

## Task 6: Self-hosting devcontainer (.devcontainer/devcontainer.json)

**Files:**
- Create: `.devcontainer/devcontainer.json`

**Step 1: Create .devcontainer directory and write the self-hosting config**

This config is used when opening the `claude-container` repo itself in a
container. It differs from the root config only in:
- `context` points to `..` (repo root)
- `postCreateCommand` uses `scripts/postCreate.sh` (not `.devcontainer/scripts/`)

```json
{
  "name": "claude-container (development)",
  "build": {
    "context": "..",
    "dockerfile": "../Dockerfile",
    "target": "agents",
    "args": {
      "USERNAME": "vscode",
      "NODE_VERSION": "lts/*"
    }
  },
  "features": {
    "ghcr.io/devcontainers/features/sshd:1": {}
  },
  "mounts": [
    {
      "source": "${localEnv:HOME}/.claude",
      "target": "/root/.claude",
      "type": "bind",
      "readonly": true
    },
    {
      "source": "${localEnv:HOME}/.gitconfig",
      "target": "/root/.gitconfig",
      "type": "bind",
      "readonly": true
    },
    {
      "source": "${localEnv:HOME}/.zshrc",
      "target": "/root/.zshrc.host",
      "type": "bind",
      "readonly": true
    }
  ],
  "postCreateCommand": "bash scripts/postCreate.sh",
  "customizations": {
    "vscode": {
      "settings": {
        "terminal.integrated.defaultProfile.linux": "zsh"
      }
    }
  },
  "remoteUser": "root"
}
```

**Step 2: Commit**

```bash
git add .devcontainer/devcontainer.json
git commit -m "feat: add self-hosting devcontainer config for this repo"
```

---

## Task 7: Smoke-test and final verification

**Step 1: Verify Docker build succeeds end-to-end**

```bash
docker build --target agents -t claude-container:smoke .
```

Expected: exits 0.

**Step 2: Verify postCreate.sh is syntactically valid**

```bash
bash -n /Users/thom/git/claude-container/scripts/postCreate.sh
```

Expected: no output (bash -n exits 0 if syntax is valid).

**Step 3: Verify JSON files are valid**

```bash
python3 -m json.tool devcontainer.json > /dev/null && echo "root devcontainer.json OK"
python3 -m json.tool .devcontainer/devcontainer.json > /dev/null && echo "self-host devcontainer.json OK"
```

Expected: both print OK.

**Step 4: Open in VS Code**

```
code /Users/thom/git/claude-container
```

In VS Code: click "Reopen in Container" when prompted (or Cmd+Shift+P →
"Dev Containers: Reopen in Container"). The container should build and open.
Verify inside the container:

```bash
claude --version        # should print a version
git config user.email  # should show your host git identity
echo $SHELL            # should be /bin/zsh
```

**Step 5: Clean up smoke-test image**

```bash
docker rmi claude-container:smoke
```

**Step 6: Final commit if any fixups were needed**

```bash
git add -p   # stage only what changed
git commit -m "fix: smoke-test fixups"
```

---

## Summary of Files Created

```
claude-container/
├── CLAUDE.md
├── README.md
├── Dockerfile
├── devcontainer.json
├── scripts/
│   └── postCreate.sh
├── .devcontainer/
│   └── devcontainer.json
└── docs/
    └── plans/
        ├── 2026-02-20-devcontainer-template-design.md
        └── 2026-02-20-devcontainer-template-mvp.md   ← this file
```
