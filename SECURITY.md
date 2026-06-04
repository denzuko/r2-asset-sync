# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| latest `main` | Yes |
| older tags | No — upgrade to latest |

## Reporting a vulnerability

Do not file a public GitHub issue for security vulnerabilities.

Report privately via email to: security@dapla.net

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix if known

Response target: 72 hours. Fix target: 14 days for confirmed vulnerabilities.

## Threat model

This tool uploads static site assets to Cloudflare R2. The primary security
concerns are:

**Credential exposure.** The R2 API token is passed via environment variables.
Never commit credentials. Use CI/CD secrets management. Rotate the token quarterly.

**Supply chain.** This script invokes `aws` CLI. Pin the CLI version in CI.
Review the `aws s3 sync` command options before running in production.

**Scope.** The R2 token should be scoped to Object Read & Write on the target
bucket only. No bucket-level admin. No account-level permissions. If this token
is compromised, the blast radius is limited to asset replacement in one bucket.

**Asset integrity.** Uploading assets to a CDN without Subresource Integrity (SRI)
in your HTML means a compromised bucket is a cross-site scripting vector. SRI must
be implemented in your site's build before switching to CDN asset delivery. See
the whitepaper for implementation guidance.

**Bucket listing.** Disable public bucket listing. Assets are accessible by URL
but the object inventory should not be enumerable.

**Data residency.** Set `--jurisdiction us` (or `eu`) at R2 bucket creation.
This cannot be changed after creation.
