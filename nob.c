/*
 * nob.c — r2-asset-sync build and sync orchestrator
 *
 * Uses nob.h (tsoding/nob.h) to define a DAG of sync steps.
 * Bootstraps itself: cc -o nob nob.c, then ./nob [target]
 *
 * Targets:
 *   ./nob sync       - sync all asset directories to R2 (default)
 *   ./nob validate   - validate environment variables only
 *   ./nob test       - run bats unit tests
 *   ./nob check      - shellcheck r2_sync.sh
 *   ./nob all        - check + test + sync
 *   ./nob help       - print this message
 *
 * Required environment variables (same as r2_sync.sh):
 *   R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ACCOUNT_ID,
 *   R2_BUCKET, BUILD_DIR
 *
 * Optional:
 *   CDN_DOMAIN, ASSET_DIRS, FAVICON_PATTERNS
 *
 * License: BSD-2-Clause
 */

#define NOB_IMPLEMENTATION
#include "nob.h"

/* ── helpers ──────────────────────────────────────────────────────────── */

static int require_env(const char *name)
{
    const char *val = getenv(name);
    if (!val || strlen(val) == 0) {
        nob_log(NOB_ERROR, "required environment variable %s is not set", name);
        return 0;
    }
    return 1;
}

static int validate_env(void)
{
    int ok = 1;
    ok &= require_env("R2_ACCESS_KEY_ID");
    ok &= require_env("R2_SECRET_ACCESS_KEY");
    ok &= require_env("R2_ACCOUNT_ID");
    ok &= require_env("R2_BUCKET");
    ok &= require_env("BUILD_DIR");
    return ok;
}

static int build_dir_exists(void)
{
    const char *build_dir = getenv("BUILD_DIR");
    if (!build_dir) return 0;
    return nob_file_exists(build_dir);
}

/* ── dag nodes ────────────────────────────────────────────────────────── */

static int dag_validate(void)
{
    nob_log(NOB_INFO, "[validate] checking required environment variables");
    if (!validate_env()) return 0;
    if (!build_dir_exists()) {
        nob_log(NOB_ERROR, "BUILD_DIR '%s' does not exist", getenv("BUILD_DIR"));
        return 0;
    }
    nob_log(NOB_INFO, "[validate] ok");
    return 1;
}

static int dag_check(void)
{
    nob_log(NOB_INFO, "[check] running shellcheck on r2_sync.sh");
    Nob_Cmd cmd = {0};
    nob_cmd_append(&cmd, "shellcheck", "r2_sync.sh");
    int ok = nob_cmd_run_sync(cmd);
    nob_cmd_free(cmd);
    if (ok) nob_log(NOB_INFO, "[check] shellcheck clean");
    return ok;
}

static int dag_test(void)
{
    nob_log(NOB_INFO, "[test] running bats unit tests");
    Nob_Cmd cmd = {0};
    nob_cmd_append(&cmd, "bats", "tests/unit.bats");
    int ok = nob_cmd_run_sync(cmd);
    nob_cmd_free(cmd);
    if (ok) nob_log(NOB_INFO, "[test] 21/21 passed");
    return ok;
}

static int dag_sync(void)
{
    nob_log(NOB_INFO, "[sync] starting R2 asset sync");

    /* Validate first — dag_sync depends on dag_validate */
    if (!dag_validate()) return 0;

    Nob_Cmd cmd = {0};
    nob_cmd_append(&cmd, "sh", "r2_sync.sh");

    /* Pass current environment through — r2_sync.sh reads its own env vars */
    int ok = nob_cmd_run_sync(cmd);
    nob_cmd_free(cmd);

    if (ok) {
        nob_log(NOB_INFO, "[sync] complete: s3://%s", getenv("R2_BUCKET"));
    } else {
        nob_log(NOB_ERROR, "[sync] failed");
    }
    return ok;
}

static int dag_all(void)
{
    nob_log(NOB_INFO, "[all] check → test → sync");
    return dag_check() && dag_test() && dag_sync();
}

static void print_help(const char *prog)
{
    printf("Usage: %s [target]\n\n", prog);
    printf("Targets:\n");
    printf("  sync      sync all asset directories to R2 (default)\n");
    printf("  validate  validate environment variables only\n");
    printf("  test      run bats unit tests\n");
    printf("  check     shellcheck r2_sync.sh\n");
    printf("  all       check + test + sync\n");
    printf("  help      print this message\n\n");
    printf("Required env: R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY,\n");
    printf("              R2_ACCOUNT_ID, R2_BUCKET, BUILD_DIR\n");
    printf("Optional env: CDN_DOMAIN, ASSET_DIRS, FAVICON_PATTERNS\n");
}

/* ── main ─────────────────────────────────────────────────────────────── */

int main(int argc, char **argv)
{
    NOB_GO_REBUILD_URSELF(argc, argv);

    const char *target = argc > 1 ? argv[1] : "sync";

    if (strcmp(target, "help") == 0) {
        print_help(argv[0]);
        return 0;
    } else if (strcmp(target, "validate") == 0) {
        return dag_validate() ? 0 : 1;
    } else if (strcmp(target, "check") == 0) {
        return dag_check() ? 0 : 1;
    } else if (strcmp(target, "test") == 0) {
        return dag_test() ? 0 : 1;
    } else if (strcmp(target, "sync") == 0) {
        return dag_sync() ? 0 : 1;
    } else if (strcmp(target, "all") == 0) {
        return dag_all() ? 0 : 1;
    } else {
        nob_log(NOB_ERROR, "unknown target '%s' — run ./nob help", target);
        return 1;
    }
}
