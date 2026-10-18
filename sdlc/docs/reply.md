# Reply

The `reply` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/reply`](../bin/reply) once a round's changes pass the [gate](gate.md). Tests: [`reply.bats`](../test/reply.bats).

It pushes and posts the agent's reply to each piece of feedback: in its thread for an inline comment, and as a PR comment otherwise.
