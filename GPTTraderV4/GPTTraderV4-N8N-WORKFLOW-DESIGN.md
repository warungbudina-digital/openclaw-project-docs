# GPTTraderV4 — n8n Workflow Design (Node-by-Node)

## 1. Design goal

This design ports GPTTraderV4 into n8n with a cleaner separation of concerns than the original FreqAI release.

Target properties:
- persistent state
- deterministic pre-processing where it matters
- LLM reserved for semantic interpretation and final action
- auditable decisions
- safe staged rollout from analysis-only to live execution

---

## 2. Recommended workflow split

Do not build this as one workflow.
Use these workflows:

1. `WF-01 Pair Scheduler`
2. `WF-02 Collect Market Content`
3. `WF-03 Build Decision Context`
4. `WF-04 LLM Decision Engine`
5. `WF-05 Execution Router`
6. `WF-06 Monitoring / Notifications`
7. `WF-07 Maintenance / Cleanup`

You can collapse some of these later, but start separated.

---

## 3. WF-01 Pair Scheduler

## Purpose
Drives the evaluation cycle per enabled pair.

## Trigger
- `Schedule Trigger`
- Example: every 5 or 10 minutes

## Node-by-node

### 1. `Schedule Trigger`
Starts the cycle.

### 2. `Postgres / Data Store: Load Enabled Pairs`
Query `pair_registry` where:
- `enabled = true`

Fields needed:
- pair
- symbol
- project_name
- use_news
- use_twitter
- news_hours
- tweet_minutes
- news_count
- tweet_count
- target_profit
- stoploss
- target_duration
- llm_model
- llm_provider

### 3. `Split In Batches`
Process one pair at a time.

Reason:
- easier rate limiting
- easier per-pair error isolation
- easier decision logging

### 4. `Postgres / Data Store: Load Pair Checkpoint`
Load latest checkpoint from `source_checkpoint`.

Needed values:
- last_news_timestamp
- last_tweet_timestamp
- last_run_at
- last_decision_action

### 5. `Postgres / Data Store: Load Position State`
Load current open/closed state from `position_state`.

Needed values:
- side
- status
- entry_price
- opened_at
- current_profit
- exchange_position_id

### 6. `Execute Workflow -> WF-02 Collect Market Content`
Pass in:
- pair
- symbol
- project_name
- config block
- checkpoint block
- position block

### 7. `IF: Any Fresh Content?`
If no:
- log skip reason
- continue next pair

### 8. `Execute Workflow -> WF-03 Build Decision Context`
Pass in normalized fresh items + pair config + position state.

### 9. `Execute Workflow -> WF-04 LLM Decision Engine`
Pass in built context + pair config.

### 10. `Execute Workflow -> WF-05 Execution Router`
Pass in decision + pair state + config.

### 11. `Execute Workflow -> WF-06 Monitoring / Notifications`
Pass in summary payload.

### 12. `Split In Batches -> Next`
Loop next pair.

---

## 4. WF-02 Collect Market Content

## Purpose
Collect and normalize news + social content.

## Input
- pair
- symbol
- project_name
- use_news
- use_twitter
- news_hours
- tweet_minutes
- news_count
- tweet_count
- checkpoints

## Node-by-node

### 1. `Set: Normalize Inputs`
Prepare a clean config payload.

### 2. `IF: project_name missing or stale?`
If yes, resolve via CoinGecko.

### 3. `HTTP Request: CoinGecko`
Resolve symbol -> project name.

Suggested endpoint:
- `/api/v3/coins/markets?vs_currency=usd&symbols={symbol}`

### 4. `Code: Validate CoinGecko Response`
Extract canonical project name.
If invalid:
- fallback to existing cached project_name
- if still missing, flag pair error and stop

### 5. `IF: use_news == true`
Branch to news collection.

**AskNews endpoint**:
- use **AskNews `/news`** here
- this is the **mandatory baseline retrieval path** for GPTTraderV4-style workflows

### 6. `HTTP Request: AskNews News Search`
Parameters:
- query using project_name + symbol
- time window from checkpoint or `news_hours`
- article limit `news_count`

**Why `/news` here**:
- lowest-cost core news retrieval
- suitable for repeated polling
- should run before any social/open-web escalation

### 7. `Code: Normalize News Items`
Map each article to standard shape:
- source_type = `news`
- published_at
- title
- body_summary
- external_sentiment
- reporting_voice
- source
- classification
- continent
- canonical_content_hash

### 8. `IF: use_twitter == true`
Branch to social collection.

**AskNews endpoint**:
- this branch is **not `/news`**
- use it only as an optional escalation path after baseline news retrieval

### 9. `HTTP Request: AskNews Live Web Search`
Parameters:
- query project_name + symbol + since filter
- restrict domain to `x.com`

**Endpoint**:
- use **AskNews `/websearch`** here
- do not replace `/news` with this as the default path

### 10. `Code: Normalize Social Items`
Map each post to standard shape:
- source_type = `tweet`
- published_at
- title
- content
- retweets
- likes
- replies
- quotes
- engagement_total
- canonical_content_hash
- source

### 11. `Merge`
Combine normalized news + tweet streams.

### 12. `Code: Deduplicate`
Deduplicate by:
- provider item id if available
- else `canonical_content_hash`

Important source rule:
- items from AskNews `/news` must remain tagged as `source_type = news`
- items from AskNews `/websearch` must remain tagged as `source_type = tweet`
- do not flatten both into one anonymous content stream

### 13. `Code: Compute Deterministic Fields`
For each item compute:
- age_minutes
- recency_factor
- engagement_total
- deterministic_impact_floor
- source_type

Important:
- tweet with zero engagement -> `deterministic_impact_floor = 0`

### 14. `Postgres / Data Store: Upsert content_items`
Persist raw normalized items.

### 15. `Code: Detect Fresh Items`
Compare item timestamps/hashes against checkpoint.

### 16. `Postgres / Data Store: Update source_checkpoint`
Update:
- latest news timestamp
- latest tweet timestamp
- latest fetch time

### 17. `Return`
Return:
- fresh_items
- all_recent_items
- updated project_name
- checkpoint summary

---

## 5. WF-03 Build Decision Context

## Purpose
Prepare the exact payload for the LLM.

## Input
- fresh_items
- recent_items
- pair config
- position state

## Node-by-node

### 1. `Code: Partition by Source Type`
Split into:
- news_items
- tweet_items

### 2. `Code: Sort by Recency`
Sort descending by `published_at`.

### 3. `Code: Limit Context Size`
Recommended:
- latest 5–10 news items
- latest 5–10 tweets

Do not blindly send everything.

### 4. `Code: Build Structured Context`
Build JSON object per item with:
- item_id
- source_type
- title
- content/body
- published_at
- age_minutes
- recency_factor
- source
- reporting_voice
- external_sentiment
- classification
- continent
- engagement_total
- engagement_breakdown

### 5. `Code: Optional Markdown Renderer`
If you want parity with original GPTTraderV4, render markdown sections:
- `## News Articles`
- `## Tweets/Social Media`

### 6. `Code: Build Pair Runtime Payload`
Include:
- pair
- project_name
- target_profit
- stoploss
- target_duration
- side
- current_profit
- duration_open
- timestamp_now
- mode = `entry` or `exit`

### 7. `Postgres / Data Store: Persist prompt_input_snapshot`
Optional but recommended.
This makes replay/debugging possible.

### 8. `Return`
Return:
- llm_input_structured
- llm_input_markdown
- runtime_payload
- mode

---

## 6. WF-04 LLM Decision Engine

## Purpose
Generate structured recommendation from the LLM.

## Input
- llm_input_structured or markdown
- runtime_payload
- mode
- model config

## Node-by-node

### 1. `Code: Build System Prompt`
Keep a versioned prompt.
Recommended prompt strategy:
- deterministic fields are already computed outside the model
- model focuses on semantic interpretation and final decision

### 2. `Code: Build User Prompt`
Two variants:
- `entry`
- `exit`

### 3. `OpenAI / HTTP Request`
Call model with structured output schema.

Recommended schema:
- `item_analysis[]`
  - item_id
  - semantic_sentiment
  - adjusted_sentiment
  - rationale
- `aggregate`
  - avg_sentiment
  - avg_heat
  - confidence
- `action`
  - `LONG_ENTER`
  - `SHORT_ENTER`
  - `LONG_EXIT`
  - `SHORT_EXIT`
  - `NEUTRAL`
- `summary`

### 4. `Code: Validate Response`
Validate:
- action in allowed enum
- scores within range
- no NaN
- confidence in [0,1]

If invalid:
- mark decision as invalid
- return `NEUTRAL`
- log parse failure

### 5. `Code: Apply Post-LLM Guardrails`
Examples:
- if no items -> force `NEUTRAL`
- if confidence < threshold -> optionally force `NEUTRAL`
- if avg_heat too low -> force `NEUTRAL`
- if tweet-only and zero engagement -> force `NEUTRAL`

### 6. `Postgres / Data Store: Insert decision_log`
Persist:
- prompt version
- model
- raw output
- validated output
- mode
- action

### 7. `Return`
Return validated decision object.

---

## 7. WF-05 Execution Router

## Purpose
Translate decision into execution or simulation.

## Input
- decision
- pair config
- current position
- current market snapshot

## Node-by-node

### 1. `IF: mode == analysis_only?`
If yes:
- skip order placement
- emit notification only

### 2. `IF: action == NEUTRAL`
If yes:
- log hold/skip
- stop

### 3. `HTTP Request / Exchange / Freqtrade API: Get Current Price`
Fetch market price for pair.

### 4. `Code: Slippage Guard`
Mimic original logic:
- for long entry, reject if price > last close × 1.0025
- for short entry, reject if price < last close × 0.9975

### 5. `Code: Position Safety Guard`
Examples:
- do not open if position already exists
- do not exit if no position exists
- do not reverse instantly unless enabled
- max_open_trades check

### 6. `IF: LONG_ENTER`
Route to long entry order.

### 7. `IF: SHORT_ENTER`
Route to short entry order.

### 8. `IF: LONG_EXIT or SHORT_EXIT`
Route to close order.

### 9. `HTTP Request: Execute Order`
Can target:
- Freqtrade REST API
- custom bridge
- direct exchange service

### 10. `Postgres / Data Store: Update position_state`
Update:
- side
- status
- opened_at / closed_at
- entry_price / exit_price
- order id
- decision id

### 11. `Postgres / Data Store: Insert execution_log`
Record request/response.

### 12. `Return`
Return execution result.

---

## 8. WF-06 Monitoring / Notifications

## Purpose
Human visibility and auditability.

## Node-by-node

### 1. `Code: Build Summary`
Include:
- pair
- mode
- action
- avg_sentiment
- avg_heat
- confidence
- summary
- order result or skip reason

### 2. `IF: important action?`
Examples:
- non-neutral decision
- failed execution
- parse failure
- data source outage

### 3. `Telegram / Discord / Email`
Send concise summary.

### 4. `Postgres / Data Store: Monitoring Event`
Persist event for dashboard use.

---

## 9. WF-07 Maintenance / Cleanup

## Purpose
Prevent state bloat.

## Trigger
- daily

## Node-by-node

### 1. `Schedule Trigger`
Daily or every 12h.

### 2. `Postgres: Delete old raw content beyond retention`
Example: keep 30–90 days.

### 3. `Postgres: Archive old decision logs`
Optional.

### 4. `Postgres: Recompute stale checkpoints`
Optional.

### 5. `Notification`
Send maintenance summary if needed.

---

## 10. Recommended rollout stages

## Stage A — Analysis only
Build:
- WF-01
- WF-02
- WF-03
- WF-04
- WF-06

No orders.

## Stage B — Paper trading
Add:
- WF-05 in simulated mode
- synthetic position_state
- pnl estimation

## Stage C — Live execution
Add:
- real order routing
- strict limits
- optional manual approval gate

---

## 11. Key implementation decisions

## Decision 1 — Structured JSON first, markdown second
Internally keep JSON.
Only render markdown if the LLM performs better with it.

## Decision 2 — Persist everything important
Persist:
- fetched content
- checkpoints
- prompts
- decisions
- executions

## Decision 3 — Deterministic pre-scoring outside the LLM
Compute outside the model:
- age
- recency
- engagement totals
- zero-engagement rule
- duration open
- slippage checks

## Decision 4 — Guardrails after the LLM too
Do not trust raw model output directly.
Always validate and possibly downgrade to `NEUTRAL`.

## Decision 5 — Use idempotent writes
Every run should be safe to replay without duplicate positions or duplicate content records.

---

## 12. Minimal MVP build order

1. Pair scheduler
2. News fetch (**AskNews `/news` first**)
3. Tweet fetch
4. Normalization + storage
5. Context builder
6. LLM decision schema
7. Decision logging
8. Telegram summary
9. Paper execution
10. Live execution

## 12.1 Explicit AskNews `/news` usage points

The following parts of this blueprint should use **AskNews `/news`**:

1. **WF-02 / Step 6**
   - first retrieval call per pair
   - main article collection path

2. **Checkpoint-driven refresh**
   - compare against `last_news_timestamp`
   - avoid paying repeatedly for the same window

3. **`content_items` population for news rows**
   - all rows with `source_type = news` should originate from `/news`

4. **Analysis-only MVP**
   - the MVP should work using `/news` alone before adding `/websearch`

5. **Primary entry/exit context**
   - if `/news` returns no fresh relevant items, the workflow should usually skip or stay neutral unless there is a specific escalation rule

---

## 13. Output files that should exist after implementation

- workflow JSON exports for each workflow
- prompt version file(s)
- schema migration file(s)
- credentials/environment mapping notes
- sample payloads for:
  - news item
  - tweet item
  - decision request
  - decision response
