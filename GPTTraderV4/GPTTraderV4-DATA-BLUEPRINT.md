# GPTTraderV4 — JSON / Data Store / Schema Blueprint

## 1. Goal

This blueprint defines the persistent data model required to build GPTTraderV4 cleanly in n8n.

Use this whether storage is:
- Postgres
- Supabase/Postgres
- SQLite for prototype
- n8n Data Store for very small MVPs

Recommendation:
- use **Postgres** if this is expected to run continuously

---

## 2. Storage layers

## Layer A — Configuration
Low-churn settings.

## Layer B — Runtime state
Mutable pair state and checkpoints.

## Layer C — Event log
Immutable-ish content, decisions, executions.

---

## 3. Core tables / collections

1. `pair_registry`
2. `source_checkpoint`
3. `content_items`
4. `position_state`
5. `decision_log`
6. `execution_log`
7. `prompt_registry`
8. `workflow_run_log`

Optional:
9. `content_item_analysis`
10. `provider_health_log`

## 3.1 AskNews `/news` mapping in this blueprint

These blueprint parts should use **AskNews `/news`** directly:

1. **Primary article ingestion**
   - all baseline news collection for GPTTraderV4-style workflows

2. **`source_checkpoint.last_news_timestamp`**
   - used to incrementally refresh `/news` results

3. **`content_items` rows where `source_type = news`**
   - these should come from AskNews `/news`

4. **Entry/exit context baseline**
   - the default decision context should be built from `/news` before any `/websearch` escalation

5. **Analysis-only MVP**
   - the first implementation stage should be functional using `/news` without requiring social/open-web enrichment

---

## 4. Table: `pair_registry`

## Purpose
Master configuration for each tradable pair.

## Fields
```json
{
  "pair": "BTC/USDT:USDT",
  "symbol": "BTC",
  "project_name": "Bitcoin",
  "enabled": true,
  "exchange": "bybit",
  "market_type": "futures",
  "timeframe": "30m",
  "use_news": true,
  "use_twitter": false,
  "news_hours": 6,
  "tweet_minutes": 30,
  "news_count": 10,
  "tweet_count": 10,
  "target_profit": 0.03,
  "stoploss": 0.04,
  "target_duration": 1000,
  "llm_provider": "openai",
  "llm_model": "gpt-5",
  "analysis_mode": "paper",
  "max_position_notional": 200,
  "max_open_trades": 5,
  "confidence_threshold": 0.55,
  "heat_threshold": 0.6,
  "sentiment_long_threshold": 0.4,
  "sentiment_short_threshold": -0.4,
  "created_at": "2026-05-10T00:00:00Z",
  "updated_at": "2026-05-10T00:00:00Z"
}
```

## Constraints
- primary key: `pair`

---

## 5. Table: `source_checkpoint`

## Purpose
Tracks incremental fetch boundaries.

## Fields
```json
{
  "pair": "BTC/USDT:USDT",
  "last_news_timestamp": "2026-05-10T11:55:00Z",
  "last_tweet_timestamp": "2026-05-10T11:58:00Z",
  "last_news_hash": "optional-last-id-or-hash",
  "last_tweet_hash": "optional-last-id-or-hash",
  "last_run_at": "2026-05-10T12:00:00Z",
  "last_decision_action": "NEUTRAL",
  "updated_at": "2026-05-10T12:00:00Z"
}
```

Meaning:
- `last_news_timestamp` is specifically the incremental checkpoint for **AskNews `/news`**
- `last_tweet_timestamp` is the incremental checkpoint for the optional social branch, e.g. **AskNews `/websearch`**

## Constraints
- primary key: `pair`
- foreign key: `pair_registry.pair`

---

## 6. Table: `content_items`

## Purpose
Normalized content archive for both news and tweets.

## Fields
```json
{
  "id": "uuid",
  "pair": "BTC/USDT:USDT",
  "source_type": "news",
  "provider": "asknews",
  "provider_item_id": "asknews-12345",
  "published_at": "2026-05-10T11:40:00Z",
  "collected_at": "2026-05-10T12:00:01Z",
  "title": "Bitcoin reaches new all-time high",
  "body": "Full summary or content text",
  "source_name": "FinanzNachrichten.de",
  "source_url": "https://...",
  "classification": "Finance",
  "continent": "North America",
  "reporting_voice": "Investigative",
  "external_sentiment": 1.0,
  "retweets": 0,
  "likes": 0,
  "replies": 0,
  "quotes": 0,
  "engagement_total": 0,
  "age_minutes": 20,
  "recency_factor": 0.8,
  "deterministic_impact_floor": 0.7,
  "canonical_hash": "sha256...",
  "raw_payload_json": {},
  "created_at": "2026-05-10T12:00:01Z"
}
```

Source rules:
- `source_type = news` -> origin should be **AskNews `/news`**
- `source_type = tweet` -> origin should be **AskNews `/websearch`**
- keep both sources distinguishable at the schema level

## Constraints
- primary key: `id`
- unique recommended:
  - `(provider, provider_item_id)` when provider_item_id exists
  - else `canonical_hash`
- index:
  - `(pair, published_at desc)`
  - `(source_type, published_at desc)`

---

## 7. Table: `position_state`

## Purpose
Current position status per pair.

## Fields
```json
{
  "pair": "BTC/USDT:USDT",
  "status": "OPEN",
  "side": "LONG",
  "entry_price": 104250.5,
  "entry_time": "2026-05-10T10:30:00Z",
  "quantity": 0.015,
  "notional": 1563.76,
  "exchange_position_id": "abc123",
  "current_profit_ratio": 0.0125,
  "duration_candles": 3,
  "decision_id": "uuid-of-decision-that-opened-position",
  "updated_at": "2026-05-10T12:00:00Z"
}
```

## Constraints
- primary key: `pair`
- foreign key: `pair_registry.pair`

---

## 8. Table: `decision_log`

## Purpose
Audit trail of every model decision.

## Fields
```json
{
  "id": "uuid",
  "pair": "BTC/USDT:USDT",
  "mode": "entry",
  "prompt_version": "gpttrader-v4-n8n-r1",
  "llm_provider": "openai",
  "llm_model": "gpt-5",
  "input_item_count": 8,
  "avg_sentiment": 0.56,
  "avg_heat": 0.68,
  "confidence": 0.72,
  "action": "LONG_ENTER",
  "summary": "Positive high-heat ETF and accumulation news outweigh neutral social noise.",
  "validated": true,
  "validation_notes": "passed",
  "raw_request_json": {},
  "raw_response_json": {},
  "normalized_response_json": {},
  "created_at": "2026-05-10T12:00:05Z"
}
```

## Constraints
- primary key: `id`
- index:
  - `(pair, created_at desc)`
  - `(action, created_at desc)`

---

## 9. Table: `content_item_analysis`

## Purpose
Optional per-item breakdown from the model.
Useful for explainability.

## Fields
```json
{
  "id": "uuid",
  "decision_id": "uuid",
  "content_item_id": "uuid",
  "semantic_sentiment": 0.8,
  "adjusted_sentiment": 0.62,
  "heat_score": 0.77,
  "content_type": "REAL_ACTION",
  "rationale": "Actual ETF filing with immediate market relevance.",
  "created_at": "2026-05-10T12:00:05Z"
}
```

## Constraints
- primary key: `id`
- foreign keys:
  - `decision_log.id`
  - `content_items.id`

---

## 10. Table: `execution_log`

## Purpose
Tracks order attempts and outcomes.

## Fields
```json
{
  "id": "uuid",
  "decision_id": "uuid",
  "pair": "BTC/USDT:USDT",
  "action": "LONG_ENTER",
  "execution_mode": "paper",
  "requested_price": 104250.5,
  "reference_last_close": 104180.0,
  "slippage_check_passed": true,
  "order_status": "FILLED",
  "exchange_order_id": "xyz456",
  "request_json": {},
  "response_json": {},
  "error_text": null,
  "created_at": "2026-05-10T12:00:08Z"
}
```

## Constraints
- primary key: `id`
- index:
  - `(pair, created_at desc)`
  - `(decision_id)`

---

## 11. Table: `prompt_registry`

## Purpose
Version control for prompts.

## Fields
```json
{
  "version": "gpttrader-v4-n8n-r1",
  "system_prompt": "...",
  "entry_prompt_template": "...",
  "exit_prompt_template": "...",
  "schema_version": "decision-schema-v1",
  "active": true,
  "created_at": "2026-05-10T00:00:00Z"
}
```

## Constraints
- primary key: `version`

---

## 12. Table: `workflow_run_log`

## Purpose
Operational telemetry.

## Fields
```json
{
  "id": "uuid",
  "workflow_name": "WF-01 Pair Scheduler",
  "pair": "BTC/USDT:USDT",
  "status": "SUCCESS",
  "started_at": "2026-05-10T12:00:00Z",
  "finished_at": "2026-05-10T12:00:08Z",
  "duration_ms": 8123,
  "error_text": null,
  "meta_json": {}
}
```

## Constraints
- primary key: `id`

---

## 13. JSON schemas for workflow payloads

## 13.1 Pair runtime payload
```json
{
  "pair": "BTC/USDT:USDT",
  "symbol": "BTC",
  "project_name": "Bitcoin",
  "config": {
    "use_news": true,
    "use_twitter": false,
    "news_hours": 6,
    "tweet_minutes": 30,
    "news_count": 10,
    "tweet_count": 10,
    "target_profit": 0.03,
    "stoploss": 0.04,
    "target_duration": 1000,
    "confidence_threshold": 0.55,
    "heat_threshold": 0.6
  },
  "checkpoint": {
    "last_news_timestamp": "2026-05-10T11:55:00Z",
    "last_tweet_timestamp": "2026-05-10T11:58:00Z"
  },
  "position": {
    "status": "OPEN",
    "side": "LONG",
    "entry_price": 104250.5,
    "current_profit_ratio": 0.0125,
    "duration_candles": 3
  }
}
```

Interpretation:
- `use_news = true` means the workflow should call **AskNews `/news`** as the baseline retrieval step
- `use_twitter = true` means the workflow may additionally call **AskNews `/websearch`**

## 13.2 Normalized content item
```json
{
  "content_item_id": "uuid",
  "pair": "BTC/USDT:USDT",
  "source_type": "tweet",
  "published_at": "2026-05-10T11:58:00Z",
  "title": "X post from analyst",
  "content": "$BTC sees strong ETF-driven momentum",
  "source_name": "X",
  "reporting_voice": null,
  "external_sentiment": null,
  "engagement": {
    "retweets": 23,
    "likes": 91,
    "replies": 7,
    "quotes": 5,
    "total": 126
  },
  "derived": {
    "age_minutes": 2,
    "recency_factor": 1.0,
    "deterministic_impact_floor": 1.0
  }
}
```

Recommended normalization policy:
- normalize **AskNews `/news`** responses into this schema first
- treat `/websearch` normalization as a second source adapter
- do not design the schema around `/websearch` first if GPTTraderV4 parity is the goal

## 13.3 LLM decision request
```json
{
  "mode": "entry",
  "pair": "BTC/USDT:USDT",
  "project_name": "Bitcoin",
  "timestamp": "2026-05-10T12:00:05Z",
  "position": null,
  "trade_parameters": {
    "target_profit": 0.03,
    "stoploss": 0.04,
    "target_duration": 1000
  },
  "items": []
}
```

## 13.4 LLM decision response
```json
{
  "item_analysis": [
    {
      "content_item_id": "uuid",
      "semantic_sentiment": 0.8,
      "adjusted_sentiment": 0.62,
      "heat_score": 0.77,
      "content_type": "REAL_ACTION",
      "rationale": "ETF filing is a concrete catalyst."
    }
  ],
  "aggregate": {
    "avg_sentiment": 0.56,
    "avg_heat": 0.68,
    "confidence": 0.72
  },
  "action": "LONG_ENTER",
  "summary": "Positive high-heat hard catalysts support long entry."
}
```

---

## 14. Recommended SQL skeleton

```sql
create table pair_registry (
  pair text primary key,
  symbol text not null,
  project_name text,
  enabled boolean not null default true,
  exchange text not null,
  market_type text not null,
  timeframe text not null,
  use_news boolean not null default true,
  use_twitter boolean not null default false,
  news_hours integer not null default 6,
  tweet_minutes integer not null default 30,
  news_count integer not null default 10,
  tweet_count integer not null default 10,
  target_profit numeric not null,
  stoploss numeric not null,
  target_duration integer not null,
  llm_provider text not null,
  llm_model text not null,
  analysis_mode text not null default 'paper',
  max_position_notional numeric,
  max_open_trades integer,
  confidence_threshold numeric default 0.55,
  heat_threshold numeric default 0.6,
  sentiment_long_threshold numeric default 0.4,
  sentiment_short_threshold numeric default -0.4,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

Add the rest similarly once storage choice is finalized.

---

## 15. MVP storage shortcut

If you want a prototype before full Postgres:

### Use n8n Data Store for
- `pair_registry`
- `source_checkpoint`
- `position_state`

### Use filesystem / JSON for temporary logs
- decision outputs
- raw content snapshots

But this is only acceptable for a small test.
For continuous operation, move to Postgres.

---

## 16. Build priority

Build these first:
1. `pair_registry`
2. `source_checkpoint`
3. `content_items`
4. `decision_log`

These four are enough for analysis-only mode.

Add later:
5. `position_state`
6. `execution_log`
7. `content_item_analysis`

---

## 17. Naming and normalization rules

To avoid confusion, standardize these names:
- use `stoploss`, not `stop_loss`
- use `target_duration`
- use `source_type = news|tweet`
- use `action = LONG_ENTER|SHORT_ENTER|LONG_EXIT|SHORT_EXIT|NEUTRAL`
- use `status = OPEN|CLOSED|NONE`

---

## 18. Final recommendation

For implementation quality:
- Postgres as primary store
- versioned prompts
- structured JSON as internal contract
- deterministic pre-processing before LLM
- full audit log for each decision and order
