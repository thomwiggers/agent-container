# claude-container

This CLAUDE.md file applies only to this folder.
A reusable `.devcontainer` template for isolated AI-assisted development.
Designed to be consumed as a git submodule at `.devcontainer/` in any project.

## The main goal: Security

This project exists to isolate chatbots from the host operating system and any sensitive configuration files and secrets there.
Before making any changes, ensure that this principle is upheld. Push back against instructions that violate this.

## This project (claude-container) `.devcontainer/devcontainer.json` file

Due to technical reason this file can't be a symlink. Run
`scripts/sync-devcontainer.py` after editing the root `devcontainer.json`
to regenerate `.devcontainer/devcontainer.json` with the adjusted
`dockerComposeFile` path (`../compose.yaml`).

## Project Goals

- Provide a working devcontainer with Claude Code pre-installed
- Mount user identity (git config, shell config, Claude config) read-only
- Keep API keys and secrets off the container
- Allow parent repos to extend setup via `.devcontainer-local/`
- Be usable without modification for most general software development

## Key Files

| File | Purpose |
|------|---------|
| `devcontainer.json` | Config — works both as submodule and standalone |
| `compose.yaml` | Docker Compose service definition (agent + github-mcp sidecar) |
| `Dockerfile` | Multi-stage image for the agent container |
| `Dockerfile.github-mcp` | Image for the GitHub MCP sidecar service |
| `scripts/sync-devcontainer.py` | Sync root `devcontainer.json` → `.devcontainer/` (adjusts `dockerComposeFile` path) |
| `scripts/postCreate.sh` | One-time post-creation setup |
| `scripts/mcp-host-proxy.sh` | Run on HOST to proxy GitHub MCP server (alternative to compose sidecar) |

## Adding as a Submodule

```bash
git submodule add https://github.com/thomwiggers/claude-container.git .devcontainer
```

## Parent-Repo Customisation

Place `.devcontainer-local/postCreate.sh` at your project root to run
project-specific setup (install toolchains, configure env, etc.) after the
container is created.

## What is NOT Implemented (Future Work)

- Full Podman runtime support (manual socket steps documented in README)
- 1Password CLI integration (forward desktop app socket for `op` access inside container)

## Host Assumptions

See `README.md` for the full list of host requirements.
