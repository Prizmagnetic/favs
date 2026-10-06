#!/usr/bin/env bash

set -euo pipefail

# This test script validates the behavior of favs.sh in a disposable temporary
# directory so the real project files are not modified during regression checks.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# Print a concise failure message and stop the script when a check does not pass.
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Assert that a string appears in a file; otherwise fail with a clear message.
assert_contains() {
  local needle="$1"
  local file="$2"
  grep -Fq -- "$needle" "$file" || fail "missing '$needle' in $file"
}

# Assert that a string is absent from a file; this guards against leaking private
# notes or other unintended output into the menu listing.
assert_not_contains() {
  local needle="$1"
  local file="$2"
  ! grep -Fq -- "$needle" "$file" || fail "unexpected '$needle' in $file"
}

# Copy the script and its sample files into a temporary work directory so each
# test can run in isolation.
cp "$script_dir/favs.sh" "$script_dir/default.txt" "$script_dir/favs.conf" "$tmp_dir/"

# Save a command using the CLI and confirm the script creates a personal file and
# persists the command after the instruction marker.
(cd "$tmp_dir" && bash favs.sh -s 'echo saved' > save-output)
assert_contains '# === END FAVS INSTRUCTIONS ===' "$tmp_dir/favs.txt"
assert_contains 'echo saved' "$tmp_dir/favs.txt"

# Listing commands should show the saved command but omit the template text that
# explains the file format.
(cd "$tmp_dir" && bash favs.sh -l > list-output)
assert_not_contains 'favs.txt is your personal command list' "$tmp_dir/list-output"
assert_contains 'echo saved' "$tmp_dir/list-output"

# Private comment lines above the end marker should not appear in the menu, while
# visible notes below it should still render as notes.
printf '%s\n' '# private instructions' '# === END FAVS INSTRUCTIONS ===' '# visible note' 'echo noted' > "$tmp_dir/favs.txt"
(cd "$tmp_dir" && bash favs.sh -l > notes-output)
assert_not_contains '# private instructions' "$tmp_dir/notes-output"
assert_contains '# visible note' "$tmp_dir/notes-output"
assert_contains 'echo noted' "$tmp_dir/notes-output"

# Install the shell function into a temporary home directory and verify it is only
# added once and points at the script correctly.
HOME="$tmp_dir/home" FAVS_RC_FILE="$tmp_dir/home/.bashrc" \
  bash "$tmp_dir/favs.sh" -i > "$tmp_dir/install-output"
HOME="$tmp_dir/home" FAVS_RC_FILE="$tmp_dir/home/.bashrc" \
  bash "$tmp_dir/favs.sh" -i > /dev/null
[[ $(grep -Fc '# >>> favs shell function >>>' "$tmp_dir/home/.bashrc") -eq 1 ]] || \
  fail 'installer created duplicate function blocks'
assert_contains "source \"$tmp_dir/favs.sh\" \"\$@\"" "$tmp_dir/home/.bashrc"

source "$tmp_dir/home/.bashrc"
[[ $(type -t f) == function ]] || fail 'installer did not define f()'
env -i PATH="$PATH" HOME="$tmp_dir/home" bash --noprofile --norc -c \
  'source "$1"; cd "$2"; f -l' _ "$tmp_dir/home/.bashrc" "$tmp_dir" > "$tmp_dir/function-output"
assert_contains '# visible note' "$tmp_dir/function-output"

# Comments should remain in file order when displayed, even when they appear
# between commands in the same list.
printf '%s\n' '# === END FAVS INSTRUCTIONS ===' 'echo first' '# note between commands' 'echo second' > "$tmp_dir/favs.txt"
(cd "$tmp_dir" && USE_COLORS=false bash favs.sh -l > order-output)
first_line=$(grep -nF 'echo first' "$tmp_dir/order-output" | cut -d: -f1)
note_line=$(grep -nF '# note between commands' "$tmp_dir/order-output" | cut -d: -f1)
second_line=$(grep -nF 'echo second' "$tmp_dir/order-output" | cut -d: -f1)
[[ $first_line -lt $note_line && $note_line -lt $second_line ]] || \
  fail 'comments were not printed in file order'

# A group menu should return to the top-level menu when the user enters 'c'.
printf '%s\n' '# === END FAVS INSTRUCTIONS ===' '## Test group' 'echo grouped' '##' > "$tmp_dir/favs.txt"
(cd "$tmp_dir" && USE_COLORS=false bash favs.sh > group-c-output <<'EOF'
0
c
EOF
)
[[ $(grep -Fc 'Choose a group number' "$tmp_dir/group-c-output") -eq 1 ]] || \
  fail 'group c returned to the top-level menu'
assert_contains 'Goodbye' "$tmp_dir/group-c-output"

# Opening the editor should emit the expected editing banner and launch the
# configured editor command.
(cd "$tmp_dir" && FAVS_EDITOR=true bash favs.sh -e > editor-output)
assert_contains 'editing:' "$tmp_dir/editor-output"

printf '%s\n' 'favs tests passed'
