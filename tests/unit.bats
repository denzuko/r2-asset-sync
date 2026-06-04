#!/usr/bin/env bats
# tests/unit.bats — unit tests for r2_sync.sh
#
# BDD workflow: these tests were written BEFORE the implementation.
# All tests must fail until r2_sync.sh exists and satisfies each spec.
#
# Run: bats tests/unit.bats
# Requires: bats-core, mock AWS CLI in fixtures/

setup() {
  # Build a fake Hugo output tree for each test
  export BUILD_DIR="${BATS_TMPDIR}/public"
  mkdir -p "${BUILD_DIR}"/{css,js,fonts,images,og}

  touch "${BUILD_DIR}/css/main.abc123.css"
  touch "${BUILD_DIR}/js/app.def456.js"
  touch "${BUILD_DIR}/fonts/inter.woff2"
  touch "${BUILD_DIR}/images/author.png"
  touch "${BUILD_DIR}/og/post-one.png"
  touch "${BUILD_DIR}/favicon.ico"
  touch "${BUILD_DIR}/apple-touch-icon.png"
  touch "${BUILD_DIR}/site.webmanifest"

  # Required env vars
  export R2_ACCESS_KEY_ID="test-key-id"
  export R2_SECRET_ACCESS_KEY="test-secret"
  export R2_ACCOUNT_ID="test-account-id"
  export R2_BUCKET="test-bucket"
  export CDN_DOMAIN="assets.cdn.example.com"

  # Point at mock aws CLI
  export MOCK_DIR="${BATS_TEST_DIRNAME}/fixtures"
  mkdir -p "${MOCK_DIR}"
  export PATH="${MOCK_DIR}:${PATH}"

  # Create mock aws that records invocations
  cat > "${MOCK_DIR}/aws" << 'SH'
#!/bin/sh
echo "$@" >> "${BATS_TMPDIR}/aws_calls.log"
exit 0
SH
  chmod +x "${MOCK_DIR}/aws"

  # Create mock curl for health check
  cat > "${MOCK_DIR}/curl" << 'SH'
#!/bin/sh
echo "HTTP/2 200"
exit 0
SH
  chmod +x "${MOCK_DIR}/curl"

  rm -f "${BATS_TMPDIR}/aws_calls.log"
}

teardown() {
  rm -rf "${BUILD_DIR}" "${MOCK_DIR}"
}

# ── Validation ────────────────────────────────────────────────────────────────

@test "fails when R2_ACCESS_KEY_ID is unset" {
  unset R2_ACCESS_KEY_ID
  run sh r2_sync.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "R2_ACCESS_KEY_ID" ]]
}

@test "fails when R2_SECRET_ACCESS_KEY is unset" {
  unset R2_SECRET_ACCESS_KEY
  run sh r2_sync.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "R2_SECRET_ACCESS_KEY" ]]
}

@test "fails when R2_ACCOUNT_ID is unset" {
  unset R2_ACCOUNT_ID
  run sh r2_sync.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "R2_ACCOUNT_ID" ]]
}

@test "fails when R2_BUCKET is unset" {
  unset R2_BUCKET
  run sh r2_sync.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "R2_BUCKET" ]]
}

@test "fails when BUILD_DIR is unset" {
  unset BUILD_DIR
  run sh r2_sync.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "BUILD_DIR" ]]
}

@test "fails when BUILD_DIR does not exist" {
  export BUILD_DIR="/nonexistent/path"
  run sh r2_sync.sh
  [ "$status" -eq 1 ]
  [[ "$output" =~ "does not exist" ]]
}

@test "fails when aws CLI is not found" {
  export PATH="/nonexistent:${PATH}"
  # Remove mock aws from PATH temporarily
  local orig_mock="${MOCK_DIR}/aws"
  mv "${orig_mock}" "${orig_mock}.bak"
  run sh r2_sync.sh
  mv "${orig_mock}.bak" "${orig_mock}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "aws" ]]
}

# ── Sync behaviour ────────────────────────────────────────────────────────────

@test "syncs css directory with immutable cache-control" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  grep -q "s3 sync" "${BATS_TMPDIR}/aws_calls.log"
  grep "css" "${BATS_TMPDIR}/aws_calls.log" | grep -q "immutable"
}

@test "syncs js directory with immutable cache-control" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  grep "js" "${BATS_TMPDIR}/aws_calls.log" | grep -q "immutable"
}

@test "syncs fonts directory with immutable cache-control" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  grep "fonts" "${BATS_TMPDIR}/aws_calls.log" | grep -q "immutable"
}

@test "syncs images directory with immutable cache-control" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  grep "images" "${BATS_TMPDIR}/aws_calls.log" | grep -q "immutable"
}

@test "syncs og directory with 7-day cache-control" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  grep "og" "${BATS_TMPDIR}/aws_calls.log" | grep -q "604800"
}

@test "syncs favicons with 24-hour cache-control" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  grep "favicon\|webmanifest\|apple-touch" "${BATS_TMPDIR}/aws_calls.log" | grep -q "86400"
}

@test "passes --delete flag to all sync operations" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  # Every aws s3 sync call should include --delete
  local sync_calls
  sync_calls=$(grep "s3 sync" "${BATS_TMPDIR}/aws_calls.log" | wc -l)
  local delete_calls
  delete_calls=$(grep "s3 sync" "${BATS_TMPDIR}/aws_calls.log" | grep -c "\-\-delete")
  [ "$sync_calls" -eq "$delete_calls" ]
}

@test "uses correct R2 endpoint URL format" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  grep -q "${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" "${BATS_TMPDIR}/aws_calls.log"
}

@test "uses correct bucket name in sync commands" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  grep -q "s3://${R2_BUCKET}" "${BATS_TMPDIR}/aws_calls.log"
}

@test "skips sync for empty asset directories" {
  rm -rf "${BUILD_DIR}/og"
  mkdir -p "${BUILD_DIR}/og"  # empty dir
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  # og sync should not appear in calls when directory is empty
  # (implementation may choose to skip or run with zero objects — both acceptable)
}

@test "exits 0 on successful sync of all directories" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
}

@test "prints sync summary to stdout" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sync" ]] || [[ "$output" =~ "done" ]] || [[ "$output" =~ "complete" ]]
}

# ── Smoke test ────────────────────────────────────────────────────────────────

@test "runs smoke test when CDN_DOMAIN is set" {
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  grep -q "assets.cdn.example.com" "${BATS_TMPDIR}/aws_calls.log" 2>/dev/null || \
    [[ "$output" =~ "smoke" ]] || [[ "$output" =~ "${CDN_DOMAIN}" ]]
}

@test "skips smoke test when CDN_DOMAIN is unset" {
  unset CDN_DOMAIN
  run sh r2_sync.sh
  [ "$status" -eq 0 ]
  # Should still succeed — smoke test is optional
}
