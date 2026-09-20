# 08 - Deployment Plan and Scaling

The target is **20-30 people at steady load**. The deployment is two phases: a de-risk pilot, then the fleet. Beyond 30, scaling stays additive.

## Phase 1 - Pilot (3-5 people, 2-3 weeks)

One Mac Studio, 3-5 power users. This is **not** the goal state - it is the de-risking run before committing ~$22k.

What the pilot must prove:

1. **Model quality is acceptable.** People coming off Claude will have opinions. Find out now, not after buying the fleet.
2. **The bridge + vault workflow sticks.** Real users, real daily use.
3. **The agents do useful work** for their actual functions, not demo tasks.

Exit criteria (answer all three "yes", then buy the fleet):

- Power users reach for the agents unprompted for daily work.
- No one is quietly going back to the cloud assistant for routine tasks.
- The vault is being read and written by both humans and agents.

## Phase 2 - Fleet (20-30 people, steady)

Add two Studios and a LiteLLM router. This is the deployment described in `docs/02-hardware.md` (tiered, 3 Studios + 1 Mini).

What changes from the pilot:

- **Router required.** Agents point `model.base_url` at LiteLLM, not at a box directly. Routing, queueing, and (optionally) cloud spillover happen in one place.
- **File sync moves to Syncthing/NAS.** iCloud does not survive 20-30 people.
- **Bridge policy becomes written and enforced**, not social. See `docs/09-security.md`.
- **Watch + backups become real ops.** Nightly backup of the vault and Hermes state; the watchdog pings every server and gateway.

### Onboard in cohorts

Do not flip 25 people on in one day. Onboard ~5 at a time, one week per cohort:

1. Give them the bridge bots and vault access.
2. Watch what they ask the agents and where the model falls short.
3. Fix routing (promote a task from 32B to 70B, add a model, adjust a prompt) before the next cohort.

This turns the rollout into a tuning loop instead of a support fire.

## The tiered → all-70B escape hatch

Start tiered. If the cohort loop surfaces quality complaints on *routine* tasks, the fix is additive: buy a fourth Studio and repoint the affected profiles at a 70B. That promotion path - 32B up to 70B, one profile at a time - is exactly why tiering is the safe default. There is no cheap path the other direction once you have bought 5 boxes.

## Beyond 30

If the operator grows past 30, the unit of scale is still the Mac Studio:

| Headcount | Hardware | Notes |
|---|---|---|
| 20-30 (target) | 3x Studio + router | tiered, steady |
| 30-50 | 4-6x Studio + router | add boxes, specialize per function |
| 50+ | Nx Studio + router + monitoring | a small on-prem inference service |

Same software, same models, same bridge. Adding capacity is "buy a box, point profiles at it."

## The one policy decision to make before the fleet

**Cloud fallback for overflow, or hard local-only?** At 20-30 people, peak load will occasionally test local capacity. You either (a) let people queue (slow but pure), or (b) let LiteLLM spill *non-sensitive* traffic to a cloud model. That is a policy decision, not a technical one - write it down before you build the router. See `docs/09-security.md`.
