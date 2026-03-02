---
paths:
  - .git/**
  - "*.md"
---

# Git Workflow Rules

## Branch Strategy
- Main branch: `main`
- Create feature branches for significant changes
- PRs target `main`

## Commit Conventions
- Summarize the "why" not just the "what"
- Keep commits focused on a single logical change
- Don't commit files containing secrets (.env, credentials.json)

## Dev Loop Integration
- Use `/dev` for agentic development with PROMPT files
- Use `/create-pr` for pull request creation
- SDD workflow artifacts live in `.claude/sdd/`

## Project Structure
Both agents and KB use hierarchical category/subcategory structures. When adding new items, maintain the existing hierarchy patterns.
