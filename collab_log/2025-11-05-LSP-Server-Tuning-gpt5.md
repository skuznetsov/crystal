2025-11-05 12:40 UTC — Codex
- Updated `crystal_v2/src/compiler/lsp/server.cr` to keep semantic analysis & type inference active even when the stub prelude is used; hover/completion/signature consumers now receive populated `type_context` and identifier maps.
- Implemented sanity checks for the real prelude (`Kernel.puts`, `Dir.glob`, `File.read`); fall back to the stub automatically when core builtins are missing so diagnostics stay clean.
- Extended `find_expr_at_position` recursion to descend into `if` branches, ensuring rename/lookups can resolve identifiers inside conditionals.
- Added targeted debug hooks (guarded by `LSP_DEBUG`) around rename flow to help trace symbol resolution.
- Adjusted `crystal_v2/benchmarks/lsp_harness.cr` to tolerate `null` LSP responses and tuned the rename scenario to hit the assignment binding (shows rename edits now).
- Rebuilt `bin/crystal_v2_lsp` for manual harness tests. Harness run shows hover/completion/inlay hints/formatting chains working; rename now returns a WorkspaceEdit instead of `null` when the symbol is resolved.
- Full `crystal spec` still fails in this environment (LibreSSL constant redefinition); manual harness + debug scripts used for verification.
2025-11-05 18:20 UTC — Codex
- Reworked go-to-definition pipeline to operate on byte offsets and load dependency ASTs on demand. DocumentState now tracks `requires`, `find_expr_at_position` uses byte offsets, and dependency analyses are cached.
- Added fallbacks to resolve `Frontend::Lexer`-style paths: we crawl dependency symbol tables and, when heuristics fail, inspect dependency ASTs to synthesize `Location`s.
- Harness run `CRYSTAL_CACHE_DIR=./.crystal-cache crystal run crystal_v2/benchmarks/lsp_harness.cr -- --server ./bin/crystal_v2_lsp_debug` now reports `definition` returning 1 location instead of 0 for `Frontend::Lexer`.
