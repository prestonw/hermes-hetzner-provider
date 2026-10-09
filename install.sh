#!/usr/bin/env bash
# Install the Hetzner Inference model-provider plugin for Hermes Agent.
# After this, `hermes model` lists "Hetzner Inference" and prompts for the key.
set -euo pipefail

DEST="${HERMES_HOME:-$HOME/.hermes}/plugins/model-providers/hetzner"
SRC="$(cd "$(dirname "$0")" && pwd)/model-provider/hetzner"

mkdir -p "$DEST"
cp -R "$SRC/." "$DEST/"
echo "installed plugin -> $DEST"

# verify discovery (python path independent of install layout)
if command -v hermes >/dev/null 2>&1; then
  python3 - "$DEST" <<'PY' && echo "OK: hetzner provider registered"
import sys, os
# find hermes-agent source: venv-adjacent or ~/.hermes/hermes-agent
import importlib.util, pathlib
candidates = [
    pathlib.Path(os.path.expanduser("~/.hermes/hermes-agent")),
    pathlib.Path(sys.executable).parent.parent,  # venv root
]
base = next((c for c in candidates if (c / "providers").exists()), None)
if base is None:
    print("WARN: hermes-agent source not found; skipping discovery check"); sys.exit(0)
sys.path.insert(0, str(base))
sys.path.insert(0, str(pathlib.Path(sys.argv[1]).parent.parent))  # plugins/model-providers
import providers
names = [p.name for p in providers.list_providers()]
sys.exit(0 if "hetzner" in names else 1)
PY
else
  echo "hermes CLI not on PATH — plugin installed; run `hermes model` after install."
fi
echo "Next: hermes model  →  pick 'Hetzner Inference'  →  paste your token"
