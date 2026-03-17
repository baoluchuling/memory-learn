#!/bin/bash
# stop-hook.sh — Session end hook: remind AI to consider learning
# Lightweight: outputs reminder text only if memory system is active
set -euo pipefail

get_memory_dir() {
    local cwd="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
    local base="$HOME/.claude/projects"
    local hash
    hash=$(printf '%s' "$cwd" | sed 's|/|-|g')
    echo "$base/-${hash}/memory"
}

MEMORY_DIR=$(get_memory_dir)

# Only trigger if memory directory exists (project has opted into memory-learn)
[[ ! -d "$MEMORY_DIR" ]] && exit 0

# Count actual memory files (not MEMORY.md)
TOTAL=0
for f in "$MEMORY_DIR"/*.md; do
    [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
    [[ -f "$f" ]] && (( TOTAL++ )) || true
done

cat <<'REMINDER'
<memory-learn-reminder>
Session ending. Quick review:
- Was a problem solved worth remembering? (error→fix pattern)
- Did the user express a new preference or correct your approach?
- Was a reusable workflow or pattern established?

If yes, ask concisely:
💡 Worth remembering: [description]
   Type: [pattern/preference/workflow/rule]
   Record? [y/n]

If nothing notable, skip silently.
</memory-learn-reminder>
REMINDER
