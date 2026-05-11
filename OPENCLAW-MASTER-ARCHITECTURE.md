# OpenClaw Master Architecture

## 1. Mission

Build an OpenClaw-based assistant platform that can:
- orchestrate multiple AI agents
- create and operate AI tools on free Google Cloud Shell when useful
- use n8n for complex automations
- use local Ollama plus multiple models selected by purpose
- use an agent-management layer to keep work aligned to target
- support specialist agents such as forecasting / prediction agents

This is not just a chatbot.
This is a **multi-layer agentic operations platform**.

---

## 2. North Star

The target system should behave like this:

1. Ayang gives a goal
2. OpenClaw interprets it and selects the right execution path
3. the system chooses whether the work belongs to:
   - direct assistant action
   - n8n workflow
   - local model
   - cloud shell tool
   - specialist agent
4. the orchestration layer tracks execution, state, and outcomes
5. results come back in a controlled, observable, low-cost way

Success means:
- the assistant is useful across many job types
- automation can scale without becoming chaotic
- model cost stays under control
- agent behavior stays aligned to target

---

## 3. System Layers

## 3.1 Human Interface Layer

### Purpose
Entry point for Ayang.

### Components
- Telegram direct chat
- future other messaging channels if needed
- optional browser/admin access

### Responsibilities
- receive goals
- clarify intent
- return results
- surface checkpoints and failures

---

## 3.2 Control Plane Layer

### Purpose
This is the main brain and coordinator.

### Core component
- **OpenClaw main agent**

### Responsibilities
- interpret goals
- choose tools and execution mode
- route work to the correct sub-agent or system
- maintain policy, safety, and context
- decide when to use n8n, shell, browser, Ollama, or specialist agents

### Target internal roles
- `main` → human-facing assistant
- `lab` → technical experimentation / debugging / builds
- `worker` → isolated background jobs / cron / webhook tasks

This layer must stay lightweight and high-trust.

---

## 3.3 Automation Plane Layer

### Purpose
Run repeatable, multi-step, machine-oriented workflows.

### Core component
- **n8n**

### Responsibilities
- scheduled jobs
- webhook triggers
- branching workflow logic
- retries and timeouts
- integration orchestration
- long-running business/ops automation

### Example use cases
- AskNews collection pipelines
- GPTTrader decision workflows
- inbox triage
- notifications
- data ingestion and transformation

n8n should not become the “brain.”
It should become the **workflow engine**.

---

## 3.4 Inference Layer

### Purpose
Provide model execution matched to task type.

### Components
- local Ollama models
- remote API models where needed
- model routing policy

### Responsibilities
- cheap models for lightweight classification/extraction
- medium models for coding or structured generation
- strong models for planning / difficult analysis / forecasting
- fallbacks if one model is unavailable

### Principle
Different tasks should use different models.
A single-model architecture is wasteful and fragile.

---

## 3.5 Tool Execution Layer

### Purpose
Run concrete tool actions outside the core assistant.

### Components
- shell execution
- browser containers
- custom CLIs
- future CLI-Anything harnesses
- Cloud Shell helper tools

### Responsibilities
- perform file operations
- browser automation
- web interaction
- tool invocation
- software-specific command execution

This layer should be as deterministic as possible.

---

## 3.6 Cloud Helper Layer

### Purpose
Use free/ephemeral cloud compute when useful.

### Core target
- **Google Cloud Shell**

### Responsibilities
- host temporary helper scripts/tools
- run experiments or lightweight remote tasks
- offload certain jobs from the VPS when appropriate

### Constraints
- should not become the primary brain
- should be treated as disposable / task-oriented
- should not store critical long-term state

---

## 3.7 Agent Orchestration Layer

### Purpose
Coordinate multiple agents so they do not conflict or drift.

### Components
- OpenClaw role separation
- worker isolation
- future `paper@clip`-style manager/orchestrator
- state and run tracking

### Responsibilities
- assign work to the right agent
- track dependencies and completion
- keep agent scope aligned with target
- stop overlap and uncontrolled loops
- manage retries, fallback, escalation, and stop conditions

This is essential if the system grows beyond a single assistant.

---

## 3.8 Specialist Intelligence Layer

### Purpose
Provide domain-specific reasoning.

### Examples
- forecasting / prediction agent
- market/news analysis agent
- retrieval or research agents
- future domain agents

### Responsibilities
- operate on narrow, specialized tasks
- return structured results to the control plane or n8n
- not replace the control plane

---

## 3.9 Persistence and Observability Layer

### Purpose
Store state and make the platform debuggable.

### Components
- Postgres / Redis where appropriate
- workflow logs
- decision logs
- prompt/input snapshots
- execution logs
- memory files / workspace notes

### Responsibilities
- preserve state across restarts
- support audit and replay
- measure cost and quality
- support troubleshooting

Without this layer, the platform will become impossible to reason about.

---

## 4. Core Components

## 4.1 OpenClaw
Main control plane and human interface.

## 4.2 n8n
Workflow automation plane.

## 4.3 Ollama
Local inference plane for cheap/fast/private tasks.

## 4.4 Browser Sandboxes
Interactive web/browser execution surface.

## 4.5 Cloud Shell
Disposable remote helper compute.

## 4.6 AskNews / external intelligence providers
Specialized retrieval inputs for certain workflows.

## 4.7 Forecast / specialist agents
Focused reasoning components.

## 4.8 Future CLI harnesses
Agent-native tool wrappers.

---

## 5. Dependency Map

## 5.1 Hard dependencies
These are foundational.

### OpenClaw depends on
- working gateway/runtime
- stable browser containers
- stable secrets/config
- reliable model access

### n8n depends on
- healthy Postgres
- healthy Redis
- working container stack
- correct environment/config

### Ollama routing depends on
- reachable providers
- model inventory
- routing config

### Specialist agents depend on
- inference layer
- observability/logging
- task schema

### Cloud Shell helper workflows depend on
- secure auth/bootstrap method
- tool packaging conventions
- clear task boundaries

---

## 5.2 Soft dependencies
These improve quality but are not required on day one.

- CLI-Anything integration
- MacroCLI abstractions
- advanced prompt/version registry
- rich cost dashboards
- advanced agent manager

---

## 6. Priority Build Order

## Priority 1 — Foundation
Build the system so it is stable before it becomes powerful.

### Components
- OpenClaw `main / lab / worker`
- secrets/env correctness
- stable browsers
- basic health and restart discipline
- n8n stable runtime
- Ollama/provider baseline

### Why first
Without this, every later layer will be unreliable.

---

## Priority 2 — Observability and Control
Make the system explainable.

### Components
- structured logs
- decision logs
- workflow logs
- model selection logs
- state persistence
- guardrails

### Why second
A multi-agent system without observability becomes impossible to tune.

---

## Priority 3 — Automation Plane
Build useful repeatable workflows.

### Components
- n8n schemas
- AskNews pipelines
- analysis-only workflows
- webhook/cron patterns
- worker isolation

### Why third
This gives immediate utility while staying contained.

---

## Priority 4 — Model Routing Layer
Stop treating inference as one-size-fits-all.

### Components
- local Ollama routing
- fallback model strategy
- per-task model policy
- low-cost / high-cost task split

### Why fourth
This reduces cost and improves reliability.

---

## Priority 5 — Agent Orchestration
Grow from tools into a platform.

### Components
- explicit task routing
- sub-agent governance
- dependency tracking
- completion/failure handling

### Why fifth
Only add real orchestration after the lower layers are stable.

---

## Priority 6 — Specialist Agents
Add capability after structure exists.

### Components
- forecasting agent
- market/news agents
- Cloud Shell helper agents
- future domain specialists

### Why sixth
Specialists are valuable only when their outputs can be controlled and observed.

---

## 7. Real Implementation Order

## Phase A — Stabilize current platform
1. finalize OpenClaw role split
2. stabilize secrets/env handling
3. stabilize browser containers
4. confirm n8n runtime health
5. confirm Ollama/provider baseline

## Phase B — Build core n8n architecture
1. finalize n8n schema/storage design
2. build analysis-only pipelines
3. build AskNews-first retrieval workflows
4. add logs and checkpoints
5. add paper execution mode

## Phase C — Build model routing
1. classify tasks by model class
2. define local vs remote routing
3. define fallback model behavior
4. add token/cost awareness

## Phase D — Build orchestration discipline
1. formalize which tasks belong to `main`, `lab`, `worker`
2. define escalation rules
3. define retry/stop/fallback rules
4. add task state tracking

## Phase E — Add specialist agents
1. forecasting/prediction agent
2. market/news specialist
3. Cloud Shell helper agent
4. future domain agents

---

## 8. Design Principles

## 8.1 Platform before proliferation
Do not add many agents before the base platform is stable.

## 8.2 Deterministic logic before prompt complexity
Hard-code what can be deterministic.
Do not ask models to simulate logic that code can enforce.

## 8.3 Cheap-first model routing
Use the cheapest model that can do the job correctly.

## 8.4 Workflow engine is not the brain
n8n executes workflows.
OpenClaw decides when and why they should run.

## 8.5 Specialist agents are narrow
They should do one domain well, not become general-purpose chaos engines.

## 8.6 Observability is mandatory
Every important decision path must be inspectable.

---

## 9. Main Risks

## 9.1 Architecture sprawl
Too many components before clear control boundaries.

## 9.2 Cost drift
Too many expensive model calls because routing is vague.

## 9.3 State confusion
No clear ownership of memory, workflow state, and task status.

## 9.4 Agent overlap
Multiple agents doing the same job or conflicting with each other.

## 9.5 Hidden failures
Automations failing silently because logs and checkpoints are weak.

---

## 10. Success Criteria

The architecture is working when:
- OpenClaw can route work consistently
- n8n runs useful workflows without manual babysitting
- Ollama/local models are used where economically appropriate
- specialist agents operate with clear scope
- Cloud Shell helpers are optional accelerators, not brittle dependencies
- logs explain why actions happened
- cost stays under control
- Ayang can trust the system

---

## 11. Immediate Next Actions

1. lock the OpenClaw base architecture
2. lock the n8n blueprint and AskNews guardrails
3. define the model routing matrix
4. define agent role boundaries
5. build the first analysis-only specialist pipeline

---

## 12. Executive Summary

The target is to build **OpenClaw as a multi-layer AI operations platform**.

### Core roles
- **OpenClaw** = brain / controller
- **n8n** = workflow engine
- **Ollama + model routing** = inference layer
- **Cloud Shell** = disposable helper compute
- **specialist agents** = narrow intelligence modules
- **observability/state** = platform memory and control

### Correct build order
1. stabilize base
2. add observability
3. build workflows
4. add model routing
5. add orchestration
6. add specialists

This is the correct path if the goal is not a demo, but a durable assistant platform.
