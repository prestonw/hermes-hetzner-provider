# hermes-hetzner-provider

One-shot setup that registers the **Hetzner Experiments Inference API**
(https://inference.hetzner.com/api/v1 — OpenAI-compatible, free, EU-hosted)
as a custom provider in [Hermes Agent](https://hermes-agent.nousresearch.com/docs),
then verifies it with a live inference call.

## Install on a new Hermes client

```bash
git clone https://github.com/prestonw/hermes-hetzner-provider.git
cd hermes-hetzner-provider
./scripts/setup.sh
```

The script:

1. Registers the custom provider entry in `~/.hermes/config.yaml`
   (`custom_providers: hetzner`, base_url `https://inference.hetzner.com/api/v1`).
2. Writes `HERMES_CUSTOM_INFERENCE_HETZNER_COM_API_KEY=<your key>` to
   `~/.hermes/.env` — the key is prompted for **masked**, never stored in the repo.
   Get a token at https://experiments.hetzner.com (Hetzner Console → Experiments → Inference).
3. Sets a default model and friendly aliases.
4. Verifies with `hermes chat -q "Reply with exactly: HETZNER_OK"`.

Idempotent — safe to re-run (e.g. after Hetzner adds new models; the model list
is refreshed from the live `/models` endpoint each run).

## Models (as of setup date)

| Model | Type | Context |
|---|---|---|
| `Qwen/Qwen3.6-35B-A3B-FP8` | MoE 35B/3B active + vision | 262k |
| `Qwen3.8-27B` | Dense + vision | 262k |

The probe lists whatever `/models` currently returns; pass a model id as the
first argument to override the default:
`./scripts/setup.sh Qwen3.8-27B`

## Manual setup (equivalent)

```bash
hermes config set custom_providers '[{name: hetzner,
  base_url: "https://inference.hetzner.com/api/v1",
  key_env: HERMES_CUSTOM_INFERENCE_HETZNER_COM_API_KEY,
  model: "Qwen/Qwen3.6-35B-A3B-FP8",
  models: {"Qwen/Qwen3.6-35B-A3B-FP8": {}, "Qwen3.8-27B": {}}}]'
echo 'HERMES_CUSTOM_INFERENCE_HETZNER_COM_API_KEY=<your token>' >> ~/.hermes/.env
hermes config set model.provider custom:hetzner
hermes config set model.default "Qwen/Qwen3.6-35B-A3B-FP8"
hermes config set model.aliases.hz "Qwen/Qwen3.6-35B-A3B-FP8"
hermes chat -q "Reply with exactly: HETZNER_OK" --oneshot --quiet
```

Use `/model hz` in a session to switch; this setup does NOT change your
existing global default unless you also run
`hermes config set model.default 'Qwen/Qwen3.6-35B-A3B-FP8'`.

## Notes

- Hetzner Inference is an **experiment**: no SLA, no billing, models may change.
- The provider is referenced as `custom:hetzner` everywhere (fallback chains:
  `hermes config set fallback_providers '[{provider: custom:hetzner, model: "Qwen/Qwen3.6-35B-A3B-FP8"}]'`).
