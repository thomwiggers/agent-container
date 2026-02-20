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
6. **`CLAUDE_CODE_OAUTH_TOKEN` exported** — required for Claude Code Pro/Max
   subscriptions (see [Authentication](#authentication) below)

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

## Authentication

Claude Code Pro/Max subscriptions use OAuth tokens stored in the macOS
Keychain, which containers cannot access. The devcontainer forwards the
`CLAUDE_CODE_OAUTH_TOKEN` environment variable from your host instead.

**macOS setup** — add this to your `~/.zshrc`:

```bash
export CLAUDE_CODE_OAUTH_TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null)
```

This extracts the OAuth access token from your Keychain on every new shell.
The token is forwarded into the container via `containerEnv` in
`devcontainer.json`.

**Linux hosts** — Claude Code stores credentials in
`~/.claude/.credentials.json` instead of a keychain, so the `~/.claude` mount
should work without this step.

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
