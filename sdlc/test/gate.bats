#!/usr/bin/env bats
# Tests sdlc/bin/gate against throwaway repos whose mise tasks record that
# they ran.

setup() {
  load helpers
  init
  # Keep the user's mise config and trust list out of the throwaway repos.
  # Tools shimmed by mise still read this checkout's config, so trust it.
  export MISE_CONFIG_DIR="$tmp/mise-config" MISE_GLOBAL_CONFIG_FILE="$tmp/mise-config/config.toml" \
    MISE_STATE_DIR="$tmp/mise-state" MISE_TRUSTED_CONFIG_PATHS="$root"
}

# Makes a repo with one commit beyond origin/main, whose mise.toml is $1.
# Each task appends its name to ran.log, which git ignores.
repo() {
  local dir="$tmp/repo"
  git init --quiet -b main "$dir"
  printf 'ran.log\n' >"$dir/.gitignore"
  git -C "$dir" add .gitignore
  git -C "$dir" commit --quiet -m base
  git -C "$dir" update-ref refs/remotes/origin/main HEAD
  printf '%s\n' "$1" >"$dir/mise.toml"
  git -C "$dir" add mise.toml
  git -C "$dir" commit --quiet -m work
}

# Runs the gate on the repo, and prints whether it passed and which tasks
# ran.
gate() {
  local result=passed
  "$root/sdlc/bin/gate" "$tmp/repo" >"$tmp/gate.out" 2>&1 || result=failed
  echo "$result: $(paste -sd, "$tmp/repo/ran.log" 2>/dev/null || true)"
}

@test "a repo without ci runs lint and test" {
  repo '
[tasks.lint]
run = "echo lint >>ran.log"
[tasks.test]
run = "echo test >>ran.log"'
  expect "passed: lint,test" "$(gate)"
}

@test "a repo with ci runs only ci" {
  repo '
[tasks.ci]
run = "echo ci >>ran.log"
[tasks.lint]
run = "echo lint >>ran.log"
[tasks.test]
run = "echo test >>ran.log"'
  expect "passed: ci" "$(gate)"
}

@test "a failing ci task fails the gate" {
  repo '
[tasks.ci]
run = ["echo ci >>ran.log", "exit 1"]'
  expect "failed: ci" "$(gate)"
}

@test "a missing lint task is skipped" {
  repo '
[tasks.test]
run = "echo test >>ran.log"'
  expect "passed: test" "$(gate)"
}
