#!/usr/bin/env bats
# Tests sdlc/bin/cleanup against a fake gh that serves a canned pull request
# and a fake orca that records the worktrees it's asked to remove.

setup() {
  load helpers
  init

  fake gh <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") cat "$FAKE_GH/pr" ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
  fake orca <<'ORCA'
#!/usr/bin/env bash
case "$1 $2" in
  "worktree rm") echo "$4" >>"$FAKE_ORCA" ;;
esac
ORCA
  mkdir -p "$tmp/gh"
  export FAKE_GH="$tmp/gh" FAKE_ORCA="$tmp/removed"
  url=https://github.com/ungood/demo/pull/9
  remote demo
}

# Makes a worktree on a new branch with one commit, pushed to the remote,
# and serves a pull request in the given state whose head is that commit.
worktree() {
  local name=$1 state=$2
  git -C "$tmp/demo" worktree add --quiet -b "$name" "$tmp/$name" main
  git -C "$tmp/$name" commit --quiet --allow-empty -m "work on $name"
  git -C "$tmp/$name" push --quiet origin "$name"
  echo "$state $(git -C "$tmp/$name" rev-parse HEAD)" >"$FAKE_GH/pr"
}

# Deletes the worktree's remote branch, as GitHub does after a merge.
delete_remote_branch() {
  git -C "$tmp/demo" push --quiet origin --delete "$1"
  git -C "$tmp/demo" fetch --quiet --prune
}

# Runs cleanup on the worktree $1, which never fails, then wants the
# worktree to be $2, removed or kept.
cleanup() {
  run "$root/sdlc/bin/cleanup" "$tmp/demo" "$tmp/$1" "$1" "$url"$'\n'
  [ "$status" -eq 0 ]
  local got=kept
  if [ -f "$FAKE_ORCA" ] && grep -qxF "path:$tmp/$1" "$FAKE_ORCA"; then got=removed; fi
  expect "$2" "$got"
}

@test "a worktree merged with a merge commit is removed" {
  # A merge commit keeps the branch's commits, so they're on main's remote.
  worktree merged MERGED
  git -C "$tmp/demo" push --quiet origin merged:main
  delete_remote_branch merged
  cleanup merged removed
}

@test "a worktree squash merged is removed" {
  # A squash merge puts a new commit on main, so the branch's commits are
  # on no remote once its remote branch is gone.
  worktree squashed MERGED
  git -C "$tmp/demo" pull --quiet
  git -C "$tmp/demo" commit --quiet --allow-empty -m "squashed"
  git -C "$tmp/demo" push --quiet origin main
  delete_remote_branch squashed
  cleanup squashed removed
}

@test "a worktree with commits that never reached the pull request is kept" {
  worktree unpushed MERGED
  git -C "$tmp/unpushed" commit --quiet --allow-empty -m "never pushed"
  delete_remote_branch unpushed
  cleanup unpushed kept
}

@test "a squash merged worktree with uncommitted changes is kept" {
  worktree dirty MERGED
  delete_remote_branch dirty
  touch "$tmp/dirty/new-file"
  cleanup dirty kept
}

@test "a worktree whose pull request isn't merged is kept" {
  worktree open OPEN
  delete_remote_branch open
  cleanup open kept
}
