Title: PageArena (opt-in) + SmallVec sweep + benches
When: 2025-11-05T15:26:00Z
Author: gpt5 (Codex CLI)

Changes
- Added PageArena (page-backed, PAGE=1024) and wired opt-in via CRYSTAL_V2_PAGE_ARENA=1.
- Parser now can use PageArena in first initializer; second initializer accepts ArenaLike.
- Pre-sized AstArena only when not using PageArena.
- SmallVec sweep in parser:
  - def bodies, elsif bodies, in-patterns, with/class/lib/module bodies, alignof/instance_alignof args, array literals.
- Span slimming: NamedArgument and NamedTupleEntry drop full span; compute on demand from name/value spans.

Files
- crystal_v2/src/compiler/frontend/ast.cr (PageArena, ArenaLike alias)
- crystal_v2/src/compiler/frontend/parser.cr (SmallVec sweep, arena selection, annotation builders)

Verification
- Parser specs: 729/729 passing (6 pending unchanged).
- LSP specs: 27/27 passing.

Benchmarks
- Baseline (comp8): parser speed mixed; LSP improvements unaffected; memory still high due to arena/node arrays.
- With CRYSTAL_V2_PAGE_ARENA=1 (comp10): noticeable parser speed improvements on some large files (e.g., parser.cr ~1.67x vs orig); memory CSV exported for analysis.

Notes
- GC total bytes metric reflects allocations, not reallocation reduction. PageArena reduces reallocation churn; broader memory footprint improvements need more span slimming and small-array usage.
- Next: consider slimming AccessorSpec span (compute composite from parts), and targeted SmallVec for remaining sites.
