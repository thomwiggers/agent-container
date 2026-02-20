# claude-container

A reusable `.devcontainer` template optimised for AI-assisted development
(Claude Code, Gemini CLI). Designed to be consumed as a git submodule.

## What This Provides

- Ubuntu 24.04 base with common dev tools
- Claude Code pre-installed (latest via official installer)
- Your `~/.claude/settings.json` and `~/.claude/CLAUDE.md` mounted read-only
- Your `~/.gitconfig` mounted read-only
- Your `~/.zshrc` sourced inside the container
- SSH agent forwarding via VS Code
- Docker-in-Docker support (build and run containers inside the devcontainer)
- Optional language toolchains: Go, Rust (ARG-gated)
- Optional Gemini CLI install (ARG-gated)
- Automatic `--dangerously-skip-permissions` configuration (container is the isolation boundary)
- Shell history and `gh` auth persist across container rebuilds via named volumes
- A hook for project-specific setup (`.devcontainer-local/`)
- `.devcontainer` is mounted read-only for security
- Session state persists across container rebuilds via named volumes

## Host Requirements

Before using this devcontainer you need:

1. **Docker Desktop or Docker Engine** installed and running
2. **VS Code** with the
   [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
   (or another devcontainer-compatible IDE)
3. **SSH agent** running on the host — either `ssh-agent` or the
   1Password SSH agent. VS Code forwards the agent socket automatically.
4. **`~/.claude` configured** — Claude Code installed on the host and
   authenticated at least once so `~/.claude/settings.json` exists
5. **`~/.gitconfig` present** with your name and email
6. **`CLAUDE_CODE_OAUTH_TOKEN` exported** — required for Claude Code Pro/Max
   subscriptions on macOS (see [Authentication](#authentication) below)

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

### postCreate hook

Create `.devcontainer-local/postCreate.sh` at your project root:

```bash
#!/usr/bin/env bash
# .devcontainer-local/postCreate.sh
# Runs inside the container after creation

# Example: install Python deps with uv
uv sync
```

The devcontainer's `postCreate.sh` sources this file automatically.

### Environment file

Create `.devcontainer-local/env` at your project root to inject environment
variables into the container shell:

```bash
# .devcontainer-local/env
MY_API_KEY=some-value
DATABASE_URL=postgres://localhost/mydb
```

Lines starting with `#` and blank lines are ignored. Variables are exported
in `.zshrc` so they're available in all shell sessions.

### Build overrides

Parent repos can provide their own `devcontainer.json` referencing
`.devcontainer/Dockerfile` with custom `build.args`, mounts, env, etc.:

```json
{
  "build": {
    "context": ".devcontainer",
    "dockerfile": ".devcontainer/Dockerfile",
    "args": {
      "INSTALL_RUST": "true",
      "INSTALL_GO": "true",
      "GO_VERSION": "1.23"
    }
  }
}
```

## Authentication

Claude Code Pro/Max subscriptions use OAuth tokens stored in the macOS
Keychain, which containers cannot access. The devcontainer forwards
`CLAUDE_CODE_OAUTH_TOKEN` so Claude Code can authenticate without an
interactive login.

Generate a long-lived OAuth token on the host:

```bash
claude setup-token
```

This prints a token value. You can supply it to VS Code in two ways:

### Option A — 1Password (recommended)

Store the token in 1Password, then use the template in this repo:

```bash
# Edit .env.tpl to point at your vault / item / field
op run --env-file=.env.tpl -- code .
```

`op run` injects the secret into the environment without writing it to disk.
VS Code inherits the variable and the devcontainer forwards it automatically.

Alternatively, generate a `.env` file once and source it:

```bash
op inject -i .env.tpl -o .env   # writes the real value to .env (gitignored)
source .env                      # then open VS Code normally
```

### Option B — shell profile

Export the token directly in `~/.zshrc` (or `~/.zprofile`):

```bash
export CLAUDE_CODE_OAUTH_TOKEN="<token from setup-token>"
```

> **Tip:** If you launch VS Code from Spotlight or the Dock rather than a
> terminal, `~/.zshrc` is not sourced. Put the export in `~/.zprofile`
> instead, or launch VS Code with `code .` from a terminal.

**Linux hosts** — Claude Code stores credentials in
`~/.claude/.credentials.json` instead of a keychain, so the `~/.claude` mount
should work without this step.

## Build Arguments

Pass these via `devcontainer.json`'s `build.args` in your project:

| ARG | Default | Description |
|-----|---------|-------------|
| `UV_VERSION` | `latest` | uv (Python package manager) version |
| `INSTALL_GEMINI` | `false` | Install Gemini CLI (installs Node.js via apt) |
| `INSTALL_GO` | `false` | Install Go toolchain system-wide |
| `GO_VERSION` | `1.24` | Go version (only used when `INSTALL_GO=true`) |
| `INSTALL_RUST` | `false` | Install Rust via rustup (user-level) |

When Rust is installed, `postCreate.sh` automatically sources
`~/.cargo/env` in `.zshrc` so `cargo` and `rustc` are on `PATH`.

## CI

The repository includes a GitHub Actions workflow (`.github/workflows/build.yml`)
that validates container builds on every push to `main` and on pull requests.
It runs two jobs:

- **build** — matrix build of the `base` and `agents` Dockerfile targets
- **build-with-optional-tools** — builds `agents` with all optional ARGs enabled
  (`INSTALL_GEMINI`, `INSTALL_GO`, `INSTALL_RUST`)

## MCP Forwarding

MCP server configurations are **not** forwarded by default. If you want to
forward MCP config files into the container, add bind mounts to your parent
repo's `devcontainer.json`:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.claude/claude_desktop_config.json,target=/home/vscode/.claude-host/claude_desktop_config.json,type=bind,readonly",
    "source=${localEnv:HOME}/.claude/mcp_servers.json,target=/home/vscode/.claude-host/mcp_servers.json,type=bind,readonly"
  ]
}
```

The `postCreate.sh` script will detect these files and copy them into the
container with all `env` values stripped (set to empty strings) so that
server definitions are available but API keys are not leaked into the
container. You'll need to provide the actual keys via
`.devcontainer-local/env` or `containerEnv`.

## Session State Persistence

The named volume `claude-code-config-${devcontainerId}` is mounted at
`~/.claude` inside the container. This means Claude Code session state,
conversation history, and settings persist across container rebuilds. Only
a full `docker volume rm` will clear this data.

## Podman

VS Code does not automatically forward the SSH agent socket when using
Podman as the container runtime. You must bind-mount the socket manually.

**Linux** — the socket is typically at `$SSH_AUTH_SOCK`:

```json
{
  "mounts": [
    "source=${localEnv:SSH_AUTH_SOCK},target=/tmp/ssh-agent.sock,type=bind"
  ],
  "containerEnv": {
    "SSH_AUTH_SOCK": "/tmp/ssh-agent.sock"
  }
}
```

**macOS** — if using the default ssh-agent:

```json
{
  "mounts": [
    "source=/run/host-services/ssh-auth.sock,target=/tmp/ssh-agent.sock,type=bind"
  ],
  "containerEnv": {
    "SSH_AUTH_SOCK": "/tmp/ssh-agent.sock"
  }
}
```

**1Password SSH agent** — mount the 1Password agent socket instead:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.1password/agent.sock,target=/tmp/ssh-agent.sock,type=bind"
  ],
  "containerEnv": {
    "SSH_AUTH_SOCK": "/tmp/ssh-agent.sock"
  }
}
```

## Security Notes

- API keys (`ANTHROPIC_API_KEY` etc.) are **not** forwarded into the container
- Only `settings.json` and `CLAUDE.md` are mounted from `~/.claude` — secrets,
  credentials, and session data stay on the host
- MCP server configurations that require API keys will not function inside
  the container unless explicitly mounted and re-keyed (this is intentional)
