#!/usr/bin/env bats
# Tests sdlc/run-tests against a clone of this commit, with one more commit
# that breaks a rule the workflow check enforces, while the working tree
# hides the break.

setup_file() {
  clone="$BATS_FILE_TMPDIR/factory"
  git clone --quiet "$(cd "$BATS_TEST_DIRNAME/../.." && pwd)" "$clone"
  export clone
}

setup() {
  load helpers
  init
  # Starts each test from this commit, with a clean working tree.
  git -C "$clone" reset --quiet --hard "$(git -C "$root" rev-parse HEAD)"
  git -C "$clone" clean --quiet -fdx
  # The workflow check counts any test that names a script's path, this
  # one included, so the scripts below are named through a variable.
  bin=sdlc/bin
}

# Runs the workflow check in the clone, and wants it to fail with $1 in its
# output.
fails_with() {
  run "$clone/sdlc/run-tests" sdlc/test/workflow.bats
  [ "$status" -ne 0 ]
  [[ "$output" == *"$1"* ]]
}

@test "this commit passes" {
  run "$clone/sdlc/run-tests" sdlc/test/workflow.bats
  [ "$status" -eq 0 ]
}

# Git hooks, such as hk's pre-push, run with GIT_DIR and the like set to
# the repo being pushed, which would point the tests' own git at it.
@test "this commit passes from inside another repo's git hook" {
  git init --quiet "$tmp/other"
  GIT_DIR="$tmp/other/.git" GIT_WORK_TREE="$tmp/other" GIT_INDEX_FILE="$tmp/other/.git/index" \
    run "$clone/sdlc/run-tests" sdlc/test/workflow.bats sdlc/test/review-state.bats
  [ "$status" -eq 0 ]
}

@test "a commit that drops a script's executable bit fails, though the working tree has it" {
  git -C "$clone" update-index --chmod=-x "$bin/reply"
  git -C "$clone" commit --quiet -m "drop reply's executable bit"
  chmod +x "$clone/$bin/reply"
  fails_with "$bin/reply, which a workflow runs, is committed with mode 100644, not 100755"
}

@test "a working tree that drops a script's executable bit passes, since the commit has it" {
  chmod -x "$clone/$bin/reply"
  run "$clone/sdlc/run-tests" sdlc/test/workflow.bats
  [ "$status" -eq 0 ]
}

@test "a test that runs a script through bash fails" {
  # shellcheck disable=SC2016 # The line is for the test, which expands it.
  printf '\nbash "$root/%s/gate"\n' "$bin" >>"$clone/sdlc/test/gate.bats"
  git -C "$clone" commit --quiet -am "run gate through bash"
  fails_with 'sdlc/test/gate.bats'
  [[ "$output" == *"bash \"\$root/$bin/gate\""* ]]
}

@test "a workflow that runs a script no test runs fails" {
  cp "$clone/$bin/gate" "$clone/$bin/untested"
  sed "s#$bin/gate#$bin/untested#" "$clone/sdlc/implement.yaml" >"$clone/sdlc/untested.yaml"
  git -C "$clone" add "$bin/untested" sdlc/untested.yaml
  git -C "$clone" commit --quiet -m "run a script no test runs"
  fails_with "$bin/untested, which a workflow runs, isn't run by path in any test"
}

@test "a workflow that runs a script that's only in the working tree fails" {
  cp "$clone/$bin/gate" "$clone/$bin/uncommitted"
  sed "s#$bin/gate#$bin/uncommitted#" "$clone/sdlc/implement.yaml" >"$clone/sdlc/uncommitted.yaml"
  # shellcheck disable=SC2016 # The line is for the test, which expands it.
  printf '\n"$root/%s/uncommitted"\n' "$bin" >>"$clone/sdlc/test/gate.bats"
  git -C "$clone" add sdlc/uncommitted.yaml sdlc/test/gate.bats
  git -C "$clone" commit --quiet -m "run a script that isn't committed"
  fails_with "$bin/uncommitted, which a workflow runs, isn't committed"
}
