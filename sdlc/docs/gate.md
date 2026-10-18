# Gate

The `gate` and `regate` steps in [`implement.yaml`](../implement.yaml) run [`sdlc/bin/gate`](../bin/gate), after the agent's first pass and after each round of feedback. Tests: [`gate.bats`](../test/gate.bats).

It fails on uncommitted changes or a branch with no new commits, then runs the repo's checks (see [Repo conventions](../../docs/sdlc.md#repo-conventions)). It doesn't trust the agent's own report.
