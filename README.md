# Project Foundry

A private, local-first AI agent fleet for a small company. No cloud models, no IP leakage. One Mac Studio, a handful of Hermes agents, and a chat bridge your team already uses.

> **On naming.** "Project Foundry" and "the operator" are code names. This guide is published with the real company, people, and any identifying details removed. The architecture, commands, and sizing are real and field-tested.

---

## The problem

A 30-50 person company runs on laptops, and everyone reaches for a cloud AI assistant for writing, code, and analysis. Every prompt - source snippets, customer notes, internal strategy - is shipped to a third party and used to train their models. For a company whose product *is* its intellectual property, that is an open tap.

## The answer

Run the models on your own hardware, in your own building, and give the team agents through a chat bridge they already know. For a pilot of **3-5 people** this is a single Mac Studio. It scales to 30-50 by adding boxes - same software, more metal.

## Architecture at a glance

![architecture](assets/architecture.svg)

Five layers, bottom to top:

1. **Hardware** - one Mac Studio (Apple Silicon, unified memory) runs everything. A cheap Mini is the cold spare.
2. **Inference** - `llama.cpp` `llama-server` exposes local models as an OpenAI-compatible API. Two or three models co-resident in unified memory.
3. **Agent framework** - [Hermes Agent](https://github.com/NousResearch/hermes-agent) profiles, one per function. Each is an independent agent with its own model, memory, skills, and bot.
4. **Bridge** - the team talks to agents over Telegram (pilot) or self-hosted Matrix (strict mode).
5. **Files / second brain** - an Obsidian vault synced via iCloud (pilot) or Syncthing/NAS (strict mode) is the shared knowledge base.

## The three decisions that matter

Every other choice is execution detail. These three shape the whole system:

| Decision | Pilot (3-5 people) | Why |
|---|---|---|
| **Bridge** | Telegram | Fastest to stand up; acceptable residual risk at this scale. Matrix if the team's IP is so hot that even message metadata matters. |
| **Model tier** | One 70B + one 32B coder + a reasoning model | Co-resident on one 192GB+ box. No cloud fallback needed for routine work. |
| **File sync** | iCloud shared folder | Fine at 3-5 people. Move to Syncthing/NAS before scaling past ~10. |

Read `docs/01-architecture.md` for the full reasoning, including the **bridge paradox** (the one non-obvious leak most people miss).

## Repo layout

```
docs/
  01-architecture.md      System design + the bridge paradox
  02-hardware.md          Sizing: pilot vs. scale
  03-models.md            Model selection + quantization
  04-inference-stack.md   llama.cpp / MLX, OpenAI-compatible server
  05-hermes-agents.md     Hermes fleet: profiles, gateways, bridge
  06-deepseek-harness.md  Parallel DeepSeek reasoning tier
  07-bridge-and-files.md  Telegram/Slack/Matrix + Obsidian sync
  08-scaling.md           Pilot (3-5) to full team (30-50)
  09-security.md          Threat model + hardening + data policy
assets/
  architecture.svg        System diagram
scripts/
  download-models.sh      Pull the pilot model set
  healthcheck.sh          Verify the stack is up
```

## Quick start (pilot, ~a weekend)

1. Buy and unbox a Mac Studio - `docs/02-hardware.md`.
2. Install the inference stack and pull the models - `docs/04-inference-stack.md`, `scripts/download-models.sh`.
3. Install Hermes and create the agent fleet - `docs/05-hermes-agents.md`.
4. Wire the DeepSeek reasoning tier - `docs/06-deepseek-harness.md`.
5. Connect the team's bridge and the shared vault - `docs/07-bridge-and-files.md`.
6. Run `scripts/healthcheck.sh`, then grow - `docs/08-scaling.md`.

## Scaling is additive, not a rewrite

The pilot is a single box. To go from 5 to 50 people you add boxes, point new agent profiles at them, and (optionally) put a small router in front. Nothing in the software stack changes. See `docs/08-scaling.md`.

## License

MIT. Use it, fork it, build your own fleet. Attribution appreciated.
