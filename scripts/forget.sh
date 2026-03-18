#!/bin/bash
# forget.sh — Delete memory entries by keyword or filename
# Usage: bash forget.sh [--id <filename>] [keyword]
set -euo pipefail

source "$(dirname "$0")/common.sh"

# ============================================================
# Incremental index removal
# ============================================================

remove_from_index() {
    local memory_dir="$1"
    local filename="$2"
    local memory_md="$memory_dir/MEMORY.md"

    [[ ! -f "$memory_md" ]] && return

    # Remove lines referencing this filename
    local tmpfile
    tmpfile=$(mktemp)
    grep -v "(${filename})" "$memory_md" > "$tmpfile" || true
    mv "$tmpfile" "$memory_md"
}

# ============================================================
# Main
# ============================================================

main() {
    local target_id=""
    local keyword=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id)
                target_id="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: forget.sh [--id <filename>] [keyword]"
                echo ""
                echo "Examples:"
                echo "  forget.sh \"API\"          # Delete memories matching 'API'"
                echo "  forget.sh --id file.md   # Delete specific file"
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
        echo "📭 No memories to delete."
        exit 0
    fi

    # Delete by specific filename
    if [[ -n "$target_id" ]]; then
        local target_path="$memory_dir/$target_id"
        if [[ -f "$target_path" ]]; then
            local name
            name=$(get_field "$target_path" "name")
            [[ -z "$name" ]] && name="$target_id"
            rm -f "$target_path"
            remove_from_index "$memory_dir" "$target_id"
            echo "✅ Deleted: $name"
            echo "📍 File: $target_id"
        else
            echo "❌ File not found: $target_id"
            exit 1
        fi
        return
    fi

    # Delete by keyword
    if [[ -z "$keyword" ]]; then
        echo "Usage: forget.sh [--id <filename>] [keyword]"
        echo ""
        echo "Examples:"
        echo "  forget.sh \"API\"          # Delete memories matching 'API'"
        echo "  forget.sh --id file.md   # Delete specific file"
        exit 1
    fi

    local lower_keyword
    lower_keyword=$(printf '%s' "$keyword" | tr '[:upper:]' '[:lower:]')

    local matches=()
    local match_names=()

    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ ! -f "$f" ]] && continue

        local name body tags
        name=$(get_field "$f" "name")
        body=$(get_body "$f")
        tags=$(get_tags "$f")
        local searchable
        searchable=$(printf '%s %s %s' "$name" "$body" "$tags" | tr '[:upper:]' '[:lower:]')

        if [[ "$searchable" == *"$lower_keyword"* ]]; then
            matches+=("$f")
            match_names+=("$name")
        fi
    done

    if (( ${#matches[@]} == 0 )); then
        echo "📭 No memories matching \"$keyword\""
        exit 0
    fi

    echo ""
    echo "🔍 Found ${#matches[@]} matching memor(ies):"
    echo ""

    for i in "${!matches[@]}"; do
        printf "  %d) %s\n" $((i + 1)) "${match_names[$i]}"
        printf "     📄 %s\n\n" "$(basename "${matches[$i]}")"
    done

    # Delete all matches
    for f in "${matches[@]}"; do
        local fname
        fname=$(basename "$f")
        rm -f "$f"
        remove_from_index "$memory_dir" "$fname"
    done

    echo "✅ Deleted ${#matches[@]} memor(ies) matching \"$keyword\""
    echo "📍 Location: $memory_dir"
}

main "$@"
