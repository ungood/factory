#!/usr/bin/env bats
# Tests sdlc/bin/reply against a local remote, a fake gh that records the
# replies it's asked to post, and a fake orca.

setup() {
  load helpers
  init

  # The fake gh appends each reply to $FAKE/posted as {where, body}, and
  # fails to post one whose body contains "unpostable".
  fake gh <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "api -X")
    body=${6#body=}
    [[ "$body" != *unpostable* ]] || exit 1
    jq -cn --arg where "$4" --arg body "$body" '{$where, $body}' >>"$FAKE/posted"
    echo "https://github.com/ungood/demo/pull/9#discussion_r1" ;;
  "pr comment")
    [[ "$5" != *unpostable* ]] || exit 1
    jq -cn --arg where "$3" --arg body "$5" '{$where, $body}' >>"$FAKE/posted"
    echo "https://github.com/ungood/demo/pull/9#issuecomment-1" ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
  fake orca <<'ORCA'
#!/usr/bin/env bash
echo "$*" >>"$FAKE/orca"
ORCA

  remote demo
  git -C "$tmp/demo" worktree add --quiet -b ungood/issue-7 "$tmp/worktree" main
  git -C "$tmp/worktree" push --quiet origin ungood/issue-7
  git -C "$tmp/worktree" commit --quiet --allow-empty -m "fix: rename"

  state="$tmp/state/factory/agents/demo-7"
  mkdir -p "$tmp/fake" "$state"
  export FAKE="$tmp/fake" XDG_STATE_HOME="$tmp/state"
  url=https://github.com/ungood/demo/pull/9
  marker='<!-- factory:reply -->'
  cat >"$state/feedback-2.json" <<'JSON'
[
  {"id": "c1", "kind": "inline", "thread": 11, "body": "Rename this."},
  {"id": "c2", "kind": "conversation", "body": "Why?\nReally?"},
  {"id": "c3", "kind": "review", "body": "Unpostable."}
]
JSON
  cat >"$state/result-2.json" <<'JSON'
{"status": "done", "replies": [
  {"id": "c1", "body": "Renamed."},
  {"id": "c2", "body": "Because."},
  {"id": "c3", "body": "unpostable"},
  {"id": "c9", "body": "Not in the feedback."}
]}
JSON
}

reply() { run --separate-stderr "$root/sdlc/bin/reply" "$tmp/demo" 7 "$tmp/worktree" "$url"$'\n' 2; }

@test "replies in an inline comment's thread, and quotes other feedback" {
  reply
  [ "$status" -eq 0 ]
  expect "$(jq -cn --arg m "$marker" --arg url "$url" '
    {where: "repos/ungood/demo/pulls/9/comments/11/replies", body: "Renamed.\n\n\($m)"},
    {where: $url, body: "> Why?\n> Really?\n\nBecause.\n\n\($m)"}')" "$(cat "$FAKE/posted")"
}

@test "pushes the round's fixes" {
  reply
  expect "$(git -C "$tmp/worktree" rev-parse HEAD)" "$(git -C "$tmp/origin.git" rev-parse ungood/issue-7)"
}

@test "moves the worktree back to in-review" {
  reply
  grep -q "worktree set --worktree path:$tmp/worktree .*--workspace-status in-review" "$FAKE/orca"
}

@test "a reply to feedback that wasn't in the round is logged and skipped" {
  reply
  [[ "$stderr" == *c9* ]]
  run ! grep -q "Not in the feedback" "$FAKE/posted"
}

@test "a retried round posts only what it couldn't post before" {
  reply
  rm "$FAKE/posted"
  jq '(.replies[] | select(.id == "c3")).body = "Fine."' "$state/result-2.json" >"$tmp/result"
  mv "$tmp/result" "$state/result-2.json"
  reply
  [ "$status" -eq 0 ]
  expect "$(jq -cn --arg m "$marker" --arg url "$url" '{where: $url, body: "> Unpostable.\n\nFine.\n\n\($m)"}')" \
    "$(cat "$FAKE/posted")"
}

@test "a failed push fails the step" {
  rm -rf "$tmp/origin.git"
  reply
  [ "$status" -ne 0 ]
}
