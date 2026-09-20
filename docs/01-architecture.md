# 01 - Architecture

## Design goals, in priority order

1. **IP never leaves the building.** The model, the conversation, the documents - all local by default.
2. **A team already knows how to use it.** No new app to learn. The bridge is a chat they already have.
3. **One person can run it.** No dedicated infra team. Reboot-and-walk-away reliability.
4. **Scales by adding boxes, not rewriting.** The pilot box is a unit; the full deployment is N units.

## The threat model

Where does data leak, and what closes each hole?

| Leak | Vector | Fix |
|---|---|---|
| Prompts + documents to a cloud model | `chat.completions` to Anthropic/OpenAI/etc. | Run models locally (`llama-server`) |
| Conversation to a cloud messenger | Bridge traffic to Telegram/Slack servers | Policy, or self-host Matrix |
| Files to a consumer cloud | iCloud/Drive/GDrive sync of the vault | Syncthing/NAS at scale |
| Agent tool calls to the internet | An agent with `web`/`browser` toolsets | Disable network toolsets on sensitive agents |

## The bridge paradox

The non-obvious one. You move the model local, but if the *bridge* is Telegram or Slack, every prompt and reply still transits a third party's servers:

- **Telegram** is not end-to-end encrypted by default. Only "secret chats" are. Regular DMs and groups are readable server-side.
- **Slack** is fully cloud, plaintext at rest, indexed.

So a local model behind a cloud bridge has moved the leak from the model vendor to the messenger vendor. The model is local; the *conversation* is not.

Three ways to resolve it:

1. **Accept residual risk (pilot).** Keep Telegram/Slack, but enforce a hard policy: no source, no customer data, no credentials in bridge messages. The bridge carries thin references; sensitive material stays in the local model and the local vault.
2. **Self-host Matrix (strict).** Run a Matrix homeserver on the same Mac Studio. Everything is end-to-end encrypted and in-house. More setup, slightly clunkier UX.
3. **Split.** Bridge for coordination (non-sensitive), a self-hosted web chat for anything sensitive.

**Recommendation:** start with (1) at 3-5 people - the policy is easy to enforce and the model is already local. Revisit Matrix when headcount passes ~15 or the work becomes more sensitive. See `docs/07-bridge-and-files.md`.

## Layer walkthrough

### 1. Hardware
A Mac Studio with Apple Silicon. Unified memory is the point: the GPU and CPU share one pool, so a 192GB machine can hold a 70B model fully in memory with no PCIe bottleneck. See `docs/02-hardware.md`.

### 2. Inference
`llama.cpp` `llama-server` loads GGUF model files and exposes an OpenAI-compatible API on `localhost:8080`. Multiple models run as multiple `llama-server` processes on different ports. MLX-LM is the Apple-native alternative; the guide uses llama.cpp because its GGUF ecosystem is the broadest.

### 3. Agent framework
[Hermes Agent](https://github.com/NousResearch/hermes-agent) profiles, one per function. Each profile is a fully independent agent - its own model, memory, skills, and messaging bot. The fleet is just a roster of profiles:

| Agent | Function | Model |
|---|---|---|
| Atlas | general ops / strategy | Qwen2.5-72B |
| Scribe | drafting / analysis / writing | Qwen2.5-72B |
| Forge | code / engineering | Qwen2.5-Coder-32B |
| Reason | deep reasoning / hard problems | DeepSeek-R1-Distill |
| Watch | fleet watchdog / cron | small fast model |

Each profile's `model.base_url` points at the local `llama-server` port for its model, so no traffic leaves the box. See `docs/05-hermes-agents.md`.

### 4. Bridge
The team's chat app. Each Hermes profile is its own bot on the bridge, so "talking to Atlas" is just messaging `@atlas_bot`. See `docs/07-bridge-and-files.md`.

### 5. Files / second brain
An Obsidian vault is the shared knowledge base. Each agent reads and writes it, and the team browses it. Synced via iCloud (pilot) or Syncthing/NAS (strict). See `docs/07-bridge-and-files.md`.

## Data flow (happy path)

```
employee ──Telegram──> Atlas bot (Hermes profile)
                            │  prompt + tool calls
                            ▼
                     llama-server :8080 (Qwen2.5-72B, local)
                            │  generated text
                            ▼
                     Atlas bot ──Telegram──> employee
                            │
                     reads/writes Obsidian vault (local + synced)
```

No hop in that path touches a third-party model. The only third party is the bridge, and that is the residual risk you consciously accept (or eliminate with Matrix).

## Diagram

`assets/architecture.svg` shows the full topology, and is embedded in the README.
