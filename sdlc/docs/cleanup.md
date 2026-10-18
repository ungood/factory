# Cleanup

The `cleanup` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/cleanup`](../bin/cleanup) after a merge. Tests: [`cleanup.bats`](../test/cleanup.bats).

It closes the agent's Orca terminals, removes the worktree with `orca worktree rm`, and deletes the local branch. GitHub deletes the remote branch on merge. A worktree with uncommitted changes, or commits that were never pushed, stays in place and the log says so. The run's state directory stays as the record of the run. Cleanup never fails the run.
