# r2-asset-sync

Shell script and CI workflow for syncing Hugo static site assets to Cloudflare R2
under a custom CDN domain. Companion to the
[Platform Sovereignty via Cloudflare](https://dwightaspencer.com) whitepaper.

## What it does

- Syncs compiled CSS, JS bundles, fonts, images, OG images, and favicons from a
  Hugo build output to a Cloudflare R2 bucket via the S3-compatible endpoint
- Sets correct `Cache-Control` headers per asset type (immutable for
  content-hashed assets, shorter TTL for favicons and manifests)
- Deletes R2 objects no longer present in the build output (`--delete`)
- Validates required environment variables before touching anything
- Idempotent: safe to run on every deploy

## Requirements

- `aws` CLI v2 (used against R2's S3-compatible endpoint — no AWS account needed)
- `curl` (health check)
- Cloudflare R2 bucket with public access enabled
- Scoped R2 API token: Object Read & Write on the target bucket only

## Usage

```sh
export R2_ACCESS_KEY_ID="your-access-key"
export R2_SECRET_ACCESS_KEY="your-secret-key"
export R2_ACCOUNT_ID="your-cloudflare-account-id"
export R2_BUCKET="your-bucket-name"
export BUILD_DIR="hugo/public"          # path to Hugo build output
export CDN_DOMAIN="assets.cdn.example.com"  # for smoke test

./r2_sync.sh
```

Or source a `.env` file (not committed):

```sh
cp .env.example .env
# fill in values
./r2_sync.sh
```

## CI/CD

See `.github/workflows/` for a ready-to-use GitHub Actions workflow that
runs `r2_sync.sh` after every Hugo build. Required secrets:

| Secret | Description |
|--------|-------------|
| `R2_ACCESS_KEY_ID` | R2 API token access key |
| `R2_SECRET_ACCESS_KEY` | R2 API token secret key |
| `R2_ACCOUNT_ID` | Cloudflare account ID |

## Asset directories synced

| Directory | Cache-Control | Notes |
|-----------|--------------|-------|
| `css/` | `public, max-age=31536000, immutable` | Content-hashed by Hugo |
| `js/` | `public, max-age=31536000, immutable` | Content-hashed by Hugo |
| `fonts/` | `public, max-age=31536000, immutable` | Static |
| `images/` | `public, max-age=31536000, immutable` | Versioned |
| `og/` | `public, max-age=604800` | Per-post OG images |
| `favicon*`, `site.webmanifest` | `public, max-age=86400` | Not fingerprinted |

## Security

See [SECURITY.md](SECURITY.md). Key controls:

- R2 token scoped to Object Read & Write on the target bucket only — no
  bucket-level or account-level admin
- Bucket listing disabled (objects accessible by URL, not enumerable)
- Set `--jurisdiction us` at bucket creation (cannot change later)
- Subresource Integrity (SRI) must be implemented in Hugo templates before
  switching asset delivery to R2 in production — see whitepaper §8.2

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Patches via pull request.
One issue per pull request. Tests must pass before review.

## License

BSD-2-Clause. See [LICENSE](LICENSE).
