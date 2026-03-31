---
name: audit
description: Audit .claude/ repository for Claude Code best practices compliance
argument-hint: "[--fix] [--section agents|kb|skills|config]"
---

# Audit Command

> Audit `.claude/` repository structure, agents, KBs, skills, and rules for best practices compliance.

## Usage

```bash
/audit                    # Full audit (report only)
/audit --fix              # Audit + auto-fix all findings
/audit --section agents   # Audit only agents
/audit --section kb       # Audit only knowledge bases
/audit --section skills   # Audit only skills and rules
/audit --section config   # Audit only CLAUDE.md, .claudeignore, memory
```

---

## Audit Checks

Run these checks in parallel using 3 Explore agents:

### Agent 1: Agents Audit

Check ALL files in `.claude/agents/`:

**Frontmatter (P0 if missing):**
- `name:` — kebab-case, matches filename
- `description:` — includes "Use PROACTIVELY when..." trigger
- `description:` — includes at least one `<example>` block with context/user/assistant
- `tools:` — array of valid tools only (valid: Read, Write, Edit, MultiEdit, Bash, Grep, Glob, TodoWrite, WebSearch, WebFetch, and mcp__* patterns)
- `model:` — one of: opus, sonnet, haiku
- `color:` — one of: blue, green, orange, purple, red, yellow, cyan

**Invalid tools to flag (P0):**
- `Task`, `AskUserQuestion`, `AskUser`, `Search` — these don't exist

**Model assignment logic (P1 if wrong):**
- opus: complex reasoning agents (brainstorm, define, design, the-planner)
- sonnet: domain implementation agents (majority)
- haiku: simple/lightweight ops only (ship)

**Optional fields (P2 if missing on domain agents):**
- `memory: user` — should be on agents that benefit from cross-session learning

**Count verification:**
- Total agent count matches CLAUDE.md
- Category counts match CLAUDE.md table

### Agent 2: KB Audit

Check ALL files in `.claude/kb/`:

**File size limits (P0 if violated):**
```
index.md         ≤ 100 lines
quick-reference.md ≤ 100 lines
concepts/*.md    ≤ 150 lines
patterns/*.md    ≤ 200 lines
```

Run: `wc -l` on ALL matching files, report every violation with exact count.

**Required structure (P0 if missing):**
Each technology folder must contain:
- `index.md`
- `quick-reference.md`
- `.metadata.json`
- `concepts/` directory
- `patterns/` directory

**Metadata quality (P1 if incomplete):**
Sample 5+ `.metadata.json` files for required fields:
- technology, category, subcategory, version, primary_use_cases, related_technologies

**Count verification:**
- Run: `find .claude/kb -name "index.md" | wc -l` for actual count
- Compare with CLAUDE.md, kb/README.md, rules/kb-development.md
- Flag ANY count mismatch as P1

**Also run:** `bash scripts/validate_kb_structure.sh`

### Agent 3: Skills, Rules, and Config Audit

**Skills** (`.claude/skills/*/SKILL.md`):
- All must have frontmatter: `name:`, `description:`
- Check `argument-hint:` consistency (P1 if missing when other skills have it)
- Count matches CLAUDE.md

**Rules** (`.claude/rules/*.md`):
- All must have `paths:` frontmatter with valid glob patterns
- Content should be accurate (check counts, references)

**CLAUDE.md accuracy:**
- Cross-check ALL counts: agents, KBs, skills, rules, categories
- Verify Quick Reference table entries exist
- Check date is current month

**.claudeignore completeness (P2):**
- Should cover: dependencies, build artifacts, caches, secrets, IDE, OS files

**Memory files:**
- Proper frontmatter (name, description, type)
- MEMORY.md index exists and links are valid

---

## Output Format

```text
AUDIT REPORT — {date}
━━━━━━━━━━━━━━━━━━━━━

COMPONENT          STATUS    P0   P1   P2
─────────────────  ────────  ───  ───  ───
Agents (43)        ✓ PASS    0    0    0
KB (45)            ⚠ ISSUES  0    1    0
Skills (16)        ✓ PASS    0    0    0
Rules (4)          ✓ PASS    0    0    0
Config             ✓ PASS    0    0    0
─────────────────  ────────  ───  ───  ───
TOTAL                        0    1    0

FINDINGS:
─────────
P1-1: [KB] README.md says "42 technologies" — actual is 45
      File: .claude/kb/README.md:3
      Fix: Update count to 45

SCORE: 98.5% compliance (A)
GRADE: A (95-100%), B (85-94%), C (70-84%), D (<70%)
```

---

## Scoring Formula

Calculate compliance score from total check items and findings:

```text
Total checks = agents + KBs + skills + rules + config items
  agents:  7 checks per agent (name, description, tools, model, color, valid tools, example block)
  KBs:     5 checks per KB (index.md size, qr size, structure, metadata, content)
  skills:  3 checks per skill (name, description, argument-hint)
  rules:   2 checks per rule (paths frontmatter, content accuracy)
  config:  5 checks (CLAUDE.md counts, date, .claudeignore, memory index, kb/README count)

Deductions per finding:
  P0 = -3 points (broken/runtime failure)
  P1 = -1 point  (inaccurate/missing recommended)
  P2 = -0.5 points (cosmetic/nice-to-have)

Score = ((total_checks - weighted_deductions) / total_checks) × 100

Grade:
  A  = 95-100%  (production ready)
  B  = 85-94%   (minor issues, should fix)
  C  = 70-84%   (significant gaps)
  D  = <70%     (needs major work)
```

**Current baseline** (43 agents + 45 KBs + 16 skills + 4 rules + 5 config):
- Total checks: 43×7 + 45×5 + 16×3 + 4×2 + 5 = **587 check items**

---

## Priority Definitions

| Priority | Meaning | Action |
|----------|---------|--------|
| **P0** | Broken — will cause runtime failures | Must fix immediately |
| **P1** | Wrong — inaccurate data or missing recommended fields | Should fix soon |
| **P2** | Improvement — nice to have for consistency | Fix when convenient |

---

## With --fix Flag

When `--fix` is passed:
1. Run full audit first
2. Auto-fix all P0 and P1 findings
3. Re-run audit to verify fixes
4. Report what was fixed and what needs manual review
5. Show git commands to commit and push

Do NOT auto-fix P2 findings — just report them.

---

## Remember

> **"Drift is silent. Audit is loud."**

Run `/audit` after:
- Adding new agents, KBs, or skills
- Major refactoring
- Syncing from downstream repos
- Any batch operations on .claude/ files
