#!/usr/bin/env bats
# Tests sdlc/bin/announce-pr against a fake orca that records its calls, and
# can fail them.

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
  set_worktree="worktree set --worktree path:/worktree --pr 9 --workspace-status in-review --comment PR #9 is ready for review --unread --json"
  send="terminal send --terminal term_1 --text The workflow opened $url for this work. --enter --json"
}

announce() { run "$root/sdlc/bin/announce-pr" "$tmp/demo" 7 /worktree "$1"; }
calls() { cat "$FAKE/calls" 2>/dev/null || true; }

@test "links the pull request and tells the agent's terminal" {
  announce "$url"$'\n'
  [ "$status" -eq 0 ]
  expect "$set_worktree"$'\n'"$send" "$(calls)"
}

@test "a URL without a pull request number does nothing" {
  announce https://github.com/ungood/demo
  [ "$status" -eq 0 ]
  expect "" "$(calls)"
}

@test "never fails when Orca does" {
  touch "$FAKE/fail"
  announce "$url"
  [ "$status" -eq 0 ]
  expect "$set_worktree"$'\n'"$send" "$(calls)"
}

@test "without the agent's terminal, only links the pull request" {
  rm "$state/terminal"
  announce "$url"
  [ "$status" -eq 0 ]
  expect "$set_worktree" "$(calls)"
}
