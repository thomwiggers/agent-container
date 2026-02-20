# claude-container

A reusable `.devcontainer` template for isolated AI-assisted development.
Designed to be consumed as a git submodule at `.devcontainer/` in any project.

## This project (claude-container) `.devcontainer/devcontainer.json` file

Due to technical reason this file can't be a symlink. Make sure it is kept
up to date with the parent `devcontainer.json`.

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
| `Dockerfile` | Multi-stage image definition |
| `scripts/postCreate.sh` | One-time post-creation setup |

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
- Persist Claude session state across container rebuilds

## Host Assumptions

See `README.md` for the full list of host requirements.
