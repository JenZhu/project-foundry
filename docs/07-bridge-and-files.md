# 07 - Bridge and Files

Two things every teammate touches: the **bridge** (how they talk to agents) and the **files** (the shared second brain). Both have a privacy dimension.

## The bridge

| Option | Privacy | Setup effort | UX | Verdict |
|---|---|---|---|---|
| **Telegram** | cloud, not E2E by default | trivial | excellent | pilot default |
| **Slack** | cloud, plaintext at rest | trivial | excellent | if the team already lives in Slack |
| **Matrix (Element)** | self-hosted, E2E | moderate | decent | strict mode |

### Pilot: Telegram (or Slack)

Already documented end-to-end in `docs/05-hermes-agents.md`: one bot per agent, numeric-ID allowlist, gateway as a `launchd` service. The team adds the bots and starts messaging.

### Strict mode: self-hosted Matrix

When even message *metadata* matters, run a [Matrix](https://matrix.org/) homeserver (e.g. Conduit or Dendrite) on the same Mac Studio. Hermes supports Matrix as a gateway platform natively. All traffic is end-to-end encrypted and never leaves the building.

Tradeoff: you now administer a homeserver, and Element is slightly less polished than Telegram. Worth it once the work is sensitive enough.

### The bridge data policy (write this down)

Whichever bridge you use, the residual-risk rule from `docs/01-architecture.md` applies. Post it and enforce it:

> The bridge carries thin references only. No source code, no customer data, no credentials, no full documents in bridge messages. Sensitive material lives in the local model and the local vault; link to it, don't paste it.

At 20-30 people this needs to be a written policy with periodic reminders.

## Files and the second brain

The **Obsidian vault** is the shared brain: team notes, project docs, meeting records, and the agents' own written output. Agents read and write it; the team browses it.

### Sync options

| Option | Privacy | Fit |
|---|---|---|
| **iCloud Drive** | Apple's cloud, consumer-grade | pilot only - zero setup |
| **Obsidian Sync** | E2E encrypted, paid | 3-20 people, simplest private option |
| **Syncthing** | self-hosted, peer-to-peer, E2E | strict mode, no third party at all |
| **NAS (Synology etc.)** | self-hosted, LAN | 15+ people, adds backup target |

### Recommendation by phase

- **Pilot:** iCloud shared folder. It is fine at this scale and needs no administration.
- **Growing (5-20):** switch to Obsidian Sync or Syncthing. iCloud gets awkward once personal Apple IDs and offboarding matter.
- **Fleet (20-30):** Syncthing or a NAS, because you now want granular access control and a backup target.

### The offboarding gotcha

Who owns the vault when someone leaves? With iCloud tied to personal Apple IDs, that answer is messy. With Syncthing or a NAS on company hardware, it is clean: the vault is a company asset, access is revoked in one place. Plan for this *before* the first person leaves, not after.

## Vault structure (suggested)

```
ObsidianVault/
  inbox/          # unfiled, agents triage here
  projects/       # one folder per project
  people/         # notes on contacts, clients (sensitive - keep out of the bridge)
  decisions/      # decision log, ADRs
  agents/         # agent outputs and runbooks
```

Keep `people/` and anything customer-specific out of the bridge entirely, and consider whether those folders should be excluded from any cloud sync at all.

## Wiring agents to the vault

From `docs/05-hermes-agents.md`: give each agent read/write access to the vault path, and serve `bge-m3` embeddings for retrieval. The vault is what turns five separate chatbots into one shared brain.
