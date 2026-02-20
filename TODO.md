# TODO

## Future Work

### Migrate to Docker Compose

Switch from a single-container `build`-based `devcontainer.json` to a Docker
Compose setup. Benefits:

- **Extensible devcontainer.json**: parent repos can layer a
  `compose.override.yaml` on top instead of replacing the entire
  `devcontainer.json` (Docker Compose deep-merges multiple files)
- **Isolated MCP servers**: run MCP servers in separate containers, isolated
  from the agent container — no shared filesystem or process namespace
- **Per-service resource limits**: constrain CPU/memory per container
