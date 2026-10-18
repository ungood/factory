#!/usr/bin/env bats
# Tests sdlc/bin/agent against a fake orca whose agent answers the task it's
# sent, and a fake gh and mise.

setup() {
  load helpers
  init

  # The fake orca lists the terminals in $FAKE/terminals.json, where a
  # created terminal runs Claude straight away. It logs what it types to
  # $FAKE/sent, and, sent the task, writes $FAKE/answer.json to the result
  # file, as the agent would.
  fake orca <<'ORCA'
#!/usr/bin/env bash
case "$1 $2" in
  "terminal list") jq -c '{result: {terminals: .}}' "$FAKE/terminals.json" ;;
  "terminal create")
    echo '[{"handle": "term_1", "agentIdentity": "claude"}]' >"$FAKE/terminals.json"
    echo '{"result": {"terminal": {"handle": "term_1"}}}' ;;
  "terminal wait") echo '{"result": {"wait": {"satisfied": true}}}' ;;
  "terminal send")
    echo "$6" >>"$FAKE/sent"
    if [[ "$6" == Read*task.md* ]]; then cp "$FAKE/answer.json" "$RESULT"; fi ;;
  "worktree set") ;;
  *) echo "fake orca: unexpected call: $*" >&2; exit 1 ;;
esac
ORCA
  fake gh <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "repo view") echo ungood/demo ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
  # The fake mise reports the source checkout's environment, which carries
  # CLAUDE_CONFIG_DIR unless $FAKE/no-config exists.
  fake mise <<'MISE'
#!/usr/bin/env bash
if [ -f "$FAKE/no-config" ]; then echo '{}'; else jq -cn --arg dir "$FAKE_CONFIG" '{CLAUDE_CONFIG_DIR: $dir}'; fi
MISE

  git init --quiet "$tmp/demo"
  git -C "$tmp/demo" remote add origin https://github.com/ungood/demo.git
  git init --quiet -b ungood/issue-7 "$tmp/worktree"

  state="$tmp/state/factory/agents/demo-7"
  mkdir -p "$tmp/fake" "$tmp/config" "$state"
  echo "# The issue" >"$state/issue.md"
  echo '[]' >"$tmp/fake/terminals.json"
  echo '{"status": "done", "title": "fix: it", "summary": "Fixed."}' >"$tmp/fake/answer.json"
  export FAKE="$tmp/fake" FAKE_CONFIG="$tmp/config" XDG_STATE_HOME="$tmp/state" \
    FACTORY_POLL_SECONDS=0 RESULT="$state/result.json"
}

agent() { run --separate-stderr "$root/sdlc/bin/agent" "$tmp/demo" 7 "$tmp/worktree"; }

@test "starts Claude on the task and prints its result" {
  agent
  [ "$status" -eq 0 ]
  expect '{"status":"done","title":"fix: it","summary":"Fixed."}' "$output"
}

@test "starts Claude with the source checkout's account, then sends the task" {
  agent
  expect "env CLAUDE_CONFIG_DIR='$tmp/config' mise x -- claude"$'\n'"Read $state/task.md and do what it says." \
    "$(cat "$FAKE/sent")"
  expect term_1 "$(cat "$state/terminal")"
}

@test "writes the task, with the issue" {
  agent
  grep -qF "issue #7 in ungood/demo, in this worktree on branch \`ungood/issue-7\`" "$state/task.md"
  expect "# The issue" "$(tail -n 1 "$state/task.md")"
}

@test "a retried step with a result reads it again, and types nothing" {
  agent
  rm "$FAKE/sent"
  agent
  [ "$status" -eq 0 ]
  expect '{"status":"done","title":"fix: it","summary":"Fixed."}' "$output"
  [ ! -f "$FAKE/sent" ]
}

@test "a retried step whose terminal is gone fails, and starts no other agent" {
  agent
  rm "$RESULT" "$FAKE/sent"
  echo '[]' >"$FAKE/terminals.json"
  agent
  [ "$status" -ne 0 ]
  expect "agent: the agent's terminal term_1 is gone, and there's no $RESULT. Look at $tmp/worktree." "$stderr"
  [ ! -f "$FAKE/sent" ]
}

@test "a blocked agent fails the step" {
  echo '{"status": "blocked", "summary": "stuck"}' >"$FAKE/answer.json"
  agent
  [ "$status" -ne 0 ]
  expect "agent: the agent reported blocked: stuck" "${stderr##*$'\n'}"
}

@test "a source checkout without a Claude account fails, and starts no agent" {
  touch "$FAKE/no-config"
  agent
  [ "$status" -ne 0 ]
  expect "agent: $tmp/demo has no CLAUDE_CONFIG_DIR in its mise environment" "$stderr"
  [ ! -f "$FAKE/sent" ]
}
