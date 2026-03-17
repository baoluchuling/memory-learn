# memory-learn

Persistent learning system for Claude Code and Codex CLI. Gives you explicit control over what your AI assistant remembers across sessions.

## What it does

- `/learn` — Record patterns, preferences, workflows, and rules
- `/recall` — Search and view stored memories
- `/forget` — Delete outdated memories
- `/deduplicate` — Find and clean up similar entries

## How it differs from built-in auto memory

| | Built-in Auto Memory | memory-learn |
|---|---|---|
| **Control** | AI decides what to save | You decide explicitly |
| **Trigger** | Automatic | Manual commands + session-end prompts |
| **Format** | Same | Same (native frontmatter `.md` files) |
| **Coexistence** | ✅ | ✅ Works alongside built-in |

memory-learn **complements** the built-in auto memory — it doesn't replace or disable it.

## Install

```bash
git clone https://github.com/YOUR_USERNAME/memory-learn.git
cd memory-learn
bash install.sh
```

## Uninstall

```bash
bash uninstall.sh
```

## How it works

1. Each memory is a standalone `.md` file with YAML frontmatter (Claude Code's native format)
2. `MEMORY.md` is an auto-generated index — first 200 lines load at session start
3. A Stop hook reminds the AI to suggest recording useful patterns at session end
4. Cross-CLI sync keeps Claude Code and Codex memories in sync

## Memory types

| Type | Use case | Example |
|------|----------|---------|
| `pattern` | Problem→solution | "CORS errors: check gateway config first" |
| `preference` | Tool/style choice | "Use pnpm, not npm" |
| `workflow` | Multi-step process | "Deploy: build → test → staging → prod" |
| `rule` | Hard constraint | "All API calls must have error handling" |

## License

MIT
