# Contributing

## Before opening a pull request

- One issue per pull request
- All bats tests must pass: `bats tests/`
- Shell must pass shellcheck: `shellcheck r2_sync.sh`
- CHANGELOG.md updated with your change under `[Unreleased]`

## Development setup

```sh
# Install bats-core
git clone https://github.com/bats-core/bats-core.git /opt/bats
export PATH="/opt/bats/bin:$PATH"

# Install shellcheck (Ubuntu/Debian)
apt-get install shellcheck

# Run tests
bats tests/unit.bats
```

## Test coverage

New behaviour requires new tests in `tests/unit.bats` before the implementation.
BDD workflow: write failing test, write code to satisfy it, verify green.

## Code style

- POSIX sh — no bashisms unless required and explicitly documented
- Functions named with underscores: `sync_asset_dir`, `validate_env`
- Error messages to stderr: `echo "error: ..." >&2`
- Exit codes: 0 success, 1 validation failure, 2 sync failure

## Changelog format

```markdown
## [Unreleased]
### Added
- description of new feature

### Fixed
- description of bug fix
```

## Semver

- MAJOR: breaking change to environment variable interface or behaviour
- MINOR: new capability, new asset type support
- PATCH: bug fix, documentation, test — patch freely, never bump major for restructuring
