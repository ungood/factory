# Tests

This repo's `test` task, [`sdlc/run-tests`](../run-tests), runs the [bats](https://github.com/bats-core/bats-core) tests in [`sdlc/test`](../test) against a clean export of `HEAD`, so file modes and missing files look the way a run sees them, and a `chmod` that was never committed doesn't count. Tests: [`run-tests.bats`](../test/run-tests.bats).

The tests run every script by path, as the workflow does, never through `bash` or `sh`. [`workflow.bats`](../test/workflow.bats) enforces both, and fails unless every script a workflow in `sdlc/*.yaml` runs is committed with mode `100755` and run by path in at least one test.

[`docs.bats`](../test/docs.bats) checks that every script a workflow runs has its own doc in `sdlc/docs`, named after the script, and that the [overview](../../docs/sdlc.md) links each doc without numbering the steps.
