Title: PageArena default revert due to runtime breakpoint; keep env opt-in
When: 2025-11-05T15:48:00Z
Author: gpt5 (Codex CLI)

Summary
- Attempted to switch Parser default arena to PageArena; specs hit a runtime breakpoint (no debugger attached) during parse.
- Reverted default to AstArena with capacity pre-sizing for stability.
- Kept PageArena available behind CRYSTAL_V2_PAGE_ARENA=1 for benches/profiling where it showed parser speed wins on large files.

Next
- Investigate PageArena breakpoint (suspect StaticArray page handling or read-before-init in paths accessing nodes out-of-order).
- Add targeted stress spec for PageArena path to catch the failing pattern.
