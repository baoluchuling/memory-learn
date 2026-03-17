#!/bin/bash
# learn.sh — Record knowledge to project memory using Claude Code's native format
# Usage: bash learn.sh --type <pattern|preference|workflow|rule> "content"
set -euo pipefail

# ============================================================
# CLI Detection & Memory Directory
# ============================================================

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

    # Convert path to project hash (same as Claude Code)
    local hash
    hash=$(printf '%s' "$cwd" | sed 's|/|-|g')
    echo "$base/-${hash}/memory"
}

# ============================================================
# Memory Type → Native Type Mapping
# ============================================================

native_type() {
    case "$1" in
        pattern)    echo "project" ;;
        preference) echo "user" ;;
        workflow)   echo "project" ;;
        rule)       echo "feedback" ;;
        *)          echo "project" ;;
    esac
}

type_description() {
    case "$1" in
        pattern)    echo "Problem-solution pattern learned from experience" ;;
        preference) echo "User preference for tools, style, or workflow" ;;
        workflow)   echo "Multi-step process or standard operating procedure" ;;
        rule)       echo "Hard constraint that must always be followed" ;;
        *)          echo "General knowledge" ;;
    esac
}

# ============================================================
# Write Memory File (Claude Code native format)
# ============================================================

write_memory_file() {
    local memory_dir="$1"
    local type="$2"
    local content="$3"

    mkdir -p "$memory_dir"

    # Generate filename from content (slugify first 50 chars)
    local slug
    slug=$(printf '%s' "$content" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g' | cut -c1-50 | sed 's/_*$//')
    local timestamp
    timestamp=$(date "+%Y%m%d_%H%M%S")
    local filename="${type}_${timestamp}_${slug}.md"
    local filepath="$memory_dir/$filename"

    # Avoid collision
    if [[ -f "$filepath" ]]; then
        filename="${type}_${timestamp}_${slug}_$(( RANDOM % 1000 )).md"
        filepath="$memory_dir/$filename"
    fi

    local native
    native=$(native_type "$type")
    local desc
    desc=$(type_description "$type")

    # Write with frontmatter (Claude Code native format)
    cat > "$filepath" << EOF
---
name: ${type}: $(echo "$content" | cut -c1-60)
description: ${desc}
type: ${native}
---

${content}
EOF

    echo "$filepath"
}

# ============================================================
# Update MEMORY.md Index
# ============================================================

update_memory_index() {
    local memory_dir="$1"
    local memory_md="$memory_dir/MEMORY.md"

    # Collect all memory files (exclude MEMORY.md itself)
    local tmpfile
    tmpfile=$(mktemp)
    trap "rm -f '$tmpfile'" EXIT

    # Group entries by type
    local rules="" patterns="" preferences="" workflows=""

    for f in "$memory_dir"/*.md; do
        [[ "$(basename "$f")" == "MEMORY.md" ]] && continue
        [[ ! -f "$f" ]] && continue

        local fname
        fname=$(basename "$f")
        # Extract name from frontmatter
        local name
        name=$(sed -n '/^---$/,/^---$/{ /^name:/{ s/^name: *//; p; q; } }' "$f" 2>/dev/null || echo "$fname")
        local ftype
        ftype=$(sed -n '/^---$/,/^---$/{ /^type:/{ s/^type: *//; p; q; } }' "$f" 2>/dev/null || echo "project")

        local entry="- [${name}](${fname})"

        case "$ftype" in
            feedback)  rules="${rules}${entry}"$'\n' ;;
            user)      preferences="${preferences}${entry}"$'\n' ;;
            project)
                # Distinguish pattern vs workflow by filename prefix
                if [[ "$fname" == workflow_* ]]; then
                    workflows="${workflows}${entry}"$'\n'
                else
                    patterns="${patterns}${entry}"$'\n'
                fi
                ;;
        esac
    done

    # Write MEMORY.md (keep under 200 lines)
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
    lines=$(wc -l < "$memory_md")
    if (( lines > 195 )); then
        head -195 "$memory_md" > "$tmpfile"
        echo "" >> "$tmpfile"
        echo "_(truncated — $(( lines - 195 )) more lines in individual files)_" >> "$tmpfile"
        mv "$tmpfile" "$memory_md"
    fi
}

# ============================================================
# Main
# ============================================================

main() {
    local type="pattern"
    local content=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type|-t)
                type="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: learn.sh [--type pattern|preference|workflow|rule] \"content\""
                exit 0
                ;;
            *)
                content="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$content" ]]; then
        echo "❌ Content required. Usage: learn.sh --type <type> \"content\""
        exit 1
    fi

    # Validate type
    case "$type" in
        pattern|preference|workflow|rule) ;;
        *)
            echo "❌ Unknown type: $type (use: pattern, preference, workflow, rule)"
            exit 1
            ;;
    esac

    local memory_dir
    memory_dir=$(get_memory_dir)

    local filepath
    filepath=$(write_memory_file "$memory_dir" "$type" "$content")

    update_memory_index "$memory_dir"

    echo "✅ Recorded ${type} → $(basename "$filepath")"
    echo "📍 Location: $memory_dir"
}

main "$@"
