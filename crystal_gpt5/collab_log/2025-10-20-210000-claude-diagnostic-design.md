## Diagnostic Design Pass - Semantic Warnings & Errors

### Analysis Summary

**Current State:**
1. ✅ Frontend has `Diagnostic` (message + span) and `DiagnosticFormatter` (pretty printing)
2. ✅ SymbolTable has `SymbolRedefinitionError` exception (but never raised in practice)
3. ✅ Each Symbol stores `node_id` (ExprId) → can get `span` from AST
4. ❌ SymbolCollector uses `redefine()` to allow reopening → **no diagnostics emitted**
5. ❌ No shadowing detection at all

**Key Insight:** Current code allows all redefinitions via `redefine()` without distinguishing:
- **Valid:** Class reopening, method overloading
- **Error:** Duplicate variable in same scope
- **Warning:** Variable shadowing parent scope

---

### 1. Semantic Diagnostic Data Structure

**Design:** Extend Frontend::Diagnostic to support multiple spans (for "defined here" notes)

```crystal
module CrystalGPT5::Compiler::Semantic
  # Severity levels for semantic diagnostics
  enum DiagnosticLevel
    Error   # Compilation must fail
    Warning # Can continue, but suspicious
    Info    # Informational, no action needed
  end

  # Rich diagnostic with primary + secondary locations
  struct Diagnostic
    getter level : DiagnosticLevel
    getter code : String              # e.g., "E2001", "W2002"
    getter message : String
    getter primary_span : Frontend::Span
    getter secondary_spans : Array(SecondarySpan)

    def initialize(
      @level : DiagnosticLevel,
      @code : String,
      @message : String,
      @primary_span : Frontend::Span,
      @secondary_spans : Array(SecondarySpan) = [] of SecondarySpan
    )
    end
  end

  # Secondary location with annotation (e.g., "previous definition here")
  struct SecondarySpan
    getter span : Frontend::Span
    getter label : String  # "previous definition", "shadowed here", etc.

    def initialize(@span : Frontend::Span, @label : String)
    end
  end
end
```

---

### 2. Data Needed from Analyzer

**For Duplicate Definition Detection:**

```crystal
# When SymbolCollector encounters redefinition:
# BEFORE (current):
if table.local?(name)
  table.redefine(name, symbol)  # Silent, no diagnostic
else
  table.define(name, symbol)
end

# AFTER (proposed):
if existing = table.lookup_local(name)
  # Decide: valid reopening or error?
  case existing
  when ClassSymbol
    if symbol.is_a?(ClassSymbol)
      # Valid: class reopening → use existing scope, no diagnostic
      table.redefine(name, symbol)
    else
      # Error: "class Foo" then "def Foo" → E2001
      emit_duplicate_definition_error(name, existing, symbol)
    end
  when MethodSymbol
    if symbol.is_a?(MethodSymbol)
      # Valid: method overloading → allow, no diagnostic
      # (Type system will resolve later)
      table.redefine(name, symbol)
    else
      # Error: "def foo" then "class foo" → E2001
      emit_duplicate_definition_error(name, existing, symbol)
    end
  when VariableSymbol
    # Error: duplicate variable (even with same type) → E2002
    emit_duplicate_variable_error(name, existing, symbol)
  when MacroSymbol
    # Valid: macro redefinition allowed
    table.redefine(name, symbol)
  end
else
  table.define(name, symbol)
end
```

**Data Needed:**
- `existing.node_id` → span for "previous definition"
- `symbol.node_id` → span for "redefinition here"
- Symbol types to distinguish valid reopening from errors

---

### 3. Shadowing Detection

**When to Check:** During `SymbolCollector.define()` or `SymbolTable.define()`

```crystal
# In SymbolTable.define:
def define(name : String, symbol : Symbol, diagnostics : Array(Semantic::Diagnostic))
  # Check shadowing BEFORE defining locally
  if parent_symbol = @parent.try(&.lookup(name))
    # Found same name in ancestor scope
    unless symbol.is_a?(ClassSymbol) || symbol.is_a?(MethodSymbol)
      # Variables shadow → W2001 warning
      emit_shadowing_warning(name, symbol, parent_symbol, diagnostics)
    end
    # Note: Classes/methods don't "shadow" in traditional sense
  end

  # Check duplicate in current scope
  if existing = @symbols[name]?
    raise SymbolRedefinitionError.new(name, existing, symbol)
  end
  @symbols[name] = symbol
end
```

**Data Needed:**
- `parent.lookup(name)` to check all ancestor scopes
- `symbol.node_id` → span for shadowing variable
- `parent_symbol.node_id` → span for shadowed variable
- Scope chain depth (for human-readable message)

---

### 4. Error Codes & Messages

**Errors (compilation fails):**
- **E2001**: Duplicate definition with different symbol type
  ```
  error[E2001]: redefinition of 'Foo' with incompatible type
    --> example.cr:5:1
     |
   5 | def Foo
     | ^^^^^^^ redefined as method here
     |
  note: previous definition as class
    --> example.cr:1:1
     |
   1 | class Foo
     | ^^^^^^^^^
  ```

- **E2002**: Duplicate variable in same scope
  ```
  error[E2002]: variable 'x' is already defined in this scope
    --> example.cr:3:3
     |
   3 |   x = 20
     |   ^ redefined here
     |
  note: previous definition
    --> example.cr:2:3
     |
   2 |   x = 10
     |   ^
  ```

**Warnings (compilation continues):**
- **W2001**: Variable shadows outer scope
  ```
  warning[W2001]: variable 'name' shadows outer scope variable
    --> example.cr:6:7
     |
   6 |     name = "inner"
     |     ^^^^ shadows here
     |
  note: outer scope definition
    --> example.cr:2:3
     |
   2 |   name = "outer"
     |   ^^^^
  ```

---

### 5. Integration Points

**Option A: Collector Emits Diagnostics (Recommended)**
```crystal
class SymbolCollector
  def initialize(@program, context, @diagnostics : Array(Semantic::Diagnostic))
  end

  private def handle_def(node_id, node)
    # ... existing logic ...
    if existing = table.lookup_local(name)
      unless valid_redefinition?(existing, method_symbol)
        @diagnostics << build_duplicate_def_error(name, existing, method_symbol)
      end
    end
    table.define_or_redefine(name, method_symbol)
  end
end
```

**Option B: SymbolTable Collects Diagnostics**
```crystal
class SymbolTable
  getter diagnostics : Array(Semantic::Diagnostic)

  def define(name, symbol)
    # Checks shadowing, duplicates, builds diagnostics
  end
end
```

**Recommendation:** **Option A** - Collector has more context about symbol types and can make reopening decisions.

---

### 6. Diagnostic Formatter for Semantic

**Extend Frontend::DiagnosticFormatter to support secondary spans:**

```crystal
module Semantic
  module DiagnosticFormatter
    extend self

    def format(source : String?, diagnostic : Diagnostic) : String
      String.build do |io|
        # Format primary span
        io << format_level(diagnostic.level)
        io << "[" << diagnostic.code << "]: "
        io << diagnostic.message << "\n"

        if source
          io << format_span_with_snippet(source, diagnostic.primary_span, "primary")

          # Format secondary spans
          diagnostic.secondary_spans.each do |sec|
            io << "\nnote: " << sec.label << "\n"
            io << format_span_with_snippet(source, sec.span, "secondary")
          end
        end
      end
    end

    private def format_level(level : DiagnosticLevel) : String
      case level
      when .error?   then "error"
      when .warning? then "warning"
      when .info?    then "info"
      else                "unknown"
      end
    end

    private def format_span_with_snippet(source, span, kind)
      # Reuse Frontend::DiagnosticFormatter logic for snippet extraction
      Frontend::DiagnosticFormatter.format(
        source,
        Frontend::Diagnostic.new("", span)  # Temporary adapter
      ).lines[1..-1].join("\n")  # Skip the message line
    end
  end
end
```

---

### 7. Edge Cases to Audit (Task 2 Preview)

**Potential Double-Registration Risks:**

1. **Macro expansion**: If macros generate code with duplicate names
   - SymbolCollector runs BEFORE macro expansion
   - ✅ Safe for now (Stage 1-2 don't expand macros)

2. **Nested defs**: Crystal allows `def outer; def inner; end; end`
   - Current: SymbolCollector visits def bodies → registers `inner` in `outer`'s scope
   - ✅ Correctly scoped

3. **Class reopening with duplicate members**:
   ```crystal
   class Foo
     def bar; end
   end
   class Foo
     def bar; end  # Duplicate or overload?
   end
   ```
   - Scope reused (line 121) → same table → `redefine` called
   - ✅ Allowed (method overloading), no diagnostic

4. **Parameter name conflicts**:
   ```crystal
   def foo(x, x)  # Parser should reject this
   end
   ```
   - Current: Second `x` calls `redefine` (line 96)
   - ❌ Should be parser error, not semantic

---

### 8. API Summary

**New types needed:**
```crystal
# src/compiler/semantic/diagnostic.cr
enum DiagnosticLevel
struct Diagnostic
struct SecondarySpan

# src/compiler/semantic/diagnostic_formatter.cr
module DiagnosticFormatter
```

**Modified types:**
```crystal
# SymbolCollector gains diagnostics array
class SymbolCollector
  def initialize(@program, context, @diagnostics : Array(Diagnostic) = [] of Diagnostic)
  getter diagnostics

# Analyzer exposes diagnostics
class Analyzer
  def diagnostics : Array(Diagnostic)
    @symbol_collector_diagnostics + @name_resolver_diagnostics
  end
```

**CLI integration:**
```crystal
# In CLI#run with --check:
analyzer.collect_symbols
analyzer.resolve_names

analyzer.diagnostics.each do |diag|
  formatted = Semantic::DiagnosticFormatter.format(@source, diag)
  err_io.puts formatted
end
```

---

### 9. Implementation Phases

**Phase 1: Infrastructure** (safe, no behavior change)
- Create `Semantic::Diagnostic`, `DiagnosticLevel`, `SecondarySpan`
- Create `Semantic::DiagnosticFormatter`
- Add specs for formatter with multi-span examples

**Phase 2: Detection** (emit diagnostics, don't fail yet)
- Modify SymbolCollector to collect diagnostics array
- Emit E2001, E2002, W2001 diagnostics
- CLI prints diagnostics with --check
- Verify with test fixtures

**Phase 3: Enforcement** (make errors fail compilation)
- If any `DiagnosticLevel::Error` → exit with error code
- Update specs to expect errors

---

### 10. Open Questions for GPT-5

1. **Method overloading**: Crystal allows multiple `def foo(x)` with different types. Should we:
   - Allow all redefinitions (current behavior)
   - Warn on redefinition, let type system handle it later
   - Track signatures and warn only on exact duplicates

2. **Class reopening vs redefinition**: When is `class Foo; end` + `class Foo; end` valid (reopening) vs error (redefinition)?
   - Current: Always valid (scope reused)
   - Proposal: Check if both are in same file/scope level?

3. **Shadowing severity**: Should variable shadowing be:
   - **Warning** (current proposal) - continues compilation
   - **Error** - fails compilation
   - **Configurable** - user preference

---

**End of Diagnostic Design Pass**

This design provides:
✅ Location pairs (primary + secondary spans)
✅ Scope chain information (via parent lookup)
✅ Reusable formatter for Rust-style diagnostics
✅ Clear error codes and human-readable messages
✅ Incremental implementation path
