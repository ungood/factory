#!/usr/bin/env bats
# Tests sdlc/bin/await-result against a fake orca whose terminal list and
# wait answer from files, and can write the result file the way an agent
# would.

setup() {
  load helpers
  init

  # The fake orca lists the terminals in $FAKE_ORCA/terminals.json. Before
  # it answers a list, it runs the script $FAKE_ORCA/on-list once, if it
  # exists. A wait runs $FAKE_ORCA/on-wait the same way, then answers with
  # the next line of $FAKE_ORCA/waits, true or false.
  fake orca <<'ORCA'
#!/usr/bin/env bash
once() {
  if [ -f "$FAKE_ORCA/$1" ]; then
    "$FAKE_ORCA/$1"
    rm "$FAKE_ORCA/$1"
  fi
}
case "$1 $2" in
  "terminal list")
    once on-list
    jq -c '{result: {terminals: .}}' "$FAKE_ORCA/terminals.json" ;;
  "terminal wait")
    once on-wait
    satisfied=$(head -n 1 "$FAKE_ORCA/waits")
    sed -i.bak 1d "$FAKE_ORCA/waits"
    echo "{\"result\": {\"wait\": {\"satisfied\": ${satisfied:-true}}}}"
    [ "${satisfied:-true}" = true ] ;;
  *) echo "fake orca: unexpected call: $*" >&2; exit 1 ;;
esac
ORCA
  mkdir -p "$tmp/orca"
  export FAKE_ORCA="$tmp/orca" FACTORY_POLL_SECONDS=0
  result="$tmp/result.json"
  open='[{"handle": "term_1", "agentIdentity": "claude"}]'
}

# Sets up the terminals, the answers to the waits, and the result file,
# where "none" means no file.
given() {
  echo "$1" >"$FAKE_ORCA/terminals.json"
  tr " " "\n" <<<"$2" >"$FAKE_ORCA/waits"
  [ "$3" = none ] || echo "$3" >"$result"
}

# Writes a script for the fake orca to run once, from $2.
hook() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$FAKE_ORCA/$1"
  chmod +x "$FAKE_ORCA/$1"
}

await() { run --separate-stderr "$root/sdlc/bin/await-result" "$result" term_1 path:/demo; }

@test "a result read once the agent is idle" {
  given "$open" true '{"status": "done"}'
  await
  [ "$status" -eq 0 ]
  expect '{"status":"done"}' "$output"
}

@test "waits for the result file to appear" {
  given "$open" true none
  hook on-list "echo '{\"status\": \"done\"}' >'$result'"
  await
  [ "$status" -eq 0 ]
  expect '{"status":"done"}' "$output"
}

@test "the agent's edits before it goes idle count" {
  given "$open" true '{"summary": "first"}'
  hook on-wait "echo '{\"summary\": \"second\"}' >'$result'"
  await
  [ "$status" -eq 0 ]
  expect '{"summary":"second"}' "$output"
}

@test "keeps waiting while the agent stays busy" {
  given "$open" "false true" '{"summary": "first"}'
  hook on-wait "echo '{\"summary\": \"second\"}' >'$result'"
  await
  [ "$status" -eq 0 ]
  expect '{"summary":"second"}' "$output"
}

@test "a result whose terminal closed is read as it is" {
  given '[]' "" '{"status": "done"}'
  await
  [ "$status" -eq 0 ]
  expect '{"status":"done"}' "$output"
}

@test "a terminal that closes without a result fails" {
  given '[]' "" none
  await
  [ "$status" -ne 0 ]
  expect "await-result: the agent's terminal term_1 closed without writing $result" "${stderr##*$'\n'}"
}

@test "a result that isn't JSON fails" {
  given "$open" true '{"status": "done", "summ'
  await
  [ "$status" -ne 0 ]
  expect "await-result: $result isn't a JSON object. Fix it, then retry the step." "${stderr##*$'\n'}"
}

@test "a result that isn't an object fails" {
  given "$open" true '"done"'
  await
  [ "$status" -ne 0 ]
  expect "await-result: $result isn't a JSON object. Fix it, then retry the step." "${stderr##*$'\n'}"
}
