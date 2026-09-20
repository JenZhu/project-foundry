# 08 - Scaling

The pilot is a single Mac Studio. Scaling to a 30-50 person team is **additive**: you buy more of the same box and point profiles at them. No rewrite.

## The unit of scale

One Mac Studio = one self-contained inference node (a few models, a few agent profiles). The full deployment is N nodes behind a router.

## Phase plan

| Phase | Headcount | Hardware | Topology |
|---|---|---|---|
| **Pilot** | 3-5 | 1x Studio (192-256GB) + 1 Mini spare | direct, no router |
| **Grow** | 5-15 | 2x Studio | split general vs. code/reasoning |
| **Scale** | 15-30 | 3-4x Studio | per-function nodes + router |
| **Fleet** | 30-50 | 4-6x Studio + router | mixed fleet, pooled |

## What actually changes at each step

### Pilot → Grow (add one box)

The concurrency math from `docs/02-hardware.md` starts to bite past ~5-8 simultaneous users. Buy a second Studio and split:

- **Box A** - general models (Qwen2.5-72B) for Atlas, Scribe, and most traffic.
- **Box B** - code + reasoning (Coder-32B, R1-Distill) for Forge and Reason.

Point each profile's `model.base_url` at the right box's IP:port (they are now on the LAN, not `localhost`). Done.

### Grow → Scale (add a router)

Once there are 3-4 boxes, put [LiteLLM](https://github.com/BerriAI/litellm) in front. It exposes a single OpenAI-compatible endpoint and:

- routes each request to the right model/box,
- queues under load instead of dropping,
- optionally falls back to a cloud model for a specific model name (policy-gated).

Every Hermes profile now points `model.base_url` at the LiteLLM endpoint instead of a box directly. Adding a box becomes a config change in one place.

### Scale → Fleet (pool and specialize)

At 30-50 people you are running a small on-prem inference service. What you add:

- **Dedicated nodes per function** (a coder node, a reasoning node, a general node) so heavy engineering traffic does not starve everyone else.
- **A second box per hot model** for redundancy - one node down should not take out a function.
- **Monitoring** - a `watch` agent (or a simple `healthcheck.sh` cron) that pings every `llama-server` and every gateway and alerts on failure. See `scripts/healthcheck.sh`.
- **Backups** - the vault and the Hermes state (profiles, cron, sessions) on a NAS with versioning.

## The concurrency budget

Repeat of the key number from `docs/02-hardware.md`:

| Concurrent interactive users | Nodes needed (70B) |
|---|---|
| up to 5 | 1 |
| 5-15 | 2 |
| 15-30 | 3-4 |
| 30-50 | 4-6 |

Background/batch agent work (overnight summarization, inbox triage, PR review) is far more forgiving than interactive chat and can queue. So your peak-interactive count is the number that drives node count.

## What does NOT change

- The software stack (llama.cpp + Hermes + bridge + Obsidian) is identical.
- The agent roster and per-agent model assignments are identical.
- The security posture and bridge policy are identical (and get *more* important, not less).

## One decision to make before you scale

**Cloud fallback for overflow, or hard local-only?** At 30-50 people, peak load will occasionally exceed local capacity. You either (a) let people queue (slow but pure), or (b) let LiteLLM spill *non-sensitive* traffic to a cloud model. That is a policy decision, not a technical one - write it down before you build the router. See `docs/09-security.md`.
