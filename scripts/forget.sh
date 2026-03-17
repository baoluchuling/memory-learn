#!/bin/bash
# forget.sh — Delete memory entries by keyword or filename
# Usage: bash forget.sh [--id <filename>] [keyword]
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

# Source the index updater from learn.sh
update_memory_index() {
    local memory_dir="$1"
    local learn_script
    learn_script="$(dirname "$0")/learn.sh"

    # Re-implement index update inline (avoid sourcing complexity)
    local memory_md="$memory_dir/MEMORY.md"
    local rules="" patterns="" preferences="" workflows=""

    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ ! -f "$f" ]] && continue

        local fname
        fname=$(basename "$f")
        local name
        name=$(sed -n '/^---$/,/^---$/{ /^name:/{ s/^name: *//; p; q; } }' "$f" 2>/dev/null || echo "$fname")
        local ftype
        ftype=$(sed -n '/^---$/,/^---$/{ /^type:/{ s/^type: *//; p; q; } }' "$f" 2>/dev/null || echo "project")

        local entry="- [${name}](${fname})"

        case "$ftype" in
            feedback)  rules="${rules}${entry}"$'\n' ;;
            user)      preferences="${preferences}${entry}"$'\n' ;;
            project)
                if [[ "$fname" == workflow_* ]]; then
                    workflows="${workflows}${entry}"$'\n'
                else
                    patterns="${patterns}${entry}"$'\n'
                fi
                ;;
        esac
    done

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

    # Delete by specific ID (filename)
    if [[ -n "$target_id" ]]; then
        local target_path="$memory_dir/$target_id"
        if [[ -f "$target_path" ]]; then
            local name
            name=$(sed -n '/^---$/,/^---$/{ /^name:/{ s/^name: *//; p; q; } }' "$target_path" 2>/dev/null || echo "$target_id")
            rm -f "$target_path"
            update_memory_index "$memory_dir"
            echo "✅ Deleted: $name"
            echo "📍 File: $target_id"
        else
            echo "❌ File not found: $target_id"
            exit 1
        fi
        return
    fi

    # Delete by keyword search
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

    # Find matching files
    local matches=()
    local match_names=()

    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ ! -f "$f" ]] && continue

        local name body lower_content
        name=$(sed -n '/^---$/,/^---$/{ /^name:/{ s/^name: *//; p; q; } }' "$f" 2>/dev/null || echo "")
        body=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$f")
        lower_content=$(printf '%s %s' "$name" "$body" | tr '[:upper:]' '[:lower:]')

        if [[ "$lower_content" == *"$lower_keyword"* ]]; then
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
        rm -f "$f"
    done

    update_memory_index "$memory_dir"

    echo "✅ Deleted ${#matches[@]} memor(ies) matching \"$keyword\""
    echo "📍 Location: $memory_dir"
}

main "$@"
