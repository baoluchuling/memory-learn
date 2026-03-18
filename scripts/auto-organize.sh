#!/bin/bash
# auto-organize.sh — Memory health report: stats, expiration detection, suggestions
# Usage: bash auto-organize.sh [--max-age N] (days, default: 90)
set -euo pipefail

source "$(dirname "$0")/common.sh"

# Parse a "YYYY-MM-DD HH:MM:SS" timestamp to epoch seconds (portable)
parse_date() {
    local datestr="$1"
    # Try macOS format first, then GNU
    if date -j -f "%Y-%m-%d %H:%M:%S" "$datestr" "+%s" 2>/dev/null; then
        return
    fi
    date -d "$datestr" "+%s" 2>/dev/null || echo 0
}

main() {
    local max_age=90  # days

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --max-age)
                max_age="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: auto-organize.sh [--max-age N] (days, default: 90)"
                exit 0
                ;;
            *)  shift ;;
        esac
    done

    local memory_dir
    memory_dir=$(get_memory_dir)

    if [[ ! -d "$memory_dir" ]]; then
        echo "📭 No memory directory found."
        exit 0
    fi

    # Collect stats
    local total=0 rules=0 patterns=0 preferences=0 workflows=0
    local tagged=0 expired_files=()
    local now
    now=$(date "+%s")
    local threshold=$(( now - max_age * 86400 ))

    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ ! -f "$f" ]] && continue

        (( total++ )) || true

        local fname
        fname=$(basename "$f")
        local type
        type=$(type_from_filename "$fname")

        case "$type" in
            rule)       (( rules++ )) || true ;;
            preference) (( preferences++ )) || true ;;
            workflow)   (( workflows++ )) || true ;;
            *)          (( patterns++ )) || true ;;
        esac

        local tags
        tags=$(get_tags "$f")
        if [[ -n "$tags" ]]; then
            (( tagged++ )) || true
        fi

        # Check expiration
        local created
        created=$(get_field "$f" "created")
        if [[ -n "$created" ]]; then
            local created_epoch
            created_epoch=$(parse_date "$created")
            if (( created_epoch > 0 && created_epoch < threshold )); then
                local name
                name=$(get_field "$f" "name")
                expired_files+=("${fname}|${name}|${created}")
            fi
        fi
    done

    # MEMORY.md line count
    local index_lines=0
    if [[ -f "$memory_dir/MEMORY.md" ]]; then
        index_lines=$(wc -l < "$memory_dir/MEMORY.md" | tr -d ' ')
    fi

    # ============================================================
    # Report
    # ============================================================

    echo ""
    echo "📊 Memory Health Report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Distribution
    echo "  📦 Total entries: $total"
    echo "     Rules:       $rules"
    echo "     Preferences: $preferences"
    echo "     Patterns:    $patterns"
    echo "     Workflows:   $workflows"
    echo "     Tagged:      $tagged / $total"
    echo ""

    # Index health
    echo "  📄 MEMORY.md: ${index_lines}/200 lines"
    if (( index_lines > 180 )); then
        echo "     ⚠️  Approaching 200-line limit!"
    elif (( index_lines == 0 )); then
        echo "     ⚠️  Index missing — run /rebuild"
    else
        echo "     ✅ OK"
    fi
    echo ""

    # Health score (simple heuristic)
    local score=100

    # Penalty: too few or too many
    if (( total == 0 )); then
        score=0
    elif (( total < 3 )); then
        (( score -= 20 )) || true
    elif (( total > 50 )); then
        (( score -= 15 )) || true
    fi

    # Penalty: only one type used
    local types_used=0
    (( rules > 0 )) && (( types_used++ )) || true
    (( preferences > 0 )) && (( types_used++ )) || true
    (( patterns > 0 )) && (( types_used++ )) || true
    (( workflows > 0 )) && (( types_used++ )) || true
    if (( types_used == 1 && total > 5 )); then
        (( score -= 15 )) || true
    fi

    # Penalty: expired entries
    local expired_count=${#expired_files[@]}
    if (( expired_count > 0 )); then
        local penalty=$(( expired_count * 5 ))
        (( penalty > 30 )) && penalty=30
        (( score -= penalty )) || true
    fi

    # Penalty: index near limit
    if (( index_lines > 180 )); then
        (( score -= 10 )) || true
    fi

    (( score < 0 )) && score=0

    echo "  🏥 Health score: ${score}/100"
    echo ""

    # Expired entries
    if (( expired_count > 0 )); then
        echo "  ⏰ Expired entries (>${max_age} days old):"
        for entry in "${expired_files[@]}"; do
            IFS='|' read -r efname ename ecreated <<< "$entry"
            echo "     - ${ename}"
            echo "       📄 ${efname}  (created: ${ecreated})"
        done
        echo ""
        echo "  💡 Use /forget --id <filename> to clean up"
        echo ""
    else
        echo "  ⏰ No expired entries (threshold: ${max_age} days)"
        echo ""
    fi

    # Suggestions
    echo "  💡 Suggestions:"
    if (( total == 0 )); then
        echo "     - Start recording with /learn"
    fi
    if (( types_used == 1 && total > 5 )); then
        echo "     - Diversify: you only have one memory type — consider adding others"
    fi
    if (( tagged * 3 < total && total > 5 )); then
        echo "     - Add tags to memories for better filtering (--tags \"api,error\")"
    fi
    if (( expired_count > 3 )); then
        echo "     - Clean up expired entries to keep memory relevant"
    fi
    if (( total > 20 )); then
        echo "     - Run /deduplicate to check for similar entries"
    fi
    if (( index_lines > 180 )); then
        echo "     - Reduce entries or run /rebuild to compact the index"
    fi
    if (( score >= 80 )); then
        echo "     - Memory looks healthy! 👍"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 Location: $memory_dir"
}

main "$@"
