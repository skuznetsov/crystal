Title: SmallVec phase 2 (branches/entries/interpolation) + benches
When: 2025-11-05T15:40:00Z
Author: gpt5 (Codex CLI)

Changes
- SmallVec conversions:
  - Case/when branches and in-branches builders → SmallVec → to_a
  - Select/when branches → SmallVec → to_a
  - HashLiteral entries (both paths) → SmallVec → to_a
  - NamedTupleLiteral entries → SmallVec → to_a
  - StringInterpolation pieces → SmallVec → to_a
  - asm(args) → SmallVec → to_a
- Parser + LSP specs re-run: green (same 6 pending parser specs for trim).

Arena
- PageArena (opt-in via CRYSTAL_V2_PAGE_ARENA) remains available; default is AstArena with pre-sizing when not streaming.

Benches
- comp11.csv/json (default arena): exported; times larger in this run (likely build mode/context). Memory columns available.
- Earlier comp10 (PageArena) showed parser speed wins on large files.

Notes
- Next: additional span slimming opportunities; consider rescue_clauses builder to SmallVec, and sweep remaining niche arrays.
