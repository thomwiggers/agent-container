# syntax=docker/dockerfile:1

# ─── Stage 1: base ────────────────────────────────────────────────────────────
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

# Install Claude Code as container user (official installer manages its own Node runtime)
USER vscode
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root

# Container opens in the workspace
WORKDIR /workspaces
