---
name: memory-learn
description: |
  Persistent learning system for Claude Code / Codex CLI.
  Complements (not replaces) the built-in auto memory with explicit user-driven commands.
  Triggers:
  (1) User says "remember this", "learn this pattern", "always do it this way"
  (2) /learn — manually record knowledge
  (3) /recall or /memory — view learned knowledge
  (4) /forget — delete a memory entry
  (5) /deduplicate — detect and merge similar memories
  (6) Auto-learning: after completing tasks, AI may suggest recording useful patterns
---

# Memory Learn — Persistent Learning System

Complements Claude Code's built-in auto memory with explicit, user-controlled memory management.

## How It Works

Memory is stored using **Claude Code's native format**:
- Individual `.md` files with YAML frontmatter in the project memory directory
- `MEMORY.md` as a concise index (must stay under 200 lines)
- First 200 lines of MEMORY.md auto-load at session start

Memory directory: `~/.claude/projects/<project-hash>/memory/`

## Commands

### `/learn` — Record Knowledge

```bash
# Quick record (AI determines type)
bash {SKILL_DIR}/scripts/learn.sh --type pattern "When API returns 429, add exponential backoff"
bash {SKILL_DIR}/scripts/learn.sh --type preference "Use pnpm instead of npm"
bash {SKILL_DIR}/scripts/learn.sh --type workflow "Before commit: test → lint → diff → commit"
bash {SKILL_DIR}/scripts/learn.sh --type rule "All API calls must have error handling"
```

Types map to Claude Code's native memory types:
| memory-learn type | Native type | Use case |
|---|---|---|
| `pattern` | project | Problem→solution patterns |
| `preference` | user | Tool/style preferences |
| `workflow` | project | Multi-step processes |
| `rule` | feedback | Hard constraints |

### `/recall` — View Memories

```bash
bash {SKILL_DIR}/scripts/recall.sh              # Show all
bash {SKILL_DIR}/scripts/recall.sh --type rule   # Filter by type
bash {SKILL_DIR}/scripts/recall.sh "API"         # Search keyword
```

### `/forget` — Delete Memory

```bash
bash {SKILL_DIR}/scripts/forget.sh "outdated pattern"  # Delete by keyword
bash {SKILL_DIR}/scripts/forget.sh --id <filename>      # Delete specific file
```

### `/deduplicate` — Merge Similar Memories

```bash
bash {SKILL_DIR}/scripts/deduplicate.sh                  # Detect duplicates (60% threshold)
bash {SKILL_DIR}/scripts/deduplicate.sh --threshold 70   # Custom threshold
```

## Auto-Learning Behavior

After completing a task, consider whether the session produced reusable knowledge:

- **Problem solved?** Record the pattern (error → root cause → fix)
- **User expressed preference?** Record it (tool choice, code style, workflow)
- **User corrected your approach?** Record as rule with the reason why

Ask concisely:

```
💡 Worth remembering: [one-line description]
   Type: [pattern/preference/workflow/rule]
   Record? [y/n]
```

Rules:
- Only ask when genuinely valuable — don't ask for trivial interactions
- Respect "no" — never re-ask in the same session
- Include context (why, not just what) so the memory is useful later

## Memory Recall Behavior

Before executing tasks, check if relevant memories exist by reading the MEMORY.md index.
If a memory applies, briefly note it:

```
💡 Applying learned pattern: [description]
```

Priority: rules > preferences > patterns > workflows
