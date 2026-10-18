#!/usr/bin/env bats
# Tests sdlc/bin/prepare against a fake orca that makes plain git worktrees,
# and a fake gh that serves a canned issue.

setup() {
  load helpers
  init

  fake gh <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "repo view") echo ungood/demo ;;
  "issue view") printf '# Demo issue\n\nDo the thing.\n' ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
  # The fake orca knows every repo under $FAKE_ROOT, and keeps its
  # worktrees in $FAKE_ORCA/<repo>.json. Each create is logged to
  # $FAKE_ORCA/creates.
  fake orca <<'ORCA'
#!/usr/bin/env bash
arg() { local want=$1; shift; while [ $# -gt 0 ]; do [ "$1" = "$want" ] && { echo "$2"; return; }; shift; done; }
list() { cat "$FAKE_ORCA/$1.json" 2>/dev/null || echo '[]'; }
case "$1 $2" in
  "repo list")
    for d in "$FAKE_ROOT"/*/.git; do d=$(dirname "$d"); jq -n --arg p "$d" --arg id "$(basename "$d")" '{id: $id, path: $p}'; done |
      jq -s '{result: {repos: .}}' ;;
  "worktree list")
    id=$(arg --repo "$@"); id=${id#id:}
    list "$id" | jq '{result: {worktrees: .}}' ;;
  "worktree create")
    id=$(arg --repo "$@"); id=${id#id:}; name=$(arg --name "$@")
    path="$FAKE_ROOT/worktrees/$name"
    git -C "$FAKE_ROOT/$id" worktree add --quiet -b "test/$name" "$path" >&2 || exit 1
    echo "$name" >>"$FAKE_ORCA/creates"
    wt=$(jq -n --arg p "$path" --arg b "refs/heads/test/$name" --arg id "$id::$path" '{id: $id, path: $p, branch: $b}')
    list "$id" | jq --argjson wt "$wt" '. + [$wt]' >"$FAKE_ORCA/$id.json.tmp"
    mv "$FAKE_ORCA/$id.json.tmp" "$FAKE_ORCA/$id.json"
    jq -n --argjson wt "$wt" '{result: {worktree: $wt}}' ;;
  *) echo "fake orca: unexpected call: $*" >&2; exit 1 ;;
esac
ORCA
  mkdir -p "$tmp/orca" "$tmp/worktrees"
  export FAKE_ORCA="$tmp/orca" FAKE_ROOT="$tmp" XDG_STATE_HOME="$tmp/state"
  # Keep the user's mise config and trust list out of the throwaway repos.
  # Tools shimmed by mise still read this checkout's config, so trust it.
  export MISE_CONFIG_DIR="$tmp/mise-config" MISE_GLOBAL_CONFIG_FILE="$tmp/mise-config/config.toml" \
    MISE_STATE_DIR="$tmp/mise-state" MISE_TRUSTED_CONFIG_PATHS="$root"
}

# Makes a repo whose committed mise.toml is $2. Each task appends its name
# to ran.log, which git ignores.
repo() {
  local dir="$tmp/$1"
  git init --quiet -b main "$dir"
  git -C "$dir" remote add origin "https://github.com/ungood/$1.git"
  printf 'ran.log\n' >"$dir/.gitignore"
  printf '%s\n' "$2" >"$dir/mise.toml"
  git -C "$dir" add .gitignore mise.toml
  git -C "$dir" commit --quiet -m base
}

prepare() { run --separate-stderr "$root/sdlc/bin/prepare" "$tmp/$1" "$2"; }

install='
[tasks.install]
run = "echo install >>ran.log"'

@test "prints the worktree and its branch" {
  repo app "$install"
  prepare app 7
  [ "$status" -eq 0 ]
  expect "{\"worktree\":\"$tmp/worktrees/issue-7\",\"branch\":\"test/issue-7\"}" "$output"
}

@test "runs the repo's install task in the worktree" {
  repo app "$install"
  prepare app 7
  expect install "$(cat "$tmp/worktrees/issue-7/ran.log")"
}

@test "saves the issue for the agent" {
  repo app "$install"
  prepare app 7
  expect "# Demo issue" "$(head -1 "$tmp/state/factory/agents/app-7/issue.md")"
}

@test "a retry reuses the worktree, and creates no second one" {
  repo app "$install"
  prepare app 7
  prepare app 7
  [ "$status" -eq 0 ]
  expect "{\"worktree\":\"$tmp/worktrees/issue-7\",\"branch\":\"test/issue-7\"}" "$output"
  expect issue-7 "$(cat "$tmp/orca/creates")"
}

@test "a repo without an install task is ready as it is" {
  repo plain '
[tasks.test]
run = "echo test >>ran.log"'
  prepare plain 8
  [ "$status" -eq 0 ]
  expect "{\"worktree\":\"$tmp/worktrees/issue-8\",\"branch\":\"test/issue-8\"}" "$output"
}

@test "a failing install task fails the step, with its output in the log" {
  repo broken '
[tasks.install]
run = ["echo the registry is down", "exit 1"]'
  prepare broken 9
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"the registry is down"* ]]
}
