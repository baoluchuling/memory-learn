#!/bin/bash
# recall.sh — View and search project memories
# Usage: bash recall.sh [--type <type>] [keyword]
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
# Display Functions
# ============================================================

show_entry() {
    local file="$1"
    local keyword="${2:-}"

    local fname
    fname=$(basename "$file")
    [[ "$fname" == "MEMORY.md" ]] && return

    # Extract frontmatter fields
    local name type
    name=$(sed -n '/^---$/,/^---$/{ /^name:/{ s/^name: *//; p; q; } }' "$file" 2>/dev/null || echo "$fname")
    type=$(sed -n '/^---$/,/^---$/{ /^type:/{ s/^type: *//; p; q; } }' "$file" 2>/dev/null || echo "unknown")

    # Extract body (after second ---)
    local body
    body=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$file" | sed '/^$/d')

    # If keyword specified, check if entry matches
    if [[ -n "$keyword" ]]; then
        local lower_keyword lower_name lower_body
        lower_keyword=$(printf '%s' "$keyword" | tr '[:upper:]' '[:lower:]')
        lower_name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
        lower_body=$(printf '%s' "$body" | tr '[:upper:]' '[:lower:]')

        if [[ "$lower_name" != *"$lower_keyword"* ]] && [[ "$lower_body" != *"$lower_keyword"* ]]; then
            return 1
        fi
    fi

    # Map native type to display label
    local label
    case "$type" in
        feedback)  label="rule" ;;
        user)      label="preference" ;;
        project)
            if [[ "$fname" == workflow_* ]]; then
                label="workflow"
            else
                label="pattern"
            fi
            ;;
        *)         label="$type" ;;
    esac

    printf "  [%s] %s\n" "$label" "$name"
    if [[ -n "$body" ]]; then
        printf "         %s\n" "$body"
    fi
    printf "         📄 %s\n\n" "$fname"
    return 0
}

# ============================================================
# Main
# ============================================================

main() {
    local filter_type=""
    local keyword=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type|-t)
                filter_type="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: recall.sh [--type pattern|preference|workflow|rule] [keyword]"
                exit 0
                ;;
            *)
                keyword="$1"
                shift
                ;;
        esac
    done

    local memory_dir
    memory_dir=$(get_memory_dir)

    if [[ ! -d "$memory_dir" ]]; then
        echo "📭 No memories found for this project."
        echo "   Use /learn to start recording."
        exit 0
    fi

    # Count files
    local count=0
    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ -f "$f" ]] && (( count++ )) || true
    done

    if (( count == 0 )); then
        echo "📭 No memories found for this project."
        echo "   Use /learn to start recording."
        exit 0
    fi

    echo ""
    echo "📚 Project Memories ($count entries)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local shown=0

    # Map filter_type to native type for filtering
    local native_filter=""
    case "$filter_type" in
        pattern)    native_filter="project" ;;
        preference) native_filter="user" ;;
        workflow)   native_filter="project" ;;  # further filtered by filename
        rule)       native_filter="feedback" ;;
        "")         native_filter="" ;;
        *)
            echo "❌ Unknown type: $filter_type"
            exit 1
            ;;
    esac

    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ ! -f "$f" ]] && continue

        # Type filter
        if [[ -n "$native_filter" ]]; then
            local ftype
            ftype=$(sed -n '/^---$/,/^---$/{ /^type:/{ s/^type: *//; p; q; } }' "$f" 2>/dev/null || echo "")

            if [[ "$ftype" != "$native_filter" ]]; then
                continue
            fi

            # Additional filename check for workflow vs pattern (both are "project" type)
            if [[ "$filter_type" == "workflow" ]] && [[ "$(basename "$f")" != workflow_* ]]; then
                continue
            fi
            if [[ "$filter_type" == "pattern" ]] && [[ "$(basename "$f")" == workflow_* ]]; then
                continue
            fi
        fi

        if show_entry "$f" "$keyword"; then
            (( shown++ )) || true
        fi
    done

    if (( shown == 0 )); then
        if [[ -n "$keyword" ]]; then
            echo "  No memories matching \"$keyword\""
        else
            echo "  No memories of type \"$filter_type\""
        fi
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 Location: $memory_dir"
}

main "$@"
