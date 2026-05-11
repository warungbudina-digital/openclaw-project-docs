# OpenClaw Work Packages

## Purpose

Break the master architecture into concrete work packages so Ayang can build the platform one component at a time without losing the overall direction.

Each package includes:
- objective
- scope
- outputs
- dependencies
- success criteria
- build order notes

---

## WP-01 — OpenClaw Base Foundation

## Objective
Stabilize the OpenClaw runtime as the control plane.

## Scope
- main / lab / worker role structure
- secrets/env correctness
- runtime health
- browser stability baseline
- container/service sanity

## Outputs
- stable OpenClaw runtime
- stable browser containers
- clean role separation
- baseline health check routine
- documented env/secret mapping

## Dependencies
- none; this is the starting point

## Success criteria
- OpenClaw can respond reliably
- browser containers stay healthy
- secrets survive restart/recreate
- role split is documented and coherent

## Notes
Do this first. Everything else depends on it.

---

## WP-02 — OpenClaw Prompt & Role Architecture

## Objective
Define how `main`, `lab`, and `worker` behave differently.

## Scope
- global prompt baseline
- `lab` systemPromptOverride
- `worker` systemPromptOverride
- heartbeat policy
- execution bias alignment

## Outputs
- prompt audit
- prompt mapping
- final per-role config design
- clean separation of conversational vs technical vs worker behavior

## Dependencies
- WP-01

## Success criteria
- `main` is human-facing and concise
- `lab` is technical and low-chatter
- `worker` is silent and deterministic

## Notes
This prevents prompt chaos later.

---

## WP-03 — Secrets, Config, and Environment Discipline

## Objective
Make config and secrets predictable and restart-safe.

## Scope
- env naming consistency
- docker-compose env propagation
- SecretRef mapping discipline
- `.env` strategy
- validation workflow before restart/reboot

## Outputs
- final env naming policy
- secrets setup guide
- known-good config validation routine

## Dependencies
- WP-01

## Success criteria
- no more missing key surprises after restart
- no hardcoded secrets needed for normal operation
- config validation becomes routine

---

## WP-04 — Browser Automation Surface

## Objective
Turn browser containers into a stable automation layer.

## Scope
- extension-enabled browser policy
- CDP/browser usage pattern
- downloads/profile persistence
- browser container recovery pattern
- clear browser ownership per use case

## Outputs
- stable browser-1/2/3 usage rules
- browser recovery/runbook
- extension policy
- guidance for manual-login-backed sessions

## Dependencies
- WP-01
- WP-03

## Success criteria
- browser sessions are usable and recoverable
- extensions and profiles survive expected restarts
- browser automation has a known operating model

---

## WP-05 — n8n Runtime Platform

## Objective
Stabilize n8n as the automation plane.

## Scope
- n8n main/worker layout
- Postgres/Redis runtime health
- image strategy
- update-notification policy
- ffmpeg/yt-dlp/custom image strategy
- domain/proxy correctness

## Outputs
- stable n8n stack
- runtime runbook
- version/update stance
- documented image strategy

## Dependencies
- WP-01
- WP-03

## Success criteria
- main and worker are healthy
- runtime survives restart cleanly
- config conflicts are removed

---

## WP-06 — n8n Operating Model

## Objective
Define how n8n will be used, not just how it runs.

## Scope
- analysis-only workflows
- paper mode
- live mode boundaries
- workflow categories
- webhook vs cron vs manual execution patterns

## Outputs
- operating model document
- workflow classification rules
- execution mode policy

## Dependencies
- WP-05

## Success criteria
- every workflow has a clear operating mode
- n8n is not misused as the “brain”
- execution boundaries are explicit

---

## WP-07 — Data Persistence & Observability

## Objective
Make the whole platform inspectable and stateful.

## Scope
- Postgres/data schema
- decision logs
- execution logs
- content archive
- workflow run logs
- prompt/version registry

## Outputs
- schema blueprint
- storage policy
- observability checklist
- replay/debugging capability design

## Dependencies
- WP-05
- WP-06

## Success criteria
- important decisions and executions are explainable
- no critical workflow depends on memory-only state
- logs are structured enough for debugging

---

## WP-08 — AskNews Integration Layer

## Objective
Build AskNews as a controlled intelligence source.

## Scope
- `/news` baseline use
- optional `/websearch` escalation
- token/request cost policy
- checkpointing
- coverage/language guardrails
- prompt optimization

## Outputs
- AskNews optimization runbook
- AskNews guardrails checklist
- endpoint mapping into workflows

## Dependencies
- WP-05
- WP-06
- WP-07

## Success criteria
- AskNews retrieval is cost-aware
- baseline `/news` path works cleanly
- escalation rules are explicit
- quality is validated by topic/language

---

## WP-09 — GPTTraderV4 / Event Intelligence Pipeline

## Objective
Port the GPTTraderV4-style idea into a maintainable n8n architecture.

## Scope
- workflow design per node
- data blueprint
- decision schema
- analysis-only mode
- paper mode
- later execution mode

## Outputs
- GPTTraderV4 implementation analysis
- workflow design
- data blueprint
- AskNews mapping

## Dependencies
- WP-06
- WP-07
- WP-08

## Success criteria
- analysis-only pipeline runs cleanly
- structured decisions are logged
- no live execution before paper validation

---

## WP-10 — Model Routing Layer

## Objective
Use different models intentionally by task.

## Scope
- task classes
- local Ollama usage
- remote fallback usage
- cheap/medium/strong model policy
- failure fallback policy

## Outputs
- routing matrix
- model inventory
- fallback policy
- cost-control policy

## Dependencies
- WP-01
- WP-05
- WP-07

## Success criteria
- not all tasks use the same model
- fallback behavior is defined
- cost control becomes measurable

---

## WP-11 — Local Inference Operations (Ollama)

## Objective
Make Ollama operationally usable as a service layer.

## Scope
- model inventory
- health check flow
- embedding usage
- remote/local connectivity
- tool/CLI management strategy

## Outputs
- local inference runbook
- model inventory policy
- operational checks

## Dependencies
- WP-10

## Success criteria
- Ollama is not just installed; it is governable
- models can be inspected, pulled, tested, and rotated intentionally

---

## WP-12 — Agent Orchestration Layer

## Objective
Prevent multi-agent chaos.

## Scope
- task ownership
- escalation rules
- fallback rules
- retry/stop rules
- worker vs specialist boundaries
- optional `paper@clip`-style manager evolution

## Outputs
- agent orchestration policy
- task-routing matrix
- failure/escalation matrix

## Dependencies
- WP-02
- WP-06
- WP-07
- WP-10

## Success criteria
- every task type has a clear owner
- agents do not overlap blindly
- stop/fallback behavior is explicit

---

## WP-13 — Cloud Shell Helper Layer

## Objective
Use Google Cloud Shell as helper compute, not as fragile core infrastructure.

## Scope
- what runs in Cloud Shell
- what never runs there
- bootstrap conventions
- temporary tool deployment
- cleanup and state expectations

## Outputs
- Cloud Shell usage policy
- helper task types
- bootstrap/run conventions

## Dependencies
- WP-12
- WP-10

## Success criteria
- Cloud Shell is used intentionally
- no critical state depends on it
- helper workflows are reproducible

---

## WP-14 — Specialist Agents

## Objective
Add narrow intelligence modules after the platform base is ready.

## Scope
- forecasting/prediction agents
- market/news agents
- specialist research agents
- output schema and escalation rules

## Outputs
- specialist-agent registry
- per-agent contract
- scope boundaries

## Dependencies
- WP-12
- WP-10
- WP-07

## Success criteria
- specialists have narrow, useful scope
- outputs are structured and auditable
- they feed the system without destabilizing it

---

## WP-15 — CLI Harness / Tool Expansion Layer

## Objective
Expand OpenClaw capabilities via stable CLI surfaces.

## Scope
- evaluate `cli-anything-n8n`
- evaluate `cli-hub`
- evaluate `cli-anything-ollama`
- evaluate browser/macro abstractions
- future custom harnesses

## Outputs
- fit-gap analysis for each harness
- adoption priority list
- integration pattern for chosen harnesses

## Dependencies
- WP-05
- WP-10
- WP-12

## Success criteria
- new tool integrations become more agent-native
- fewer workflows depend on fragile UI-only interactions

---

## 2. Dependency Summary

### Base-first chain
- WP-01 → WP-02 / WP-03 / WP-04 / WP-05

### n8n chain
- WP-05 → WP-06 → WP-07 → WP-08 → WP-09

### model/agent chain
- WP-07 + WP-05 → WP-10 → WP-11 → WP-12 → WP-14

### expansion chain
- WP-12 + WP-10 → WP-13 / WP-15

---

## 3. Recommended Build Order

### Order 1
- WP-01 OpenClaw Base Foundation
- WP-02 OpenClaw Prompt & Role Architecture
- WP-03 Secrets, Config, and Environment Discipline
- WP-04 Browser Automation Surface

### Order 2
- WP-05 n8n Runtime Platform
- WP-06 n8n Operating Model
- WP-07 Data Persistence & Observability

### Order 3
- WP-08 AskNews Integration Layer
- WP-09 GPTTraderV4 / Event Intelligence Pipeline

### Order 4
- WP-10 Model Routing Layer
- WP-11 Local Inference Operations (Ollama)

### Order 5
- WP-12 Agent Orchestration Layer
- WP-13 Cloud Shell Helper Layer
- WP-14 Specialist Agents
- WP-15 CLI Harness / Tool Expansion Layer

---

## 4. Immediate “Do Next” Package Set

If Ayang wants the clearest next move, start with this exact subset:

1. **WP-01**
2. **WP-03**
3. **WP-05**
4. **WP-06**
5. **WP-07**
6. **WP-08**
7. **WP-10**

This sequence gives:
- stable platform
- stable n8n
- state/logging
- AskNews integration
- model routing foundation

That is enough to start serious analysis workflows without overbuilding the rest.

---

## 5. Final Guidance

The platform should be built in layers.
Do not jump to specialist agents or Cloud Shell helpers before:
- OpenClaw is stable
- n8n is stable
- logging exists
- model routing is explicit

The right goal is not “many agents fast.”
The right goal is:

**stable base → observable workflows → controlled inference → orchestrated specialists**
