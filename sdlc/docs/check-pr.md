# Check

The `check` step in [`implement.yaml`](../implement.yaml), after the agent's first pass, and the `recheck` step, after each round of feedback, run [`sdlc/bin/check-pr`](../bin/check-pr). Tests: [`check-pr.bats`](../test/check-pr.bats).

The agent commits, pushes and opens the PR itself, and CI on the PR runs the repo's checks, so this step isn't a gate. It checks only what the workflow can observe: the branch has a PR, the PR's head is the worktree's `HEAD`, and nothing is uncommitted. It doesn't wait for CI.

If a check fails, it writes the problems to `check-<n>.md` in the run's state directory and sends them to the agent's terminal, once, then waits for `check-<n>.json` the same way the [agent](agent.md) step waits for its result. If the checks still fail, the step fails, and the run [escalates](end-run.md) to me. A retried step doesn't ask the agent twice.

After a round of feedback passes, it moves the worktree back to `in-review` in Orca with a comment such as "PR #9 is ready for another review (round 2)" and marks it unread.
