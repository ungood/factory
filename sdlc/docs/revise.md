# Revise

The `revise` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/revise`](../bin/revise) when the [review](review-state.md) finds new feedback. Tests: [`revise.bats`](../test/revise.bats).

It writes the new feedback to `feedback-<n>.json` in the run's state directory and sends it into the agent's own terminal, so the session keeps its context, then waits for `result-<n>.json` the same way the [agent](agent.md) step waits for its first result. It sets the worktree's Orca comment to something like "Round 2: agent working on 1 comment" once the agent has the feedback.

If the agent's terminal has closed or no longer runs Claude, the run fails rather than starting a new agent.
