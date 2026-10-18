# Retrospective

The `retro` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/retro`](../bin/retro) once the [review](review-state.md) is over. Tests: [`retro.bats`](../test/retro.bats).

It runs a headless, read-only `claude -p` over the issue, the PR diff, the agent's result file and Claude transcript, and the marche run's logs, including the gate's output. It proposes up to three issues from the friction it finds, each citing evidence from the run, and the script files them in this repo or the one the run worked on, labeled `retro` and linking the PR. The agent checks each repo's open issues first to avoid duplicates.

It runs after the review, so it sees each round of feedback too. It also reads the reviewer's reviews and comments that no round handled, such as a review left with the merge, and files an issue for each idea for follow-up work in them, on top of its own three. Comments posted after the run has finished aren't read yet.

Like the [agent](agent.md), it copies `CLAUDE_CONFIG_DIR` from the source checkout. A failed retrospective is logged and never fails the run.
