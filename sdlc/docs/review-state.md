# Review

The review loop in [`implement.yaml`](../implement.yaml) waits for the reviewer's feedback and hands it to the agent, until the PR is merged or closed. The workflow never merges: whoever merges the PR approves it.

Right away, then every five minutes, the `reviewState` step runs [`sdlc/bin/review-state`](../bin/review-state). Tests: [`review-state.bats`](../test/review-state.bats). It reports whether there's no new feedback (`pending`), new feedback (`changes`), or whether the reviewer `merged` the PR or `closed` it without merging. Only the reviewer's own reviews and comments count, and none from round to round counts twice. A run that restarts or finishes a round checks again at once rather than waiting.

What happens next depends on the state:

- **Changes:** the agent addresses the feedback in a new round, through [revise](revise.md), the [gate](gate.md) and [reply](reply.md). The first round of feedback is round 2, because the agent's first pass was round 1.
- **Merged:** the merge is the approval. The run moves on to the [retrospective](retro.md) and then [cleans up](cleanup.md).
- **Closed:** the run moves on to the retrospective, then [ends](end-run.md) and leaves the worktree.
- **No review for 7 days:** the run ends without merging and [says so](end-run.md), after the retrospective. The PR and its worktree stay.

The worktree's Orca status follows along, through [show-review](show-review.md): `in-review` while the run waits for the reviewer, `in-progress` while the agent works, and `completed` after the merge or close.
