#!/bin/bash
# deduplicate.sh — Detect and report duplicate/similar memories
# Usage: bash deduplicate.sh [--threshold N]
set -euo pipefail

detect_cli() {
    if [[ "${CLAUDE_CLI:-}" == "codex" ]] || [[ -n "${CODEX_SESSION_ID:-}" ]]; then
        echo "codex"
    else
        echo "claude"
    fi
}

get_memory_dir() {
    local cwd="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
    local cli
    cli=$(detect_cli)
    local base

    if [[ "$cli" == "codex" ]]; then
        base="$HOME/.codex/projects"
    else
        base="$HOME/.claude/projects"
    fi

    local hash
    hash=$(printf '%s' "$cwd" | sed 's|/|-|g')
    echo "$base/-${hash}/memory"
}

# ============================================================
# Similarity Calculation
# ============================================================

# Word-overlap similarity (0-100)
similarity() {
    local text1="$1"
    local text2="$2"

    # Normalize: lowercase, extract words > 2 chars
    local words1 words2
    words1=$(printf '%s' "$text1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | awk 'length>2' | sort -u)
    words2=$(printf '%s' "$text2" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | awk 'length>2' | sort -u)

    if [[ -z "$words1" ]] || [[ -z "$words2" ]]; then
        echo 0
        return
    fi

    # Count common words
    local common
    common=$(comm -12 <(echo "$words1") <(echo "$words2") | wc -l | tr -d ' ')

    # Count total unique words
    local total1 total2
    total1=$(echo "$words1" | wc -l | tr -d ' ')
    total2=$(echo "$words2" | wc -l | tr -d ' ')

    local total=$(( total1 + total2 ))
    if (( total == 0 )); then
        echo 0
        return
    fi

    # Dice coefficient: 2*common / (count1 + count2) * 100
    echo $(( common * 200 / total ))
}

# ============================================================
# Main
# ============================================================

main() {
    local threshold=60

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --threshold|-t)
                threshold="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: deduplicate.sh [--threshold N] (default: 60)"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    local memory_dir
    memory_dir=$(get_memory_dir)

    if [[ ! -d "$memory_dir" ]]; then
        echo "📭 No memories to deduplicate."
        exit 0
    fi

    # Collect all memory files
    local files=()
    local names=()
    local bodies=()

    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ ! -f "$f" ]] && continue

        files+=("$f")

        local name
        name=$(sed -n '/^---$/,/^---$/{ /^name:/{ s/^name: *//; p; q; } }' "$f" 2>/dev/null || echo "$(basename "$f")")
        names+=("$name")

        local body
        body=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$f" | tr '\n' ' ')
        bodies+=("$body")
    done

    local count=${#files[@]}
    if (( count < 2 )); then
        echo "📭 Need at least 2 memories to check for duplicates (found: $count)"
        exit 0
    fi

    echo ""
    echo "🔍 Checking $count memories for duplicates (threshold: ${threshold}%)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local found=0

    for (( i=0; i<count; i++ )); do
        for (( j=i+1; j<count; j++ )); do
            local text1="${names[$i]} ${bodies[$i]}"
            local text2="${names[$j]} ${bodies[$j]}"

            local sim
            sim=$(similarity "$text1" "$text2")

            if (( sim >= threshold )); then
                (( found++ )) || true
                echo ""
                echo "⚠️  Similar pair (${sim}% match):"
                echo "  1) ${names[$i]}"
                echo "     📄 $(basename "${files[$i]}")"
                echo "  2) ${names[$j]}"
                echo "     📄 $(basename "${files[$j]}")"
                echo ""
                echo "  💡 Use /forget --id <filename> to remove one"
            fi
        done
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if (( found == 0 )); then
        echo "✅ No duplicates found"
    else
        echo "⚠️  Found $found similar pair(s)"
    fi

    echo "📍 Location: $memory_dir"
}

main "$@"
