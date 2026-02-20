#!/usr/bin/env bash
# Run this on the HOST machine to proxy the GitHub MCP server into the
# devcontainer over HTTP.  The GitHub token stays on the host — it never
# enters the container.
#
# Prerequisites: Node.js / npx installed on the host.
#
# Usage:
#   export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...
#   ./scripts/mcp-host-proxy.sh
#
# The container connects via http://host.docker.internal:<port>/sse
set -euo pipefail

: "${GITHUB_PERSONAL_ACCESS_TOKEN:?Export GITHUB_PERSONAL_ACCESS_TOKEN before running this script}"

PORT="${MCP_PROXY_PORT:-8765}"

echo "Starting GitHub MCP proxy on port ${PORT}…"
echo "Container URL: http://host.docker.internal:${PORT}/sse"
echo "Press Ctrl-C to stop."

exec npx -y supergateway \
  --stdio "npx -y @modelcontextprotocol/server-github" \
  --port "${PORT}"
