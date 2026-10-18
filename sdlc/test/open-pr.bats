#!/usr/bin/env bats
# Tests sdlc/bin/open-pr against a local remote and a fake gh that records
# the pull requests it's asked to open.

setup() {
  load helpers
  init

  # The fake gh serves the branch's pull request from $FAKE_GH/url, if it
  # exists, and records the arguments of a created one in
  # $FAKE_GH/created, one per line.
  fake gh <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") cat "$FAKE_GH/url" 2>/dev/null ;;
  "pr create")
    shift 2
    printf '%s\n' "$@" >"$FAKE_GH/created"
    echo https://github.com/ungood/demo/pull/9 ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
  mkdir -p "$tmp/gh"
  export FAKE_GH="$tmp/gh"

  remote demo
  git -C "$tmp/demo" switch --quiet -c ungood/issue-7
  git -C "$tmp/demo" commit --quiet --allow-empty -m "fix: the thing"
}

open_pr() { run --separate-stderr "$root/sdlc/bin/open-pr" "$tmp/demo" 7 "fix: the thing" "It's fixed."; }
pushed() { expect "$(git -C "$tmp/demo" rev-parse HEAD)" "$(git -C "$tmp/origin.git" rev-parse ungood/issue-7)"; }

@test "a new branch is pushed and gets a draft pull request that closes the issue" {
  open_pr
  [ "$status" -eq 0 ]
  expect https://github.com/ungood/demo/pull/9 "$output"
  expect "$(printf '%s\n' --draft --title "fix: the thing" --body "It's fixed." "" "Closes #7")" "$(cat "$FAKE_GH/created")"
  pushed
}

@test "a branch with a pull request is pushed, and its URL printed" {
  echo https://github.com/ungood/demo/pull/8 >"$FAKE_GH/url"
  open_pr
  [ "$status" -eq 0 ]
  expect https://github.com/ungood/demo/pull/8 "$output"
  [ ! -f "$FAKE_GH/created" ]
  pushed
}
