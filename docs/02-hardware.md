# 02 - Hardware

## Why Apple Silicon

The whole design rests on **unified memory**. On a Mac Studio the CPU and GPU share one physical memory pool, so a 192GB machine can hold a ~40GB model fully resident with no PCIe transfer bottleneck. That is what makes "a 70B model on a ~$7k box serving a team" viable. An x86 server with a comparable GPU would cost 3-5x more and need a datacenter.

## The load model

The target is **20-30 people at steady load**. Steady means work is spread through the day, not meeting-driven bursts, so the concurrent-user estimate is reliable:

- **Peak concurrent interactive sessions: ~8-12** (25-40% of headcount active at once).
- Background/batch agents (overnight summarization, inbox triage, PR review) queue gracefully and do not drive sizing.

That 8-12 number is what the fleet is sized for. If the operator's reality is burstier (everyone returns from a meeting and hits agents at once), add a box to whichever design you pick.

## Phase 1 - the de-risk pilot (3-5 people)

Before the fleet, one box proves the concept:

| Item | Spec | Why |
|---|---|---|
| **Mac Studio** | M3 Ultra, **256GB** (or M2 Ultra 192GB used) | runs the full model set with headroom |
| **Mac mini** (optional) | M4 Pro | runs the Watch watchdog agent; becomes the fleet's ops box later |

Two weeks, ~$7k. The pilot answers the one question that can kill the project: *is the local model good enough that the team will actually use it?* Everything below assumes that answer is yes.

## Phase 2 - the fleet (20-30 people, steady)

Two defensible designs. Both assume a LiteLLM router in front and a Mini for the watchdog.

### Option A - Tiered (recommended)

Match model size to task. Routine work goes to a fast, high-concurrency 32B; heavy work goes to the 70B flagship.

| Box | Models | Role | Serves |
|---|---|---|---|
| Studio 1 | Qwen2.5-72B | heavy general | Atlas, Scribe (big jobs) |
| Studio 2 | Qwen2.5-72B | heavy general (surge capacity) | Atlas, Scribe |
| Studio 3 | Qwen2.5-32B + Coder-32B + R1-Distill-32B | routine general + code + reasoning | most traffic |
| Mini | small model | Watch / fleet ops | cron, healthchecks |

**~$22k one-time** (3 Studios + 1 Mini + router software). Capacity: ~14-20 concurrent, comfortable headroom over the 8-12 peak.

### Option B - All-70B

Every request gets the flagship. No tiering mental model, more peak headroom, marginally better routine answers.

| Box | Models | Role |
|---|---|---|
| Studio 1-4 | Qwen2.5-72B | general for everyone |
| Studio 5 | Coder-32B + R1-Distill-70B | code + heavy reasoning |
| Mini | small model | Watch / fleet ops |

**~$36k one-time** (5 Studios + 1 Mini + router software). Capacity: ~18-24 concurrent.

## The tradeoff, stated plainly

| Dimension | Tiered | All-70B |
|---|---|---|
| Cost | ~$22k | ~$36k |
| Heavy work (analysis, strategy, long drafting) | **70B flagship** | 70B flagship |
| Routine work (quick answers, triage, code) | 32B | 70B |
| Peak capacity | ~14-20 | ~18-24 |
| Operational simplicity | two tiers to route | one model everywhere |

**What the extra ~$14k buys:** flagship quality on *routine* tasks - where a 32B is already doing the job well - plus insurance against a burstier-than-expected load profile. It does **not** buy a night-and-day difference on the heavy work, because both designs put a 70B there. If the operator's work is heavily analytical, all-70B is justifiable. If it is the typical mix of routine and occasional deep work, tiered captures most of the value at 60% of the cost.

**Recommendation: start tiered.** It is trivially reversible - if the team reports quality complaints on routine tasks, add a fourth Studio and promote the affected profiles to 70B. Going the other direction (buying 5 boxes and later wishing you had only spent 3) is not reversible.

## RAM math (the number that matters)

Unified memory is the binding constraint. Co-resident model footprint per box:

| Model | Quant | RAM |
|---|---|---|
| Qwen2.5-72B-Instruct | Q4_K_M | ~43GB |
| Qwen2.5-32B-Instruct | Q4_K_M | ~20GB |
| Qwen2.5-Coder-32B-Instruct | Q4_K_M | ~20GB |
| DeepSeek-R1-Distill-Qwen-32B | Q4_K_M | ~20GB |
| bge-m3 (embeddings) | F16 | ~2GB |

A 256GB box holds a 70B plus several 32B models and embeddings with room for the OS and KV cache. A 192GB box holds a 70B plus one 32B comfortably. Match the box's RAM to what it must co-reside.

## Concurrency reality

Local inference is roughly one stream at full speed:

| Model | Tokens/sec | Comfortable concurrent sessions |
|---|---|---|
| 70B (Q4) | ~25-35 | 3-5 |
| 32B (Q4) | ~45-60 | 8-10 |

A 32B serves roughly 2-3x the concurrent users of a 70B - which is exactly why tiering is the cost lever it is. Human reading speed is ~8-10 tok/s, so a session stays responsive as long as its share of throughput stays above that line.

## Power, cooling, and network

- **Power**: a Mac Studio idles ~20-40W, peaks ~300W under load. A fleet of 3-5 runs on ordinary outlets. A UPS is cheap insurance against a power blip killing long generations.
- **Cooling**: self-contained and near-silent. A closet or rack shelf with airflow is fine.
- **Network**: wired Ethernet between the boxes. Inference binds to `127.0.0.1` on each box; the router (LiteLLM) is the single LAN endpoint the agents call. Nothing is exposed to the public internet.
- **Headless**: the boxes run headless. Enable auto-login and power-failure auto-restart, and decide the FileVault tradeoff deliberately. See `docs/09-security.md`.

## Buy list

**Pilot:** 1x Mac Studio M3 Ultra 256GB (or M2 Ultra 192GB used), 1x Mac mini, Ethernet cables, a UPS.

**Fleet (tiered):** +2x Mac Studio M3 Ultra 256GB, a small switch, and LiteLLM running on one of the boxes (or the Mini). Total 3 Studios + 1 Mini.
