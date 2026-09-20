# 05 - Hermes Agents

[Hermes Agent](https://github.com/NousResearch/hermes-agent) is the framework that turns a local model into a working agent: tool calling, persistent memory, skills, cron, and a messaging bridge. The fleet is a roster of Hermes **profiles** - one per function, each pointed at a local model and exposed as its own bot.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

Verify the install and check dependencies:

```bash
hermes doctor
```

## Point Hermes at a local model

First make the default profile talk to the local `llama-server` instead of any cloud provider:

```bash
hermes config set model.default "qwen2.5-72b"
hermes config set model.base_url "http://localhost:8080/v1"
hermes config set model.api_key "local"   # llama-server has no auth; any placeholder works
```

Confirm with a one-shot query:

```bash
hermes chat -q "Reply with the single word: ready" -Q
```

> **Verify the exact key names** against your installed version: `hermes config check` and the [configuration docs](https://hermes-agent.nousresearch.com/docs/user-guide/configuration). The local-endpoint pattern is `model.base_url` + `model.api_key`; the provider key for a custom OpenAI-compatible endpoint may differ by version.

## Build the fleet

Create a profile per function. Each profile is independent - its own model, memory, skills, and bot.

```bash
hermes profile create atlas     # general ops / strategy
hermes profile create scribe    # drafting / analysis
hermes profile create forge     # code / engineering
hermes profile create reason    # deep reasoning (DeepSeek harness)
hermes profile create watch     # fleet watchdog / cron
```

Point each at its model's port (this is what makes the fleet a *fleet*):

| Profile | Model | `model.base_url` |
|---|---|---|
| atlas | Qwen2.5-72B | `http://localhost:8080/v1` |
| scribe | Qwen2.5-72B | `http://localhost:8080/v1` |
| forge | Qwen2.5-Coder-32B | `http://localhost:8081/v1` |
| reason | DeepSeek-R1-Distill-32B | `http://localhost:8082/v1` |
| watch | small fast model | `http://localhost:8083/v1` |

Set each with the profile flag:

```bash
hermes -p forge config set model.default "qwen2.5-coder-32b"
hermes -p forge config set model.base_url "http://localhost:8081/v1"
hermes -p forge config set model.api_key "local"
```

## The `.env` inheritance pitfall (will bite you)

**A profile's `.env` does NOT inherit from the parent `~/.hermes/.env`.** When you `hermes profile create <name>`, the profile gets its own `~/.hermes/profiles/<name>/.env`. Anything you set only in the parent (API keys, Telegram tokens) is invisible to the profile.

So for each profile, put its Telegram bot token in *that profile's* `.env`, not the parent's:

```bash
# each profile gets its own bot token (create one per bot in BotFather)
grep -q TELEGRAM_BOT_TOKEN ~/.hermes/profiles/forge/.env \
  || echo 'TELEGRAM_BOT_TOKEN=...' >> ~/.hermes/profiles/forge/.env
```

## Connect each agent to the bridge (Telegram)

One bot per agent. Repeat this per profile.

1. **Create a bot** in [@BotFather](https://t.me/BotFather): `/newbot`, name it (`atlas`, `scribe`, `forge`, ...). BotFather returns a token like `1234567890:ABCdefGHIjklMNOpqrs`.
   - **Pitfall:** the token MUST include the numeric prefix and colon. Copying only the part after the colon yields `InvalidToken`.
2. **Get each teammate's numeric Telegram ID** from [@userinfobot](https://t.me/userinfobot). These go in the allowlist.
   - **Pitfall:** `TELEGRAM_ALLOWED_USERS` takes **numeric** IDs, not `@handles`. A username here makes the bot silently ignore everyone.
3. **Write the profile's `.env`:**

   ```bash
   cat >> ~/.hermes/profiles/forge/.env <<'EOF'
   TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrs
   TELEGRAM_ALLOWED_USERS=123456789,987654321,555111222
   EOF
   ```

   For a 5-person team, the same 5 numeric IDs go in every profile's allowlist.
4. **Install the gateway** so the bot runs as a background service:

   ```bash
   hermes -p forge gateway install
   hermes -p forge gateway status
   ```

   The gateway runs as a `launchd` service, so it survives reboots.
5. **Verify** by messaging the bot and checking the log:

   ```bash
   tail -20 ~/.hermes/logs/gateway.log | grep -i telegram
   ```

   Look for `connected` / `Connected to Telegram (polling mode)`.

Repeat for `atlas`, `scribe`, `reason`, `watch`.

## Gatekeeper pitfalls (from a live multi-agent deployment)

- **The gateway service does not see shell env vars.** Keys set in `~/.zshrc` or `~/.bash_profile` are invisible to the `launchd` gateway. Put provider keys in the profile's `.env`, then restart the gateway.
- **`hermes gateway restart` may be blocked** by command-approval rules. On macOS, use `launchctl stop ai.hermes.gateway && launchctl start ai.hermes.gateway` as the workaround.
- **Each profile is its own bot.** Do not reuse one bot token across profiles - they will fight over the same webhook/polling session.
- **Verify with logs, not just `status`.** `gateway status` reports the `launchd` state, not whether Telegram auth succeeded. Check the log for the connection line.

## Keep sensitive agents offline

Agents that touch source or customer data should have the network toolsets disabled so they cannot exfiltrate anything:

```bash
hermes -p forge tools disable web
hermes -p forge tools disable browser
```

The agent can still read/write local files and call the local model; it just cannot reach the internet. See `docs/09-security.md`.

## Shared second brain (RAG)

Give the agents a shared memory by pointing them at the Obsidian vault. Two parts:

1. **Embeddings server** - serve `bge-m3` for retrieval:
   ```bash
   llama-server --hf-repo gpustack/bge-m3-GGUF --embeddings --port 8083
   ```
2. **Vault access** - agents read and write `~/Documents/ObsidianVault/`. Drop team knowledge there; the agents retrieve against it instead of guessing.

See `docs/07-bridge-and-files.md` for the vault sync strategy.

## The roster, at a glance

| Agent | Function | Model (port) | Bridge bot |
|---|---|---|---|
| Atlas | strategy, ops, decisions | Qwen2.5-72B (:8080) | `@atlas_bot` |
| Scribe | drafting, analysis, writing | Qwen2.5-72B (:8080) | `@scribe_bot` |
| Forge | code, engineering | Coder-32B (:8081) | `@forge_bot` |
| Reason | hard reasoning | R1-Distill-32B (:8082) | `@reason_bot` |
| Watch | cron, fleet health | small (:8083) | `@watch_bot` |
