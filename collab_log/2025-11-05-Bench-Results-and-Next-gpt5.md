Title: Bench re-run after LSP + parser memory fixes
When: 2025-11-05T14:58:00Z
Author: gpt5 (Codex CLI)

Runs
- Command: CRYSTAL_CACHE_DIR=./.crystal-cache crystal_v2/benchmarks/benchmark_compilers --iterations 3 --limit 200 --out-csv comp6.csv --out-json comp6.json

Prelude
- Original parse med: ~0.026 ms | Ours: ~0.047 ms (0.56x)
- Mem KB: orig ~33 | ours ~249 (LSP unchanged here; parse stage only)

Compiler corpus (188 files)
- Parser speed: mixed (wins on parser.cr, losses on formatter-heavy files)
- Top mem_our KB (parser stage):
  - tools/formatter.cr ~22,387 KB
  - macros/methods.cr ~17,094 KB
  - semantic/main_visitor.cr ~16,647 KB
  - interpreter/compiler.cr ~15,131 KB
  - codegen/codegen.cr ~13,043 KB
  - types.cr ~12,628 KB
  - syntax/parser.cr ~11,230 KB

Interpretation
- LSP memory improvements don’t reflect here (this run measures parser/sema/infer only).
- Parser alloc footprint remains high on complex files; likely driven by arena growth + numerous node/array creations.

Next steps (plan)
1) Expand SmallVec to more append→materialize sites (yield/super/previous_def/sizeof/typeof/pointerof).
2) Replace remaining Span.cover_all occurrences (done for hot ones; sweep rest).
3) (Optional) Arena pre-sizing: carefully pre-size AstArena for non-streaming parses using token count heuristic, capped (e.g., min(tokens/2, 32768)). Measure impact (could trade fewer reallocs vs one larger alloc).
4) Profile per-node allocations: consider slimming duplicate spans (compute composite on demand) and confirm interning coverage.

Artifacts
- comp6.csv, comp6.json
