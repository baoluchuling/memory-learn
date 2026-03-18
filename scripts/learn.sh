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
# MEMORY.md Index — Init & Incremental Update
# ============================================================

MEMORY_MD_TEMPLATE='# Project Memory

## Rules
_(none)_

## Preferences
_(none)_

## Patterns
_(none)_

## Workflows
_(none)_
'

# Ensure MEMORY.md exists with section headers
ensure_memory_md() {
    local memory_md="$1/MEMORY.md"
    if [[ ! -f "$memory_md" ]]; then
        printf '%s\n' "$MEMORY_MD_TEMPLATE" > "$memory_md"
    fi
}

# Map type → section header in MEMORY.md
section_for_type() {
    case "$1" in
        rule)       echo "## Rules" ;;
        preference) echo "## Preferences" ;;
        pattern)    echo "## Patterns" ;;
        workflow)   echo "## Workflows" ;;
    esac
}

# Append one entry to the correct section in MEMORY.md
append_to_index() {
    local memory_dir="$1"
    local type="$2"
    local filename="$3"
    local name="$4"

    local memory_md="$memory_dir/MEMORY.md"
    ensure_memory_md "$memory_dir"

    local section
    section=$(section_for_type "$type")
    local entry="- [${name}](${filename})"

    # Find the section header line number
    local section_line
    section_line=$(grep -n "^${section}$" "$memory_md" | head -1 | cut -d: -f1)

    if [[ -z "$section_line" ]]; then
        # Section missing — append at end
        printf '\n%s\n%s\n' "$section" "$entry" >> "$memory_md"
        return
    fi

    # Remove _(none)_ placeholder if present (the line right after the header)
    local next_line=$(( section_line + 1 ))
    local next_content
    next_content=$(sed -n "${next_line}p" "$memory_md")
    if [[ "$next_content" == "_(none)_" ]]; then
        sed -i.bak "${next_line}d" "$memory_md" && rm -f "$memory_md.bak"
    fi

    # Insert entry right after the section header
    sed -i.bak "${section_line}a\\
${entry}" "$memory_md" && rm -f "$memory_md.bak"

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

    # Incremental update: only append the new entry to MEMORY.md
    local fname
    fname=$(basename "$filepath")
    local display_name
    display_name="${type}: $(echo "$content" | cut -c1-60)"
    append_to_index "$memory_dir" "$type" "$fname" "$display_name"

    echo "✅ Recorded ${type} → $(basename "$filepath")"
    echo "📍 Location: $memory_dir"
}

main "$@"
