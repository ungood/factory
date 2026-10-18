#!/usr/bin/env bats
# Checks that the tests use the SDLC's scripts the way a run does: every
# script a workflow in sdlc/*.yaml runs is committed with mode 100755 and run
# by path in at least one test, and no test runs a script through bash or sh,
# which would hide a missing executable bit.
#
# Reads the modes from HEAD, not the working tree, since the commit is what a
# run gets.

setup() {
  load helpers
  init
  cd "$root" || return
  tests=(sdlc/test/*.bats sdlc/test/*.bash)
}

@test "the tests run scripts by path" {
  # Lines, other than comments, that hand a file to a shell instead of
  # running it: a shell, source or . followed by a variable, a path or a .sh
  # file. bash -c and the like run a string, which is fine.
  local file='[[:space:]]+["'\'']?(\$|~|\.{0,2}/|[[:alnum:]_.-]+/|[[:alnum:]_.-]+\.(sh|bash)([[:space:]"'\'']|$))'
  local shell="((^|[^[:alnum:]_./-])(bash|sh|dash|zsh|source)|(^|[;&|({])[[:space:]]*\.)$file"
  local hits
  hits=$(grep -nE "$shell" "${tests[@]}" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
  expect "" "$hits"
}

@test "every script a workflow runs is committed executable and run by path in a test" {
  local scripts
  scripts=$(workflow_scripts)
  [ -n "$scripts" ]

  local code problems="" script mode
  code=$(grep -vhE '^[[:space:]]*#' "${tests[@]}")
  for script in $scripts; do
    mode=$(git ls-tree HEAD -- "$script" | awk '{print $1}')
    case "$mode" in
      100755) ;;
      "") problems+="$script, which a workflow runs, isn't committed"$'\n' ;;
      *) problems+="$script, which a workflow runs, is committed with mode $mode, not 100755"$'\n' ;;
    esac
    if ! grep -qE "/$script([\"'[:space:]]|$)" <<<"$code"; then
      problems+="$script, which a workflow runs, isn't run by path in any test in sdlc/test"$'\n'
    fi
  done
  expect "" "$problems"
}
