# Devcontainer Template Design

**Date**: 2026-02-20
**Status**: Approved

## Goal

A reusable `.devcontainer` template, consumed as a git submodule, optimised for
AI-assisted development with Claude Code and similar agents. The container
isolates the agent from the host OS while preserving the developer's identity
(git config, shell config, SSH access) in a read-only manner. API keys and
secrets are explicitly kept off the container.

---

## Repository Structure

```
claude-container/                 ← the repo; becomes .devcontainer/ as a submodule
├── devcontainer.json             ← used when repo IS .devcontainer/ (submodule case)
├── Dockerfile                    ← multi-stage image definition
├── scripts/
│   └── postCreate.sh             ← runs once after container creation
├── .devcontainer/
│   └── devcontainer.json         ← self-hosting: opens this repo in a container
├── CLAUDE.md                     ← project goals/instructions (keep up to date)
├── README.md                     ← setup assumptions, features, future work
└── docs/
    └── plans/                    ← design docs and implementation plans
```

The root `devcontainer.json` is what consumers get when they do:

```bash
git submodule add <url> .devcontainer
```

The `.devcontainer/devcontainer.json` is only for developing *this* repo —
it references `../Dockerfile` so both paths build the same image.

---

## Dockerfile (Multi-Stage)

```
Stage 1 – base
  FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04
  ARG USERNAME=vscode
  ARG NODE_VERSION=lts/*
  Common dev tools via apt (git, zsh, curl, etc.)

Stage 2 – agents  (default build target)
  Install Node.js via nvm (required for Claude Code)
  Install claude: npm install -g @anthropic-ai/claude-code
```

**Build ARGs** in `devcontainer.json` so parent repos can override via their
own `devcontainer.json` build args.

**Future**: Add an optional customisation stage for language toolchains (Rust,
Go, Python/uv, etc.) gated by ARGs. Add Gemini CLI as an ARG-gated option.

---

## Mounts and Runtime Configuration

All mounts are read-only unless noted.

| Host path        | Container path       | Notes                                  |
|------------------|----------------------|----------------------------------------|
| `~/.claude`      | `/root/.claude`      | Claude Code config, plugins, CLAUDE.md |
| `~/.gitconfig`   | `/root/.gitconfig`   | Git identity and signing config        |
| `~/.zshrc`       | `/root/.zshrc.host`  | Sourced by container's `.zshrc`        |
| SSH agent socket | forwarded            | Via VS Code SSH feature                |

**Secrets policy**: No API keys or tokens are forwarded into the container.
`ANTHROPIC_API_KEY` and similar env vars are explicitly excluded.

**SSH**: Uses `ghcr.io/devcontainers/features/sshd:1` feature which handles
agent socket forwarding through VS Code. Podman users must forward the socket
manually (documented in README).

---

## Parent-Repo Configuration Loading

When this repo is used as a `.devcontainer/` submodule, parent repos can provide
project-specific setup in a `.devcontainer-local/` folder at their project root:

```
parent-project/
├── .devcontainer/          ← this repo (submodule)
├── .devcontainer-local/
│   └── postCreate.sh       ← sourced by devcontainer's postCreate.sh
└── ...
```

`scripts/postCreate.sh` checks for `.devcontainer-local/postCreate.sh` one
level up from the workspace root and runs it if found.

**Future**: Support `.devcontainer-local/devcontainer.json` for build ARG
overrides (requires tooling outside of the VS Code devcontainer JSON spec to
merge/override; document the manual pattern in the README).

---

## What Is NOT in the MVP

| Feature                    | Status   | Notes                                   |
|----------------------------|----------|-----------------------------------------|
| Gemini CLI                 | Future   | Add as ARG-gated install in agents stage |
| Podman runtime detection   | Future   | Document manual steps in README         |
| MCP forwarding (no keys)   | Future   | Proxy approach or filtered config       |
| Image customisation layer  | Future   | Additional Dockerfile stage for toolchains |
| devcontainer.local.json    | Future   | JSON override/extend for build args     |
| uv / Python toolchain      | Future   | Optional stage                          |

---

## Host Assumptions (Documented in README)

- Docker Desktop or Docker Engine installed
- VS Code with the Dev Containers extension (or equivalent IDE)
- SSH agent running on the host (`ssh-agent` or 1Password SSH agent)
- `~/.claude` exists and is configured (Claude Code installed on host)
- `~/.gitconfig` exists with user identity
