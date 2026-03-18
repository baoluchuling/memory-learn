#!/bin/bash
# stop-hook.sh — Session end hook: remind AI to consider learning
set -euo pipefail

source "$(dirname "$0")/common.sh"

MEMORY_DIR=$(get_memory_dir)

# Only trigger if memory directory exists
[[ ! -d "$MEMORY_DIR" ]] && exit 0

# Count memory files
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
