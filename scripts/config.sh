#!/bin/bash
# config.sh — Manage memory-learn configuration
# Usage: bash config.sh [get|set] <key> [value]
set -euo pipefail

source "$(dirname "$0")/common.sh"

get_config_file() {
    local memory_dir
    memory_dir=$(get_memory_dir)
    mkdir -p "$memory_dir"
    echo "$memory_dir/.config"
}

# Initialize config with defaults if not exists
ensure_config() {
    local config_file
    config_file=$(get_config_file)
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
# memory-learn configuration
# auto_learn: on = record automatically, off = ask before recording
auto_learn=on
# auto_learn_types: which types to auto-record (comma-separated)
# options: pattern,preference,workflow,rule
auto_learn_types=pattern,preference,rule
# expire_days: days before a memory is flagged as expired
expire_days=90
EOF
    fi
}

# Get a config value
get_config() {
    local key="$1"
    local config_file
    config_file=$(get_config_file)
    ensure_config

    local value
    value=$(grep "^${key}=" "$config_file" 2>/dev/null | head -1 | cut -d'=' -f2-)
    echo "$value"
}

# Set a config value
set_config() {
    local key="$1"
    local value="$2"
    local config_file
    config_file=$(get_config_file)
    ensure_config

    if grep -q "^${key}=" "$config_file" 2>/dev/null; then
        # Update existing key (portable sed)
        local tmpfile
        tmpfile=$(mktemp)
        awk -v k="$key" -v v="$value" '
            $0 ~ "^"k"=" { print k"="v; next }
            { print }
        ' "$config_file" > "$tmpfile"
        mv "$tmpfile" "$config_file"
    else
        echo "${key}=${value}" >> "$config_file"
    fi
}

# ============================================================
# Main
# ============================================================

main() {
    local action="${1:-show}"
    local key="${2:-}"
    local value="${3:-}"

    case "$action" in
        get)
            if [[ -z "$key" ]]; then
                echo "Usage: config.sh get <key>"
                exit 1
            fi
            get_config "$key"
            ;;
        set)
            if [[ -z "$key" ]] || [[ -z "$value" ]]; then
                echo "Usage: config.sh set <key> <value>"
                exit 1
            fi
            set_config "$key" "$value"
            echo "✅ Set ${key}=${value}"
            ;;
        show)
            local config_file
            config_file=$(get_config_file)
            ensure_config
            echo ""
            echo "⚙️  memory-learn config"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            while IFS= read -r line; do
                [[ "$line" == \#* ]] && continue
                [[ -z "$line" ]] && continue
                local k v
                k=$(echo "$line" | cut -d'=' -f1)
                v=$(echo "$line" | cut -d'=' -f2-)
                printf "  %-20s = %s\n" "$k" "$v"
            done < "$config_file"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📍 Config: $config_file"
            echo ""
            echo "Usage:"
            echo "  config.sh set auto_learn on     # Enable auto-learning"
            echo "  config.sh set auto_learn off    # Disable (ask before recording)"
            echo "  config.sh set expire_days 60    # Change expiry threshold"
            ;;
        --help|-h)
            echo "Usage: config.sh [show|get <key>|set <key> <value>]"
            ;;
        *)
            echo "❌ Unknown action: $action"
            echo "Usage: config.sh [show|get <key>|set <key> <value>]"
            exit 1
            ;;
    esac
}

main "$@"
