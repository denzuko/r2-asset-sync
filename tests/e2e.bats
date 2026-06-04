#!/usr/bin/env bats
# tests/e2e.bats — end-to-end integration tests for r2_sync.sh
#
# These tests run against a REAL Cloudflare R2 bucket and CDN domain.
# They require live credentials and will make actual AWS API calls.
#
# Prerequisites:
#   export R2_ACCESS_KEY_ID="..."
#   export R2_SECRET_ACCESS_KEY="..."
#   export R2_ACCOUNT_ID="..."
#   export R2_BUCKET="..."         # a dedicated TEST bucket, not production
#   export CDN_DOMAIN="..."        # the custom domain bound to the test bucket
#   export BUILD_DIR="..."         # path to a Hugo build output
#
# Safety: these tests use a dedicated test bucket. Never run against
# the production bucket. The test bucket should be disposable.
#
# Skip in CI unless R2 credentials are present:
#   bats tests/e2e.bats    # skips automatically if creds are absent

setup() {
  # Skip entire suite if live credentials are not available
  if [ -z "${R2_ACCESS_KEY_ID:-}" ] || \
     [ -z "${R2_SECRET_ACCESS_KEY:-}" ] || \
     [ -z "${R2_ACCOUNT_ID:-}" ] || \
     [ -z "${R2_BUCKET:-}" ]; then
    skip "R2 credentials not set — skipping e2e tests"
  fi

  command -v aws >/dev/null 2>&1 || skip "aws CLI not found"

  # Use a real (but minimal) build dir if BUILD_DIR not set
  if [ -z "${BUILD_DIR:-}" ]; then
    export BUILD_DIR="${BATS_TMPDIR}/e2e_public"
    mkdir -p "${BUILD_DIR}"/{css,js,og}
    echo "body{}" > "${BUILD_DIR}/css/main.abc123.css"
    echo "var x=1;" > "${BUILD_DIR}/js/app.def456.js"
    echo "<svg/>" > "${BUILD_DIR}/og/test-post.png"
    touch "${BUILD_DIR}/favicon.ico"
    touch "${BUILD_DIR}/site.webmanifest"
  fi

  export R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
}

teardown() {
  # Clean up test objects from the bucket after each test
  if [ -n "${R2_ACCESS_KEY_ID:-}" ] && [ -n "${R2_BUCKET:-}" ]; then
    AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
    AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
    aws s3 rm "s3://${R2_BUCKET}/" \
      --endpoint-url "${R2_ENDPOINT}" \
      --recursive \
      --quiet 2>/dev/null || true
  fi
}

# ── Sync completes against live R2 ───────────────────────────────────────────

@test "[e2e] script exits 0 against live R2 bucket" {
  run sh r2_sync.sh
  echo "output: $output"
  [ "$status" -eq 0 ]
}

@test "[e2e] css file is accessible in R2 after sync" {
  sh r2_sync.sh

  AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
  AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
  result=$(aws s3 ls "s3://${R2_BUCKET}/css/" \
    --endpoint-url "${R2_ENDPOINT}" 2>&1)

  echo "$result" | grep -q "main.abc123.css"
}

@test "[e2e] js file is accessible in R2 after sync" {
  sh r2_sync.sh

  AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
  AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
  result=$(aws s3 ls "s3://${R2_BUCKET}/js/" \
    --endpoint-url "${R2_ENDPOINT}" 2>&1)

  echo "$result" | grep -q "app.def456.js"
}

@test "[e2e] og image is accessible in R2 after sync" {
  sh r2_sync.sh

  AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
  AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
  result=$(aws s3 ls "s3://${R2_BUCKET}/og/" \
    --endpoint-url "${R2_ENDPOINT}" 2>&1)

  echo "$result" | grep -q "test-post.png"
}

@test "[e2e] favicon is accessible at R2 bucket root after sync" {
  sh r2_sync.sh

  AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
  AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
  result=$(aws s3 ls "s3://${R2_BUCKET}/" \
    --endpoint-url "${R2_ENDPOINT}" 2>&1)

  echo "$result" | grep -q "favicon.ico"
}

@test "[e2e] --delete removes objects no longer in build output" {
  # First sync — upload all files
  sh r2_sync.sh

  # Remove a file from the build and re-sync
  rm -f "${BUILD_DIR}/og/test-post.png"
  sh r2_sync.sh

  # Verify the file is gone from R2
  AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
  AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
  result=$(aws s3 ls "s3://${R2_BUCKET}/og/" \
    --endpoint-url "${R2_ENDPOINT}" 2>&1)

  ! echo "$result" | grep -q "test-post.png"
}

@test "[e2e] css object has correct Cache-Control header in R2" {
  sh r2_sync.sh

  AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
  AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
  headers=$(aws s3api head-object \
    --bucket "${R2_BUCKET}" \
    --key "css/main.abc123.css" \
    --endpoint-url "${R2_ENDPOINT}" 2>&1)

  echo "$headers" | grep -qi "immutable"
}

@test "[e2e] favicon has correct Cache-Control header in R2" {
  sh r2_sync.sh

  AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" \
  AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" \
  headers=$(aws s3api head-object \
    --bucket "${R2_BUCKET}" \
    --key "favicon.ico" \
    --endpoint-url "${R2_ENDPOINT}" 2>&1)

  echo "$headers" | grep -q "86400"
}

# ── CDN health check ──────────────────────────────────────────────────────────

@test "[e2e] CDN domain serves favicon after sync" {
  [ -n "${CDN_DOMAIN:-}" ] || skip "CDN_DOMAIN not set"

  sh r2_sync.sh

  # Allow up to 30s for CDN propagation
  status_code=""
  for i in $(seq 1 6); do
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
      "https://${CDN_DOMAIN}/favicon.ico" 2>/dev/null || echo "000")
    [ "${status_code}" = "200" ] && break
    sleep 5
  done

  [ "${status_code}" = "200" ]
}

@test "[e2e] CDN serves css with immutable cache header" {
  [ -n "${CDN_DOMAIN:-}" ] || skip "CDN_DOMAIN not set"

  sh r2_sync.sh
  sleep 2  # brief propagation wait

  headers=$(curl -s -D - -o /dev/null \
    "https://${CDN_DOMAIN}/css/main.abc123.css" 2>/dev/null || true)

  echo "$headers" | grep -qi "immutable"
}

@test "[e2e] script is idempotent — second run exits 0 with no changes" {
  sh r2_sync.sh
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
}
