# Release Management

> **Purpose**: Semantic versioning, release-please, changelogs, and GitHub Releases
> **MCP Validated**: 2026-02-19

## When to Use

- Automating version bumps and changelog generation
- Publishing GitHub Releases with release notes
- Managing semantic versioning (semver) in CI/CD
- Distributing release artifacts (binaries, wheels, Docker images)

## Semantic Versioning

```
MAJOR.MINOR.PATCH
  |     |     |
  |     |     └── Bug fixes (backwards-compatible)
  |     └──────── New features (backwards-compatible)
  └────────────── Breaking changes (incompatible API changes)

Examples:
  1.0.0 → 1.0.1  (patch: bug fix)
  1.0.1 → 1.1.0  (minor: new feature)
  1.1.0 → 2.0.0  (major: breaking change)
```

## Conventional Commits

Release automation tools parse commit messages to determine version bumps:

| Prefix | Version Bump | Example |
|--------|-------------|---------|
| `fix:` | Patch | `fix: resolve null pointer in parser` |
| `feat:` | Minor | `feat: add user authentication` |
| `feat!:` or `BREAKING CHANGE:` | Major | `feat!: redesign API response format` |
| `docs:` | None | `docs: update README` |
| `chore:` | None | `chore: upgrade dependencies` |
| `refactor:` | None | `refactor: extract helper function` |

## Release-Please (Google)

Automated release management that creates release PRs from conventional commits.

### Setup

```yaml
# .github/workflows/release-please.yml
name: Release Please
on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
    steps:
      - uses: googleapis/release-please-action@v4
        id: release
        with:
          release-type: python
```

### How It Works

1. Developers merge PRs with conventional commits to `main`
2. Release-please creates/updates a "Release PR" with:
   - Version bump in `pyproject.toml` (or `package.json`, etc.)
   - Generated `CHANGELOG.md` entries
3. When the Release PR is merged:
   - A GitHub Release is created with generated notes
   - A git tag is pushed (e.g., `v1.2.0`)
4. Downstream workflows trigger on the new tag

### Chaining with Publish

```yaml
  publish:
    needs: release-please
    if: needs.release-please.outputs.release_created == 'true'
    runs-on: ubuntu-latest
    permissions:
      id-token: write
    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v7

      - name: Build
        run: uv build

      - name: Publish to PyPI
        run: uv publish --trusted-publishing always
```

### Configuration

Create `release-please-config.json`:

```json
{
  "packages": {
    ".": {
      "release-type": "python",
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": true
    }
  }
}
```

## Semantic-Release (Alternative)

Fully automated: analyzes commits, bumps version, generates changelog, publishes, and creates GitHub Release in one step. Uses `npx semantic-release` with `GITHUB_TOKEN`. Best for single-package npm projects.

## Manual GitHub Releases

```bash
gh release create v1.0.0 --generate-notes --title "v1.0.0"
gh release create v2.0.0-beta.1 --prerelease --title "v2.0.0 Beta 1"
gh release upload v1.0.0 dist/*.whl dist/*.tar.gz
gh release create v1.0.0 --draft --generate-notes
```

## Decision Matrix

| Tool | Best For | Automation Level |
|------|----------|-----------------|
| **release-please** | Monorepos, multi-language | PR-based, manual merge |
| **semantic-release** | Single packages, npm ecosystem | Fully automated |
| **Manual (gh release)** | Simple projects, infrequent releases | None |

## Changelog Best Practices

| Practice | Details |
|----------|---------|
| Keep a CHANGELOG.md | Human-readable release history |
| Use conventional commits | Enable automated changelog generation |
| Group by type | Features, Bug Fixes, Breaking Changes |
| Include PR links | Link back to discussion context |
| Date each release | `## [1.2.0] - 2026-02-12` |

## Tag Protection

Protect release tags from deletion or overwriting:

```bash
# Repository rulesets can protect tags
# Settings > Rules > Rulesets > New tag ruleset
# Pattern: v*
# Rules: Restrict deletions, restrict force pushes
```

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Manual version bumps | Human error, forgotten updates | Automate with release-please |
| No changelog | Users don't know what changed | Generate from conventional commits |
| Mutable tags | `v1.0` pointing to different commits | Use immutable semver tags |
| No pre-releases | Breaking changes surprise users | Use `v2.0.0-beta.1` |
| Giant releases | Hard to debug regressions | Release frequently, small batches |

## Related

- [branching-strategies](branching-strategies.md)
- [ci-cd-workflows](ci-cd-workflows.md)
- [../concepts/repositories](../concepts/repositories.md)
- [../concepts/security](../concepts/security.md)
