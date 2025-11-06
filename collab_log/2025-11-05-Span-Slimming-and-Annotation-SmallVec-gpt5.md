Title: Span slimming (NamedArgument/NamedTupleEntry) + SmallVec in annotations
When: 2025-11-05T15:12:00Z
Author: gpt5 (Codex CLI)

Summary
- Removed stored redundant span fields and compute on demand:
  - NamedArgument: now stores name_span/value_span; span() computed as cover.
  - NamedTupleEntry: now stores key_span/value_span; span() computed as cover.
- Parser updated to new ctors (no arg/entry span arguments passed).
- Converted parse_annotation args/named_args to SmallVec builders with single materialization.

Files
- crystal_v2/src/compiler/frontend/ast.cr
- crystal_v2/src/compiler/frontend/parser.cr

Verification
- Parser suite: 729/729 passing (6 pending unchanged).
- LSP semantic tokens suite: 27/27 passing.

Notes
- This reduces per-node memory (one Span per entry/argument removed) with minimal code touch.
- Next candidates for span slimming (later): AccessorSpec.span (compute from name_span/type/default), possibly others with obvious span duplication.
