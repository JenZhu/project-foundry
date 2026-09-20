# 03 - Models

## Selection principles

1. **Local-first.** Only models that run in llama.cpp/MLX on Apple Silicon. No cloud dependency for routine work.
2. **Function-matched.** A general model for most agents, a coder for engineering, a reasoning model for hard problems. One size does not fit all.
3. **Quantized to fit.** Use GGUF quantizations sized to unified memory, not the full BF16 weights.
4. **License-checked.** Everything below is permissively or openly licensed for internal commercial use. Verify against your own counsel before redistributing.

## The model set

| Role | Model | Quant | RAM | Serves |
|---|---|---|---|---|
| General | `Qwen2.5-72B-Instruct` | Q4_K_M | ~43GB | Atlas, Scribe |
| Coder | `Qwen2.5-Coder-32B-Instruct` | Q4_K_M | ~20GB | Forge |
| Reasoning | `DeepSeek-R1-Distill-Qwen-32B` | Q4_K_M | ~20GB | Reason (see `docs/06`) |
| Embeddings | `BAAI/bge-m3` | F16 | ~2GB | RAG over the vault |

Swap-ins, same roles:

- General: `Llama-3.3-70B-Instruct`, `Qwen3-72B`
- Coder: `Qwen2.5-Coder-14B` (lighter), `DeepSeek-Coder-V2-Lite`
- Reasoning: `DeepSeek-R1-Distill-Llama-70B` (heavier, better), `QwQ-32B`

## What "like this one" actually costs

A frontier cloud assistant (Claude, GPT, DeepSeek-V3/R1) is a 400B-1T parameter system. That does **not** run on a Mac Studio. The honest tradeoff:

| Want | Get locally | Gap |
|---|---|---|
| Routine drafting, summarization, triage | 70B is excellent | minimal |
| Code generation | 32B coder is strong | noticeable on novel/large systems |
| Hard multi-step reasoning | R1-Distill-32B/70B is good | real gap vs. frontier |
| Frontier-level everything | 671B DeepSeek on a 512GB box, ~5-15 tok/s, single stream | impractical for a team |

Set expectations with the team: the local fleet is the everyday workhorse, not a frontier lab model. If a specific task genuinely needs frontier quality, route *that one task* to a cloud model under policy - see `docs/06-deepseek-harness.md` and `docs/09-security.md`.

## Quantization guide

GGUF quant levels trade quality for size. Rules of thumb:

- **Q4_K_M** - the default. Best size/quality balance for general chat.
- **Q5_K_M / Q6_K** - better quality, bigger. Prefer for code (Forge) if memory allows.
- **Q8_0** - near-lossless, ~2x the size of Q4. Only if you have the RAM to spare.
- **Q3 / Q2 / IQ variants** - only when the model won't fit otherwise; visible quality loss.

Start everything at Q4_K_M, then bump Forge to Q5_K_M or Q6_K since the coder is only 32B and there is headroom.

## Where to get the files

GGUF files come from Hugging Face. Two ways to find the right one:

1. **The llama.cpp local-app page** for a repo gives the exact `llama-server` command and recommended quant:
   `https://huggingface.co/<repo>?local-app=llama.cpp`
2. **The tree API** confirms exact filenames and sizes:
   `https://huggingface.co/api/models/<repo>/tree/main?recursive=true`

Typical GGUF repos (verify at download time):

- `bartowski/Qwen2.5-72B-Instruct-GGUF`
- `bartowski/Qwen2.5-Coder-32B-Instruct-GGUF`
- `bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF`
- `gpustack/bge-m3-GGUF`

`scripts/download-models.sh` pulls the model set for you.

## Embeddings and RAG

`bge-m3` turns vault documents into vectors so agents can retrieve relevant notes instead of guessing. llama.cpp serves it with `--embeddings`. This is optional for the pilot but is the difference between an agent that "remembers what it read" and one that guesses. See `docs/05-hermes-agents.md` for wiring RAG into the fleet.
