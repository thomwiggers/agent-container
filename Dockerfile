# syntax=docker/dockerfile:1

# ─── Stage 1: base ────────────────────────────────────────────────────────────
ARG UV_VERSION=latest
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 AS base

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

# Create directories and set ownership (combined for fewer layers)
RUN mkdir -p /commandhistory /workspace /home/vscode/.claude /opt && \
  touch /commandhistory/.bash_history && \
  touch /commandhistory/.zsh_history && \
  chown -R vscode:vscode /commandhistory /workspace /home/vscode/.claude /opt

# Set environment variables
ENV DEVCONTAINER=true
ENV SHELL=/bin/zsh

# Install uv (Python package manager) via multi-stage copy
COPY --from=uv /uv /usr/local/bin/uv

# Install Claude Code as container user (official installer manages its own Node runtime)
USER vscode
RUN curl -fsSL https://claude.ai/install.sh | bash

# Container opens in the workspace
WORKDIR /workspaces
