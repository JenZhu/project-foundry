# 02 - Hardware

## Why Apple Silicon

The whole design rests on **unified memory**. On a Mac Studio the CPU and GPU share one physical memory pool, so a 192GB machine can hold a ~40GB model fully resident with no PCIe transfer bottleneck. That is what makes "a 70B model on a $4-6k box serving a small team" viable. An x86 server with a comparable GPU would cost 3-5x more and need a datacenter.

## The pilot box (3-5 people)

| Item | Spec | Why |
|---|---|---|
| **Mac Studio** | M3 Ultra, **256GB** unified memory | Runs a 70B + a 32B coder + a reasoning model + embeddings, all at once, with headroom |
| *(value option)* | M2 Ultra, **192GB** | Same job, slightly older, cheaper used |
| **Mac mini** (optional) | M4 Pro, 64GB | Cold spare; also runs the Watch watchdog agent |
| Storage | 2TB internal | Models live on disk too; a 70B Q4 is ~40GB, plus a coder and a reasoning model |

You do **not** need two Studios at this scale. "A couple of boxes" was the instinct for 50 people. At 3-5 people, one box plus a cheap spare is correct.

## RAM math (the number that matters)

Unified memory is the binding constraint. Co-resident model footprint on the pilot box:

| Model | Quant | RAM |
|---|---|---|
| Qwen2.5-72B-Instruct | Q4_K_M | ~43GB |
| Qwen2.5-Coder-32B-Instruct | Q4_K_M | ~20GB |
| DeepSeek-R1-Distill-Qwen-32B | Q4_K_M | ~20GB |
| bge-m3 (embeddings) | F16 | ~2GB |
| **Total** | | **~85GB** |

That leaves ~100GB of a 192GB box for the OS, agents, context (KV cache), and future headroom. Comfortable. On a 256GB box, even more room for a second 70B or larger context windows.

## Concurrency reality

Local inference is roughly one stream at full speed. A 70B Q4 on an M3 Ultra does ~25-35 tokens/sec. That translates to:

| Concurrent interactive users | Feel |
|---|---|
| 1-2 | snappy |
| 3-5 | fine, slightly slower at peak |
| 8+ | queues start; add a second box |

For 3-5 people this is a non-issue. For 30-50, see `docs/08-scaling.md`.

## Sizing table (pilot → full team)

| Headcount | Hardware | Models | Notes |
|---|---|---|---|
| 3-5 | 1x Studio (192-256GB) | 70B + 32B coder + reasoning | the pilot |
| 5-15 | 2x Studio | split general vs. code/reasoning | add one box, repoint some profiles |
| 15-30 | 3-4x Studio | per-function boxes | add a LiteLLM router in front |
| 30-50 | 4-6x Studio + router | mixed fleet | the full deployment |

The unit of scale is the Mac Studio. Adding capacity is "buy a box, point profiles at it."

## Power, cooling, and network

- **Power**: a Mac Studio idles around 20-40W, peaks ~300W under load. Runs on a normal outlet. No UPS strictly required, but a cheap one prevents a power blip from killing a long generation.
- **Cooling**: self-contained, near-silent. A closet with airflow is fine.
- **Network**: wired Ethernet. The agents talk to the inference server over `localhost`, so the box itself only needs outbound access for the bridge (Telegram/Slack) and OS updates.
- **Headless**: the box runs headless. Enable **auto-login** and **power-failure auto-restart**, and decide whether **FileVault** is worth the "power cut = stuck at unlock screen until someone types the password" tradeoff. These three interact - get them right before you walk away from it. See `docs/09-security.md`.

## Buy list (pilot)

1. Mac Studio, M3 Ultra 256GB (or M2 Ultra 192GB used)
2. Optional Mac mini M4 Pro 64GB (spare + watchdog)
3. Ethernet cable
4. Small UPS (optional, recommended)
