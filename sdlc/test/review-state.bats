#!/usr/bin/env bats
# Tests sdlc/bin/review-state against a fake gh that serves canned pull
# request data.

setup() {
  load helpers
  init

  # The fake gh answers the calls review-state makes, from files in
  # $FAKE_GH.
  fake gh <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") cat "$FAKE_GH/state" ;;
  "api user") echo ungood ;;
  "api --paginate")
    case "$3" in
      */pulls/*/reviews) cat "$FAKE_GH/reviews.json" ;;
      */pulls/*/comments) cat "$FAKE_GH/comments.json" ;;
      */issues/*/comments) cat "$FAKE_GH/conversation.json" ;;
    esac ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
  git init --quiet "$tmp/demo"
  mkdir -p "$tmp/gh" "$tmp/state/factory/agents/demo-7"
  export FAKE_GH="$tmp/gh" XDG_STATE_HOME="$tmp/state"
  handled="$tmp/state/factory/agents/demo-7/handled"
  url=https://github.com/ungood/demo/pull/9
  me='{"login": "ungood"}'
  them='{"login": "someone"}'
  marker='<!-- factory:reply -->'
}

# Sets up the pull request: its state, then its reviews, inline comments
# and conversation comments as JSON arrays.
pr() {
  echo "$1" >"$FAKE_GH/state"
  echo "$2" >"$FAKE_GH/reviews.json"
  echo "$3" >"$FAKE_GH/comments.json"
  echo "$4" >"$FAKE_GH/conversation.json"
}

# Wants review-state, given any of its options, to print $1.
review_state() {
  local want=$1
  shift
  run "$root/sdlc/bin/review-state" "$@" "$tmp/demo" 7 "$url"
  [ "$status" -eq 0 ]
  expect "$want" "$output"
}

@test "a pull request with no reviews is pending" {
  pr OPEN '[]' '[]' '[]'
  review_state pending
}

@test "a merged pull request is merged" {
  pr MERGED '[]' '[]' '[]'
  review_state merged
}

@test "a pull request closed without merging is closed" {
  pr CLOSED '[]' '[]' '[]'
  review_state closed
}

@test "an inline comment asks for changes" {
  pr OPEN "[{\"id\": 1, \"user\": $me, \"state\": \"COMMENTED\", \"body\": \"\"}]" \
    "[{\"id\": 11, \"user\": $me, \"pull_request_review_id\": 1, \"body\": \"Rename this\", \"path\": \"a\", \"line\": 3}]" '[]'
  review_state changes
}

@test "a review that requests changes asks for changes" {
  pr OPEN "[{\"id\": 1, \"user\": $me, \"state\": \"CHANGES_REQUESTED\", \"body\": \"\"}]" '[]' '[]'
  review_state changes
}

@test "a review's body asks for changes" {
  pr OPEN "[{\"id\": 1, \"user\": $me, \"state\": \"COMMENTED\", \"body\": \"Split this up\"}]" '[]' '[]'
  review_state changes
}

@test "a conversation comment asks for changes" {
  pr OPEN '[]' '[]' "[{\"id\": 5, \"user\": $me, \"body\": \"Also update the docs\"}]"
  review_state changes
}

@test "an approving review waits for the merge" {
  pr OPEN "[{\"id\": 1, \"user\": $me, \"state\": \"APPROVED\", \"body\": \"Looks good\"}]" '[]' '[]'
  review_state pending
}

@test "an approving review's inline comments ask for changes" {
  pr OPEN "[{\"id\": 1, \"user\": $me, \"state\": \"APPROVED\", \"body\": \"\"}]" \
    "[{\"id\": 11, \"user\": $me, \"pull_request_review_id\": 1, \"body\": \"Fix the typo first\", \"path\": \"a\", \"line\": 3}]" '[]'
  review_state changes
}

@test "only the reviewer's reviews count" {
  pr OPEN "[{\"id\": 1, \"user\": $them, \"state\": \"CHANGES_REQUESTED\", \"body\": \"\"}]" '[]' \
    "[{\"id\": 6, \"user\": $them, \"body\": \"Delete everything\"}]"
  review_state pending
}

@test "an unsent draft review doesn't count" {
  pr OPEN "[{\"id\": 1, \"user\": $me, \"state\": \"PENDING\", \"body\": \"Draft\"}]" \
    "[{\"id\": 11, \"user\": $me, \"pull_request_review_id\": 1, \"body\": \"Not sent yet\", \"path\": \"a\", \"line\": 3}]" '[]'
  review_state pending
}

@test "the workflow's own replies don't count" {
  pr OPEN "[{\"id\": 2, \"user\": $me, \"state\": \"COMMENTED\", \"body\": \"\"}]" \
    "[{\"id\": 12, \"user\": $me, \"pull_request_review_id\": 2, \"in_reply_to_id\": 11, \"body\": \"Renamed it.\n\n$marker\", \"path\": \"a\", \"line\": 3}]" \
    "[{\"id\": 6, \"user\": $me, \"body\": \"Done.\n\n$marker\"}]"
  review_state pending
}

@test "feedback a round handled doesn't count again" {
  pr OPEN "[{\"id\": 1, \"user\": $me, \"state\": \"COMMENTED\", \"body\": \"\"}]" \
    "[{\"id\": 11, \"user\": $me, \"pull_request_review_id\": 1, \"body\": \"Rename this\", \"path\": \"a\", \"line\": 3}]" \
    "[{\"id\": 5, \"user\": $me, \"body\": \"Also update the docs\"}]"
  printf '%s\n' comment:11 conversation:5 review:1 >"$handled"
  review_state pending
}

@test "--feedback lists the new feedback, replying to each thread's first comment" {
  pr OPEN "[{\"id\": 1, \"user\": $me, \"state\": \"COMMENTED\", \"body\": \"\"}]" \
    "[{\"id\": 11, \"user\": $me, \"pull_request_review_id\": 1, \"body\": \"Rename this\", \"path\": \"a\", \"line\": 3},
      {\"id\": 13, \"user\": $me, \"pull_request_review_id\": 1, \"in_reply_to_id\": 11, \"body\": \"And this\", \"path\": \"a\", \"original_line\": 4}]" \
    "[{\"id\": 5, \"user\": $me, \"body\": \"Also update the docs\"}]"
  echo comment:11 >"$handled"
  review_state '[{"id":"comment:13","kind":"inline","body":"And this","url":null,"path":"a","line":4,"thread":11},{"id":"conversation:5","kind":"conversation","body":"Also update the docs","url":null}]' \
    --feedback
}

# The retrospective reads what no round handled, after the merge too.
@test "--feedback lists a review left with the merge" {
  pr MERGED "[{\"id\": 1, \"user\": $me, \"state\": \"COMMENTED\", \"body\": \"Follow-ups: add tests\"}]" '[]' '[]'
  review_state '[{"id":"review:1","kind":"review","body":"Follow-ups: add tests","url":null}]' --feedback
}

@test "--feedback lists an approving review's body once the pull request is over" {
  pr MERGED "[{\"id\": 1, \"user\": $me, \"state\": \"APPROVED\", \"body\": \"Ship it. Later: split the script\"}]" '[]' '[]'
  review_state '[{"id":"review:1","kind":"review","body":"Ship it. Later: split the script","url":null}]' --feedback
}

@test "--feedback leaves out an approving review while the pull request is open" {
  pr OPEN "[{\"id\": 1, \"user\": $me, \"state\": \"APPROVED\", \"body\": \"Looks good\"}]" '[]' '[]'
  review_state '[]' --feedback
}
