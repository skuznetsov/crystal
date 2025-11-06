Date: 2025-11-05
Author: GPT-5 (Codex CLI)

Summary
- Upgraded benchmark_full_comparison.cr to a paired, apples-to-apples harness.
- Added multi-file mode with geometric-mean speedup across a corpus and time-weighted aggregate.
- Added flags to toggle streaming parser and trivia retention.

Details
- Single-file (default = src/compiler/crystal/syntax/parser.cr):
  - Interleaved pairs (Original vs CrystalV2) with per-iteration ratio.
  - Reports avg/median, and semantic overhead on the same Program instance.
- Multi-file: `--all --pattern PAT[,PAT2] --limit N --iterations M`
  - Collects files by glob(s), sorts by size, caps by limit.
  - For each file: paired median speedup; aggregates:
    - Geometric mean of per-file medians
    - Arithmetic mean of per-file medians
    - Time-weighted: sum(original)/sum(ours)
- Streaming: `--stream` sets CRYSTAL_V2_PARSER_STREAM=1 for our timings.
- Trivia: `--keep-trivia` sets CRYSTAL_V2_PARSER_KEEP_TRIVIA=1.

Commands
- Single-file release run:
  - `CRYSTAL_CACHE_DIR=./.crystal-cache crystal build --release crystal_v2/benchmarks/benchmark_full_comparison.cr -o crystal_v2/bin/bench_full`
  - `./crystal_v2/bin/bench_full --iterations 20`
- Multi-file release run:
  - `./crystal_v2/bin/bench_full --all --pattern src/**/*.cr,crystal_v2/src/**/*.cr --iterations 5 --limit 50`

Observed (local sample)
- parser.cr: ~1.6x speedup (median), ~0.6–1.0% semantic overhead.
- Multi-file (top 30 by size): geomean < 1 in current state; several data-heavy library files dominate. Indicates next optimization targets outside parser.cr.

Next steps (suggested)
- Complete SmallVec migration in macro piece builders and remaining param/else bodies.
- Optimize span computations (offset-only fast-path in hot nodes).
- Avoid String.build in rare type annotation paths for common cases.
- Profile unicode/data-heavy sources; possibly bypass via light lexer path or chunked skip.
- Keep streaming mode off by default; revisit after stability+profiling.

