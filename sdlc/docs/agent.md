# Agent

The `agent` step in [`implement.yaml`](../implement.yaml) runs [`sdlc/bin/agent`](../bin/agent). Tests: [`agent.bats`](../test/agent.bats) and [`await-result.bats`](../test/await-result.bats).

It starts Claude in a terminal in the prepared worktree, so a person can watch it and take over. The task it sends tells Claude to write tests, implement, and commit, and to document a change in the doc for the step or feature it changed. Claude then pushes, fixing whatever the pre-push hook reports rather than bypassing it, and opens a draft PR that closes the issue, following the repo's PR template if it has one. As its last action, it writes a result file with its status, the PR's URL and a summary. The [check](check-pr.md) step then confirms the PR matches the worktree.

The step waits for that file, then for Claude to go back to its prompt, through [`sdlc/bin/await-result`](../bin/await-result), so edits Claude makes after first writing the file still count. A result that isn't JSON fails the step, and so does a result whose status isn't `done`. A retried step reuses the terminal and result, so a worker crash never starts a second agent.

Orca puts worktrees outside the workplace, where its untracked `mise.local.toml` doesn't apply, so the script copies `CLAUDE_CONFIG_DIR` from the source checkout. Without it, the agent would run on the wrong Claude account.
