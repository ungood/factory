#!/usr/bin/env bats
# Tests sdlc/bin/retro against a fake gh, mise, marche and claude, checking
# what it hands the review and which issues it files.

setup() {
  load helpers
  init

  # The fakes answer from, and record into, files in $FAKE.
  fake gh <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "repo view") sed -e 's#.*github\.com/##' -e 's#\.git$##' <<<"$3" ;;
  "pr diff") echo "diff --git a/a b/a" ;;
  "pr view") echo MERGED ;;
  "api user") echo ungood ;;
  "api --paginate")
    case "$3" in
      */pulls/*/reviews) cat "$FAKE/reviews.json" ;;
      */pulls/*/comments) echo '[]' ;;
      */issues/*/comments) echo '[]' ;;
    esac ;;
  "label create") ;;
  "issue create")
    shift 2
    while [ $# -gt 0 ]; do
      case "$1" in
        -R) repo=$2 ;;
        --title) title=$2 ;;
        --body) body=$2 ;;
      esac
      shift 2
    done
    jq -cn --arg repo "$repo" --arg title "$title" --arg body "$body" '{$repo, $title, $body}' >>"$FAKE/filed"
    echo "https://github.com/$repo/issues/$(wc -l <"$FAKE/filed" | tr -d ' ')" ;;
  *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
esac
GH
  fake mise <<'MISE'
#!/usr/bin/env bash
jq -cn --arg dir "$FAKE_CONFIG" '{CLAUDE_CONFIG_DIR: $dir}'
MISE
  fake marche <<'MARCHE'
#!/usr/bin/env bash
echo '{"tasks": []}'
MARCHE
  # The review keeps a copy of what it was handed, and answers with
  # $FAKE/review.json.
  fake claude <<'CLAUDE'
#!/usr/bin/env bash
cp -R . "$FAKE/inputs"
jq -c '{is_error: false, structured_output: .}' "$FAKE/review.json"
CLAUDE

  git init --quiet "$tmp/workplace"
  git -C "$tmp/workplace" remote add origin https://github.com/ungood/factory.git
  git init --quiet "$tmp/demo"
  git -C "$tmp/demo" remote add origin https://github.com/ungood/demo.git
  state="$tmp/state/factory/agents/demo-7"
  mkdir -p "$tmp/fake" "$tmp/config" "$state"
  echo "# The issue" >"$state/issue.md"
  echo '{"status": "done"}' >"$state/result.json"
  export FAKE="$tmp/fake" FAKE_CONFIG="$tmp/config" XDG_STATE_HOME="$tmp/state"
  url=https://github.com/ungood/demo/pull/9

  # The pull request was merged together with a review that holds two
  # ideas for follow-up work, and the retrospective's own analysis found
  # three issues, its limit.
  cat >"$FAKE/reviews.json" <<'JSON'
[{"id": 1, "user": {"login": "ungood"}, "state": "COMMENTED", "html_url": "https://github.com/ungood/demo/pull/9#pullrequestreview-1",
  "body": "Follow-ups:\n- Test the scripts\n- Make the prompts skills"}]
JSON
  cat >"$FAKE/review.json" <<'JSON'
{
  "issues": [
    {"repo": "ungood/factory", "title": "Retro one", "body": "Evidence one"},
    {"repo": "ungood/factory", "title": "Retro two", "body": "Evidence two"},
    {"repo": "ungood/demo", "title": "Retro three", "body": "Evidence three"}
  ],
  "followUps": [
    {"repo": "ungood/factory", "title": "Test the scripts", "body": "The reviewer asked for tests.",
     "comment": "https://github.com/ungood/demo/pull/9#pullrequestreview-1"},
    {"repo": "ungood/factory", "title": "Make the prompts skills", "body": "The reviewer asked for skills.",
     "comment": "https://github.com/ungood/demo/pull/9#pullrequestreview-1"}
  ]
}
JSON
}

retro() {
  cd "$tmp/workplace" || return
  run --separate-stderr "$root/sdlc/bin/retro" "$tmp/demo" 7 "$tmp/worktree" "$url" run-1
  [ "$status" -eq 0 ]
}

@test "the review is handed the feedback left with the merge" {
  retro
  jq -e '.[] | select(.id == "review:1")' "$FAKE/inputs/unhandled.json"
}

@test "the reviewer's follow-ups are filed on top of the retrospective's three issues" {
  retro
  expect 5 "$(jq length <<<"$output")"
  expect 5 "$(wc -l <"$FAKE/filed" | tr -d ' ')"
}

@test "a follow-up links the comment it came from" {
  retro
  jq -se 'map(select(.title == "Test the scripts"))[0].body
    | contains("https://github.com/ungood/demo/pull/9#pullrequestreview-1")' "$FAKE/filed"
}
