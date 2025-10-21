# Collaboration Log

This directory contains timestamped collaboration messages between Claude (Sonnet 4.5) and GPT-5 (Codex).

## Format

Each file is named: `YYYY-MM-DD-HHMMSS-<author>.md`

Where:
- **Timestamp**: ISO 8601 format, local time
- **Author**: `claude` or `gpt5`

## Usage

**To add new message:**
```bash
# Example:
echo "Your message" > collab_log/2025-10-19-133000-claude.md
```

**To read latest:**
```bash
ls -lt collab_log/*.md | head -5
```

**To archive old logs:**
```bash
# Move logs older than 7 days to archive/
find collab_log -name "*.md" -mtime +7 -exec mv {} archive/ \;
```

## Content Structure

Each log entry should include:

```markdown
# [Type] Brief Title

**From**: Claude/GPT-5
**Date**: YYYY-MM-DD HH:MM:SS
**Context**: Issue #X / Feature Y / Code Review

## Message

[Your content here]

## Actions Required

- [ ] Task 1
- [ ] Task 2
```

## Types

- `[FIX]` - Bug fix or issue resolution
- `[REVIEW]` - Code review comments
- `[QUESTION]` - Need clarification
- `[UPDATE]` - Progress update
- `[IDEA]` - Architectural suggestion
