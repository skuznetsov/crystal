# CrystalV2 Development Roadmap

## Current Status (2025-11-01)

### ✅ Completed Components

1. **Parser** - Full Crystal language support
   - ✅ 30/30 regression tests passing
   - ✅ Parses parser.cr: 14,377 nodes
   - ✅ More compact AST than original (-8% nodes)

2. **FileLoader** - Multi-file project support
   - ✅ Parallel loading (1.73x speedup with MT)
   - ✅ Perfect deduplication (0% waste)
   - ✅ Shard support verified (Kemal: 244 files in 371ms)
   - ✅ VirtualArena for incremental updates

3. **Type Inference** - Partial implementation
   - ✅ Basic type inference working
   - ⚠️ Needs completion for codegen
   - ⚠️ Generic types partially supported

4. **Semantic Analysis** - Partial implementation
   - ✅ Symbol resolution
   - ✅ Scope tracking
   - ⚠️ Needs full type checking

---

## Phase 1: LSP Server MVP (Week 1-2) 🎯 HIGH PRIORITY

### Goal: Make Crystal development experience 10x better

### Why LSP First?
- ✅ Uses only what we already have (parser + partial inference)
- ✅ Immediate value for entire Crystal community
- ✅ Showcases our technology
- ✅ NO codegen required!

### Week 1: Core LSP Features

**Dependencies:** Parser ✅, FileLoader ✅

**Tasks:**
1. **LSP Protocol Implementation** (2 days)
   ```
   - initialize/initialized
   - textDocument/didOpen
   - textDocument/didChange
   - textDocument/didClose
   - workspace/didChangeWatchedFiles
   ```

2. **Basic Diagnostics** (2 days)
   ```
   - Syntax errors from parser
   - Unresolved requires
   - Basic semantic errors
   ```

3. **Incremental Updates** (1 day)
   ```
   - Use VirtualArena.replace_file_arena
   - Smart re-parsing on textDocument/didChange
   - Debouncing for performance
   ```

**Deliverable:** LSP that shows syntax errors in real-time across workspace

---

### Week 2: Advanced LSP Features

**Dependencies:** Week 1 ✅, Type Inference (partial) ✅

**Tasks:**
1. **Hover (Type Information)** (2 days)
   ```
   - textDocument/hover
   - Show inferred types
   - Show documentation from comments
   ```

2. **Go-to-Definition** (2 days)
   ```
   - textDocument/definition
   - Method definitions
   - Class definitions
   - Variable assignments
   ```

3. **Auto-completion** (2 days)
   ```
   - textDocument/completion
   - Method names (from type inference)
   - Class names (from symbol table)
   - Built-in types
   ```

**Deliverable:** Production-ready LSP server for VS Code / other editors

---

## Phase 2: Type Inference Completion (Week 3-5) 🔥 CRITICAL FOR CODEGEN

### Goal: Complete type inference engine for codegen

### Why Inference Matters?
- ⚠️ **Required for codegen** - need exact types for LLVM
- ⚠️ **Required for advanced LSP features** - better autocomplete/hover
- ⚠️ **Crystal's main feature** - we must get this right!

### Week 3: Generic Types & Type Constraints

**Current Gap:** Generic types partially supported

**Tasks:**
1. **Generic Method Instantiation** (3 days)
   ```crystal
   def foo(x : T) forall T
     x + 1
   end

   foo(42)     # Should infer T = Int32
   foo("str")  # Should fail (no + for String)
   ```

2. **Type Constraints** (2 days)
   ```crystal
   def foo(x : T) forall T where T < Number
     x * 2
   end
   ```

3. **Generic Classes** (2 days)
   ```crystal
   class Box(T)
     def initialize(@value : T); end
   end

   Box(Int32).new(42)
   Box.new("hello")  # Should infer Box(String)
   ```

**Deliverable:** Full generic type support

---

### Week 4: Union Types & Nilable Types

**Current Gap:** Union type inference incomplete

**Tasks:**
1. **Union Type Inference** (3 days)
   ```crystal
   x = rand > 0.5 ? 42 : "hello"
   # x should be Int32 | String
   ```

2. **Nilable Type Handling** (2 days)
   ```crystal
   x : Int32? = nil
   if x
     x + 1  # x is Int32 here (not nilable)
   end
   ```

3. **Type Narrowing** (2 days)
   ```crystal
   x : Int32 | String = get_value
   if x.is_a?(Int32)
     x + 1  # x is Int32 here
   end
   ```

**Deliverable:** Complete union type support with smart narrowing

---

### Week 5: Method Overloading & Dispatch

**Current Gap:** Method resolution needs work

**Tasks:**
1. **Overload Resolution** (3 days)
   ```crystal
   def foo(x : Int32); "int"; end
   def foo(x : String); "string"; end

   foo(42)      # Should call first
   foo("hi")    # Should call second
   ```

2. **Virtual Dispatch** (2 days)
   ```crystal
   class Base
     def foo; "base"; end
   end

   class Derived < Base
     def foo; "derived"; end
   end
   ```

3. **Multiple Dispatch** (2 days)
   ```crystal
   def foo(x : Int32, y : Int32); end
   def foo(x : String, y : String); end
   ```

**Deliverable:** Complete method dispatch for codegen

---

## Phase 3: Semantic Analysis Completion (Week 6-7)

### Goal: Full type checking for error reporting

**Tasks:**
1. **Type Checking** (3 days)
   - Assignment compatibility
   - Method call type checking
   - Return type checking

2. **Error Messages** (2 days)
   - Detailed type mismatch errors
   - Suggestions for fixes
   - Multiple error reporting

3. **Flow-sensitive Analysis** (2 days)
   - Definite assignment checking
   - Unreachable code detection

**Deliverable:** Production-quality error messages

---

## Phase 4: Code Generation (Week 8-12) 🚀 FINAL GOAL

### Goal: Full compiler - CrystalV2 can compile itself!

### Week 8-9: LLVM IR Generation

**Dependencies:** Phase 2 ✅ (complete type inference)

**Tasks:**
1. **Basic IR Generation** (4 days)
   - Functions
   - Variables
   - Primitive operations

2. **Memory Management** (3 days)
   - Heap allocation
   - GC integration
   - Stack allocation

**Deliverable:** Can compile simple programs

---

### Week 10-11: Advanced Code Generation

**Tasks:**
1. **Classes & Virtual Tables** (4 days)
   - Virtual method tables
   - Inheritance
   - Type casts

2. **Closures & Blocks** (3 days)
   - Closure capture
   - Block compilation

**Deliverable:** Can compile complex OOP programs

---

### Week 12: Optimization & Self-Hosting

**Tasks:**
1. **Optimizations** (3 days)
   - Dead code elimination
   - Constant folding
   - Inlining

2. **Self-Hosting Test** (2 days)
   - Compile CrystalV2 with CrystalV2
   - Performance benchmarks
   - Bootstrap test

**Deliverable:** Full self-hosting compiler!

---

## Parallel Tracks (Ongoing)

### Track A: Utilities (Can do anytime)

1. **Crystal Linter** (3 days)
   - Static analysis
   - Code style checking
   - Best practices

2. **Crystal Formatter** (3 days)
   - Fast formatting
   - Configurable style
   - Editor integration

3. **Crystal Doc Generator** (4 days)
   - Better than crystal doc
   - Markdown output
   - Type information

---

## Success Metrics

### Phase 1 (LSP):
- ✅ VS Code extension published
- ✅ 100+ GitHub stars in first month
- ✅ Faster than Crystalline (currently 3-5 seconds)
- ✅ Community adoption

### Phase 2 (Inference):
- ✅ Pass all Crystal compiler type inference tests
- ✅ Generics work correctly
- ✅ Union types fully supported

### Phase 4 (Codegen):
- ✅ Can compile prelude.cr
- ✅ Can compile itself (self-hosting)
- ✅ Performance within 10% of original compiler

---

## Risk Analysis

### High Risk:
1. **Type Inference Complexity** - Crystal's type system is sophisticated
   - **Mitigation:** Study original compiler code carefully
   - **Mitigation:** Incremental implementation with tests

2. **LLVM Integration** - Low-level details can be tricky
   - **Mitigation:** Start with simple IR, add complexity gradually
   - **Mitigation:** Reference original compiler's LLVM code

### Medium Risk:
1. **LSP Performance** - Need to be fast for good UX
   - **Mitigation:** Incremental parsing with VirtualArena
   - **Mitigation:** Caching type inference results

2. **Generic Type Complexity** - Many edge cases
   - **Mitigation:** Comprehensive test suite
   - **Mitigation:** Maieutic debugging when stuck

---

## Timeline Summary

```
Week 1-2:  LSP MVP                    [Phase 1]
Week 3-5:  Type Inference Completion  [Phase 2]
Week 6-7:  Semantic Analysis          [Phase 3]
Week 8-12: Code Generation            [Phase 4]

Total: ~3 months to full compiler
```

---

## Recommended Approach: Variant Г (Hybrid)

**Strategy:**
1. **Start with LSP** (Week 1-2) - **Immediate value**
2. **Complete Inference** (Week 3-5) - **Required for codegen**
3. **Parallel: Create utilities** - **Additional value**
4. **Finally: Codegen** (Week 8-12) - **Ultimate goal**

**Why this order?**
- ✅ Quick wins (LSP) show progress
- ✅ Inference is prerequisite for codegen
- ✅ Utilities can be done by contributors
- ✅ Codegen is the hardest, do it last when we're ready

---

## Next Steps (Immediate)

1. **Today:** Create LSP server skeleton
2. **This week:** Implement core LSP protocol
3. **Next week:** Add hover + go-to-definition
4. **Week 3:** Start type inference improvements

**First command to run tomorrow:**
```bash
mkdir crystal_v2_lsp
cd crystal_v2_lsp
crystal init app lsp_server
```

---

## Questions to Consider

1. **Should we write LSP in Crystal or another language?**
   - Pro (Crystal): Dogfooding, use our parser directly
   - Pro (Other): Faster initial development, wider contributor base
   - **Recommendation:** Crystal - shows confidence in our tech

2. **Should we target VS Code only or support multiple editors?**
   - **Recommendation:** LSP is universal - works with all editors
   - Priority: VS Code (most popular)
   - Also works: Vim, Emacs, Sublime, etc.

3. **When to release LSP publicly?**
   - **Recommendation:** After Week 2 (when it's useful)
   - Alpha release: Week 1 (syntax errors only)
   - Beta release: Week 2 (hover + goto work)
   - Stable: Week 3-4 (after community feedback)
