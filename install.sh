#!/usr/bin/env bash
#
# Installs the skills in this repository into ~/.claude/skills/ as symlinks,
# so that a `git pull` in this repository updates them in place.
#
# Existing files or directories are never overwritten.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

mkdir -p "$TARGET_DIR"

installed=0
skipped=0

for skill_dir in "$REPO_DIR"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
    target="$TARGET_DIR/$name"

    if [ -L "$target" ]; then
        current="$(readlink "$target")"
        if [ "$current" = "${skill_dir%/}" ]; then
            echo "  = $name (already linked)"
            installed=$((installed + 1))
            continue
        fi
        echo "  ! $name is a symlink to $current — skipping"
        skipped=$((skipped + 1))
        continue
    fi

    if [ -e "$target" ]; then
        echo "  ! $name already exists as a real path — skipping"
        skipped=$((skipped + 1))
        continue
    fi

    ln -s "${skill_dir%/}" "$target"
    echo "  + $name"
    installed=$((installed + 1))
done

echo
echo "Installed/linked: $installed   Skipped: $skipped"
echo "Target: $TARGET_DIR"
echo
echo "Start a new Claude Code session for the skill to be picked up."
