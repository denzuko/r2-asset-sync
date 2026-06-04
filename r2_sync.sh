#!/bin/sh
# r2_sync.sh — sync Hugo static site assets to Cloudflare R2
#
# Usage: see README.md
# Requirements: aws CLI v2, curl
# License: BSD-2-Clause

set -eu

# ── Validation ────────────────────────────────────────────────────────────────

die() {
  echo "error: $*" >&2
  exit 1
}

require_env() {
  eval "val=\${${1}:-}"
  [ -n "$val" ] || die "required environment variable ${1} is not set"
}

require_env R2_ACCESS_KEY_ID
require_env R2_SECRET_ACCESS_KEY
require_env R2_ACCOUNT_ID
require_env R2_BUCKET
require_env BUILD_DIR

command -v aws >/dev/null 2>&1 || die "aws CLI not found — install awscli v2"

[ -d "${BUILD_DIR}" ] || die "BUILD_DIR '${BUILD_DIR}' does not exist"

# ── Configuration ─────────────────────────────────────────────────────────────

R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}"

# ── Sync helpers ──────────────────────────────────────────────────────────────

sync_dir() {
  src_dir="$1"
  dst_prefix="$2"
  cache_control="$3"

  local_path="${BUILD_DIR}/${src_dir}"

  # Skip if directory does not exist or is empty
  [ -d "${local_path}" ] || return 0
  [ -n "$(ls -A "${local_path}" 2>/dev/null)" ] || return 0

  echo "sync: ${src_dir}/ -> s3://${R2_BUCKET}/${dst_prefix}"

  aws s3 sync "${local_path}/" \
    "s3://${R2_BUCKET}/${dst_prefix}" \
    --endpoint-url "${R2_ENDPOINT}" \
    --cache-control "${cache_control}" \
    --delete \
    --no-progress
}

sync_files() {
  dst_prefix="$1"
  cache_control="$2"
  shift 2
  # remaining args are include patterns

  includes=""
  for pattern in "$@"; do
    includes="${includes} --include ${pattern}"
  done

  echo "sync: root assets -> s3://${R2_BUCKET}/${dst_prefix}"

  # shellcheck disable=SC2086
  aws s3 cp "${BUILD_DIR}/" \
    "s3://${R2_BUCKET}/${dst_prefix}" \
    --endpoint-url "${R2_ENDPOINT}" \
    --cache-control "${cache_control}" \
    --recursive \
    --exclude "*" \
    ${includes} \
    --delete \
    --no-progress
}

# ── Sync ──────────────────────────────────────────────────────────────────────

IMMUTABLE="public, max-age=31536000, immutable"
WEEK="public, max-age=604800"
DAY="public, max-age=86400"

sync_dir "css"    "css"    "${IMMUTABLE}"
sync_dir "js"     "js"     "${IMMUTABLE}"
sync_dir "fonts"  "fonts"  "${IMMUTABLE}"
sync_dir "images" "images" "${IMMUTABLE}"
sync_dir "og"     "og"     "${WEEK}"

sync_files "" "${DAY}" \
  "favicon*" \
  "apple-touch*" \
  "site.webmanifest"

# ── Smoke test ────────────────────────────────────────────────────────────────

CDN_DOMAIN="${CDN_DOMAIN:-}"

if [ -n "${CDN_DOMAIN}" ]; then
  echo "smoke: checking https://${CDN_DOMAIN}/favicon.ico"
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://${CDN_DOMAIN}/favicon.ico" || true)
  case "${status}" in
    200|304) echo "smoke: ok (HTTP ${status})" ;;
    404)     echo "smoke: warning — favicon.ico not found (HTTP 404)" ;;
    *)       echo "smoke: warning — unexpected HTTP ${status}" ;;
  esac
fi

echo "sync complete: s3://${R2_BUCKET}"
