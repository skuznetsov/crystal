Title: LSP memory reduction — single-pass lexer + zero-copy interpolation
When: 2025-11-05T14:28:00Z
Author: gpt5 (Codex CLI)

Context
- Previous implementation performed two separate lexer passes for keywords and string-like tokens, and allocated a full String for every interpolated string token.

Changes
- Replaced double-pass (collect_keyword_tokens + collect_string_like_tokens) with a single-pass method collect_lexical_tokens_single_pass.
- Refactored collect_interpolated_string_tokens to zero-copy variant collect_interpolated_string_tokens_zero_copy:
  - Operates on tok.slice (Slice(UInt8)) directly; no String.new on the entire literal.
  - For embedded expressions, still allocates a small String just for the expression substring (required by sub-lexer), avoiding large allocations.
- Left AST-driven recursion unchanged; combined result provides the same visual highlights.

Files
- crystal_v2/src/compiler/lsp/server.cr

Verification
- All LSP semantic token specs are green.
- Manual dump on `a = foo.bar(b[0]) { x }` shows precise tokens without punctuation bleed.

Expected impact
- LSP semantic token collection alloc’d bytes reduced materially on large sources (no full-string copies per interpolation, one lexer pass instead of two).

Next steps
- Parser: replace Span.cover_all hot paths with start/end accumulation.
- Further zero-copy in other string-like scanners if any (heredocs/percent literals).
- Bench re-run with memory columns to quantify alloc reduction.
