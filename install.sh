#!/usr/bin/env bash
# SwiftSkills installer for Claude Code (CLI, desktop app, IDE extensions).
# Installs the ios-swift-master skill and subagent so Claude Code becomes an
# expert in Swift 6.4, SwiftUI and SwiftData.
# Safe to run repeatedly. Run ./install.sh help for usage.

set -euo pipefail

VERSION="1.0.0 (Swift 6.4, iOS 27, Xcode 27)"
SKILL_NAME="ios-swift-master"
AGENT_FILE="ios-swift-master.md"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SKILL="$SCRIPT_DIR/skills/$SKILL_NAME"
SRC_AGENT="$SCRIPT_DIR/agents/$AGENT_FILE"
SRC_CLAUDE_MD="$SCRIPT_DIR/CLAUDE.md"

COPY_MODE=0
FORCE=0
WITH_CLAUDE_MD=0

info()  { printf '  %s\n' "$*"; }
ok()    { printf '  [ok] %s\n' "$*"; }
warn()  { printf '  [warn] %s\n' "$*" >&2; }
fail()  { printf '  [error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
SwiftSkills installer $VERSION

Usage:
  ./install.sh personal [--copy] [--force]
      Install for all projects on this Mac.
        Skill  -> ~/.claude/skills/$SKILL_NAME   (symlink by default)
        Agent  -> ~/.claude/agents/$AGENT_FILE
      --copy    copy files instead of symlinking (use if a tool cannot follow symlinks)
      --force   replace existing non-managed files (a timestamped backup is kept)

  ./install.sh project <path-to-repo> [--claude-md] [--force]
      Install into one repository (committed, shared with your team).
        <repo>/.claude/skills/$SKILL_NAME/
        <repo>/.claude/agents/$AGENT_FILE
      --claude-md  also copy CLAUDE.md to the repo root if it does not exist

  ./install.sh uninstall-personal
  ./install.sh uninstall-project <path-to-repo>
  ./install.sh verify [<path-to-repo>]
  ./install.sh help
EOF
}

check_sources() {
  [[ -f "$SRC_SKILL/SKILL.md" ]] || fail "Missing $SRC_SKILL/SKILL.md. Run this script from the repository folder."
  [[ -f "$SRC_AGENT" ]] || fail "Missing $SRC_AGENT"
  local name
  name="$(awk -F': *' '/^name:/{print $2; exit}' "$SRC_SKILL/SKILL.md" | tr -d "\"'")"
  [[ "$name" == "$SKILL_NAME" ]] || fail "SKILL.md name '$name' does not match folder '$SKILL_NAME'"
}

backup() {
  local target="$1"
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  mv "$target" "$target.backup-$stamp"
  warn "Existing $target moved to $target.backup-$stamp"
}

# place <source> <destination> <link|copy>
place() {
  local src="$1" dest="$2" mode="$3"
  mkdir -p "$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$mode" == "link" && "$current" == "$src" ]]; then
      ok "Already linked: $dest"
      return
    fi
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    if [[ -e "$dest/.swiftskills-managed" ]] || { [[ -f "$dest" ]] && grep -qE "ios-swift-master|iOS Swift Master" "$dest"; } || [[ "$FORCE" == 1 ]]; then
      if [[ "$FORCE" == 1 && ! -e "$dest/.swiftskills-managed" ]]; then backup "$dest"; else rm -rf "$dest"; fi
    else
      fail "$dest already exists and was not installed by this script. Re-run with --force to back it up and replace it."
    fi
  fi

  if [[ "$mode" == "link" ]]; then
    ln -s "$src" "$dest"
    ok "Linked $dest"
  else
    cp -R "$src" "$dest"
    [[ -d "$dest" ]] && printf '%s\n' "$VERSION" > "$dest/.swiftskills-managed"
    ok "Copied $dest"
  fi
}

install_personal() {
  check_sources
  local mode="link"
  [[ "$COPY_MODE" == 1 ]] && mode="copy"
  echo "Installing personal skill and agent ($mode mode)"
  place "$SRC_SKILL" "$HOME/.claude/skills/$SKILL_NAME" "$mode"
  place "$SRC_AGENT" "$HOME/.claude/agents/$AGENT_FILE" "$mode"
  echo
  info "Next: start (or restart) Claude Code. Run /agents to confirm 'ios-swift-master' is listed."
}

install_project() {
  local repo="${1:-}"
  [[ -n "$repo" ]] || fail "Provide a repository path: ./install.sh project /path/to/repo"
  [[ -d "$repo" ]] || fail "Not a directory: $repo"
  check_sources
  repo="$(cd "$repo" && pwd)"
  echo "Installing into $repo/.claude"
  place "$SRC_SKILL" "$repo/.claude/skills/$SKILL_NAME" copy
  place "$SRC_AGENT" "$repo/.claude/agents/$AGENT_FILE" copy
  if [[ "$WITH_CLAUDE_MD" == 1 ]]; then
    if [[ -e "$repo/CLAUDE.md" ]]; then
      warn "Skipped CLAUDE.md (already exists at $repo/CLAUDE.md)"
    else
      cp "$SRC_CLAUDE_MD" "$repo/CLAUDE.md"
      ok "Copied $repo/CLAUDE.md"
    fi
  fi
  echo
  info "Next: commit .claude/ so teammates and Claude Code cloud sessions get it."
}

uninstall_personal() {
  echo "Removing personal install"
  for p in "$HOME/.claude/skills/$SKILL_NAME" "$HOME/.claude/agents/$AGENT_FILE"; do
    if [[ -L "$p" || -e "$p/.swiftskills-managed" ]]; then rm -rf "$p"; ok "Removed $p"
    elif [[ -f "$p" ]] && grep -q "iOS Swift Master" "$p"; then rm -f "$p"; ok "Removed $p"
    elif [[ -e "$p" ]]; then warn "Skipped $p (not managed by this script)"
    fi
  done
}

uninstall_project() {
  local repo="${1:-}"
  [[ -d "$repo" ]] || fail "Provide a repository path: ./install.sh uninstall-project /path/to/repo"
  repo="$(cd "$repo" && pwd)"
  echo "Removing project install from $repo/.claude"
  local skill="$repo/.claude/skills/$SKILL_NAME"
  [[ -e "$skill/.swiftskills-managed" ]] && { rm -rf "$skill"; ok "Removed $skill"; }
  local agent="$repo/.claude/agents/$AGENT_FILE"
  [[ -f "$agent" ]] && grep -q "iOS Swift Master" "$agent" && { rm -f "$agent"; ok "Removed $agent"; }
}

verify() {
  local repo="${1:-}"
  echo "SwiftSkills $VERSION"
  check_sources && ok "Package is valid (name matches folder, all files present)"
  local refs
  refs="$(find "$SRC_SKILL/references" -name '*.md' | wc -l | tr -d ' ')"
  ok "$refs reference files"
  for p in "$HOME/.claude/skills/$SKILL_NAME/SKILL.md" "$HOME/.claude/agents/$AGENT_FILE"; do
    [[ -e "$p" ]] && ok "Found $p" || info "Not installed: $p"
  done
  if [[ -n "$repo" ]]; then
    for p in "$repo/.claude/skills/$SKILL_NAME/SKILL.md" "$repo/.claude/agents/$AGENT_FILE"; do
      [[ -e "$p" ]] && ok "Found $p" || info "Not installed: $p"
    done
  fi
}

cmd="${1:-help}"
shift || true
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --copy) COPY_MODE=1 ;;
    --force) FORCE=1 ;;
    --claude-md) WITH_CLAUDE_MD=1 ;;
    *) ARGS+=("$arg") ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

case "$cmd" in
  personal) install_personal ;;
  project) install_project "${1:-}" ;;
  uninstall-personal) uninstall_personal ;;
  uninstall-project) uninstall_project "${1:-}" ;;
  verify) verify "${1:-}" ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
