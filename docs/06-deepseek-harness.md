# 06 - Parallel DeepSeek Harness

A second inference path running **DeepSeek-family models**, in parallel with the general Qwen/Llama models. It gives the fleet a dedicated *reasoning* tier - the thing DeepSeek is best at - without sending a single token to DeepSeek's cloud.

## What "harness" means here

Not a vendor SDK. It is a plain `llama-server` process (or MLX server) exposing a DeepSeek model as an OpenAI-compatible endpoint on its own port, wired into the `reason` agent profile. "Parallel" because it runs alongside the general and coder models as a separate, co-resident process.

## Local harness (the default)

```bash
llama-server \
  --hf-repo bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF \
  --hf-file '*Q4_K_M.gguf' \
  --port 8082 \
  --ctx-size 8192 \
  --n-gpu-layers 99
```

Point the `reason` profile at it:

```bash
hermes -p reason config set model.default "deepseek-r1-distill-qwen-32b"
hermes -p reason config set model.base_url "http://localhost:8082/v1"
hermes -p reason config set model.api_key "local"
```

That is the whole harness: a local DeepSeek model, OpenAI-compatible, agent-ready.

## Model choice for the harness

| Model | RAM (Q4) | Notes |
|---|---|---|
| `DeepSeek-R1-Distill-Qwen-32B` | ~20GB | the default - fast, strong reasoning, fits anywhere |
| `DeepSeek-R1-Distill-Llama-70B` | ~40GB | heavier, better reasoning, use on a 192GB+ box |
| `QwQ-32B` | ~20GB | non-DeepSeek reasoning alternative |

## Full DeepSeek 671B (for completeness, not the pilot)

The *actual* DeepSeek-V3/R1 is a 671B MoE. It runs on Apple Silicon only at the extreme:

- Requires a **512GB M3 Ultra** Mac Studio (~350GB for Q4, plus KV cache).
- Runs at ~5-15 tokens/sec, effectively **single stream**.
- Impractical for a team; included here so the tradeoff is explicit.

The distill models above capture most of the reasoning behavior at a fraction of the size. If you ever need the real thing, it is a *dedicated* box, not a shared fleet node.

## Cloud fallback (deliberate, not accidental)

There is a legitimate case for a cloud DeepSeek model on *some* tasks. If you choose it, do it on purpose:

```bash
# in the reason profile's .env
DEEPSEEK_API_KEY=sk-...
```

```bash
hermes -p reason config set model.provider "deepseek"
hermes -p reason config set model.default "deepseek-chat"
```

This reintroduces cloud, so gate it behind policy: cloud only for non-sensitive material, never for source or customer data. A hybrid is defensible - local by default, cloud for the rare frontier-grade task, with the boundary written down (see `docs/09-security.md`).

## Why parallel instead of replacing

The reasoning tier is slow and specialized. You do not want the whole fleet on R1-Distill - it over-reasons on trivial requests and burns context. Keeping it **parallel** means:

- General agents (Atlas, Scribe) stay on the fast 72B for everyday work.
- The `reason` agent is a specialist you reach for when a problem actually needs multi-step reasoning.
- Both share the same box, the same Hermes framework, the same bridge.

That separation is the point of a fleet over a single chatbot.
