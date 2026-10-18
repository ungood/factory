# Show review

The `showReview` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/show-review`](../bin/show-review) after each check of the [review](review-state.md). Tests: [`show-review.bats`](../test/show-review.bats).

It sets the worktree's Orca comment and status to what the loop is doing, such as "Waiting for review, next check 11:27". If Orca can't be updated, that's logged and the run goes on.
