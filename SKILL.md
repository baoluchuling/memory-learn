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
  (6) /organize — memory health report and expiration check
  (7) /rebuild — repair corrupted MEMORY.md index
  (8) Auto-learning: after completing tasks, AI may suggest recording useful patterns
---

# Memory Learn — Persistent Learning System

Complements Claude Code's built-in auto memory with explicit, user-controlled memory management.

## Storage

Memory uses **Claude Code's native format**: individual `.md` files with YAML frontmatter.
`MEMORY.md` is a concise index (≤200 lines, auto-loaded at session start).

Directory: `~/.claude/projects/<project-hash>/memory/`

## Commands

### `/learn` — Record Knowledge

```bash
bash {SKILL_DIR}/scripts/learn.sh --type pattern "When API returns 429, add exponential backoff"
bash {SKILL_DIR}/scripts/learn.sh --type preference "Use pnpm instead of npm"
bash {SKILL_DIR}/scripts/learn.sh --type workflow "Before commit: test → lint → diff → commit"
bash {SKILL_DIR}/scripts/learn.sh --type rule "All API calls must have error handling"

# With tags for better filtering
bash {SKILL_DIR}/scripts/learn.sh --type pattern --tags "api,error" "429 errors need exponential backoff"
```

### `/recall` — View & Search Memories

```bash
bash {SKILL_DIR}/scripts/recall.sh                        # Show all
bash {SKILL_DIR}/scripts/recall.sh --type rule             # Filter by type
bash {SKILL_DIR}/scripts/recall.sh --tag api               # Filter by tag
bash {SKILL_DIR}/scripts/recall.sh API error               # Multi-keyword (AND match)
bash {SKILL_DIR}/scripts/recall.sh --type pattern --tag api "retry"  # Combined filters
```

### `/forget` — Delete Memory

```bash
bash {SKILL_DIR}/scripts/forget.sh "outdated pattern"      # Delete by keyword
bash {SKILL_DIR}/scripts/forget.sh --id <filename>          # Delete specific file
```

### `/deduplicate` — Find Similar Memories

```bash
bash {SKILL_DIR}/scripts/deduplicate.sh                    # Default 60% threshold
bash {SKILL_DIR}/scripts/deduplicate.sh --threshold 70     # Stricter
```

### `/organize` — Health Report

```bash
bash {SKILL_DIR}/scripts/auto-organize.sh                  # Default: flag entries >90 days
bash {SKILL_DIR}/scripts/auto-organize.sh --max-age 60     # Custom threshold
```

Reports: type distribution, index usage, expired entries, health score, suggestions.

### `/rebuild` — Repair Index

```bash
bash {SKILL_DIR}/scripts/rebuild.sh                        # Rebuild MEMORY.md from files
```

Use when MEMORY.md is corrupted, out of sync, or after manual edits.

## Auto-Learning Behavior

After completing a task, consider whether the session produced reusable knowledge.
Ask concisely only when genuinely valuable:

```
💡 Worth remembering: [one-line description]
   Type: [pattern/preference/workflow/rule]
   Tags: [optional]
   Record? [y/n]
```

- Respect "no" — never re-ask in the same session
- Include context (why, not just what)

## Memory Recall Behavior

Before executing tasks, check MEMORY.md for relevant memories.
If applicable, briefly note: `💡 Applying: [description]`

Priority: rules > preferences > patterns > workflows
