"""Hetzner Inference provider profile.

Hetzner Experiments Inference — free OpenAI-compatible endpoint at
https://inference.hetzner.com/api/v1. Token generated at
https://experiments.hetzner.com/inference (shown once).

Drop this directory into ``~/.hermes/plugins/model-providers/hetzner/`` and
run ``hermes model`` — Hetzner appears in the picker like any built-in
provider and prompts for HETZNER_INFERENCE_API_KEY.
"""

from providers import register_provider
from providers.base import ProviderProfile

hetzner = ProviderProfile(
    name="hetzner",
    aliases=("hetzner-inference", "hz"),
    display_name="Hetzner Inference",
    description="Hetzner Experiments — free EU OpenAI-compatible API",
    signup_url="https://experiments.hetzner.com/inference",
    env_vars=("HETZNER_INFERENCE_API_KEY",),
    base_url="https://inference.hetzner.com/api/v1",
    auth_type="api_key",
    supports_vision=True,
    fallback_models=("Qwen/Qwen3.6-35B-A3B-FP8", "Qwen3.8-27B"),
)

register_provider(hetzner)
