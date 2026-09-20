# 09 - Security

The entire project exists to protect intellectual property. Security is not a section - it is the point. Everything here assumes the threat model from `docs/01-architecture.md`: the adversary is the model vendor, the messenger vendor, and the consumer cloud, all of whom would happily train on your data.

## The one rule

**Local by default. Anything that leaves the building leaves on purpose, and someone wrote down why.**

## Hardening checklist

### 1. Inference is local-only

- `llama-server` binds to `127.0.0.1` (localhost). No port is exposed to the LAN or the internet.
- When you scale to multiple boxes (`docs/08-scaling.md`), move inference to a **private LAN** - never public IPs, never port-forwarded.
- No outbound calls from the inference layer. The models do not phone home.

### 2. Agents have least privilege

- Disable network toolsets on agents that touch source or customer data:
  ```bash
  hermes -p forge tools disable web
  hermes -p forge tools disable browser
  ```
- Keep `terminal` and `file` toolsets only on agents that need them, and scope their working directory to the vault and project paths.
- Command approvals on: `hermes config set approvals.mode smart` (auto-approve low-risk, prompt on high-risk).

### 3. The bridge is a policy surface

- Post and enforce the bridge data policy from `docs/07-bridge-and-files.md` (no source, no customer data, no credentials in chat).
- Prefer self-hosted Matrix when the material is hot.
- Rotate bot tokens if anyone leaks one.

### 4. Secrets stay in `.env`, never in git or chat

- All API keys, bot tokens, and credentials live in `~/.hermes/.env` and each profile's `.env`.
- Never commit `.env` files, and never paste tokens into bridge messages.
- The gateway (`launchd`) cannot see shell env vars - put keys in `.env`, not `~/.zshrc`.

### 5. Headless box hygiene (the "walk away" test)

A headless Mac Studio has three interacting settings that decide whether it survives your absence. Get all three right:

1. **Power-failure auto-restart** - so the box boots after a power cut:
   ```bash
   sudo pmset -a autorestart 1
   ```
2. **Auto-login** - so the user session (and the `launchd` agents) start without a human typing a password. Without this, a reboot strands every gateway at the login screen.
3. **FileVault** - the tradeoff. FileVault protects data at rest (important for an IP-vault), but FileVault **plus** no auto-login means a power cut leaves the box at the unlock screen until someone physically types a password.

**Recommended:** enable auto-restart + auto-login, and accept FileVault only if you have a documented physical-access procedure. The three interact - verify with:

```bash
fdesetup status
pmset -g | grep autorestart
```

### 6. Disable automatic updates

A surprise macOS update that reboots the box can strand it (see above). On a machine running production agents:

```bash
sudo softwareupdate --schedule off
```

Apply updates deliberately, during a maintenance window, with someone on hand.

### 7. Backups

- The Obsidian vault is the crown jewel - back it up to a NAS or encrypted volume nightly.
- Back up Hermes state (`~/.hermes/profiles/`) so the fleet's memory and cron survive a disk failure.

### 8. Offboarding

When someone leaves (see `docs/07-bridge-and-files.md`):

- Remove their numeric ID from every profile's `TELEGRAM_ALLOWED_USERS`.
- Revoke their vault access in one place (Syncthing/NAS, not iCloud).
- Rotate any tokens they might have seen.

## The explicit cloud-fallback decision

If you adopt a cloud fallback for overflow or frontier-grade tasks (`docs/08-scaling.md`), write down:

- **Which** cloud provider (e.g. DeepSeek, DashScope).
- **What** traffic may go there (categories, not "anything").
- **What** never goes there (source, customer data, credentials, `people/` notes).
- **How** it is enforced (routing rule + the bridge policy).

A hybrid is defensible. An *accidental* hybrid is how IP leaks. Make it a written, enforced boundary.

## Quick reference

| Concern | Action |
|---|---|
| Model sees my data | local `llama-server`, `127.0.0.1` only |
| Messenger sees my data | bridge policy, or Matrix |
| Cloud sync sees my files | Syncthing/NAS instead of iCloud at scale |
| Agent exfiltrates | network toolsets disabled |
| Reboot strands the fleet | auto-restart + auto-login, deliberate updates |
| Disk failure | nightly backup of vault + Hermes state |
| Employee leaves | revoke IDs + vault access + rotate tokens |
