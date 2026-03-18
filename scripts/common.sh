#!/bin/bash
# common.sh — Shared functions for memory-learn scripts
# Source this file: source "$(dirname "$0")/common.sh"

# Detect active CLI (claude or codex)
detect_cli() {
    if [[ "${CLAUDE_CLI:-}" == "codex" ]] || [[ -n "${CODEX_SESSION_ID:-}" ]]; then
        echo "codex"
    else
        echo "claude"
    fi
}

# Get the project memory directory path
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

# Extract a frontmatter field from a memory file
# Usage: get_field "file.md" "name"
get_field() {
    local file="$1"
    local field="$2"
    awk -v key="$field" '
        /^---$/ { count++; next }
        count == 1 && $0 ~ "^"key":" {
            sub("^"key":[ ]*", "")
            # Strip surrounding quotes
            gsub(/^["'\'']|["'\'']$/, "")
            print
            exit
        }
        count >= 2 { exit }
    ' "$file" 2>/dev/null
}

# Extract body content (after second ---) from a memory file
get_body() {
    local file="$1"
    awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$file" | sed '/^$/d'
}

# Map memory-learn type to native Claude Code type
native_type() {
    case "$1" in
        pattern)    echo "project" ;;
        preference) echo "user" ;;
        workflow)   echo "project" ;;
        rule)       echo "feedback" ;;
        *)          echo "project" ;;
    esac
}

# Map memory-learn type to section header in MEMORY.md
section_for_type() {
    case "$1" in
        rule)       echo "## Rules" ;;
        preference) echo "## Preferences" ;;
        pattern)    echo "## Patterns" ;;
        workflow)   echo "## Workflows" ;;
    esac
}

# Infer memory-learn type from filename prefix
type_from_filename() {
    local fname="$1"
    case "$fname" in
        rule_*)       echo "rule" ;;
        preference_*) echo "preference" ;;
        workflow_*)   echo "workflow" ;;
        pattern_*)    echo "pattern" ;;
        *)            echo "pattern" ;;
    esac
}

# Extract tags from frontmatter (comma-separated)
get_tags() {
    local file="$1"
    get_field "$file" "tags"
}

# Check if a string contains a substring (case-insensitive)
contains_ci() {
    local haystack="$1"
    local needle="$2"
    local lower_h lower_n
    lower_h=$(printf '%s' "$haystack" | tr '[:upper:]' '[:lower:]')
    lower_n=$(printf '%s' "$needle" | tr '[:upper:]' '[:lower:]')
    [[ "$lower_h" == *"$lower_n"* ]]
}
