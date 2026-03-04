# syntax=docker/dockerfile:1

# ─── Stage 1: base ────────────────────────────────────────────────────────────
ARG UV_VERSION=latest
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 AS base

# Install common dev tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update && apt-get install -y --no-install-recommends \
        curl \
        git \
        zsh \
        vim \
        jq \
        make \
        build-essential \
        python3 \
        python3-venv

# ─── Stage 2: agents ──────────────────────────────────────────────────────────
FROM base AS agents

# Create directories and set ownership (combined for fewer layers)
RUN mkdir -p /commandhistory /workspace /home/vscode/.claude /opt && \
  touch /commandhistory/.bash_history && \
  touch /commandhistory/.zsh_history && \
  chown -R vscode:vscode /commandhistory /workspace /home/vscode/ /opt

# Set environment variables
ENV DEVCONTAINER=true
ENV SHELL=/bin/zsh

# Install uv (Python package manager) via multi-stage copy
COPY --from=uv /uv /usr/local/bin/uv

# ── Optional: Gemini CLI (ARG-gated) ─────────────────────────────────────────
ARG INSTALL_GEMINI=false
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    if [ "${INSTALL_GEMINI}" = "true" ]; then \
      apt-get update && apt-get install -y --no-install-recommends nodejs npm \
      && npm install -g @google/gemini-cli; \
    fi

# ── Optional: Go (ARG-gated, system-wide) ────────────────────────────────────
ARG INSTALL_GO=false
ARG GO_VERSION=1.24
RUN if [ "${INSTALL_GO}" = "true" ]; then \
      curl -fsSL -o /tmp/go.tar.gz \
        "https://dl.google.com/go/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
      && tar -C /usr/local -xzf /tmp/go.tar.gz \
      && rm /tmp/go.tar.gz \
      && ln -s /usr/local/go/bin/go /usr/local/bin/go \
      && ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt; \
    fi

# Install Claude Code as container user (official installer manages its own Node runtime)
USER vscode
RUN curl -fsSL https://claude.ai/install.sh | bash

# ── Optional: Rust (ARG-gated, user-level) ───────────────────────────────────
ARG INSTALL_RUST=false
RUN if [ "${INSTALL_RUST}" = "true" ]; then \
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path; \
    fi

# Container opens in the workspace
WORKDIR /workspaces
