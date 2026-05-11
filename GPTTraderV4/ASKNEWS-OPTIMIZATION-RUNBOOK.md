# AskNews Optimization Runbook

## 1. Scope

This document is a practical optimization guide for using AskNews efficiently in an LLM workflow such as GPTTraderV4 or an n8n decision pipeline.

It focuses on:
- request cost optimization
- token optimization
- prompt optimization
- workflow design choices
- reliability and troubleshooting patterns
- how to measure whether the integration is actually working

## 2. Sources reviewed

### Official docs reviewed
- AskNews documentation home
- News endpoint docs
- Web Search docs
- Rate Limiting / pricing docs
- DeepNews docs
- Chat docs
- Sources docs
- AutoFilter docs
- Analytics docs
- Alerts docs

### Discord channels reviewed from the AskNews server in `openclaw-sandbox-browser-2`
Reviewed visible and relevant material from:
- `#announcements`
- `#roadmap`
- `#🦜-general`
- `#🔄-feedback`
- `#📈-finance-news-api`
- `#📡-coverage-requests`
- `#🫴🏽-prompting-tips`
- `#🤖-chat-with-the-news`

Important note:
- this is a practical review of the relevant visible docs/channels and visible solved support items
- it is not a byte-for-byte export of the entire Discord history

---

## 3. What AskNews is best at

AskNews is strongest as a **retrieval and context-engineering layer**, not as a standalone guarantee of correct final answers.

Its strengths are:
- licensed news coverage
- prompt-optimized retrieval output
- structured metadata in dict form
- X/Twitter firehose access through web search
- filterable source/date/category controls
- optional higher-level agents like DeepNews

For an LLM workflow, the sweet spot is:

**AskNews = data and retrieval substrate**

not:

**AskNews = your full decision logic**

---

## 4. Endpoint selection strategy

This is the first major optimization lever.

## 4.1 Use `/news` as the default retrieval endpoint

Use `/news` when you need:
- recent news
- low latency
- low request cost
- structured metadata or prompt-ready context

Why:
- docs indicate `/news` (last 48h) costs **1 request**
- it returns either:
  - `as_string` = prompt-optimized string
  - `as_dicts` = structured metadata
  - or both

This should be the default for most event-driven trading or monitoring flows.

## 4.2 Use `/websearch` selectively, not by default

Use `/websearch` when you need:
- X/Twitter firehose
- open web sources beyond AskNews indexed news
- domain-restricted search

Why to be careful:
- docs indicate `/websearch` costs **5 requests**
- it is much more expensive than `/news`

Best practice:
- only call `/websearch` when a pair/topic is in a high-interest state
- do not run it for every pair on every cycle

## 4.3 Use `/deepnews` only for complex analytical questions

Use `DeepNews` when you need:
- iterative research
- planning/reflection
- multi-hop contextual explanation
- investigation or report generation

Do **not** use DeepNews for every polling cycle.

Why:
- it is heavier
- it introduces more token cost
- it is better suited to “investigate this” than “classify this short feed cheaply”

## 4.4 Use `AutoFilter` when manual filtering becomes messy

Use `AutoFilter` when you have complex targeting like:
- include finance and banking
- exclude Brexit
- limit geography/language/source types

This is good because:
- you can generate the filter once
- then reuse it across `/news`, `/graph`, `/chat`, `/forecast`

That reduces prompt complexity and keeps retrieval more consistent.

---

## 5. Cost optimization

## 5.1 Optimize request cost first

Most people jump to token cost first.
For AskNews, request cost can become a bigger problem earlier.

From docs:
- `/news (last 48 hours)` = 1 request
- `/news (archive)` = 5 requests
- `/websearch` = 5 requests
- `/graph` = 15 requests
- `/autofilter` = 3 requests
- `/chat fast` and `/chat rich` are token-metered

### Rule of thumb
- use `/news` whenever possible
- upgrade to `/websearch` only when social/X really matters
- use `/graph` only on demand, not in the hot loop
- use `AutoFilter` only when manual filtering is actually too weak

## 5.2 Query less often by using checkpoints

Do not repeatedly ask for the same time window.

Persist:
- last news timestamp per pair/topic
- last tweet timestamp per pair/topic
- last content hash

Then only fetch increments.

This is one of the biggest practical cost savers.

## 5.3 Don’t run every endpoint for every pair

Tier pairs by importance.

Example:
- Tier A pairs: news + websearch
- Tier B pairs: news only
- Tier C pairs: alerts-only or lower-frequency polling

## 5.4 Separate collection frequency from analysis frequency

Example:
- collect news every 5 min
- run expensive decision analysis every 15–30 min
- trigger immediate analysis only if fresh content has high impact

This reduces both AskNews calls and LLM tokens.

## 5.5 Use the right plan, not the biggest plan

Discord `#feedback` suggests a recurring misunderstanding:
- users think they need full high-tier access for all use cases
- team response indicated this depends on what endpoints you actually need

Practical takeaway:
- if you mostly need lower-cost data access or token-metered news chat, do not overbuy prematurely
- choose the plan that matches your endpoint mix

---

## 6. Token optimization

## 6.1 Prefer `as_dicts` internally

For machine pipelines, `as_dicts` should usually be your internal canonical format.

Why:
- less brittle than raw prompt strings
- easier to store
- easier to dedupe
- easier to compute deterministic metadata

## 6.2 Render prompt text only for the final LLM step

Good pattern:
1. AskNews returns `as_dicts`
2. your workflow computes:
   - age_minutes
   - engagement_total
   - recency_factor
   - filters/dedup
3. only then build a compact prompt or markdown context

This saves tokens and keeps prompt quality high.

## 6.3 Use `as_string` when you want quickest direct injection

AskNews docs explicitly provide `as_string` as a prompt-optimized object.

Use it when:
- you want quick prototyping
- you want to inject context directly into an LLM
- you don’t need heavy custom preprocessing

Avoid using `as_string` as your only storage layer.

## 6.4 Limit context aggressively

Do not pass every item to the model.

Good defaults:
- top 5–10 news items
- top 5–10 social items
- sorted by recency and impact

If you give the model 50 mediocre items, you pay more and usually get worse focus.

## 6.5 Use deterministic pre-scoring outside the prompt

Before the LLM step, calculate:
- recency buckets
- tweet engagement totals
- zero-engagement rule
- high-priority source flags

Then let the model do the semantic part only.

This reduces token usage because the prompt no longer needs to explain every formula in full detail every time.

## 6.6 Use smaller models for narrow classification tasks

If the task is just:
- classify article impact
- detect speculation vs real event
- produce short rationale

then use a cheaper/smaller model first.

Reserve larger models for:
- synthesis across many items
- deep reports
- strategic forecasts

---

## 7. Prompt optimization

## 7.1 AskNews is strongest when you ask narrow questions

Bad prompt shape:
- “tell me everything important about crypto today”

Better prompt shape:
- “for BTC in the last 2 hours, identify concrete events that are likely to move price, and ignore speculation or recycled commentary”

The narrower the task, the better the retrieval-to-token ratio.

## 7.2 Separate retrieval prompt from decision prompt

Do not make one giant prompt that does:
- retrieval instructions
- filtering instructions
- scoring instructions
- execution rules
- report formatting

Better pattern:
- retrieval controlled by AskNews query/filter params
- decision prompt only consumes curated results

## 7.3 Use system prompts for policy, user prompts for context

System prompt should define:
- what counts as real event vs speculation
- what output schema is required
- what safety/risk constraints apply

User prompt should provide:
- current pair/topic
- selected content items
- deterministic metrics
- exact question

## 7.4 Turn on journalistic integrity features when using AskNews chat/deepnews for reports

Docs for Chat/DeepNews mention `journalist_mode`.

Use `journalist_mode = true` when you want:
- stronger evidence-grounding
- better citation behavior
- more disciplined reporting style

Turn it off only if:
- you have your own prompt layer and citation logic
- you want maximum custom control

## 7.5 Don’t over-explain formulas in every prompt

For repeated operational tasks, do not keep sending long educational prompt blocks.

Better:
- hard-code formulas in workflow/code
- prompt the model with already-computed fields

This lowers token cost and improves consistency.

---

## 8. Retrieval optimization

## 8.1 Use `string_guarantee` and exclusion filters intentionally

If you know the exact entity/topic you care about, enforce it.

Why:
- less off-topic retrieval
- lower downstream token waste

Use:
- `string_guarantee`
- `reverse_string_guarantee`
- source/domain filters
- category filters
- language filters

## 8.2 Reuse filter objects across endpoints

Docs for `AutoFilter` make this explicit.

If you build a good filter once, reuse it across:
- `/news`
- `/graph`
- `/chat`
- `/forecast`

This keeps context consistent and reduces human prompt tinkering.

## 8.3 Use `sources` endpoint to audit coverage quality

Do not assume coverage quality blindly.

Use the `sources` endpoint to inspect:
- source diversity
- publisher mix
- whether your topic is dominated by weak sources

This is especially important for finance and geopolitics.

## 8.4 Use language controls carefully

Discord `#coverage-requests` shows AskNews adds languages only after QA/QC confidence.

Practical takeaway:
- if you rely on multilingual coverage, inspect language quality explicitly
- do not mix multilingual feeds into a critical trading flow without testing retrieval quality first

---

## 9. Workflow optimization patterns

## 9.1 Best pattern for a trading/event pipeline

Recommended flow:
1. AskNews `/news` for baseline signal
2. if baseline signal is interesting, call `/websearch` for X/open-web confirmation
3. if still ambiguous and high value, call LLM or DeepNews
4. if strong enough, route to execution or analyst review

This staged escalation is cheaper than calling everything every cycle.

## 9.2 Use alerts for sparse-event workflows

If your use case is “tell me when X happens,” consider AskNews Alerts instead of continuous polling.

This can be much cheaper operationally.

## 9.3 Archive raw AskNews responses

Store:
- raw provider response
- normalized content
- decision prompt
- model output

Without this, you cannot debug why a bad decision happened.

---

## 10. Solved issues and support patterns seen in Discord

## 10.1 Free-account / model-selection issue

In `#🫴🏽-prompting-tips`, a visible solved issue showed:
- a user hit repeated errors
- AskNews staff suggested selecting the open model for free accounts
- staff also mentioned a backend flag fix was applied

Operational takeaway:
- some failures may be account-tier or model-selection mismatches, not query bugs

## 10.2 Chat/page error troubleshooting pattern

In `#🔄-feedback`, a visible support thread showed this pattern:
- clarify whether error happens on page load or chat action
- identify which model is being used
- reproduce on another account or role
- backend-side fix applied and issue resolved

Operational takeaway:
- capture:
  - endpoint
  - model
  - account tier
  - whether failure is UI-only or request-time

## 10.3 Pricing misunderstanding pattern

Also in `#🔄-feedback`, a user confused plan pricing with token usage.
Team response pointed to rate-limit/pricing docs and clarified that some workloads are token-metered and some are endpoint-limited.

Operational takeaway:
- model cost, request cost, and plan tier are separate levers
- track them separately in your own cost dashboard

## 10.4 Coverage is QA/QC-gated

In `#📡-coverage-requests`, AskNews staff explicitly described new language coverage as being gated by QA/QC.

Operational takeaway:
- do not treat “coverage request accepted” as equivalent to “production-grade retrieval quality already proven”

---

## 11. How to optimize AskNews specifically for GPTTraderV4-style systems

## 11.1 Use `/news` as the baseline signal bus

For every pair:
- first poll `/news`
- keep query narrow with project name + ticker + market framing
- dedupe and checkpoint results

## 11.2 Only call `/websearch` for X when needed

Good triggers:
- strong but ambiguous news
- rumor-driven pair
- high-volatility event
- confirmation needed from social reaction

Do not call X firehose for every quiet cycle.

## 11.3 Don’t let AskNews perform all reasoning

AskNews gives you excellent retrieval.
Your workflow should still own:
- recency scoring
- engagement scoring
- confidence thresholds
- action gating
- slippage/risk controls

## 11.4 Run DeepNews only for strategic review, not hot-loop execution

Use DeepNews for:
- end-of-day report
- why-did-this-move investigation
- research notes
- risk briefings

Not for every 5-minute trading decision.

---

## 12. Metrics you should track

If you want to know whether AskNews is helping, track these.

## 12.1 Retrieval metrics
- requests per endpoint per day
- hit rate with fresh results
- duplicate result rate
- average items returned per query
- source diversity per topic

## 12.2 Token metrics
- average prompt size before LLM
- average prompt size after pruning
- model cost per decision
- percent of cycles that skipped LLM due to no fresh content

## 12.3 Quality metrics
- precision of relevant articles in sampled runs
- percent of speculative/noise items that slip through
- analyst override rate
- false positive decision rate

## 12.4 Outcome metrics
- decision win rate
- pnl by source mix:
  - news only
  - news + websearch
  - deepnews-assisted
- latency from publication to decision
- cost per profitable decision

---

## 13. Recommended implementation posture

## For MVP
- `/news`
- `as_dicts`
- deterministic preprocessing
- small/medium model for classification
- no DeepNews in hot path

## For richer version
- conditional `/websearch`
- source diversity audits
- alerts for event-driven triggers
- DeepNews for analyst-grade post-analysis

## For production
- full persistence
- cost dashboards
- prompt versioning
- retrieval A/B testing
- explicit fallback behavior on rate limit or empty result

---

## 14. Final recommendations

1. Treat AskNews as your **retrieval and context layer**, not your final arbiter.
2. Default to `/news`; escalate to `/websearch` and `DeepNews` only when justified.
3. Keep `as_dicts` as your internal source of truth.
4. Build deterministic scoring outside the model.
5. Version prompts and log all decisions.
6. Watch request cost and token cost separately.
7. Test coverage quality by topic/language, not just globally.
8. Use Discord support patterns as operational hints, not as formal guarantees.

---

## 15. Local files related to this study

- `/home/node/.openclaw/workspace/GPTTraderV4/GPTTraderV4-N8N-IMPLEMENTATION-ANALYSIS.md`
- `/home/node/.openclaw/workspace/GPTTraderV4/GPTTraderV4-N8N-WORKFLOW-DESIGN.md`
- `/home/node/.openclaw/workspace/GPTTraderV4/GPTTraderV4-DATA-BLUEPRINT.md`
- `/home/node/.openclaw/workspace/GPTTraderV4/ASKNEWS-OPTIMIZATION-RUNBOOK.md`
