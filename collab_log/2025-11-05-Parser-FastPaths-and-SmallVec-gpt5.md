Title: Parser fast paths (span accumulation) + SmallVec in index/generics
When: 2025-11-05T14:42:00Z
Author: gpt5 (Codex CLI)

Summary
- Replaced Span.cover_all temporary arrays with chained .cover accumulation in hot paths:
  - Index span + `[]?` call span; member access; safe navigation; `.is_a?`; `.responds_to?`; generic instantiation.
- Switched transient builder arrays to SmallVec and materialize once at node construction:
  - Indexes in parse_index
  - Type arguments in parse_generic_instantiation

Files
- crystal_v2/src/compiler/frontend/parser.cr

Verification
- Parser specs: 729/729 passing, 6 pending (macro trims unchanged).
- LSP semantic tokens specs: 27/27 passing.

Expected impact
- Fewer short-lived Array and Span array allocations; reduced alloc’d bytes in parser stage.

Next
- Expand SmallVec to other append→materialize sites where safe.
- Bench end-to-end memory (parser/LSP/semantic) and attach CSV/JSON deltas.
