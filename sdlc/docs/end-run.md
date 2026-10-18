# End

The `closed` step in [`implement.yaml`](../implement.yaml), and the `faulted` step in its `catch`, run [`sdlc/bin/end-run`](../bin/end-run). Tests: [`end-run.bats`](../test/end-run.bats).

A run that ends without a merge says so where I look, so a run that has stopped never looks like one that's waiting. After a close, it sets the Orca worktree's comment to "PR #N closed without merging; worktree kept" and its status to `completed`, and tells the agent in its terminal that the run is over and nothing more will come.

Everything after `remember` runs in one `try`. A run that faults at any step, or gives up waiting for review, does the same with the reason, such as "Run faulted in gate: Command failed; worktree kept", moves the worktree to `todo` and marks it unread, then faults with the same error. If Orca or the terminal can't be updated, that's logged and the run goes on.
