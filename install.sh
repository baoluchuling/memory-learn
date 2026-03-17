#!/bin/bash
# install.sh — Install memory-learn skill to Claude Code (and optionally Codex CLI)
# Usage: bash install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🧠 Installing memory-learn skill..."
echo ""

# ============================================================
# 1. Claude Code
# ============================================================
CLAUDE_SKILL_DIR="$HOME/.claude/skills/memory-learn"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "📦 Installing to Claude Code..."

mkdir -p "$CLAUDE_SKILL_DIR/scripts"
mkdir -p "$CLAUDE_SKILL_DIR/references"

cp "$SCRIPT_DIR/SKILL.md" "$CLAUDE_SKILL_DIR/SKILL.md"
cp "$SCRIPT_DIR/scripts/"*.sh "$CLAUDE_SKILL_DIR/scripts/"
[[ -d "$SCRIPT_DIR/references" ]] && cp "$SCRIPT_DIR/references/"*.md "$CLAUDE_SKILL_DIR/references/" 2>/dev/null || true
chmod +x "$CLAUDE_SKILL_DIR/scripts/"*.sh

echo "  ✅ Skill files installed to $CLAUDE_SKILL_DIR"

# Inject Stop hook (does NOT disable autoMemoryEnabled)
if [[ -f "$CLAUDE_SETTINGS" ]]; then
    if grep -q 'stop-hook.sh' "$CLAUDE_SETTINGS" 2>/dev/null; then
        echo "  ⏭️  Stop hook already exists, skipping"
    else
        python3 -c "
import json

with open('$CLAUDE_SETTINGS', 'r') as f:
    settings = json.load(f)

settings.setdefault('hooks', {})
stop_hooks = settings['hooks'].get('Stop', [])
stop_hooks.append({
    'matcher': '',
    'hooks': [
        {
            'type': 'command',
            'command': 'bash $CLAUDE_SKILL_DIR/scripts/stop-hook.sh'
        }
    ]
})
settings['hooks']['Stop'] = stop_hooks

with open('$CLAUDE_SETTINGS', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
        echo "  ✅ Stop hook injected into settings.json"
    fi
else
    cat > "$CLAUDE_SETTINGS" << SETTINGS
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash $CLAUDE_SKILL_DIR/scripts/stop-hook.sh"
          }
        ]
      }
    ]
  }
}
SETTINGS
    echo "  ✅ Created settings.json with Stop hook"
fi

# ============================================================
# 2. Codex CLI (optional)
# ============================================================
if command -v codex &>/dev/null || [[ -d "$HOME/.codex" ]]; then
    CODEX_SKILL_DIR="$HOME/.codex/skills/memory-learn"
    CODEX_AGENTS="$HOME/.codex/AGENTS.md"

    echo ""
    echo "📦 Installing to Codex CLI..."

    mkdir -p "$CODEX_SKILL_DIR/scripts"
    mkdir -p "$CODEX_SKILL_DIR/references"

    cp "$SCRIPT_DIR/SKILL.md" "$CODEX_SKILL_DIR/SKILL.md"
    cp "$SCRIPT_DIR/scripts/"*.sh "$CODEX_SKILL_DIR/scripts/"
    [[ -d "$SCRIPT_DIR/references" ]] && cp "$SCRIPT_DIR/references/"*.md "$CODEX_SKILL_DIR/references/" 2>/dev/null || true
    chmod +x "$CODEX_SKILL_DIR/scripts/"*.sh

    echo "  ✅ Skill files installed to $CODEX_SKILL_DIR"

    if [[ -f "$CODEX_AGENTS" ]] && grep -q 'memory-learn' "$CODEX_AGENTS" 2>/dev/null; then
        echo "  ⏭️  AGENTS.md already configured, skipping"
    else
        cat >> "${CODEX_AGENTS:-$HOME/.codex/AGENTS.md}" << 'AGENTS'

## Auto-Learning (memory-learn)

After completing tasks, briefly consider if anything is worth remembering:
- Problem→solution patterns, user preferences, workflow corrections
- If so, ask the user and record with: bash ~/.codex/skills/memory-learn/scripts/learn.sh --type <type> "<content>"
AGENTS
        echo "  ✅ Auto-learning instructions added to AGENTS.md"
    fi
else
    echo ""
    echo "⏭️  Codex CLI not detected, skipping"
fi

# ============================================================
# Done
# ============================================================
echo ""
echo "🎉 Installation complete!"
echo ""
echo "  Commands:"
echo "    /learn              Record knowledge"
echo "    /recall             View memories"
echo "    /forget             Delete memories"
echo "    /deduplicate        Find duplicates"
echo ""
echo "  Note: Built-in auto memory remains enabled (works alongside memory-learn)"
echo "  Uninstall: bash $SCRIPT_DIR/uninstall.sh"
