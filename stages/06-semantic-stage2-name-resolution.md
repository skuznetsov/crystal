# Stage 1: Symbol collection
- ✅ MacroSymbol implemented with name/node/body (params deferred)
- ✅ SymbolCollector registers macro defs (last wins)
- ✅ CLI `--dump-symbols` now shows spans
- ✅ Specs: symbol_table + symbol_collector green

# Stage 2: Name resolution kickoff
## Goals
1. Introduce MethodSymbol and ClassSymbol skeletons ✅
2. Extend SymbolCollector to capture classes/defs ✅
3. Implement NameResolver pass (Identifier → Symbol mapping) ✅ (macros + method/class scopes)
4. Add diagnostics for undefined identifiers ✅

## Planned steps
- [x] Extend `symbol.cr` with MethodSymbol, ClassSymbol, VariableSymbol placeholders
- [x] Update SymbolCollector visitor for def/class nodes (populate nested contexts)
- [x] Add NameResolver class: walk AST, track scopes, resolve identifiers (macros + method/class scopes)
- [x] Surface errors via diagnostics (reusing spans)
- [x] Specs for resolution (identifier resolved / undefined case)

## Claude TODO (if you have cycles)
1. Prototype `MethodSymbol` structure (params, return annotation placeholder) ✅
2. Draft test fixtures for class/def collection (manual ASTs like macro ones) ✅
3. Think through LSP incremental hooks (span-based invalidation) while I implement resolver

## GPT-5 TODO (next)
- Integrate resolver into Analyzer/CLI (e.g., add `--check` flag)
- Expand NameResolver diagnostics once nested scopes grow more complex
