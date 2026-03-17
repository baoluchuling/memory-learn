#!/bin/bash
# uninstall.sh — Remove memory-learn skill
set -euo pipefail

echo "🗑️  Uninstalling memory-learn skill..."

# Claude Code
if [[ -d "$HOME/.claude/skills/memory-learn" ]]; then
    rm -rf "$HOME/.claude/skills/memory-learn"
    echo "  ✅ Removed Claude Code skill directory"
fi

# Remove Stop hook from settings.json
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [[ -f "$CLAUDE_SETTINGS" ]] && grep -q 'stop-hook.sh' "$CLAUDE_SETTINGS" 2>/dev/null; then
    python3 -c "
import json

with open('$CLAUDE_SETTINGS', 'r') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
if 'Stop' in hooks:
    hooks['Stop'] = [h for h in hooks['Stop'] if 'stop-hook.sh' not in json.dumps(h)]
    if not hooks['Stop']:
        del hooks['Stop']
    if not hooks:
        del settings['hooks']

with open('$CLAUDE_SETTINGS', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
    echo "  ✅ Removed Stop hook from settings.json"
fi

# Codex CLI
if [[ -d "$HOME/.codex/skills/memory-learn" ]]; then
    rm -rf "$HOME/.codex/skills/memory-learn"
    echo "  ✅ Removed Codex CLI skill directory"
fi

echo ""
echo "🎉 Uninstall complete!"
echo "  Note: Your memory data in ~/.claude/projects/*/memory/ is preserved."
echo "  Note: Codex AGENTS.md memory-learn section needs manual removal if present."
