# AskNews Guardrails Checklist for n8n

Use this checklist when building AskNews into n8n workflows, especially for GPTTraderV4-style event pipelines.

---

## 1. Account / Tier Guardrails

### Required
- [ ] Record which AskNews account / credential is used per workflow
- [ ] Record the expected tier/plan for that credential
- [ ] Map which endpoints are allowed for that tier:
  - [ ] `/news`
  - [ ] `/websearch`
  - [ ] `/deepnews`
  - [ ] `/chat`
  - [ ] `/graph`
- [ ] Do not assume every credential can use every model or endpoint

### Recommended
- [ ] Store `account_tier` in config
- [ ] Store `allowed_endpoints[]` in config
- [ ] Store `allowed_models[]` in config
- [ ] Add a preflight check before production runs

### Failure policy
- [ ] If endpoint is not allowed for current tier, fail fast with explicit error
- [ ] If model is not allowed, use configured fallback model
- [ ] If account is free/limited, route only to supported model path

---

## 2. Model Selection Guardrails

### Required
- [ ] Define a primary model for AskNews-powered chat/analysis
- [ ] Define at least one fallback model
- [ ] Keep model selection separate from prompt logic

### Recommended
- [ ] Use smaller/cheaper model for classification steps
- [ ] Use stronger model only for synthesis or high-value decisions
- [ ] Log selected model on every run

### Failure policy
- [ ] If primary model fails due to tier or backend restriction, retry with fallback
- [ ] If fallback also fails, stop and mark run as `model_unavailable`
- [ ] Do not continue with silent degraded behavior

---

## 3. Endpoint Guardrails

### AskNews `/news`
- [ ] Use as default baseline retrieval path
- [ ] Use checkpoint-based incremental fetches
- [ ] Deduplicate results before passing to the LLM

### AskNews `/websearch`
- [ ] Treat as optional escalation path
- [ ] Do not run it by default for every pair/topic
- [ ] Only call it when:
  - [ ] high-interest event detected
  - [ ] social confirmation needed
  - [ ] rumor-sensitive topic

### AskNews `/deepnews`
- [ ] Do not use in hot polling loops
- [ ] Reserve for:
  - [ ] post-event investigation
  - [ ] analyst report
  - [ ] high-value synthesis

### General
- [ ] Keep endpoint usage policy documented per workflow
- [ ] Track request count by endpoint separately

---

## 4. Logging Guardrails

### Required fields for every AskNews call
- [ ] workflow name
- [ ] pair/topic
- [ ] endpoint used
- [ ] timestamp
- [ ] account/credential id
- [ ] account tier
- [ ] model used (if model involved)
- [ ] success/failure status
- [ ] response latency
- [ ] request cost category

### Error logging
- [ ] Distinguish `load/init error` vs `request/chat error`
- [ ] Store raw error text
- [ ] Store retry count
- [ ] Store whether fallback was attempted

### Recommended
- [ ] Log normalized request payload
- [ ] Log normalized response summary
- [ ] Log dedupe counts
- [ ] Log “no fresh content” as a normal outcome, not as an error

---

## 5. Coverage / Language Guardrails

### Required
- [ ] Do not assume all languages or domains are equally mature
- [ ] Validate coverage quality per topic/language before live use
- [ ] Keep `language` and `source diversity` visible in QA samples

### Recommended
- [ ] Test each target language separately
- [ ] Sample retrieval quality manually before production
- [ ] Use `sources`/coverage inspection where relevant
- [ ] Maintain a whitelist of trusted topic/source profiles

### Failure policy
- [ ] If coverage quality is uncertain, downgrade to analysis-only mode
- [ ] If source diversity is weak, do not let the pipeline act with high confidence
- [ ] If a new language/domain is unvalidated, block live execution for it

---

## 6. Prompt Guardrails

### Required
- [ ] Keep prompt policy separate from retrieval policy
- [ ] Do not embed large retrieval instructions in every prompt
- [ ] Prefer structured context over raw dumps

### Recommended
- [ ] Precompute deterministic fields before prompting:
  - [ ] age_minutes
  - [ ] recency_factor
  - [ ] engagement_total
  - [ ] source type
  - [ ] source credibility flags
- [ ] Keep prompt focused on semantic interpretation and final action
- [ ] Version prompts explicitly

### Failure policy
- [ ] If prompt output fails schema validation, force `NEUTRAL`
- [ ] If the response is malformed, retry once with smaller context
- [ ] If still malformed, stop and log `schema_failure`

---

## 7. Token Cost Guardrails

### Required
- [ ] Track prompt token size before inference
- [ ] Track average items sent to the model
- [ ] Limit context size aggressively

### Recommended
- [ ] Use `as_dicts` internally
- [ ] Render markdown only for final prompt step if needed
- [ ] Do not pass all retrieved items to the model
- [ ] Cap top-K items by recency and impact

### Failure policy
- [ ] If context is too large, prune oldest/lowest-impact items first
- [ ] If token budget would be exceeded, skip low-priority branches like `/websearch`

---

## 8. Decision Guardrails

### Required
- [ ] Validate model output schema
- [ ] Validate score ranges
- [ ] Validate action enum

### Recommended
- [ ] Require minimum confidence threshold
- [ ] Require minimum heat threshold
- [ ] Require minimum content count for actionability
- [ ] Require stronger evidence for live execution than for analysis-only mode

### Failure policy
- [ ] If confidence too low -> `NEUTRAL`
- [ ] If only low-quality/noisy content -> `NEUTRAL`
- [ ] If fresh content exists but is contradictory -> `NEUTRAL` or analyst review

---

## 9. Execution Guardrails

### Required
- [ ] Keep AskNews retrieval separate from order execution
- [ ] Require a validated decision object before any trade action
- [ ] Enforce slippage/risk checks outside the prompt

### Recommended
- [ ] Add cooldown after position reversal
- [ ] Add max decisions per pair per hour
- [ ] Add optional human approval for live mode

### Failure policy
- [ ] If AskNews retrieval fails, do not reuse stale data silently for execution
- [ ] If execution checks fail, log decision but do not place order

---

## 10. Fallback Guardrails

### Retrieval fallback
- [ ] If `/websearch` fails, continue with `/news`-only mode if acceptable
- [ ] If `/news` fails, stop decisioning unless another trusted baseline exists

### Model fallback
- [ ] If preferred model unavailable, use configured backup
- [ ] Mark decision quality as downgraded when fallback model is used

### Coverage fallback
- [ ] If topic/language coverage is weak, route to analyst review or skip

---

## 11. QA / Rollout Guardrails

### Stage 1 — Analysis only
- [ ] no live execution
- [ ] log all retrievals
- [ ] inspect sample decisions manually

### Stage 2 — Paper mode
- [ ] simulated positions only
- [ ] compare decisions against market outcomes
- [ ] measure cost per useful signal

### Stage 3 — Live mode
- [ ] only after retrieval precision is validated
- [ ] only after model fallback path is tested
- [ ] only after tier/endpoint assumptions are verified

---

## 12. Minimum Config Fields to Add

```json
{
  "asknews": {
    "account_tier": "spelunker",
    "allowed_endpoints": ["news", "websearch"],
    "allowed_models": ["open-model-a", "open-model-b"],
    "primary_model": "open-model-a",
    "fallback_model": "open-model-b",
    "news_enabled": true,
    "websearch_enabled": false,
    "deepnews_enabled": false,
    "confidence_threshold": 0.55,
    "heat_threshold": 0.6,
    "max_context_items": 10,
    "analysis_mode": "paper"
  }
}
```

---

## 13. Minimal “Go / No-Go” Checklist

Before enabling production-like use:
- [ ] `/news` path works reliably
- [ ] model/tier mismatch behavior tested
- [ ] fallback model tested
- [ ] logging captures endpoint + model + tier + error type
- [ ] language/topic coverage validated
- [ ] prompt schema validation tested
- [ ] context pruning tested
- [ ] neutral fallback behavior tested
- [ ] live execution still disabled until paper results are acceptable

---

## 14. Practical Summary

If reduced to essentials, the AskNews guardrails are:

1. know your tier
2. know your allowed models/endpoints
3. make `/news` your baseline
4. only escalate when needed
5. log enough to debug fast
6. validate coverage before trusting it
7. keep deterministic logic outside the model
8. fail safe to `NEUTRAL`
