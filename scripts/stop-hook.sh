#!/bin/bash
# stop-hook.sh — Session end hook: auto-learn + maintenance reminders
set -euo pipefail

source "$(dirname "$0")/common.sh"

MEMORY_DIR=$(get_memory_dir)

# Only trigger if memory directory exists
[[ ! -d "$MEMORY_DIR" ]] && exit 0

# Read config
CONFIG_FILE="$MEMORY_DIR/.config"
AUTO_LEARN="on"
EXPIRE_DAYS=90
if [[ -f "$CONFIG_FILE" ]]; then
    AUTO_LEARN=$(grep "^auto_learn=" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "on")
    EXPIRE_DAYS=$(grep "^expire_days=" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d'=' -f2- || echo "90")
fi

# Count memories and check for maintenance needs
TOTAL=0
EXPIRED=0
NOW=$(date "+%s")
THRESHOLD=$(( NOW - EXPIRE_DAYS * 86400 ))

for f in "$MEMORY_DIR"/*.md; do
    [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
    [[ ! -f "$f" ]] && continue
    (( TOTAL++ )) || true

    # Check expiration
    CREATED=$(awk '/^---$/{ c++; next } c==1 && /^created:/ { sub("^created: *",""); print; exit }' "$f" 2>/dev/null)
    if [[ -n "$CREATED" ]]; then
        # Portable date parsing
        EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "$CREATED" "+%s" 2>/dev/null || date -d "$CREATED" "+%s" 2>/dev/null || echo 0)
        if (( EPOCH > 0 && EPOCH < THRESHOLD )); then
            (( EXPIRED++ )) || true
        fi
    fi
done

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ============================================================
# Output instructions for the AI
# ============================================================

if [[ "$AUTO_LEARN" == "on" ]]; then
    cat << EOF
<memory-learn-auto>
Session ending. AUTO-LEARN is ON. Memory: ${TOTAL} entries.

STEP 1 — Auto-record learnings:
Review this session and record anything valuable WITHOUT asking.
For each item, run:
  bash ${SKILL_DIR}/scripts/learn.sh --type <type> [--tags "t1,t2"] "description with WHY context"
Then notify: 📝 Auto-recorded: [type] "description"

Record if:
- Problem was solved (pattern: error → root cause → fix)
- User corrected your approach (rule: what + why)
- User expressed a preference (preference: choice + reason)
- A multi-step workflow was established (workflow)

Skip if: simple Q&A, trivial file reads, nothing reusable.

EOF
else
    cat << 'EOF'
<memory-learn-reminder>
Session ending. Quick review — if anything valuable happened, ask:
💡 Worth remembering: [description]
   Type: [pattern/preference/workflow/rule]
   Record? [y/n]
If nothing notable, skip silently.

EOF
fi

# Maintenance warnings
MAINT=""
if (( TOTAL > 30 )); then
    MAINT="${MAINT}STEP 2 — Dedup check: You have ${TOTAL} memories. Suggest: \"You have ${TOTAL} memories — consider running /deduplicate\"\n"
fi
if (( EXPIRED > 0 )); then
    MAINT="${MAINT}STEP 3 — Expired: ${EXPIRED} memories are older than ${EXPIRE_DAYS} days. Suggest: \"${EXPIRED} memories may be outdated — consider running /organize\"\n"
fi

if [[ -n "$MAINT" ]]; then
    printf '%b' "$MAINT"
fi

if [[ "$AUTO_LEARN" == "on" ]]; then
    echo "</memory-learn-auto>"
else
    echo "</memory-learn-reminder>"
fi
