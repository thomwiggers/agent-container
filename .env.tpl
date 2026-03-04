# 1Password secret template for claude-container
#
# Usage (pick one):
#
#   # Inject secrets at launch time (recommended — never writes to disk):
#   op run --env-file=.env.tpl -- code .
#
#   # Or generate a .env file, then source it:
#   op inject -i .env.tpl -o .env
#   source .env          # then open VS Code normally
#
# Customise the op:// references to match your vault, item, and field names.
# See: https://developer.1password.com/docs/cli/secrets-reference-syntax/

CLAUDE_CODE_OAUTH_TOKEN="op://3nzmsfcyczi2cet7unez7ccth4/Claude Code Setup Token/referentie"
GITHUB_PERSONAL_ACCESS_TOKEN="op://Work/GitHub Personal Access Token/token"

# Workspace mount root relative to compose.yaml.
# Use ".." when this repo is a submodule at .devcontainer/ in a parent project.
# Use "." for standalone use (compose.yaml is already at the project root).
COMPOSE_WORKSPACE_ROOT=..
