# PROMPT: EXAMPLE_KB

> Example PROMPT for Dev Loop — Building a Knowledge Base

---

## Goal

Create a complete Redis KB domain with quick-reference, concepts, and patterns following the KB architecture standards.

---

## Quality Tier

**Tier:** production

---

## Context

- KB is organized hierarchically: `.claude/kb/{category}/{subcategory}/{domain}/`
- Must follow structure: index.md, quick-reference.md, .metadata.json, concepts/, patterns/
- Registry is at `.claude/kb/_index.yaml`
- See existing KB: `.claude/kb/ai-ml/validation/pydantic/` for reference
- See category index: `.claude/kb/README.md` for navigation
- Redis would go under: `.claude/kb/data-engineering/caching/redis/`

---

## Tasks (Prioritized)

### 🔴 RISKY (Do First)

- [ ] Validate KB structure requirements by reading `.claude/kb/_index.yaml`
- [ ] Check if Redis domain already exists: Verify: `ls .claude/kb/data-engineering/caching/redis/ 2>/dev/null || echo "Domain not found"`
- [ ] Ensure parent category exists: Verify: `ls .claude/kb/data-engineering/ 2>/dev/null || echo "Category not found"`

### 🟡 CORE

- [ ] @kb-architect: Create Redis KB domain structure at `data-engineering/caching/redis/`
- [ ] Create index.md (overview and getting started)
- [ ] Create quick-reference.md (max 100 lines): Verify: `wc -l .claude/kb/data-engineering/caching/redis/quick-reference.md | awk '{print ($1 <= 100) ? "OK" : "TOO_LONG"}'`
- [ ] Create .metadata.json with technology metadata
- [ ] Create concepts/data-structures.md: Verify: `ls .claude/kb/data-engineering/caching/redis/concepts/data-structures.md`
- [ ] Create concepts/persistence.md: Verify: `ls .claude/kb/data-engineering/caching/redis/concepts/persistence.md`
- [ ] Create patterns/caching.md: Verify: `ls .claude/kb/data-engineering/caching/redis/patterns/caching.md`

### 🟢 POLISH (Do Last)

- [ ] Update `.claude/kb/_index.yaml` with Redis domain
- [ ] Update `.claude/kb/data-engineering/README.md` with Redis reference
- [ ] @code-reviewer: Review KB structure for completeness

---

## Exit Criteria

- [ ] Domain folder exists: `ls -la .claude/kb/data-engineering/caching/redis/`
- [ ] Quick reference exists: `ls .claude/kb/data-engineering/caching/redis/quick-reference.md`
- [ ] At least 2 concepts: `ls .claude/kb/data-engineering/caching/redis/concepts/ | wc -l | awk '{print ($1 >= 2) ? "OK" : "NEED_MORE"}'`
- [ ] At least 1 pattern: `ls .claude/kb/data-engineering/caching/redis/patterns/ | wc -l | awk '{print ($1 >= 1) ? "OK" : "NEED_MORE"}'`
- [ ] Registered in index: `grep -q "redis" .claude/kb/_index.yaml && echo "OK" || echo "NOT_REGISTERED"`

---

## Progress

**Status:** NOT_STARTED

| Iteration | Timestamp | Task Completed | Key Decision | Files Changed |
|-----------|-----------|----------------|--------------|---------------|
| - | - | - | - | - |

---

## Config

```yaml
mode: hitl
quality_tier: production
max_iterations: 15
max_retries: 3
circuit_breaker: 3
small_steps: true
feedback_loops:
  - ls .claude/kb/data-engineering/caching/redis/
```

---

## Notes

This is an example PROMPT file demonstrating how to build a KB domain using Dev Loop.
Copy this file to `.claude/dev/tasks/` and customize it for your use case.

**KB categories:** data-engineering, ai-ml, cloud, devops-sre, automation, document-processing

---

## References

- [KB Master Index](.claude/kb/README.md)
- [KB Architecture](.claude/kb/_index.yaml)
- [Example KB: Pydantic](.claude/kb/ai-ml/validation/pydantic/)
- [Category READMEs](.claude/kb/data-engineering/README.md)
