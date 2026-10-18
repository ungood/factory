#!/usr/bin/env bats
# Tests sdlc/bin/show-review against a fake orca that records the comment and
# status it's asked to set, and one that always fails.

setup() {
  load helpers
  init

  # Records "<worktree>|<status>|<comment>|<unread>" for each worktree set.
  fake orca <<'ORCA'
#!/usr/bin/env bash
[ "$1 $2" = "worktree set" ] || { echo "fake orca: unexpected call: $*" >&2; exit 1; }
[ -n "${FAKE_ORCA_FAIL-}" ] && exit 1
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
echo "$worktree|$status|$comment|$unread" >"$FAKE_ORCA"
ORCA
  export FAKE_ORCA="$tmp/set"
}

# Runs show-review with the rest of the arguments, and wants the line the
# fake orca recorded to match the pattern $1.
shows() {
  local want=$1
  shift
  run "$root/sdlc/bin/show-review" "$@"
  [ "$status" -eq 0 ]
  [[ "$(cat "$FAKE_ORCA")" =~ ^$want$ ]]
}

@test "pending says when the next check is" {
  shows "path:/w\|in-review\|Waiting for review, next check [0-2][0-9]:[0-5][0-9]\|no" /w pending 2 5
}

@test "a trailing newline on the state doesn't matter" {
  shows "path:/w\|in-review\|Waiting for review, next check [0-2][0-9]:[0-5][0-9]\|no" /w $'pending\n' 2 5
}

@test "changes says the round is starting" {
  shows "path:/w\|in-progress\|Round 3: sending the new feedback to the agent\|no" /w changes 3 5
}

@test "merged says the retrospective is running" {
  shows "path:/w\|in-review\|PR merged, running the retrospective\|no" /w merged 2 5
}

@test "closed says the worktree stays" {
  shows "path:/w\|in-review\|PR closed without merging, so the worktree stays\|no" /w closed 2 5
}

@test "the next check time counts from now" {
  before=$(date +%H:%M)
  run "$root/sdlc/bin/show-review" /w pending 2 0
  after=$(date +%H:%M)
  [ "$status" -eq 0 ]
  got=$(cut -d'|' -f3 "$FAKE_ORCA")
  [ "$got" = "Waiting for review, next check $before" ] || [ "$got" = "Waiting for review, next check $after" ]
}

@test "an Orca failure doesn't fail the step" {
  FAKE_ORCA_FAIL=1 run "$root/sdlc/bin/show-review" /w pending 2 5
  [ "$status" -eq 0 ]
}

@test "an unknown state doesn't fail the step" {
  run "$root/sdlc/bin/show-review" /w surprise 2 5
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_ORCA" ]
}
