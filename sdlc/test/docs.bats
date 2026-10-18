#!/usr/bin/env bats
# Checks that each step of the SDLC has a doc of its own, so a pull request
# that adds or changes a step edits only that step's doc. docs/sdlc.md is an
# overview: it links every step doc and doesn't number the steps, since
# renumbering a list rewrites the lines that describe other steps.

setup() {
  load helpers
  init
  cd "$root" || return
}

@test "every script a workflow runs has its own doc in sdlc/docs" {
  local problems="" script
  for script in $(workflow_scripts); do
    if [ ! -f "sdlc/docs/$(basename "$script").md" ]; then
      problems+="$script, which a workflow runs, has no sdlc/docs/$(basename "$script").md"$'\n'
    fi
  done
  expect "" "$problems"
}

@test "the overview links every step doc" {
  local problems="" doc
  for doc in sdlc/docs/*.md; do
    if ! grep -qF "](../$doc)" docs/sdlc.md; then
      problems+="docs/sdlc.md doesn't link $doc"$'\n'
    fi
  done
  expect "" "$problems"
}

@test "the overview doesn't number the steps" {
  local hits
  hits=$(grep -nE '^[[:space:]]*[0-9]+\.[[:space:]].*\]\(\.\./sdlc/' docs/sdlc.md || true)
  expect "" "$hits"
}

@test "the overview leaves the scripts to the step docs" {
  local hits
  hits=$(grep -nF '](../sdlc/bin/' docs/sdlc.md || true)
  expect "" "$hits"
}
