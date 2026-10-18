# Shared by the SDLC's tests. Each test file's setup runs `load helpers`,
# then init.
#
# The tests run the scripts in sdlc/bin by path, the way the workflow does,
# never through bash or sh. sdlc/test/workflow.bats checks that.

bats_require_minimum_version 1.5.0

# Sets $root to the checkout under test and $tmp to the test's own
# directory, resolved, since the scripts resolve repo paths through git.
# Puts $tmp/bin, where fake makes its fakes, first on PATH.
init() {
  # shellcheck disable=SC2034 # The test files use it.
  root=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  tmp=$(cd "$BATS_TEST_TMPDIR" && pwd -P)
  mkdir -p "$tmp/bin"
  export PATH="$tmp/bin:$PATH"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  # mise keeps its trusted configs under XDG_STATE_HOME, which tests move,
  # so keep it pointed at the real one.
  export MISE_STATE_DIR="${MISE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/mise}"
}

# Makes the fake command $1 from the script on stdin.
fake() {
  cat >"$tmp/bin/$1"
  chmod +x "$tmp/bin/$1"
}

# Fails, showing both, unless what's wanted, $1, is what we got, $2.
expect() {
  if [ "$1" != "$2" ]; then
    printf 'want: %s\ngot:  %s\n' "$1" "$2"
    return 1
  fi
}

# Makes a bare remote at $tmp/origin.git and a clone of it at $tmp/$1 with
# one commit on main.
remote() {
  git init --quiet --bare -b main "$tmp/origin.git"
  git clone --quiet "$tmp/origin.git" "$tmp/$1" 2>/dev/null
  git -C "$tmp/$1" commit --quiet --allow-empty -m init
  git -C "$tmp/$1" push --quiet origin main
}
