#!/usr/bin/env bash
#
# Removes symlinks created by install.sh. Only removes symlinks that point
# into this repository; real files and foreign symlinks are left alone.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

removed=0

for skill_dir in "$REPO_DIR"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
    target="$TARGET_DIR/$name"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "${skill_dir%/}" ]; then
        rm "$target"
        echo "  - $name"
        removed=$((removed + 1))
    fi
done

echo
echo "Removed: $removed"
