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

ARG USERNAME=vscode
ARG NODE_VERSION=lts/*
ARG NVM_DIR=/usr/local/share/nvm

# Install nvm + Node.js + Claude Code
RUN mkdir -p "${NVM_DIR}" \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | NVM_DIR="${NVM_DIR}" bash \
    && . "${NVM_DIR}/nvm.sh" \
    && nvm install "${NODE_VERSION}" \
    && nvm use "${NODE_VERSION}" \
    && nvm alias default "${NODE_VERSION}" \
    && npm install -g @anthropic-ai/claude-code \
    && chown -R "${USERNAME}:${USERNAME}" "${NVM_DIR}"

# Container opens in the workspace
WORKDIR /workspaces
