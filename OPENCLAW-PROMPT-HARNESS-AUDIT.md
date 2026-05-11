# OpenClaw Prompt/Harness Audit

## Goal

Map the current OpenClaw prompt system to a cleaner `main / lab / worker` design aligned with the Codex/OpenAI GPT-5 agent prompting guide, while minimizing duplication.

---

## Current OpenClaw Capability Reality

The current config/runtime supports these knobs that matter here:

- `agents.defaults.promptOverlays.gpt5.personality`
  - global GPT-5 overlay only
  - affects all GPT-5-family embedded agents
- `agents.list[].systemPromptOverride`
  - full per-agent prompt replacement
  - powerful, but duplicates prompt content if overused
- `agents.list[].model`
- `agents.list[].thinkingDefault`
- `agents.list[].reasoningDefault`
- `agents.list[].tools.profile`
- `agents.list[].heartbeat`
- `agents.list[].runtime`
- `agents.list[].sandbox`

### Important limitation

There is **no clean per-agent `promptMode` config field** exposed today.
There is also **no per-agent GPT-5 overlay personality override** exposed in config.

So the least confusing design is:

1. keep **global defaults** as the shared base
2. keep `main` close to global default behavior
3. only use `systemPromptOverride` for `lab` and `worker`, where divergence is worth it

This avoids duplicating the full prompt three times.

---

## What to Keep Globally

Keep these concepts in the shared/global baseline:

- tool discipline
- execution bias
- safety policy
- runtime/workspace grounding
- approval discipline
- concise tool narration
- completion contract

These are the strongest parts of the current harness.

---

## What to Scope Only to `main`

These are useful for the conversational main agent, but too heavy for technical/background agents:

- friendly GPT-5 personality overlay
- rich messaging/output directives emphasis
- social/warmth framing
- heartbeat magic/proactive prose
- reaction/voice/group-chat style guidance
- heavier project-context personality files (`SOUL.md`, `USER.md`, etc.)

---

## What to Change Per Agent

### `main`

Use shared global defaults.
Do **not** use `systemPromptOverride` unless absolutely needed.

Recommended:
- keep GPT-5 friendly overlay on
- keep chat/messaging-oriented sections
- keep default heartbeat model/behavior
- keep `tools.profile = coding` unless you later intentionally narrow it

### `lab`

Use a short `systemPromptOverride` because this agent should be much drier and more tool-first than `main`.

Recommended:
- `thinkingDefault = medium`
- `reasoningDefault = off`
- `tools.profile = coding`
- heartbeat disabled unless you have a real reason
- model can stay GPT-5 or use a coding-specialized model later

### `worker`

Use a short `systemPromptOverride` because this agent should be non-interactive and low-chatter.

Recommended:
- `thinkingDefault = low`
- `reasoningDefault = off`
- `tools.profile = coding`
- heartbeat disabled in the agent itself unless worker is the heartbeat target
- use isolated cron/session flows for scheduled work

---

## Why this design minimizes confusion

This design avoids these bad outcomes:

- 3 full prompt trees that drift apart
- duplicate safety/tooling rules repeated everywhere
- global prompt changed just to satisfy worker behavior
- `main` becoming too robotic because `worker` needs low chatter

Instead:

- **global defaults** = shared core behavior
- **main** = inherits shared core + friendly overlay
- **lab/worker** = only override where behavior truly must diverge

---

## Practical Recommendation

If you want the cleanest next step without code changes upstream:

- leave `agents.defaults` as the shared foundation
- add explicit agents:
  - `main`
  - `lab`
  - `worker`
- give `lab` and `worker` targeted `systemPromptOverride`
- keep the overrides short and role-specific

If later you want the *cleanest* architecture, upstream OpenClaw should eventually add:

- `agents.list[].promptMode`
- `agents.list[].promptOverlays`

That would remove the need for full per-agent prompt replacement.

---

## Notes on Remaining Warning

The worker concurrency warning (`< 5`) is intentionally not optimized away here.

Reason:
- host has only 2 vCPU
- worker now carries media tooling (`ffmpeg`, `yt-dlp`)
- forcing concurrency 5 just to remove the warning would be operationally worse

So that warning is acceptable by design.
