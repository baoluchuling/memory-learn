#!/bin/bash
# recall.sh — View and search project memories
# Usage: bash recall.sh [--type <type>] [--tag <tag>] [keyword ...]
set -euo pipefail

source "$(dirname "$0")/common.sh"

# ============================================================
# Display
# ============================================================

show_entry() {
    local file="$1"
    shift
    local keywords=("$@")

    local fname
    fname=$(basename "$file")
    [[ "$fname" == "MEMORY.md" ]] && return 1

    local name type tags body created
    name=$(get_field "$file" "name")
    type=$(get_field "$file" "type")
    tags=$(get_field "$file" "tags")
    created=$(get_field "$file" "created")
    body=$(get_body "$file")

    [[ -z "$name" ]] && name="$fname"

    # Multi-keyword matching: ALL keywords must match somewhere
    if (( ${#keywords[@]} > 0 )); then
        local searchable
        searchable=$(printf '%s %s %s %s' "$name" "$body" "$tags" "$fname" | tr '[:upper:]' '[:lower:]')
        for kw in "${keywords[@]}"; do
            local lower_kw
            lower_kw=$(printf '%s' "$kw" | tr '[:upper:]' '[:lower:]')
            if [[ "$searchable" != *"$lower_kw"* ]]; then
                return 1
            fi
        done
    fi

    # Display label
    local label
    label=$(type_from_filename "$fname")

    printf "  [%s] %s\n" "$label" "$name"
    if [[ -n "$body" ]]; then
        # Indent body, max 2 lines
        local line_count=0
        while IFS= read -r line; do
            (( line_count++ ))
            if (( line_count > 2 )); then
                printf "         ...\n"
                break
            fi
            printf "         %s\n" "$line"
        done <<< "$body"
    fi
    if [[ -n "$tags" ]]; then
        printf "         🏷️  %s\n" "$tags"
    fi
    if [[ -n "$created" ]]; then
        printf "         📅 %s\n" "$created"
    fi
    printf "         📄 %s\n\n" "$fname"
    return 0
}

# ============================================================
# Main
# ============================================================

main() {
    local filter_type=""
    local filter_tag=""
    local keywords=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type|-t)
                filter_type="$2"
                shift 2
                ;;
            --tag)
                filter_tag="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: recall.sh [--type pattern|preference|workflow|rule] [--tag <tag>] [keyword ...]"
                echo ""
                echo "Examples:"
                echo "  recall.sh                    # Show all"
                echo "  recall.sh API error          # Match memories containing both 'API' AND 'error'"
                echo "  recall.sh --type rule        # Only rules"
                echo "  recall.sh --tag api          # Only tagged with 'api'"
                exit 0
                ;;
            *)
                keywords+=("$1")
                shift
                ;;
        esac
    done

    local memory_dir
    memory_dir=$(get_memory_dir)

    if [[ ! -d "$memory_dir" ]]; then
        echo "📭 No memories found. Use /learn to start recording."
        exit 0
    fi

    # Count files
    local total=0
    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ -f "$f" ]] && (( total++ )) || true
    done

    if (( total == 0 )); then
        echo "📭 No memories found. Use /learn to start recording."
        exit 0
    fi

    echo ""
    echo "📚 Project Memories ($total entries)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local shown=0

    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ ! -f "$f" ]] && continue

        local fname
        fname=$(basename "$f")

        # Type filter
        if [[ -n "$filter_type" ]]; then
            local inferred
            inferred=$(type_from_filename "$fname")
            if [[ "$inferred" != "$filter_type" ]]; then
                continue
            fi
        fi

        # Tag filter
        if [[ -n "$filter_tag" ]]; then
            local file_tags
            file_tags=$(get_tags "$f")
            local lower_tags lower_filter
            lower_tags=$(printf '%s' "$file_tags" | tr '[:upper:]' '[:lower:]')
            lower_filter=$(printf '%s' "$filter_tag" | tr '[:upper:]' '[:lower:]')
            if [[ "$lower_tags" != *"$lower_filter"* ]]; then
                continue
            fi
        fi

        if show_entry "$f" "${keywords[@]+"${keywords[@]}"}"; then
            (( shown++ )) || true
        fi
    done

    if (( shown == 0 )); then
        echo "  No matching memories."
        if [[ -n "$filter_type" ]]; then echo "  Filter: type=$filter_type"; fi
        if [[ -n "$filter_tag" ]]; then echo "  Filter: tag=$filter_tag"; fi
        if (( ${#keywords[@]} > 0 )); then echo "  Keywords: ${keywords[*]}"; fi
    else
        echo "  Showing $shown of $total entries"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 Location: $memory_dir"
}

main "$@"
