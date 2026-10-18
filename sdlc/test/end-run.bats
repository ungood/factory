#!/usr/bin/env bats
# Tests sdlc/bin/end-run against a fake orca that records its calls, and can
# fail them.

setup() {
  load helpers
  init

  # The fake orca appends each call to $FAKE/calls, then fails if
  # $FAKE/fail exists.
  fake orca <<'ORCA'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE/calls"
[ ! -f "$FAKE/fail" ]
ORCA
  git init --quiet "$tmp/demo"

  state="$tmp/state/factory/agents/demo-7"
  mkdir -p "$tmp/fake" "$state"
  echo term_1 >"$state/terminal"
  export FAKE="$tmp/fake" XDG_STATE_HOME="$tmp/state"
  url=https://github.com/ungood/demo/pull/9
  run_id=factory.implement-01ABC
  timed_out='{"type":"https://github.com/ungood/factory/errors/review-timed-out","status":408,"title":"No review within 7 days","detail":"Nobody reviewed https://github.com/ungood/demo/pull/9 within 7 days, so the run ended without merging it. The pull request and its worktree are still there.","instance":"/do/1/implement/try/24/giveUp"}'
  failed='{"type":"https://open-workflow-specification.org/spec/1.0.0/errors/runtime","status":500,"title":"Command failed","detail":"The command exited with code 1. Standard error ended with:\ngate: mise run ci failed","instance":"/do/1/implement/try/2/gate"}'
}

end_run() { run "$root/sdlc/bin/end-run" "$1" "$tmp/demo" 7 "${@:2}"; }
calls() { cat "$FAKE/calls" 2>/dev/null || true; }

@test "a pull request closed without merging says so in Orca and the terminal" {
  end_run closed /worktree "$url"$'\n'
  [ "$status" -eq 0 ]
  expect "worktree set --worktree path:/worktree --comment PR #9 closed without merging; worktree kept --workspace-status completed --json
terminal send --terminal term_1 --text PR #9 was closed without merging, so this run is over and the workflow won't send anything more. The worktree stays. --enter --json" "$(calls)"
}

@test "a review that timed out says so in Orca and the terminal" {
  end_run faulted /worktree "$run_id" "$timed_out"
  [ "$status" -eq 0 ]
  expect "worktree set --worktree path:/worktree --comment Run ended: No review within 7 days; worktree kept --workspace-status todo --unread --json
terminal send --terminal term_1 --text The run ended: No review within 7 days. Nobody reviewed https://github.com/ungood/demo/pull/9 within 7 days, so the run ended without merging it. The pull request and its worktree are still there. The workflow won't send anything more; \`marche show $run_id\` has the details. --enter --json" "$(calls)"
}

@test "a faulted run names the step that faulted, on one line" {
  end_run faulted /worktree "$run_id" "$failed"
  [ "$status" -eq 0 ]
  expect "worktree set --worktree path:/worktree --comment Run faulted in gate: Command failed; worktree kept --workspace-status todo --unread --json
terminal send --terminal term_1 --text The run faulted in gate: Command failed. The command exited with code 1. Standard error ended with: gate: mise run ci failed The workflow won't send anything more; \`marche show $run_id\` has the details. --enter --json" "$(calls)"
}

@test "a step inside a nested try is named by its outermost task" {
  end_run faulted /worktree "$run_id" '{"status":500,"title":"Command failed","detail":"","instance":"/do/1/implement/try/7/reviewState/try/0/check"}'
  [ "$status" -eq 0 ]
  [[ "$(calls)" == *"--comment Run faulted in reviewState: Command failed; worktree kept"* ]]
}

@test "a long detail is cut short" {
  local long
  long=$(printf 'x%.0s' $(seq 1000))
  end_run faulted /worktree "$run_id" "{\"status\":500,\"title\":\"Command failed\",\"detail\":\"$long\",\"instance\":\"/do/1/implement/try/2/gate\"}"
  [ "$status" -eq 0 ]
  local text
  text=$(grep '^terminal send' "$FAKE/calls")
  [ "${#text}" -lt 600 ]
  [[ "$text" == *"x… The workflow won't send anything more;"* ]]
}

@test "a run that faulted before it had a worktree only tells the terminal, if there is one" {
  end_run faulted "" "$run_id" "$failed"
  [ "$status" -eq 0 ]
  [ "$(calls | wc -l | tr -d ' ')" -eq 1 ]
  [[ "$(calls)" == "terminal send --terminal term_1 "* ]]
}

@test "without the agent's terminal, only updates Orca" {
  rm "$state/terminal"
  end_run closed /worktree "$url"
  [ "$status" -eq 0 ]
  expect "worktree set --worktree path:/worktree --comment PR #9 closed without merging; worktree kept --workspace-status completed --json" "$(calls)"
}

@test "never fails when Orca does" {
  touch "$FAKE/fail"
  end_run closed /worktree "$url"
  [ "$status" -eq 0 ]
  [ "$(calls | wc -l | tr -d ' ')" -eq 2 ]
}

@test "never fails on an error it can't read" {
  end_run faulted /worktree "$run_id" 'not json'
  [ "$status" -eq 0 ]
  [[ "$(calls)" == *"--comment Run faulted; worktree kept"* ]]
}

@test "never fails on an ending it doesn't know" {
  end_run vanished /worktree
  [ "$status" -eq 0 ]
  expect "" "$(calls)"
}
