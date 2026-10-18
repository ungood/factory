#!/usr/bin/env bats
# Tests sdlc/bin/show-review against a fake orca that records the comment and
# status it's asked to set, and can fail.

setup() {
  load helpers
  init

  # The fake orca writes "<worktree>|<status>|<comment>|<unread>" to
  # $FAKE/set for each worktree set, and fails if $FAKE/fail exists.
  fake orca <<'ORCA'
#!/usr/bin/env bash
[ "$1 $2" = "worktree set" ] || { echo "fake orca: unexpected call: $*" >&2; exit 1; }
[ -f "$FAKE/fail" ] && exit 1
shift 2
worktree= status= comment= unread=no
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree) worktree=$2; shift ;;
    --workspace-status) status=$2; shift ;;
    --comment) comment=$2; shift ;;
    --unread) unread=yes ;;
  esac
  shift
done
echo "$worktree|$status|$comment|$unread" >"$FAKE/set"
ORCA
  mkdir -p "$tmp/fake"
  export FAKE="$tmp/fake"
}

show() { run "$root/sdlc/bin/show-review" "$@"; }
shown() { cat "$FAKE/set" 2>/dev/null || echo nothing; }

@test "pending says when the next check is" {
  show /w pending 2 5
  [ "$status" -eq 0 ]
  [[ "$(shown)" =~ ^path:/w\|in-review\|Waiting\ for\ review,\ next\ check\ [0-2][0-9]:[0-5][0-9]\|no$ ]]
}

@test "a trailing newline on the state doesn't matter" {
  show /w $'pending\n' 2 5
  [ "$status" -eq 0 ]
  [[ "$(shown)" =~ ^path:/w\|in-review\|Waiting\ for\ review,\ next\ check\ [0-2][0-9]:[0-5][0-9]\|no$ ]]
}

@test "the next check time counts from now" {
  local before after
  before=$(date +%H:%M)
  show /w pending 2 0
  after=$(date +%H:%M)
  [ "$(shown)" = "path:/w|in-review|Waiting for review, next check $before|no" ] ||
    expect "path:/w|in-review|Waiting for review, next check $after|no" "$(shown)"
}

@test "changes says the round is starting" {
  show /w changes 3 5
  [ "$status" -eq 0 ]
  expect "path:/w|in-progress|Round 3: sending the new feedback to the agent|no" "$(shown)"
}

@test "merged says the retrospective is running" {
  show /w merged 2 5
  [ "$status" -eq 0 ]
  expect "path:/w|in-review|PR merged, running the retrospective|no" "$(shown)"
}

@test "closed says the worktree stays" {
  show /w closed 2 5
  [ "$status" -eq 0 ]
  expect "path:/w|in-review|PR closed without merging, so the worktree stays|no" "$(shown)"
}

@test "an Orca failure doesn't fail the step" {
  touch "$FAKE/fail"
  show /w pending 2 5
  [ "$status" -eq 0 ]
}

@test "an unknown state doesn't fail the step, and changes nothing" {
  show /w surprise 2 5
  [ "$status" -eq 0 ]
  expect nothing "$(shown)"
}
