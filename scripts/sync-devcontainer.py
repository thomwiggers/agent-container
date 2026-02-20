#!/usr/bin/env python3
"""Sync root devcontainer.json -> .devcontainer/devcontainer.json.

The root file is the canonical config (consumed when used as a submodule).
The .devcontainer/ copy is adjusted so this repo can be developed from
within its own devcontainer (build paths prepended with ../).
"""

import json
import posixpath
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ROOT_CONFIG = REPO_ROOT / "devcontainer.json"
DEVCONTAINER_CONFIG = REPO_ROOT / ".devcontainer" / "devcontainer.json"


def main() -> int:
    config = json.loads(ROOT_CONFIG.read_text())

    # .devcontainer/ sits one level below the repo root, so build paths
    # that are relative to devcontainer.json need a ../ prefix.
    build = config.get("build", {})
    for key in ("context", "dockerfile"):
        if key in build:
            build[key] = posixpath.normpath(posixpath.join("..", build[key]))

    mounts = []
    for mount in config.get("mounts", []):
        if ".devcontainer" in mount:
            continue
        mounts.append(mount)
    config["mounts"] = mounts

    DEVCONTAINER_CONFIG.write_text(json.dumps(config, indent=2) + "\n")
    print(f"Synced {ROOT_CONFIG.relative_to(REPO_ROOT)}"
          f" -> {DEVCONTAINER_CONFIG.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
