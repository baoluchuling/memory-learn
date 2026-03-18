#!/bin/bash
# rebuild.sh — Rebuild MEMORY.md index from individual memory files
# Use when the index is corrupted or out of sync
# Usage: bash rebuild.sh
set -euo pipefail

source "$(dirname "$0")/common.sh"

main() {
    local memory_dir
    memory_dir=$(get_memory_dir)

    if [[ ! -d "$memory_dir" ]]; then
        echo "📭 No memory directory found."
        exit 0
    fi

    local memory_md="$memory_dir/MEMORY.md"

    # Collect entries grouped by type
    local rules="" patterns="" preferences="" workflows=""
    local count=0

    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ ! -f "$f" ]] && continue

        (( count++ )) || true

        local fname
        fname=$(basename "$f")
        local name tags
        name=$(get_field "$f" "name")
        tags=$(get_field "$f" "tags")
        [[ -z "$name" ]] && name="$fname"

        local entry="- [${name}](${fname})"
        if [[ -n "$tags" ]]; then
            entry="${entry} \`${tags}\`"
        fi

        local type
        type=$(type_from_filename "$fname")

        case "$type" in
            rule)       rules="${rules}${entry}"$'\n' ;;
            preference) preferences="${preferences}${entry}"$'\n' ;;
            workflow)   workflows="${workflows}${entry}"$'\n' ;;
            *)          patterns="${patterns}${entry}"$'\n' ;;
        esac
    done

    # Write fresh MEMORY.md
    cat > "$memory_md" << EOF
# Project Memory

## Rules
${rules:-_(none)_
}
## Preferences
${preferences:-_(none)_
}
## Patterns
${patterns:-_(none)_
}
## Workflows
${workflows:-_(none)_
}
EOF

    # Enforce 200-line limit
    local lines
    lines=$(wc -l < "$memory_md" | tr -d ' ')
    if (( lines > 195 )); then
        local tmpfile
        tmpfile=$(mktemp)
        head -195 "$memory_md" > "$tmpfile"
        echo "" >> "$tmpfile"
        echo "_(truncated — $(( lines - 195 )) more lines in individual files)_" >> "$tmpfile"
        mv "$tmpfile" "$memory_md"
    fi

    echo "✅ Rebuilt MEMORY.md from $count memory files"
    echo "📍 Location: $memory_dir"
}

main "$@"
