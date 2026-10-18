# Pull request

The `pullRequest` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/open-pr`](../bin/open-pr). Tests: [`open-pr.bats`](../test/open-pr.bats).

It pushes the branch and opens a draft PR that closes the issue, with the agent's title and summary.
