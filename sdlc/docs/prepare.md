# Prepare

The `prepare` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/prepare`](../bin/prepare), so the agent starts in a ready worktree. Tests: [`prepare.bats`](../test/prepare.bats).

It creates an Orca worktree named `issue-<n>`, then runs `mise trust` and `mise install` there, and the repo's `install` task if it defines one (see [Repo conventions](../../docs/sdlc.md#repo-conventions)). A failure fails the run, with the task's output in the log. A retried step reuses the worktree.
