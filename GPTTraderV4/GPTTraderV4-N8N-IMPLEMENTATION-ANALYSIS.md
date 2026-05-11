# GPTTraderV4 — Workflow Analysis and n8n Implementation Blueprint

## 1. Scope

Source files downloaded from Discord `FreqAI > #feature-updates`:
- `GPTTraderV4.py`
- `GPTStrategyV4.py`
- `config_freqai_gpttrader_v4.json`
- `GPTTRADER_V4_README.md`

This document does three things:
1. explains how GPTTraderV4 actually works
2. identifies important implementation details and inconsistencies
3. maps the design into an n8n workflow that can be implemented later

---

## 2. What the project is

GPTTraderV4 is **not** a pure rules-based strategy.
It is a **news/social-event driven trading decision engine** wrapped inside Freqtrade/FreqAI.

The system:
- fetches crypto news from AskNews
- optionally fetches X/Twitter posts from AskNews live web search
- converts both into a markdown context block
- sends that context to an LLM
- asks the LLM for structured output:
  - per-item sentiment scores
  - per-item heat scores
  - a final trade action
  - a short explanation
- converts that result into entry/exit signals for Freqtrade

So the core of the strategy is:

**external event ingestion → LLM judgment → structured recommendation → trade execution**

---

## 3. File-by-file role

## 3.1 `GPTTraderV4.py`
This is the **decision engine / model layer**.

Responsibilities:
- load GPTTrader config
- connect to OpenAI-compatible LLM via `instructor`
- connect to AskNews
- fetch news and tweets
- cache recent news/posts
- build prompt context
- call the LLM for entry or exit recommendations
- translate recommendation into FreqAI output fields

Important methods:
- `__init__()`
- `_prepare_latest_news()`
- `_prepare_latest_twitter()`
- `_get_entry_recommendation()`
- `_get_exit_recommendation()`
- `train()`
- `predict()`
- `get_state_info()`
- helper functions `fetch_project_name()`, `build_news_context()`, `build_web_context()`

## 3.2 `GPTStrategyV4.py`
This is the **Freqtrade strategy wrapper**.

Responsibilities:
- define trading parameters
- read FreqAI-generated fields
- convert those fields into actual long/short entry signals
- decide exits using `custom_exit()`
- confirm entry price sanity using `confirm_trade_entry()`

## 3.3 `config_freqai_gpttrader_v4.json`
This is the **runtime configuration**:
- Bybit futures
- 30m timeframe
- dry-run enabled
- FreqAI enabled
- GPTTrader settings
- API server config

## 3.4 `GPTTRADER_V4_README.md`
This is the **conceptual documentation**.
It explains the intended weighting system and operating model, but the actual behavior is still controlled by code + prompts.

---

## 4. Actual runtime flow

## 4.1 High-level flow

```text
Pair (e.g. BTC/USDT)
  -> resolve project name via CoinGecko
  -> fetch recent news from AskNews
  -> optionally fetch recent X posts from AskNews live web search
  -> merge with cached previous items
  -> build markdown context
  -> inspect whether a position is already open
      -> if no open position: ask LLM for ENTRY recommendation
      -> if open position: ask LLM for EXIT recommendation
  -> store structured result
  -> map result to Freqtrade signals
  -> strategy enters/exits depending on output
```

---

## 4.2 Initialization flow

In `GPTTraderV4.__init__()`:
- reads `self.freqai_info['GPTTrader']`
- validates it through `GPTTraderConfig`
- creates LLM client through `instructor.from_provider()`
- creates AskNews SDK client
- initializes two caches:
  - `self.last_news`
  - `self.last_x_posts`

Important implication:
- this model is **stateful in memory**
- if the process restarts, those caches reset

For n8n, that means you must decide whether to:
- tolerate stateless execution, or
- persist cache/state in DB / Redis / data store

---

## 4.3 Project name resolution

Method: `fetch_project_name(pair)`

Flow:
- extracts symbol from pair, e.g. `BTC/USDT -> btc`
- calls CoinGecko markets endpoint
- reads the coin name
  - e.g. `btc -> Bitcoin`
- retries up to 5 times with delays
- uses `lru_cache()` so repeated pair lookups are memoized

Purpose:
- AskNews queries use both project name and symbol for better recall

n8n implication:
- keep a symbol→project-name cache table
- refresh only occasionally

---

## 4.4 News ingestion

Method: `_prepare_latest_news(project_name, symbol)`

Behavior:
- queries AskNews with a string like:
  - `cryptocurrency market {project_name} {symbol} {symbol}`
- uses `string_guarantee=[project_name, symbol, symbol]`
- if there is prior cache, it uses `start_timestamp` from the latest cached article
- otherwise it uses `hours_back = news_hours`
- merges fresh items with cached items
- truncates to `news_count`
- converts the result into markdown with `build_news_context()`

Returned format example:
- `#### News#0`
- title
- published timestamp and age in minutes
- source
- classification
- external analyst sentiment
- reporting voice
- continent
- summary

Key implementation detail:
- the model does **not** directly compute sentiment in code
- it delegates that interpretation to the LLM through the prompt

---

## 4.5 Twitter/X ingestion

Method: `_prepare_latest_twitter(project_name, symbol)`

Behavior:
- uses AskNews `chat.live_web_search()` against `https://x.com`
- constructs a query combining project name, symbol, and recency filter
- uses the latest cached tweet timestamp if available
- merges fresh posts with cached posts
- truncates to `news_count`
- converts posts to markdown via `build_web_context()`

For each social post, it tries to extract:
- content text
- retweets
- likes
- replies
- quotes

Metrics are parsed from `key_points` strings.

Key implementation detail:
- if engagement is zero, the prompt instructs the LLM to assign effectively zero impact
- again, the heat/sentiment logic is mostly enforced by prompt, not hard-coded calculations

---

## 4.6 Entry recommendation flow

Method: `_get_entry_recommendation()`

Input:
- `news_context`
- `x_context`
- config values like target profit, duration, stoploss

It sends:
- `SYSTEM_PROMPT`
- `USER_PROMPT_ENTER_POSITION`

The response is parsed into `TradingRecommendation`.

Structured response fields:
- `sentiments: List[float]`
- `heat_scores: List[float]`
- `action`
- `summary`

Computed properties:
- average `sentiment`
- average `heat`

Expected actions:
- `LONG_ENTER`
- `SHORT_ENTER`
- `NEUTRAL`

---

## 4.7 Exit recommendation flow

Method: `_get_exit_recommendation()`

Same structure as entry flow, but with:
- current side
- current profit
- current duration

Expected actions:
- `LONG_EXIT`
- `SHORT_EXIT`
- `NEUTRAL`

The LLM decides whether current news/social data should close an open position.

---

## 4.8 Train / predict split in FreqAI

This is important.

### `train()`
In this project, `train()` is misnamed in the ML sense.
It is used as the **main decision cycle**.

It does:
- fetch fresh external inputs
- skip LLM call if nothing new arrived
- detect current position state
- request either entry or exit recommendation
- return the recommendation as a serializable dict

### `predict()`
This converts the stored recommendation into fields consumed by the strategy:
- `sentiment_yes`
- `sentiment_no`
- `sentiment_unknown`
- `sentiment`
- `heat`
- `expert_long_enter`
- `expert_long_exit`
- `expert_short_enter`
- `expert_short_exit`
- `expert_neutral`
- `expert_opinion`

Then it returns zero-valued dummy predictions for the normal FreqAI label channel.

Meaning:
- the normal ML prediction layer is effectively bypassed
- FreqAI here is being used as a transport/control harness for LLM decisions

For n8n, this is actually good news:
- you do not need to reproduce FreqAI training/prediction semantics
- you only need to reproduce the **decision loop and signal mapping**

---

## 5. How the strategy executes trades

## 5.1 Entry rules

In `GPTStrategyV4.populate_entry_trend()`:
- if `expert_long_enter == 1` -> set `enter_long = 1`
- if `expert_short_enter == 1` -> set `enter_short = 1`

So the strategy is almost entirely downstream of LLM action flags.

## 5.2 Exit rules

In `custom_exit()`:
- expires trade after duration > 1000 minutes/candles logic branch in code comments
- exits short if `expert_short_exit == 1`
- exits long if `expert_long_exit == 1`
- uses `expert_opinion` as part of exit reason string

## 5.3 Entry price confirmation

In `confirm_trade_entry()`:
- for long: reject if price is more than 0.25% above last close
- for short: reject if price is more than 0.25% below last close

This is a slippage guard.

## 5.4 Static risk envelope in strategy

Strategy-level settings:
- `stoploss = -0.04`
- `minimal_roi = {"0": 0.03, "5000": -1}`
- `can_short = True`
- cooldown and max-drawdown protections

So there are two layers of risk logic:
1. **strategy hard rules**
2. **LLM event-based decision rules**

---

## 6. What the prompts are really doing

A critical point:

The README sounds like the project has a deterministic formula for sentiment and heat.
In reality, the **formula is described to the LLM**, not enforced numerically in code.

That means:
- sentiment values are **model-generated judgments**
- heat values are **model-generated judgments**
- weighting logic is **prompt-guided**, not mathematically guaranteed

So the real architecture is:

**prompt-engineered qualitative reasoning -> structured numeric output**

This matters for n8n because you have two implementation options:

### Option A — faithful port
Keep the same approach:
- same context style
- same prompts
- structured LLM output
- same thresholds

### Option B — hardened deterministic port
Move some logic out of prompt and into code/workflow:
- calculate recency decay in code
- calculate tweet engagement impact in code
- score article metadata in code
- reserve the LLM for semantic interpretation only

For production n8n, Option B is stronger.
For parity with this Discord release, Option A is closer.

---

## 7. Important inconsistencies and implementation caveats

These matter if you want to reproduce the project cleanly.

## 7.1 `stop_loss` vs `stoploss`

In `GPTTraderConfig`:
- field name is `stoploss`

In config file:
- key is `stop_loss`

That mismatch means the config value may not populate the field as intended.
Most likely result:
- default `stoploss = 0.04` remains in effect
- config key `stop_loss` is ignored by the model config parser

For n8n, normalize this to **one name only**.
Recommendation:
- use `stoploss`

## 7.2 JSON file contains comments

`config_freqai_gpttrader_v4.json` contains inline `// comments`.
That is **not valid strict JSON**.

Implication:
- some parsers will fail unless they support JSON5/commented JSON

For n8n or any standard parser:
- remove comments
- or store config in JSON5/YAML

## 7.3 Prompt says external sentiment weight 20–30%, code/docs say 30%

There is slight narrative inconsistency across:
- README
- SYSTEM_PROMPT
- USER prompts

Not fatal, but it means this is not mathematically rigid.

## 7.4 `tweet_minutes` default mismatch

`GPTTraderConfig` default:
- `tweet_minutes = 15`

README example/config example often references 30.

Not a major issue, but standardize it in your port.

## 7.5 `news_count` also caps tweets

The same `news_count` setting is used to cap both:
- article cache
- tweet cache

This is simple, but not ideal.
In n8n you may want:
- `news_count`
- `tweet_count`

## 7.6 Model state is in memory only

The caches:
- `last_news`
- `last_x_posts`

are not persisted.

After restart:
- all incremental fetch behavior resets

If you port this to n8n, state persistence is one of the first things to improve.

## 7.7 Short entry tag bug in `GPTStrategyV4.py`

In `populate_entry_trend()`:
- long entries use `TAG_ENTER_LONG`
- short entries also incorrectly use `TAG_ENTER_LONG`

That is almost certainly a bug.
Expected behavior should be:
- short entries should use `TAG_ENTER_SHORT`

Why it matters:
- `custom_exit()` checks `entry_tag == TAG_ENTER_SHORT` for short exits
- if the short position was tagged as long on entry, exit logic can become inconsistent

If you port this to n8n, fix this explicitly.

## 7.8 Duration/risk config mismatch

There are multiple duration/risk values that are not consistently wired:

- `GPTTraderConfig.target_duration` defaults to `100`
- config file sets `target_duration: 1000`
- `custom_exit()` hardcodes `if trade_duration > 1000:`
- strategy ROI and stoploss are also hardcoded separately:
  - `stoploss = -0.04`
  - `minimal_roi = {"0": 0.03, "5000": -1}`

Implication:
- some risk controls live in config
- some live in prompts
- some live in hardcoded strategy values
- they are not fully unified

For n8n, centralize these in one risk config source.

## 7.9 CoinGecko dependency is in the critical path

If CoinGecko fails:
- project name resolution may block the rest of the cycle

In n8n, cache pair metadata locally and do not rely on CoinGecko every run.

---

## 8. Exact behavioral logic to preserve if you want parity

If your goal is to preserve project behavior, keep these:

1. Use pair symbol + project name to query content
2. Use recent-content windows:
   - news by `news_hours`
   - tweets by `tweet_minutes`
3. Skip the LLM call entirely if there is no fresh content
4. If no open position -> request entry recommendation
5. If open position -> request exit recommendation
6. Preserve structured output fields:
   - sentiments
   - heat_scores
   - action
   - summary
7. Map actions directly to trade signals
8. Keep the slippage check before sending orders

---

## 9. n8n implementation architecture

## 9.1 Recommended design

Do **not** port this as one giant workflow.
Break it into layers.

### Workflow A — Pair State Scheduler
Triggered every N minutes per pair.

Responsibilities:
- iterate enabled pairs
- load pair metadata
- load cached state
- branch to entry or exit evaluation

### Workflow B — Data Collection
Responsibilities:
- resolve project name if missing
- fetch AskNews articles
- fetch AskNews/X posts if enabled
- normalize records
- deduplicate
- persist latest fetch timestamps per pair/source

### Workflow C — Decision Engine
Responsibilities:
- build markdown or structured context
- call OpenAI
- parse structured recommendation
- validate action and numeric ranges
- persist decision log

### Workflow D — Trade Execution
Responsibilities:
- fetch current market price
- apply slippage guard
- place long/short/close order
- store resulting position state

### Workflow E — Monitoring / Audit
Responsibilities:
- store raw articles/posts
- store LLM prompt and response metadata
- store decisions and executed actions
- support replay/debugging

---

## 9.2 Minimum data model for n8n

You need persistent state. At minimum:

### `pair_registry`
- pair
- symbol
- project_name
- enabled
- use_news
- use_twitter
- target_profit
- stoploss
- target_duration

### `source_checkpoint`
- pair
- last_news_timestamp
- last_tweet_timestamp

### `content_items`
- id
- pair
- source_type (`news` / `tweet`)
- source_id
- published_at
- title
- body/content
- metadata_json
- external_sentiment
- reporting_voice
- engagement_json
- dedupe_hash

### `position_state`
- pair
- side
- entry_price
- opened_at
- current_profit
- status

### `decision_log`
- pair
- run_at
- mode (`entry` / `exit`)
- sentiments_json
- heat_scores_json
- avg_sentiment
- avg_heat
- action
- summary
- prompt_version
- model_name
- raw_response_json

---

## 9.3 Recommended n8n node sequence

### Entry/Exit decision workflow

```text
Cron / Schedule Trigger
  -> Load enabled pairs
  -> Split In Batches (per pair)
  -> Load pair state + checkpoints
  -> Resolve project name (if missing or stale)
  -> HTTP Request: AskNews news search
  -> IF use_twitter
      -> HTTP Request: AskNews live web search
  -> Normalize and dedupe items
  -> IF no fresh items
      -> Log "skipped: no fresh content"
      -> next pair
  -> Build context (Function node)
  -> IF open position?
      -> build exit prompt
     else
      -> build entry prompt
  -> OpenAI Chat/Responses call with structured schema
  -> Validate schema / numeric bounds
  -> Persist decision_log
  -> IF action == LONG_ENTER / SHORT_ENTER / LONG_EXIT / SHORT_EXIT
      -> Fetch market price
      -> Slippage check
      -> Send order via exchange endpoint / freqtrade API
      -> Update position_state
  -> Notify / audit log
```

---

## 9.4 Where to keep deterministic logic in n8n

Recommended hard-coded logic in workflow rather than prompt:

### Deterministic in workflow
- recency bucket calculation
- tweet engagement sum
- zero-engagement => impact zero
- timestamp aging
- slippage rejection
- dedupe and checkpointing
- current position duration
- target/stop math

### LLM-only logic
- semantic reading of article/tweet content
- classification of real action vs prediction/speculation
- contextual market interpretation
- final trade recommendation summary

This split will make the n8n port more stable than the original.

---

## 10. Suggested prompt strategy for n8n

If you want a strong production port, simplify the LLM contract.

Instead of asking the model to invent everything, feed it partially computed metadata:
- `recency_factor`
- `engagement_total`
- `impact_pre_score`
- `source_type`
- `reporting_voice`
- `external_sentiment`

Then ask it for:
- semantic sentiment adjustment
- confidence
- action
- short rationale

This reduces drift and token waste.

---

## 11. Suggested API and tool mapping

## 11.1 External services used by original project
- CoinGecko: symbol -> project name
- AskNews News API
- AskNews live web search for X/Twitter
- OpenAI-compatible LLM endpoint
- Exchange execution via Freqtrade/ccxt

## 11.2 For n8n
You can map them as:
- `HTTP Request` node -> CoinGecko
- `HTTP Request` node -> AskNews
- `OpenAI` node or HTTP call -> model inference
- `Postgres` / `Redis` / `Data Store` -> state persistence
- `HTTP Request` node -> Freqtrade API or exchange bridge

---

## 12. Recommended first implementation phases

## Phase 1 — Analysis-only
Build a workflow that:
- fetches content
- produces recommendation
- stores decision log
- sends Telegram/Discord summary
- **does not trade**

This validates prompt quality and data flow.

## Phase 2 — Paper execution
Add:
- synthetic position state
- simulated fills
- pnl tracking

## Phase 3 — Controlled live execution
Add:
- real order routing
- strict per-pair limits
- manual approval gate if desired

---

## 13. Practical implementation notes

## 13.1 Do not depend on raw markdown forever
The original project uses markdown because it is quick.
For n8n, prefer a structured JSON intermediary, and only render markdown if the prompt still benefits from it.

## 13.2 Store raw source artifacts
Keep:
- raw AskNews response
- normalized content
- final prompt body
- final model output

Without this, debugging trade decisions later will be painful.

## 13.3 Add guardrails the original project does not enforce strongly
Recommended:
- max decisions per pair per hour
- cooldown after reversal
- skip trading on conflicting action within short interval
- require minimum content count for high conviction
- require minimum confidence for live execution

## 13.4 Separate data freshness from trade frequency
The original project couples content freshness to its decision loop tightly.
In n8n, it is better to:
- collect content frequently
- evaluate trading on a controlled schedule

---

## 14. Condensed “true flow” summary

If reduced to essentials, GPTTraderV4 works like this:

1. Resolve coin/project name
2. Pull fresh news
3. Optionally pull fresh tweets/X posts
4. Merge with recent cache
5. If nothing new, do nothing
6. If no position, ask LLM whether to open long/short/neutral
7. If there is a position, ask LLM whether to exit or hold
8. Convert recommendation into action flags
9. Let Freqtrade strategy execute based on those flags
10. Enforce simple price/slippage sanity at entry

---

## 15. Recommendation for your n8n port

If the goal is **implementable and maintainable**, do this:

### Keep from original
- event-driven thesis
- AskNews + optional X inputs
- real-vs-speculative distinction
- entry/exit split
- structured model output

### Improve in your version
- persistent checkpoints/state
- deterministic recency and engagement scoring
- normalized JSON instead of markdown-only internals
- config field cleanup
- explicit confidence/risk gates
- audit trail for every decision

That gives you the same strategic idea, but with much stronger operations.

---

## 16. Files saved locally

Downloaded files are stored at:
- `/home/node/.openclaw/workspace/GPTTraderV4/GPTTraderV4.py`
- `/home/node/.openclaw/workspace/GPTTraderV4/GPTStrategyV4.py`
- `/home/node/.openclaw/workspace/GPTTraderV4/config_freqai_gpttrader_v4.json`
- `/home/node/.openclaw/workspace/GPTTraderV4/GPTTRADER_V4_README.md`

Analysis document:
- `/home/node/.openclaw/workspace/GPTTraderV4/GPTTraderV4-N8N-IMPLEMENTATION-ANALYSIS.md`
