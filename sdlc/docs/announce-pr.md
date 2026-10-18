# Announce

The `announce` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/announce-pr`](../bin/announce-pr). Tests: [`announce-pr.bats`](../test/announce-pr.bats).

It links the PR to the run's Orca worktree, moves the worktree to `in-review` with a comment and marks it unread, and types the PR's URL into the agent's terminal. If Orca can't be updated, that's logged and the run goes on.
