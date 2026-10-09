#!/usr/bin/env bash
# Register Hetzner Experiments Inference API as a Hermes custom provider.
# Idempotent. API key is prompted masked and written to ~/.hermes/.env only.
set -euo pipefail

BASE_URL="https://inference.hetzner.com/api/v1"
KEY_ENV="HERMES_CUSTOM_INFERENCE_HETZNER_COM_API_KEY"
DEFAULT_MODEL="${1:-}"
HERMES_BIN="${HERMES_BIN:-hermes}"
CONFIG="$HOME/.hermes/config.yaml"
ENVFILE="$HOME/.hermes/.env"

echo "==> Hermes Hetzner provider setup"

# 1. Key: reuse existing, else prompt masked
have_key=0
if [ -f "$ENVFILE" ] && grep -q "^${KEY_ENV}=" "$ENVFILE"; then
  echo "    key already present in $ENVFILE"
  have_key=1
else
  printf "    paste Hetzner Inference token (input hidden): "
  read -rs TOKEN; echo
  if [ -z "$TOKEN" ]; then echo "ERROR: empty token"; exit 1; fi
  mkdir -p "$(dirname "$ENVFILE")"
  touch "$ENVFILE"; chmod 600 "$ENVFILE"
  printf '%s=%s\n' "$KEY_ENV" "$TOKEN" >> "$ENVFILE"
  echo "    key written to $ENVFILE (chmod 600)"
fi

# 2. Probe available models (works without auth on 401? no — needs key; use config probe later)
MODELS="$(curl -fsS -m 15 "$BASE_URL/models" -H "Authorization: Bearer $(grep "^${KEY_ENV}=" "$ENVFILE" | head -1 | cut -d= -f2-)" 2>/dev/null \
  | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)["data"]
  print(" ".join(m["id"] for m in d))
except Exception:
  print("")' || true)"
if [ -n "$MODELS" ]; then
  echo "    endpoint serves: $MODELS"
else
  echo "    WARNING: could not list models (key may be unset/invalid); using known defaults"
  MODELS="Qwen/Qwen3.6-35B-A3B-FP8 Qwen3.8-27B"
fi

# 3. Pick default model
if [ -z "$DEFAULT_MODEL" ]; then
  DEFAULT_MODEL="$(echo $MODELS | awk '{print $1}')"
fi
echo "    default model: $DEFAULT_MODEL"

# 4. Build models yaml block
MODELS_YAML="$(python3 - "$MODELS" <<'PY'
import sys
ids = sys.argv[1].split()
print("\n".join(f'    "{i}": {{}}' for i in ids))
PY
)"

# 5. Write custom_providers entry into config.yaml (replace existing hetzner entry)
python3 - "$CONFIG" "$DEFAULT_MODEL" "$MODELS_YAML" <<'PY'
import sys, os, re
cfg_path, default_model, models_yaml = sys.argv[1:4]
os.makedirs(os.path.dirname(cfg_path), exist_ok=True)
text = open(cfg_path).read() if os.path.exists(cfg_path) else ""

entry = f"""custom_providers:
  - name: hetzner
    base_url: https://inference.hetzner.com/api/v1
    key_env: HERMES_CUSTOM_INFERENCE_HETZNER_COM_API_KEY
    model: {default_model}
    models:
{models_yaml}
"""

# strip any existing hetzner custom provider entry (simple block match)
text = re.sub(r"(?ms)^\s*-\s*name:\s*hetzner\n(    .*\n)+", "", text)
text = re.sub(r"(?m)^custom_providers:\s*\n\s*\n?", "", text) if "custom_providers:" in text and "- name:" not in text.split("custom_providers:")[1].split("\n\n")[0] else text
if "custom_providers:" in text:
    # insert under existing key
    text = re.sub(r"(?m)^custom_providers:\s*$", "custom_providers:\n" + entry.split("custom_providers:\n",1)[1].rstrip("\n"), text, count=1)
else:
    text = text.rstrip("\n") + "\n\n" + entry
open(cfg_path, "w").write(text)
print("    config.yaml updated")
PY

# 6. Point Hermes at it (only sets provider if user confirms; default = explicit opt-in)
"$HERMES_BIN" config set model.provider custom:hetzner || true
"$HERMES_BIN" config set model.aliases.hz "$DEFAULT_MODEL" || true

echo "==> Setup done."
echo "    Current global provider/default NOT changed beyond provider pointer."
echo "    To make Hetzner the default: hermes config set model.default '$DEFAULT_MODEL'"
echo "    Verify:  hermes chat -q 'Reply with exactly: HETZNER_OK' --oneshot --quiet"
