#!/usr/bin/env bats
# Tests sdlc/bin/check-pr against a local remote, a fake gh that serves the
# branch's pull request, and a fake orca whose agent can fix what it's sent.

setup() {
  load helpers
  init

  # The fake gh serves the pull request in $FAKE/pr.json, if it exists, and
  # records each pull request it's asked about in $FAKE/viewed.
  fake gh <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view")
    shift 2
    echo "$*" >>"$FAKE/viewed"
    if [ -f "$FAKE/pr.json" ]; then cat "$FAKE/pr.json"; else echo "no pull requests found" >&2; exit 1; fi ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
  # The fake orca lists the terminals in $FAKE/terminals.json, logs what it
  # types to $FAKE/sent and its other calls to $FAKE/calls. Sent a task, it
  # runs $FAKE/fix, if it exists, in the worktree, then writes
  # $FAKE/answer.json to the result file, as the agent would.
  fake orca <<'ORCA'
#!/usr/bin/env bash
case "$1 $2" in
  "terminal list") jq -c '{result: {terminals: .}}' "$FAKE/terminals.json" ;;
  "terminal wait") echo '{"result": {"wait": {"satisfied": true}}}' ;;
  "terminal send")
    echo "$6" >>"$FAKE/sent"
    if [ -x "$FAKE/fix" ]; then (cd "$WORKTREE" && "$FAKE/fix"); fi
    cp "$FAKE/answer.json" "$RESULT" ;;
  *) printf '%s\n' "$*" >>"$FAKE/calls" ;;
esac
ORCA

  remote demo
  git -C "$tmp/demo" switch --quiet -c ungood/issue-7
  git -C "$tmp/demo" commit --quiet --allow-empty -m "fix: the thing"
  git -C "$tmp/demo" push --quiet origin ungood/issue-7

  state="$tmp/state/factory/agents/demo-7"
  mkdir -p "$tmp/fake" "$state"
  echo term_1 >"$state/terminal"
  echo '[{"handle": "term_1", "agentIdentity": "claude"}]' >"$tmp/fake/terminals.json"
  echo '{"status": "done", "summary": "Fixed."}' >"$tmp/fake/answer.json"
  url=https://github.com/ungood/demo/pull/9
  export FAKE="$tmp/fake" XDG_STATE_HOME="$tmp/state" FACTORY_POLL_SECONDS=0 \
    WORKTREE="$tmp/demo" RESULT="$state/check-1.json"
  serve
}

# Serves the pull request with its head at $1, or the worktree's HEAD.
serve() {
  jq -cn --arg url "$url" --arg head "${1:-$(git -C "$tmp/demo" rev-parse HEAD)}" \
    '{url: $url, headRefOid: $head}' >"$FAKE/pr.json"
}

# Makes the agent's fix the script on stdin.
fix() {
  cat >"$FAKE/fix"
  chmod +x "$FAKE/fix"
}

check() { run --separate-stderr "$root/sdlc/bin/check-pr" "$tmp/demo" 7 "$tmp/demo" "$1" "${2:-1}"; }
sent() { cat "$FAKE/sent" 2>/dev/null || true; }

@test "a pushed, committed pull request passes, and its URL is printed" {
  check "$url"$'\n'
  [ "$status" -eq 0 ]
  expect "$url" "$output"
  expect "" "$(sent)"
}

@test "without a URL, finds the branch's pull request" {
  check ""
  [ "$status" -eq 0 ]
  expect "$url" "$output"
  expect "--json url,headRefOid" "$(cat "$FAKE/viewed")"
}

@test "uncommitted changes go back to the agent, who fixes them" {
  touch "$tmp/demo/stray"
  fix <<'FIX'
#!/usr/bin/env bash
git add stray && git commit --quiet -m "chore: add stray" && git push --quiet origin HEAD
FIX
  # The fake gh serves whatever the remote's branch is.
  fake gh <<'GH'
#!/usr/bin/env bash
jq -cn --arg head "$(git -C "$WORKTREE" rev-parse origin/ungood/issue-7)" \
  '{url: "https://github.com/ungood/demo/pull/9", headRefOid: $head}'
GH
  check "$url"
  [ "$status" -eq 0 ]
  expect "$url" "$output"
  expect "Read $state/check-1.md and do what it says." "$(sent)"
  grep -qF "uncommitted changes" "$state/check-1.md"
  grep -qF "?? stray" "$state/check-1.md"
}

@test "a head that isn't the worktree's HEAD goes back to the agent" {
  local old
  old=$(git -C "$tmp/demo" rev-parse HEAD)
  git -C "$tmp/demo" commit --quiet --allow-empty -m "fix: more"
  serve "$old"
  fix <<FIX
#!/usr/bin/env bash
echo '{"url": "$url", "headRefOid": "'\$(git rev-parse HEAD)'"}' >"$FAKE/pr.json"
FIX
  check "$url"
  [ "$status" -eq 0 ]
  grep -qF "$url's head is $old, but the worktree's HEAD is $(git -C "$tmp/demo" rev-parse HEAD)" "$state/check-1.md"
}

@test "a missing pull request goes back to the agent" {
  rm "$FAKE/pr.json"
  fix <<FIX
#!/usr/bin/env bash
echo '{"url": "$url", "headRefOid": "'\$(git rev-parse HEAD)'"}' >"$FAKE/pr.json"
FIX
  check ""
  [ "$status" -eq 0 ]
  expect "$url" "$output"
  grep -qF "There's no pull request for the branch \`ungood/issue-7\`" "$state/check-1.md"
}

@test "a problem the agent doesn't fix fails the step, after asking once" {
  touch "$tmp/demo/stray"
  check "$url"
  [ "$status" -ne 0 ]
  expect "Read $state/check-1.md and do what it says." "$(sent)"
  [[ "$stderr" == *"check-pr: the agent didn't fix"*"uncommitted changes"* ]]
}

@test "a retried step doesn't ask the agent twice" {
  touch "$tmp/demo/stray"
  check "$url"
  rm "$FAKE/sent"
  check "$url"
  [ "$status" -ne 0 ]
  expect "" "$(sent)"
}

@test "a blocked agent fails the step" {
  touch "$tmp/demo/stray"
  echo '{"status": "blocked", "summary": "stuck"}' >"$FAKE/answer.json"
  check "$url"
  [ "$status" -ne 0 ]
  expect "check-pr: the agent reported blocked: stuck" "${stderr##*$'\n'}"
}

@test "without the agent's terminal, a problem fails the step" {
  rm "$state/terminal"
  touch "$tmp/demo/stray"
  check "$url"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"there's no $state/terminal"* ]]
  expect "" "$(sent)"
}

@test "each round has its own task and result" {
  touch "$tmp/demo/stray"
  RESULT="$state/check-2.json" check "$url" 2
  [ "$status" -ne 0 ]
  expect "Read $state/check-2.md and do what it says." "$(sent)"
  [ -f "$state/check-2.json" ]
}

@test "a round that passes is ready for another review in Orca" {
  check "$url" 2
  [ "$status" -eq 0 ]
  expect "worktree set --worktree path:$tmp/demo --comment PR #9 is ready for another review (round 2) --workspace-status in-review --unread --json" \
    "$(cat "$FAKE/calls")"
}

@test "the first pass leaves Orca to the announce step" {
  check "$url"
  [ "$status" -eq 0 ]
  [ ! -f "$FAKE/calls" ]
}
