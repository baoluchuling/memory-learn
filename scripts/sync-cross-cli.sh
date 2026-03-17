#!/bin/bash
# sync-cross-cli.sh — Sync memory between Claude Code and Codex CLI
# Usage: bash sync-cross-cli.sh [project_path]
set -euo pipefail

PROJECT_PATH="${1:-$(pwd)}"
HASH=$(printf '%s' "$PROJECT_PATH" | sed 's|/|-|g')

CLAUDE_DIR="$HOME/.claude/projects/-${HASH}/memory"
CODEX_DIR="$HOME/.codex/projects/-${HASH}/memory"

# Only sync if both CLI directories exist
[[ ! -d "$HOME/.claude" ]] && exit 0
[[ ! -d "$HOME/.codex" ]] && exit 0

# Get modification time (portable macOS/Linux)
get_mtime() {
    if stat -f "%m" "$1" 2>/dev/null; then
        return
    fi
    stat -c "%Y" "$1" 2>/dev/null || echo 0
}

# Determine source (most recently modified) and target
if [[ -d "$CLAUDE_DIR" ]] && [[ -d "$CODEX_DIR" ]]; then
    local_mtime=$(get_mtime "$CLAUDE_DIR")
    remote_mtime=$(get_mtime "$CODEX_DIR")

    if (( local_mtime >= remote_mtime )); then
        SOURCE="$CLAUDE_DIR"
        TARGET="$CODEX_DIR"
    else
        SOURCE="$CODEX_DIR"
        TARGET="$CLAUDE_DIR"
    fi
elif [[ -d "$CLAUDE_DIR" ]]; then
    SOURCE="$CLAUDE_DIR"
    TARGET="$CODEX_DIR"
elif [[ -d "$CODEX_DIR" ]]; then
    SOURCE="$CODEX_DIR"
    TARGET="$CLAUDE_DIR"
else
    exit 0
fi

# Sync: copy newer files only (don't destroy target)
mkdir -p "$TARGET"

for f in "$SOURCE"/*.md; do
    [[ ! -f "$f" ]] && continue
    local fname
    fname=$(basename "$f")
    local target_file="$TARGET/$fname"

    # Only copy if source is newer or target doesn't exist
    if [[ ! -f "$target_file" ]] || [[ "$f" -nt "$target_file" ]]; then
        cp "$f" "$target_file"
    fi
done

echo "✅ Synced memory: $(basename "$SOURCE") → $(basename "$TARGET")"
