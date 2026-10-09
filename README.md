# hermes-hetzner-provider

Adds **Hetzner Experiments Inference** (https://inference.hetzner.com/api/v1 —
free, EU-hosted, OpenAI-compatible) as a first-class provider in
[Hermes Agent](https://hermes-agent.nousresearch.com/docs). After install it
appears in `hermes model`'s provider picker like any built-in — the picker
prompts for the API key itself, exactly like deepseek/openrouter/etc.

## Install on any Hermes client

```bash
git clone https://github.com/prestonw/hermes-hetzner-provider.git
cd hermes-hetzner-provider
./install.sh
hermes model        # pick "Hetzner Inference" — it asks for the key
```

`install.sh` copies `model-provider/hetzner/` into
`~/.hermes/plugins/model-providers/hetzner/` and verifies the provider
registers. The key is added through Hermes itself (`hermes model` picker,
`hermes auth add hetzner`, or Settings → Providers in the desktop app).

Get the token at https://experiments.hetzner.com/inference →
"Create API Token" (shown once).

## Use it

```bash
hermes model                          # interactive picker → select Hetzner
hermes chat -m hetzner -q "hi"        # one-shot on hetzner default
/model hz                             # in-session alias switch
```

Models are discovered live from `/v1/models`; fallback list ships
`Qwen/Qwen3.6-35B-A3B-FP8` and `Qwen3.8-27B`.

## Bonus: Technitium DNS guard

`scripts/dns-guard.sh` + `scripts/install-dns-guard.sh` fix/monitor a
Technitium DNS gotcha where a partial authoritative `github.com` zone makes
`api.github.com` NXDOMAIN network-wide. See `docs/dns-guard.md`.

## Layout

```
model-provider/hetzner/   the plugin (drop-in ProviderProfile)
install.sh                copies plugin into ~/.hermes/plugins/model-providers/
scripts/setup.sh          legacy: custom_providers config entry (no picker)
scripts/dns-guard.sh      hourly DNS self-heal for friday/Technitium
```

## Notes

- Hetzner Inference is an **experiment**: no SLA, no billing, models may change.
- Works on all hermes clients (CLI/TUI/desktop) since it's a standard plugin
  profile discovered at `~/.hermes/plugins/model-providers/`.
