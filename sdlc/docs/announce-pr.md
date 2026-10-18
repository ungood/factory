# Announce

The `announce` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/announce-pr`](../bin/announce-pr). Tests: [`announce-pr.bats`](../test/announce-pr.bats).

It links the PR to the run's Orca worktree, and moves the worktree to `in-review` with a comment and marks it unread. The agent opened the PR, so its session already knows about it. If Orca can't be updated, that's logged and the run goes on.
