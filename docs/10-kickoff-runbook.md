# 10 - Kickoff Runbook

The "do this" version of the guide. Follow it top to bottom and you go from zero to a working pilot in two weeks, then make a data-backed call on the fleet.

**Outcome:** a 3-5 person pilot running on one Mac Studio, real users on the agents daily, and a go/no-go decision on the 20-30 person fleet backed by evidence - not opinion.

## Roles

| Role | Who | Owns |
|---|---|---|
| Operator | the technical owner (Andrea or a delegate) | hardware, network, the inference stack |
| Pilot lead | one technical person | runs the commands, tunes the fleet, triages |
| Pilot users | 3-5 people | use the agents daily, give feedback |
| The agents | Atlas, Scribe, Forge, Reason, Watch | the actual work |

If the operator and pilot lead are the same person (common at this size), fine - the split still clarifies what to own.

## Week 0 - Buy and unbox (2 days)

- [ ] Order the hardware (full specs in `docs/02-hardware.md`):

| Item | Spec | Purpose |
|---|---|---|
| Mac Studio | M3 Ultra, 256GB | primary inference + agent host |
| Mac mini | M4 Pro, 64GB (optional) | Watch watchdog + cold spare |
| Ethernet cable | - | wired, not Wi-Fi |
| Small UPS | - | survives power blips |

- [ ] Unbox, place in a ventilated closet/shelf, connect wired Ethernet.
- [ ] Set the two settings that let it run headless (`docs/09-security.md`):

```bash
# power-failure auto-restart
sudo pmset -a autorestart 1
# disable automatic macOS updates (a surprise reboot strands a headless box)
sudo softwareupdate --schedule off
```

- [ ] Enable **auto-login** (System Settings → Users & Groups) so agents start without a human typing a password.
- [ ] Confirm: `fdesetup status` and `pmset -g | grep autorestart`. Decide FileVault deliberately.

## Week 1 - Stand up the stack (5 days)

### Day 1 - Inference

- [ ] Install llama.cpp: `brew install llama.cpp`
- [ ] Pull the model set: `./scripts/download-models.sh`
- [ ] Serve the models (full launchd plists in `docs/04-inference-stack.md`):

```bash
llama-server --hf-repo bartowski/Qwen2.5-72B-Instruct-GGUF --hf-file '*Q4_K_M.gguf' --port 8080 --ctx-size 8192 --n-gpu-layers 99 &
llama-server --hf-repo bartowski/Qwen2.5-Coder-32B-Instruct-GGUF --hf-file '*Q4_K_M.gguf' --port 8081 --ctx-size 8192 --n-gpu-layers 99 &
llama-server --hf-repo bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF --hf-file '*Q4_K_M.gguf' --port 8082 --ctx-size 8192 --n-gpu-layers 99 &
llama-server --hf-repo gpustack/bge-m3-GGUF --embeddings --port 8083 &
```

- [ ] Verify each responds (see `docs/04-inference-stack.md` for the exact curl).
- [ ] Wrap each in a launchd plist so they survive reboot.

### Day 2 - Hermes fleet

- [ ] Install Hermes:

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
hermes doctor
```

- [ ] Point the default profile at the local 72B: `hermes config set model.base_url http://localhost:8080/v1`
- [ ] Create the five profiles: `hermes profile create atlas`, then `scribe`, `forge`, `reason`, `watch`.
- [ ] Point each at its model's port (table in `docs/05-hermes-agents.md`).
- [ ] Create one Telegram bot per agent in BotFather (`/newbot` → `atlas`, `scribe`, `forge`, `reason`, `watch`).

### Day 3 - Bridge

- [ ] For each profile, write its `.env` with its bot token + the pilot users' numeric IDs:

```bash
cat >> ~/.hermes/profiles/forge/.env <<'EOF'
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrs
TELEGRAM_ALLOWED_USERS=111111,222222,333333
EOF
```

- [ ] Install each gateway: `hermes -p forge gateway install` (repeat for all five).
- [ ] Verify in the log: `tail -20 ~/.hermes/logs/gateway.log | grep -i telegram`
- [ ] The two classic pitfalls: the bot token must include the `BOT_ID:` prefix, and the allowlist wants numeric IDs, not `@handles`.

### Day 4 - Second brain

- [ ] Create the vault at `~/Documents/ObsidianVault/` with the suggested structure (`docs/07-bridge-and-files.md`).
- [ ] Point the agents at the vault path; give them file read/write there.
- [ ] Seed it with a few real team docs so the agents have something to retrieve against.

### Day 5 - Shakeout

- [ ] Run `./scripts/healthcheck.sh` - four servers up, five gateways running.
- [ ] Message each bot from your own account and confirm a reply comes back.
- [ ] Kill one server, confirm the watchdog notices, restart it.

## Week 2 - Run, tune, decide (7 days)

### Onboard the pilot users (Day 8-9)

- [ ] Hand each pilot user the five bot handles + vault access.
- [ ] Ask them to use the agents for real daily work, not demos.
- [ ] Tell them the one rule: no source, no customer data, no credentials in chat (the bridge policy, `docs/09-security.md`).

### Tune daily (the whole week)

- [ ] Log what people ask and where the model falls short.
- [ ] Promote a task from 32B to 70B when quality disappoints (`docs/08-scaling.md`).
- [ ] Add vault docs where the agents guess instead of retrieve.
- [ ] Adjust prompts/skills per agent, not globally.

### Go / no-go (Day 14)

Check the three exit criteria honestly. All three "yes" = buy the fleet.

- [ ] Power users reach for the agents unprompted for daily work.
- [ ] No one is quietly going back to the cloud assistant for routine tasks.
- [ ] The vault is being read and written by both humans and agents.

If any is "no", the pilot did its job: you found the problem for ~$7k instead of ~$22k. Fix it (usually model quality or a missing workflow), run another week.

## Fleet decision (if "go")

- [ ] Read `docs/02-hardware.md` - tiered (3 Studios, ~$22k) vs. all-70B (5 Studios, ~$36k).
- [ ] Decide **tiered** unless the pilot showed routine tasks genuinely need flagship quality.
- [ ] Order: +2 Mac Studios, a switch, and pick a NAS or Syncthing for the vault.
- [ ] Onboard in cohorts of ~5, one week each (`docs/08-scaling.md`).
- [ ] Write the cloud-fallback policy before you build the router (`docs/09-security.md`).

## Quick gotchas (the ones that bite)

| Gotcha | Fix |
|---|---|
| Bot ignores everyone | `TELEGRAM_ALLOWED_USERS` wants numeric IDs, not handles |
| `InvalidToken` | token missing the `BOT_ID:` prefix - get the full one from BotFather |
| Profile can't find the model | profile `.env` does not inherit the parent `.env` - set keys per profile |
| Gateway dies on reboot | auto-login is off; enable it |
| Model OOM at startup | lower `--n-gpu-layers` |
| Port already in use | one model per port; keep the 8080-8083 map |

## Where everything lives (reference)

| Need | Doc |
|---|---|
| Hardware specs + cost | `docs/02-hardware.md` |
| Model + quant choices | `docs/03-models.md` |
| Full inference commands | `docs/04-inference-stack.md` |
| Hermes fleet + bridge | `docs/05-hermes-agents.md` |
| DeepSeek reasoning tier | `docs/06-deepseek-harness.md` |
| Bridge + vault | `docs/07-bridge-and-files.md` |
| Scaling + cohorts | `docs/08-scaling.md` |
| Security + hardening | `docs/09-security.md` |
