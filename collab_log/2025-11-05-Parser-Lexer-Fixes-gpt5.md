Date: 2025-11-05
Author: GPT-5 (Codex CLI)

Scope
- crystal_v2 frontend (lexer + parser)
- Goal: fix parser compile/runtime failures, macro body termination, and keyword misclassification breaking many specs; keep SmallVec migration stable.

Changes
- Parser: parse_select else-body builder variable mismatch fixed
  - File: crystal_v2/src/compiler/frontend/parser.cr
  - Fix: declare/use `else_body_b` consistently; materialize to `else_body` before node creation.
  - Why: compile error risk + undefined variable when no else branch.

- Parser: macro body termination corrected (don’t stop on inner `end`)
  - File: parser.cr (parse_macro_body)
  - Added `block_depth` tracking for regular language blocks (def/class/module/struct/enum/begin/if/unless/while/until/case/select/lib/do).
  - Now only stops on the macro-def `end` when `control_depth == 0 && block_depth == 0`.
  - Result: macro tests no longer emit extra top-level roots; body contains full text (incl. inner `end`).

- Lexer: keyword classification reworked (correct sizes + coverage)
  - File: crystal_v2/src/compiler/frontend/lexer.cr (keyword_kind_for)
  - Fixed mis-bucketed keywords (sizeof/pointerof/previous_def/protected/uninitialized, etc.).
  - Added missing mappings: as, self, else, elsif, yield, raise, macro, asm, include, extend,
    require, alignof, offsetof, instance_alignof, and others.
  - Preserved zero-allocation comparisons via `Slice(UInt8) == "literal".to_slice`.

Verification
- Built CLI: `CRYSTAL_CACHE_DIR=./.crystal-cache crystal build crystal_v2/src/compiler/cli.cr -o crystal_v2/bin/crystal-v2`
- Targeted specs (all green):
  - sizeof/as: `crystal spec crystal_v2/spec/parser/parser_sizeof_spec.cr crystal_v2/spec/parser/parser_as_spec.cr`
  - alignof/instance_alignof: `crystal spec crystal_v2/spec/parser/parser_alignof_spec.cr`
  - unless: `crystal spec crystal_v2/spec/parser/parser_unless_spec.cr`
  - asm: `crystal spec crystal_v2/spec/parser/parser_asm_spec.cr`
- Full parser suite: `crystal spec crystal_v2/spec/parser` → 0 failures, 6 pending (trim tests).

Maieutic Notes
- Assumption: macro body should treat all tokens as text except macro controls and the terminal macro `end`.
  - Falsifier: inner `end` prematurely stopping body → led to extra roots; fixed via `block_depth`.
- Prediction: fixing keyword mapping would flip most “X parsed as Call” failures → confirmed for sizeof/as/asm/alignof.

Requests for Claude
- Macro trims (pending): finalize dash/tilde trim semantics + verbatim block behavior; ensure backslash newline skip matches Crystal.
- Convert remaining macro piece builders to `SmallVec` (pieces, params), materialize only at node construction.
- LSP: double-check member span precision (method name coloring), folding ranges for case/begin/macro/string (no duplicates), and add tests in `spec/lsp/`.
- ExpressionNode purge: continue migrating lingering spec helpers to typed accessors; once green, drop legacy shims in `ast.cr`.
- Perf: after stability, re-run `benchmarks/benchmark_full_comparison.cr --release` and share ratios; consider enabling streaming mode behind env flag after parser suite stays green.

Commands to reproduce
- Parser: `CRYSTAL_CACHE_DIR=./.crystal-cache crystal spec crystal_v2/spec/parser`
- Selected: `crystal spec crystal_v2/spec/parser/parser_spec.cr -l 67` (or run full file)
- Build: `CRYSTAL_CACHE_DIR=./.crystal-cache crystal build crystal_v2/src/compiler/cli.cr -o crystal_v2/bin/crystal-v2`

Status
- Parser specs: GREEN (6 pending trim specs)
- Next: trims + LSP polish + spec cleanup for ExpressionNode removal

