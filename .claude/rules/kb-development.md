---
paths:
  - .claude/kb/**
---

# KB Development Rules

## File Size Limits
- `index.md`: 100 lines max
- `quick-reference.md`: 100 lines max
- `concepts/*.md`: 150 lines max
- `patterns/*.md`: 200 lines max
- `specs/*.yaml`: No limit

## Required Structure
Each technology folder must contain:
- `index.md` — entry point, navigation
- `quick-reference.md` — fast lookup
- `.metadata.json` — technology, category, subcategory, version, use cases, related techs
- `concepts/` — atomic definitions (one concept per file)
- `patterns/` — reusable code patterns with copy-paste examples

## Creating New KBs
1. Use `/create-kb <category>/<subcategory>/<domain>` for consistency
2. Choose from: data-engineering, ai-ml, cloud, devops-sre, automation, document-processing
3. Follow templates in `.claude/kb/_templates/`
4. Add `.metadata.json` with technology info
5. Update category README with new technology

## Validation
- Run `scripts/validate_kb_structure.sh` after changes
- MCP-validate content against official docs (Context7, Exa, Ref)
- Include practical, copy-paste ready examples in every pattern file

## Master Index
`.claude/kb/README.md` provides navigation, decision frameworks, and cross-references across all 45 technologies.
