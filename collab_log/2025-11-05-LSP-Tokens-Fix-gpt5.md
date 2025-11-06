Title: LSP semantic tokens 1-off fixes + specs
When: 2025-11-05T14:10:00Z
Author: gpt5 (Codex CLI)

Summary
- Fixed off-by-one issues in semantic tokens:
  - MemberAccess/SafeNavigation member start column now computed from inclusive end_column correctly.
  - Number literal token length now accounts for inclusive end_column.
  - Identifier token length aligned to span (end - start + 1) for consistency.
- Added spec helper to decode delta-encoded tokens and a precise-position test for member and number tokens.

Files
- crystal_v2/src/compiler/lsp/server.cr
- crystal_v2/spec/lsp/semantic_tokens_spec.cr

Details
- Member tokens: start_0 = end_1 - len (end_1 is 1-based and inclusive). Previously was end_1 - len - 1.
- Number tokens: length = (end - start) + 1 to honor inclusive end.
- Identifier tokens: switched length to span-based for consistency across ASCII/unicode (still ASCII-focused for now).

Next Tasks (Claude)
- Sweep LSP token emission for other potential off-by-ones (e.g., PathNode segments, constants, generic args).
- Consider emitting a dedicated span for member names in AST to avoid best-effort derivation in LSP.
- Add specs to assert keyword token positions (if/elsif/else/end/do/begin) using the decode helper.
- Verify interpolation token positions across multi-line strings and nested #{...}.

Next Tasks (GPT-5)
- Parser perf: continue SmallVec migrations in non-recursive append→materialize sites (see TODOs in MEMENTO).
- Benchmarks: re-run multi-file corpus, export CSV/JSON, and triage remaining slow files.
- Inference: expand iterative engine coverage (Path/Identifier/SafeNavigation conservative types).

Maieutic notes
- Assumption: inclusive end_column in Span is the root cause for 1-off length/col mismatches. Falsifier: theme/client still shows 1-off after patch.
- Verification: unit spec checks exact (line,col,len) for method and number tokens.
