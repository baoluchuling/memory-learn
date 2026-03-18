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
  (8) /config — manage auto-learn settings
  (9) Auto-learning: AI records useful patterns automatically (configurable)
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

### `/rebuild` — Repair Index

```bash
bash {SKILL_DIR}/scripts/rebuild.sh                        # Rebuild MEMORY.md from files
```

### `/config` — Settings

```bash
bash {SKILL_DIR}/scripts/config.sh                         # Show current config
bash {SKILL_DIR}/scripts/config.sh set auto_learn on       # Auto-record (default)
bash {SKILL_DIR}/scripts/config.sh set auto_learn off      # Ask before recording
bash {SKILL_DIR}/scripts/config.sh set expire_days 60      # Change expiry threshold
```

## Auto-Learning Mode (default: ON)

When `auto_learn=on`:

**During session** — If you detect something worth remembering mid-conversation (user correction, preference, solved problem), record it immediately:

```bash
bash {SKILL_DIR}/scripts/learn.sh --type <type> --tags "relevant,tags" "description with context"
```

Then notify: `📝 Auto-recorded: [type] "description"`

**At session end** — The Stop hook triggers. You MUST:
1. Review the session for reusable knowledge
2. Record anything valuable directly (don't ask)
3. Notify user what was recorded

**What to auto-record:**
- Problem→fix patterns (include: error, root cause, solution)
- User corrections to your approach (record as rule with reason)
- Expressed preferences (tools, style, workflow choices)
- Multi-step workflows that worked well

**What NOT to auto-record:**
- Simple Q&A, file reads, trivial changes
- Task-specific details that won't apply elsewhere
- Information already in existing memories (check first)

When `auto_learn=off`: Ask before recording (old behavior).

## Session-End Maintenance Hook

The Stop hook also triggers lightweight maintenance:
1. Auto-learn (above)
2. If memory count > 30, warn about running `/deduplicate`
3. If any memory > expire_days old, mention running `/organize`

This runs automatically — no user action needed.

## Memory Recall Behavior

Before executing tasks, check MEMORY.md for relevant memories.
If applicable, briefly note: `💡 Applying: [description]`

Priority: rules > preferences > patterns > workflows
