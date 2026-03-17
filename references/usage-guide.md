# Memory Learn Usage Guide

## Quick Start

```bash
# Install
bash install.sh

# Record something
/learn --type preference "Use pnpm instead of npm"

# View memories
/recall

# Search memories
/recall "API"

# Delete a memory
/forget "outdated pattern"

# Check for duplicates
/deduplicate
```

## Memory Types

| Type | When to use | Example |
|------|-------------|---------|
| `pattern` | Problem→solution you discovered | "CORS errors: check API gateway config, not just server headers" |
| `preference` | Tool/style choice | "Use Vitest, not Jest" |
| `workflow` | Multi-step process | "Deploy: build → test → staging → canary → prod" |
| `rule` | Must-follow constraint | "Never commit .env files" |

## How Memory Works

1. Each memory is a standalone `.md` file with YAML frontmatter
2. `MEMORY.md` is an auto-generated index (first 200 lines load at session start)
3. AI checks relevant memories before executing tasks
4. Stop hook reminds AI to suggest learning at session end

## Storage

```
~/.claude/projects/<project-hash>/memory/
├── MEMORY.md                        # Auto-generated index
├── pattern_20260317_*.md            # Individual memories
├── preference_20260317_*.md
├── workflow_20260317_*.md
└── rule_20260317_*.md
```

## Compatibility

- Works alongside Claude Code's built-in auto memory (does NOT disable it)
- Uses Claude Code's native frontmatter format
- Supports Codex CLI via cross-CLI sync
- macOS and Linux compatible

## Tips

- Be specific: include context (why), not just conclusions (what)
- Review periodically: `/recall` then `/forget` outdated entries
- Use `/deduplicate` when memory grows large
- Keep rules minimal — too many rules create cognitive overhead
