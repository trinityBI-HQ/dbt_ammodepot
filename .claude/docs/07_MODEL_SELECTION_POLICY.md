# Section 7: Model Selection Policy

> **Delivery Standards** — trinityBI Engineering
>
> Last updated: 2026-04-02

## Purpose

Ensure every Claude Code task uses the cheapest model that produces correct output. Wrong model selection wastes tokens and budget with no quality gain.

---

## 7.1 Model Tiers

| Model | Speed | Cost | Best For |
|-------|-------|------|----------|
| **Haiku** | Fastest | $ | Read-only lookups, summarization, file inventory, formatting |
| **Sonnet** | Fast | $$ | Implementation, code review, domain expert advice, multi-step reasoning |
| **Opus** | Slower | $$$$ | Architectural decisions, novel trade-off analysis, SDD phases 0-2 |

---

## 7.2 Decision Matrix

### Use Haiku when:

- Reading and summarizing files (no decisions required)
- Extracting structured data from existing files
- File inventory, glob/grep scans, schema dumps
- Git log summaries, diff statistics
- Generating documentation from well-defined code (doc strings, README tables)
- Shipping/archiving completed work (no reasoning, just file operations)

### Use Sonnet when:

- Writing or modifying code (any language)
- Code review with judgment (bugs, security, patterns)
- Answering domain questions that require KB reasoning
- Multi-step tasks that include both reading and writing
- Running tests, interpreting results, and fixing failures
- Implementation from a DESIGN document
- Orchestrating sub-agents

### Use Opus when:

- Choosing architecture: medallion vs Data Vault, Dagster vs Airflow, etc.
- Writing DEFINE or DESIGN phase documents (SDD workflow)
- Novel trade-off analysis where KB + MCP don't have a clear answer
- Strategic planning across multiple systems
- Evaluating new technology for the practice

---

## 7.3 Current Agent Assignments

| Agent | Model | Rationale |
|-------|-------|-----------|
| brainstorm-agent | Opus | Phase 0 — exploratory, high ambiguity |
| define-agent | Opus | Phase 1 — requirements precision matters |
| design-agent | Opus | Phase 2 — architectural decisions |
| medallion-architect | Opus | Architecture guidance, novel trade-offs |
| the-planner | Opus | Strategic multi-system planning |
| dbt-expert | Sonnet | KB-backed implementation with judgment |
| snowflake-expert | Sonnet | Domain advice + SQL generation |
| dagster-expert | Sonnet | Asset design requires multi-step reasoning |
| spark-specialist | Sonnet | Optimization requires iterative analysis |
| lakeflow-architect | Sonnet | Pipeline design with code generation |
| python-developer | Sonnet | Code writing + review |
| code-reviewer | Sonnet | Judgment-based review |
| test-generator | Sonnet | Code generation with pattern matching |
| ci-cd-specialist | Sonnet | Pipeline configuration + code |
| adaptive-explainer | Sonnet | Audience-adaptive reasoning |
| meeting-analyst | Sonnet | Extraction from unstructured input |
| build-agent | Sonnet | Implementation execution |
| iterate-agent | Sonnet | Cross-phase cascade reasoning |
| design-agent | Sonnet | (see Opus above) |
| dev-loop-executor | Sonnet | Multi-step task execution |
| prompt-crafter | Sonnet | Structured requirement elicitation |
| kb-architect | Sonnet | KB creation with MCP validation |
| code-documenter | **Haiku** | Summarization from code — no reasoning |
| codebase-explorer | **Haiku** | File scanning + structured summary |
| ship-agent | **Haiku** | Archival — file ops only |

---

## 7.4 Rules

1. **Default to Sonnet.** Only upgrade to Opus when the task involves novel trade-offs that KB + MCP can't resolve.
2. **Downgrade to Haiku** for any agent whose primary action is reading + summarizing (no code decisions).
3. **Never use Opus** for tasks that have a known pattern in the KB.
4. **When creating a new agent**, assign the model before writing the system prompt — it constrains scope.
5. **Re-evaluate on upgrade.** If an agent is consistently invoked for Haiku-level tasks, downgrade it.

---

## 7.5 Anti-Patterns

❌ Using Opus for "write me a dbt model" — Sonnet + KB is sufficient
❌ Using Sonnet for "summarize this file" — Haiku is faster and cheaper
❌ Mixing model tiers within a single agent (agent prompt should match its model tier's capabilities)
❌ Using Opus as a default because it "feels safer" — it is 8-20× more expensive than Sonnet

---

## 7.6 Revisit Signals

Revisit model assignments when:
- A Sonnet agent is frequently consulted for architecture decisions → consider Opus
- A Sonnet agent is only ever asked to summarize or list → consider Haiku
- New Claude model generations change capability/price ratios
- An agent's scope expands significantly after initial creation

---

*Match the model to the task. Correctness first, cost second, speed third.*
