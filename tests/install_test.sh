#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

assert_absent() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected path to be absent: $1"
}

HOME="$TEST_ROOT/home"
export HOME
mkdir -p "$HOME"

"$ROOT/install.sh" verify >/dev/null

# --- project install (copy, committable) ---
project="$TEST_ROOT/sample-project"
mkdir -p "$project"

"$ROOT/install.sh" project "$project" --claude-md >/dev/null
"$ROOT/install.sh" project "$project" --claude-md >/dev/null   # idempotent

assert_file "$project/.claude/skills/ios-swift-master/SKILL.md"
assert_file "$project/.claude/agents/ios-swift-master.md"
assert_file "$project/CLAUDE.md"

# existing CLAUDE.md must be preserved
printf '# my own guidance\n' > "$project/CLAUDE.md"
"$ROOT/install.sh" project "$project" --claude-md >/dev/null
grep -q '# my own guidance' "$project/CLAUDE.md" || fail "existing CLAUDE.md was overwritten"

"$ROOT/install.sh" uninstall-project "$project" >/dev/null
assert_absent "$project/.claude/skills/ios-swift-master"
assert_absent "$project/.claude/agents/ios-swift-master.md"

# --- personal install (copy) ---
"$ROOT/install.sh" personal --copy >/dev/null
assert_file "$HOME/.claude/skills/ios-swift-master/SKILL.md"
assert_file "$HOME/.claude/agents/ios-swift-master.md"

"$ROOT/install.sh" uninstall-personal >/dev/null
assert_absent "$HOME/.claude/skills/ios-swift-master"
assert_absent "$HOME/.claude/agents/ios-swift-master.md"

# --- personal install (symlink, default) ---
"$ROOT/install.sh" personal >/dev/null
assert_file "$HOME/.claude/skills/ios-swift-master/SKILL.md"
[[ -L "$HOME/.claude/skills/ios-swift-master" ]] || fail "expected a symlink for the default personal install"

"$ROOT/install.sh" uninstall-personal >/dev/null
assert_absent "$HOME/.claude/skills/ios-swift-master"

printf 'All installer tests passed.\n'
