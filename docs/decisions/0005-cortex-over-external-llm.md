# 0005 — AI features run on Snowflake Cortex, not an external LLM

**Status:** accepted 2026-04-14.

## Context

The dashboard needed a natural-language analyst (text-to-SQL); narratives and forecasts followed.

## Decision

Snowflake Cortex only — Cortex Analyst over a semantic view, the Cortex LLM functions, Cortex ML —
because **the client will not provide external LLM API keys**. Everything bills as Snowflake credits,
with no external access integration or secret to manage.

## Alternatives rejected

- An external LLM API with a custom agent — the best reasoning, blocked by the API key.
- A hybrid of Cortex and an external LLM — the same blocker.
- An external vector database — unnecessary; Cortex Search covers retrieval.

## Consequences

- Only models Cortex serves in us-east-1: `gemini-2-5-flash` returns 400 here, so the narratives use
  `llama3.1-70b`.
- What was built on it: `../architecture/ai-features.md`; the analyst app:
  `../../streamlit_analyst/AGENTS.md`.
