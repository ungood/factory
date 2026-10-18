#!/usr/bin/env bats
# Tests sdlc/bin/revise against a fake orca whose agent answers the feedback
# it's sent, and a fake gh that serves the reviewer's feedback.

setup() {
  load helpers
  init

  # The fake orca lists the terminals in $FAKE/terminals.json, logs what it
  # types to $FAKE/sent, and, sent a task, writes $FAKE/answer.json to the
  # round's result file, as the agent would.
  fake orca <<'ORCA'
#!/usr/bin/env bash
case "$1 $2" in
  "terminal list") jq -c '{result: {terminals: .}}' "$FAKE/terminals.json" ;;
  "terminal wait") echo '{"result": {"wait": {"satisfied": true}}}' ;;
  "terminal send")
    echo "$6" >>"$FAKE/sent"
    cp "$FAKE/answer.json" "$RESULT" ;;
  "worktree set") ;;
  *) echo "fake orca: unexpected call: $*" >&2; exit 1 ;;
esac
ORCA
  # The fake gh serves one inline comment from the reviewer.
  fake gh <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") echo OPEN ;;
  "api user") echo ungood ;;
  "api --paginate")
    case "$3" in
      */pulls/*/comments) echo '[{"id": 5, "user": {"login": "ungood"}, "body": "Rename this.", "path": "a", "line": 1, "html_url": "u"}]' ;;
      *) echo '[]' ;;
    esac ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
  git init --quiet "$tmp/demo"

  state="$tmp/state/factory/agents/demo-7"
  mkdir -p "$tmp/fake" "$state"
  echo term_1 >"$state/terminal"
  echo '[{"handle": "term_1", "agentIdentity": "claude"}]' >"$tmp/fake/terminals.json"
  echo '{"status": "done", "replies": []}' >"$tmp/fake/answer.json"
  export FAKE="$tmp/fake" XDG_STATE_HOME="$tmp/state" FACTORY_POLL_SECONDS=0 RESULT="$state/result-2.json"
  url=https://github.com/ungood/demo/pull/9
}

revise() { run --separate-stderr "$root/sdlc/bin/revise" "$tmp/demo" 7 /worktree "$url"$'\n' 2; }

@test "sends the feedback to the agent and prints its result" {
  revise
  [ "$status" -eq 0 ]
  expect '{"status":"done","replies":[]}' "$output"
  expect "Read $state/review-2.md and do what it says." "$(cat "$FAKE/sent")"
}

@test "the task says to push, and to reply to each item with the marker" {
  revise
  grep -qF "Commit your work with conventional commit messages, and push it." "$state/review-2.md"
  grep -qF "gh api -X POST repos/ungood/demo/pulls/9/comments/<thread>/replies" "$state/review-2.md"
  grep -qF "End every reply with the line \`<!-- factory:reply -->\`" "$state/review-2.md"
}

@test "writes the round's feedback, and records it as handled" {
  revise
  expect '[{"kind":"inline","body":"Rename this."}]' "$(jq -c '[.[] | {kind, body}]' "$state/feedback-2.json")"
  expect "$(jq -r '.[].id' "$state/feedback-2.json")" "$(cat "$state/handled")"
}

@test "a retried round waits for the result without sending the feedback twice" {
  revise
  rm "$FAKE/sent" "$RESULT"
  "$root/sdlc/bin/revise" "$tmp/demo" 7 /worktree "$url" 2 >"$tmp/retried" 2>/dev/null &
  sleep 1
  echo '{"status": "done", "replies": []}' >"$RESULT"
  wait $!
  [ ! -f "$FAKE/sent" ]
  expect '{"status":"done","replies":[]}' "$(cat "$tmp/retried")"
}

@test "a blocked agent fails the round" {
  echo '{"status": "blocked", "summary": "stuck"}' >"$FAKE/answer.json"
  revise
  [ "$status" -ne 0 ]
  expect "revise: the agent reported blocked: stuck" "${stderr##*$'\n'}"
}

@test "a terminal that no longer runs Claude fails the round, unsent" {
  echo '[{"handle": "term_1"}]' >"$FAKE/terminals.json"
  revise
  [ "$status" -ne 0 ]
  expect "revise: the agent's terminal term_1 runs a shell, not Claude, so nobody can address the feedback in $state/feedback-2.json. Starting a fresh agent isn't supported yet." \
    "${stderr##*$'\n'}"
  [ ! -f "$FAKE/sent" ]
}

@test "a closed terminal fails the round" {
  echo '[]' >"$FAKE/terminals.json"
  revise
  [ "$status" -ne 0 ]
  expect "revise: the agent's terminal term_1 has closed, so nobody can address the feedback in $state/feedback-2.json. Starting a fresh agent isn't supported yet." \
    "${stderr##*$'\n'}"
}
