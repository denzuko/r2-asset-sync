# CLAUDE.md

AI assistant guidance for r2-asset-sync.

## Project

Shell script and CI workflow for syncing Hugo static site assets to
Cloudflare R2. POSIX sh, BSD-2-Clause, BDD-enforced.

## BDD workflow (mandatory)

1. Write failing bats test in `tests/unit.bats`
2. Verify test fails for the right reason
3. Write implementation in `r2_sync.sh` to satisfy the test
4. Verify green
5. Run shellcheck
6. Update CHANGELOG.md

Never write implementation before the test exists and fails.

## Code constraints

- POSIX sh only — `#!/bin/sh`, not `#!/bin/bash`
- shellcheck must pass with no warnings
- All environment variables validated before any AWS CLI call
- Error output to stderr, not stdout
- No hardcoded bucket names, domains, or credentials anywhere in source

## Semver

- MAJOR: breaking change to env var interface
- MINOR: new asset type or capability
- PATCH: bug fix, docs, tests
- Never bump major for restructuring
- Patch freely — patch version may exceed 100

## Test structure

Unit tests: `tests/unit.bats` — mock AWS CLI via `$MOCK_DIR`
Integration tests: `tests/integration.bats` — requires live R2 credentials
E2E tests: `tests/e2e.bats` — full sync against a real bucket and CDN domain

Run unit tests only in CI unless R2 secrets are present.

## File layout

```
r2_sync.sh          main sync script
tests/
  unit.bats         unit tests (mocked)
  integration.bats  integration tests (live R2)
  e2e.bats          end-to-end tests (live R2 + CDN)
.env.example        environment variable template
.github/workflows/  CI workflow
CHANGELOG.md
CONTRIBUTING.md
LICENSE
README.md
SECURITY.md
```
