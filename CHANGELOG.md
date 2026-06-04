# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-03

### Added
- Initial release
- `r2_sync.sh`: sync Hugo build output to Cloudflare R2 via S3-compatible endpoint
- Per-asset-type Cache-Control headers (immutable for fingerprinted, short TTL for favicons)
- Environment variable validation before any AWS CLI invocation
- `--delete` flag to remove R2 objects no longer in build output
- `tests/unit.bats`: BDD unit tests with mocked AWS CLI
- `tests/e2e.bats`: end-to-end integration tests against live R2 bucket
- `.env.example`: environment variable template
- `.github/workflows/r2-sync.yml`: GitHub Actions workflow
- BSD-2-Clause license
