## Edge-Case Audit: SymbolCollector & NameResolver

### Audit Methodology
Systematically reviewed both files for:
- Double-registration risks
- Scope management issues
- Missing validations
- Macro expansion edge cases
- AST structure assumptions

---

## PART 1: SymbolCollector Edge Cases

### ✅ SAFE: Class Reopening
**Code:** Lines 119-122
```crystal
existing = table.lookup_local(name)
if existing.is_a?(ClassSymbol)
  class_scope = existing.scope  # Reuse scope
end
```

**Analysis:**
- **Intent:** Allow `class Foo; end` followed by `class Foo; end` to share scope
- **Edge case:** What if class Foo defined, then reopened with different superclass?
  ```crystal
  class Foo < Bar; end
  class Foo < Baz; end  # Silent superclass change!
  ```
- **Risk:** 🟡 MEDIUM - Superclass stored in symbol (line 114) but old superclass lost
- **Recommendation:** Check `superclass_name` compatibility:
  ```crystal
  if existing.is_a?(ClassSymbol)
    if existing.superclass_name && super_name && existing.superclass_name != super_name
      # DIAGNOSTIC: Conflicting superclass in class reopening
    end
    class_scope = existing.scope
  end
  ```

---

### ❌ RISKY: Parameter Symbol node_id
**Code:** Line 94
```crystal
param_symbol = VariableSymbol.new(param_name, Frontend::ExprId.new(-1))
```

**Analysis:**
- **Problem:** Parameters get invalid node_id (-1)
- **Impact:**
  - Can't generate diagnostics pointing to parameter location
  - Breaks assumption that all symbols have valid spans
- **Edge case:** If diagnostic formatter tries to format parameter symbol → crash or garbage span
- **Risk:** 🔴 HIGH - Breaks diagnostic infrastructure
- **Recommendation:** Parser should store parameter spans, or compute from def signature:
  ```crystal
  # Option 1: Parser stores param spans in AST
  params_with_spans = node.def_param_spans || []
  params_with_spans.each do |param_name, param_span_or_id|
    param_symbol = VariableSymbol.new(param_name, param_span_or_id)
    method_scope.define(param_name, param_symbol)
  end

  # Option 2: Derive from def name span (less accurate)
  # Use def_name's span as fallback
  param_symbol = VariableSymbol.new(param_name, node_id)
  ```

---

### ✅ SAFE: Nested Def Scoping
**Code:** Lines 91-106 (handle_def)
```crystal
push_table(method_scope)
# ... register params ...
(node.def_body || [] of Frontend::ExprId).each do |expr_id|
  visit(expr_id)  # Can register nested defs
end
pop_table
```

**Analysis:**
- Crystal allows `def outer; def inner; end; end`
- **Behavior:** `inner` registered in `outer`'s scope (correct)
- **Edge case:** Multiple levels of nesting
  ```crystal
  def a
    def b
      def c
        x = 1  # x registered in c's scope ✓
      end
    end
  end
  ```
- **Risk:** ✅ SAFE - Scope stack handles arbitrary nesting

---

### 🟡 MODERATE: Macro Body Not Visited
**Code:** Lines 51-72 (handle_macro_def)
```crystal
unless @arena[body_id].kind == ExpressionNode::Kind::MacroLiteral
  return  # Bail if not MacroLiteral
end

symbol = MacroSymbol.new(name, node_id, body_id)
# ... register symbol ...
# NOTE: Does NOT visit body!
```

**Analysis:**
- **Intent:** Macros are templates, not executed during symbol collection
- **Edge case:** Macro body contains `def` or `class`:
  ```crystal
  macro generate_method
    def generated; end  # NOT collected until macro expanded
  end
  ```
- **Behavior:** Macro body symbols collected only if/when expanded
- **Risk:** 🟡 MODERATE - Correct for now (no macro expansion in Stage 1-2), but future expansion system must run SymbolCollector on generated AST
- **Recommendation:** Add TODO comment:
  ```crystal
  # TODO: When Stage 3+ adds macro expansion, must run SymbolCollector
  # on expanded AST to register symbols from macro-generated code
  ```

---

### ❌ RISKY: Redefine Without Diagnostic
**Code:** Lines 67-71, 85-89, 95-99, 126-130
```crystal
if table.local?(name)
  table.redefine(name, symbol)  # Silent overwrite
else
  table.define(name, symbol)
end
```

**Analysis:**
- **Problem:** All redefinitions silently succeed, even invalid ones:
  ```crystal
  x = 1
  x = 2      # VariableSymbol redefined → should warn/error
  def foo; end
  class foo; end  # MethodSymbol → ClassSymbol → should error
  ```
- **Risk:** 🔴 HIGH - No diagnostics for invalid redefinitions
- **Recommendation:** Implement diagnostic emission as designed in diagnostic design doc

---

### ✅ SAFE: Empty Body Handling
**Code:** Lines 102-104, 133-136
```crystal
(node.def_body || [] of Frontend::ExprId).each do |expr_id|
  visit(expr_id)
end
```

**Analysis:**
- **Handles:** `def foo; end` (empty body)
- **Edge case:** Parser returns `nil` or empty array
- **Risk:** ✅ SAFE - `|| [] of ExprId` guards against nil

---

## PART 2: NameResolver Edge Cases

### ❌ RISKY: Silent Failure on Missing Symbol
**Code:** Lines 110-113 (visit_def)
```crystal
symbol = @current_table.lookup(name)
unless symbol.is_a?(MethodSymbol)
  return  # Silent skip
end
```

**Analysis:**
- **Problem:** If SymbolCollector failed to register method, NameResolver silently skips body
- **Edge case:**
  ```crystal
  def foo(x)
    x + 1  # If 'foo' not in table, identifiers in body never resolved
  end
  ```
- **Impact:** Missing "undefined variable" diagnostics
- **Risk:** 🟡 MODERATE - Should emit diagnostic
- **Recommendation:**
  ```crystal
  symbol = @current_table.lookup(name)
  unless symbol.is_a?(MethodSymbol)
    # Missing method symbol → internal error (collector should have registered it)
    # For now, emit diagnostic and skip
    @diagnostics << Diagnostic.new(
      "internal error: method '#{name}' not found in symbol table",
      node.span
    )
    return
  end
  ```

---

### ✅ SAFE: Scope Restoration
**Code:** Lines 116-123 (visit_def)
```crystal
prev_table = @current_table
@current_table = method_scope
# ... visit body ...
@current_table = prev_table  # Always restored
```

**Analysis:**
- **Edge case:** Exception during body visit could skip restoration
- **Current:** Crystal doesn't use exceptions for control flow here
- **Risk:** ✅ SAFE - Linear flow guarantees restoration

---

### ❌ RISKY: Identifier Resolution Doesn't Check Symbol Kind
**Code:** Lines 74-84 (resolve_identifier)
```crystal
if symbol = @current_table.lookup(name)
  @identifier_symbols[node_id] = symbol  # Any symbol type
else
  @diagnostics << Diagnostic.new("undefined local variable or method '#{name}'", node.span)
end
```

**Analysis:**
- **Edge case:** Identifier resolves to ClassSymbol or MacroSymbol:
  ```crystal
  class Foo; end
  x = Foo  # 'Foo' resolves to ClassSymbol - is this valid?

  macro bar; end
  y = bar  # 'bar' resolves to MacroSymbol - valid?
  ```
- **Behavior:** Both accepted (stored in identifier_symbols)
- **Risk:** 🟡 MODERATE - Type system (Stage 3) must validate usage
- **Current:** Acceptable for Stage 2 (name resolution only)
- **Recommendation:** Add TODO:
  ```crystal
  # TODO: Stage 3 type inference should validate:
  # - ClassSymbol used as type annotation or constant
  # - MacroSymbol only callable, not assignable
  # - MethodSymbol/VariableSymbol for normal identifiers
  ```

---

### ✅ SAFE: Call Argument Resolution
**Code:** Lines 49-51 (Call case)
```crystal
when ExpressionNode::Kind::Call
  visit(node.callee.not_nil!) if node.callee
  node.args.try &.each { |arg| visit(arg) }
```

**Analysis:**
- **Edge case:** Callee or args might be nil (parser error)
- **Guards:** `if node.callee` and `.try` prevent crashes
- **Risk:** ✅ SAFE - Defensive checks in place

---

### 🟡 MODERATE: Macro Literal Pieces Not Fully Validated
**Code:** Lines 86-103 (visit_macro_literal)
```crystal
when Frontend::MacroPiece::Kind::Expression
  visit(piece.expr.not_nil!) if piece.expr
when Frontend::MacroPiece::Kind::ControlStart,
     Frontend::MacroPiece::Kind::ControlElse,
     # ...
  # TODO: Handle control flow bodies once semantic stages support them
```

**Analysis:**
- **Problem:** Control flow bodies ({% if %}, {% for %}) not visited
- **Edge case:**
  ```crystal
  macro example
    {% if true %}
      some_var = 1  # 'some_var' not resolved
    {% end %}
  end
  ```
- **Risk:** 🟡 MODERATE - Identifiers in control flow branches not resolved
- **Current:** Acceptable (macros not expanded yet)
- **Recommendation:** Implement control flow traversal when Stage 3 adds macro expansion

---

### ❌ CRITICAL: Class Reopening with Different Symbol Type
**Code:** Lines 126-134 (visit_class)
```crystal
symbol = @current_table.lookup(name)
unless symbol.is_a?(ClassSymbol)
  return  # Skip if not ClassSymbol
end
```

**Analysis:**
- **Edge case:** SymbolCollector allowed incompatible redefinition:
  ```crystal
  def Foo; end     # MethodSymbol registered
  class Foo; end   # SymbolCollector uses redefine → MethodSymbol overwritten
  ```
  Then NameResolver visits `class Foo`:
  ```crystal
  symbol = @current_table.lookup("Foo")  # Gets ClassSymbol (overwritten)
  unless symbol.is_a?(ClassSymbol)       # Passes
    return
  end
  # Proceeds with ClassSymbol
  ```
- **Problem:** NameResolver doesn't see the conflict because SymbolCollector already overwrote
- **Risk:** 🔴 CRITICAL - Silently accepts invalid code
- **Root cause:** SymbolCollector's unconditional `redefine`
- **Recommendation:** Fix in SymbolCollector (emit diagnostic for incompatible types)

---

## PART 3: Cross-Component Issues

### ❌ CRITICAL: SymbolCollector and NameResolver Assume Same Traversal Order
**Analysis:**
- Both use `program.roots` and traverse AST in same order
- **Edge case:** If traversal orders diverge (e.g., parallel processing):
  ```crystal
  class Foo
    def bar; x; end  # NameResolver visits before SymbolCollector finishes?
  end
  ```
- **Current:** Sequential execution guarantees SymbolCollector runs fully before NameResolver
- **Risk:** 🟡 MODERATE - If future optimization parallelizes, could break
- **Recommendation:** Enforce contract:
  ```crystal
  class Analyzer
    def analyze
      collect_symbols   # MUST complete before resolve_names
      resolve_names
    end

    # Prevent misuse
    def resolve_names
      raise "Must run collect_symbols first" unless @symbols_collected
    end
  end
  ```

---

### 🟡 MODERATE: No Validation of Parser Invariants
**Analysis:**
- Both components assume parser produces valid AST:
  - `def_name` is non-nil for Def nodes
  - `class_name` is non-nil for Class nodes
  - `def_body`/`class_body` are valid ExprId arrays
- **Edge case:** If parser has bugs or future changes break invariants:
  ```crystal
  # Parser bug: Def node with nil def_name
  node.kind == Def && node.def_name.nil?
  ```
- **Risk:** 🟡 MODERATE - Would cause crashes or silent skips
- **Current:** Parser specs should catch this
- **Recommendation:** Add defensive assertions in debug builds:
  ```crystal
  private def handle_def(node_id, node)
    name_slice = node.def_name
    {% if flag?(:debug) %}
      raise "Parser invariant: Def node must have def_name" unless name_slice
    {% end %}
    return unless name_slice  # Still guard in release
    # ...
  end
  ```

---

## PART 4: Summary of Risks

### 🔴 CRITICAL (Must Fix Before Stage 3)
1. **Parameter symbols have invalid node_id (-1)** → Breaks diagnostics
2. **No diagnostics for incompatible redefinitions** → Accepts invalid code
3. **Incompatible type redefinitions silent** → SymbolCollector/NameResolver divergence

### 🟡 MODERATE (Fix in Stage 3 or when adding features)
1. **Class reopening doesn't validate superclass compatibility** → Silent superclass changes
2. **Macro body symbols not collected** → Expected (no expansion yet)
3. **Identifier resolution accepts any symbol type** → Type system will validate
4. **Macro control flow not traversed** → Expected (no expansion yet)
5. **No validation of parser invariants** → Add defensive checks

### ✅ SAFE (No action needed)
1. **Nested def scoping** → Scope stack handles correctly
2. **Empty body handling** → Guarded with `|| []`
3. **Scope restoration** → Linear flow guarantees
4. **Call argument resolution** → Defensive checks present

---

## PART 5: Recommended Fixes (Priority Order)

### Priority 1: Fix Before Diagnostics (Prerequisite)
```crystal
# FIX: Parameter symbols need valid node_id
# LOCATION: symbol_collector.cr:94
# DEPENDS: Parser must track parameter spans OR use def span as fallback

params.each do |param_name|
  # Use def node_id as fallback (conservative)
  param_symbol = VariableSymbol.new(param_name, node_id)
  method_scope.define(param_name, param_symbol)
end
```

### Priority 2: Implement Diagnostic Emission
```crystal
# FIX: Emit diagnostics for incompatible redefinitions
# LOCATION: symbol_collector.cr:85-89 (and similar in handle_macro_def, handle_class)
# DEPENDS: Semantic::Diagnostic infrastructure (from design doc)

if existing = table.lookup_local(name)
  case existing
  when MethodSymbol
    if symbol.is_a?(MethodSymbol)
      table.redefine(name, symbol)  # Valid overloading
    else
      @diagnostics << build_incompatible_redefinition_error(name, existing, symbol)
      # Still redefine to allow compilation to continue and find more errors
      table.redefine(name, symbol)
    end
  # ... other cases ...
  end
end
```

### Priority 3: Add Validation for Class Reopening
```crystal
# FIX: Validate superclass compatibility
# LOCATION: symbol_collector.cr:119-122

if existing.is_a?(ClassSymbol)
  if existing.superclass_name && super_name && existing.superclass_name != super_name
    @diagnostics << Diagnostic.new(
      DiagnosticLevel::Error,
      "E2003",
      "class '#{name}' reopened with different superclass",
      get_span(node_id),
      [SecondarySpan.new(get_span(existing.node_id), "originally defined here")]
    )
  end
  class_scope = existing.scope
end
```

### Priority 4: Add TODOs for Future Work
```crystal
# ADD: Documentation for macro limitations
# LOCATION: symbol_collector.cr:64 (after MacroSymbol creation)

# TODO(Stage 3): When macro expansion is implemented, must run
# SymbolCollector on expanded AST to register generated symbols

# LOCATION: name_resolver.cr:98 (after ControlStart case)

# TODO(Stage 3): Traverse control flow bodies when macro expansion added
```

---

## PART 6: Test Cases to Add

### Test Case 1: Parameter Diagnostic Formatting
```crystal
# Should produce diagnostic pointing to parameter location
def foo(invalid_param)
  invalid_param.unknown_method  # Error should reference param definition
end
```

### Test Case 2: Incompatible Redefinition
```crystal
# Should emit E2001 error
def bar; end
class bar; end  # Error: redefinition with incompatible type
```

### Test Case 3: Class Reopening with Different Superclass
```crystal
# Should emit E2003 error
class Foo < Bar; end
class Foo < Baz; end  # Error: different superclass
```

### Test Case 4: Deeply Nested Defs
```crystal
# Should correctly scope all levels
def a
  def b
    def c
      x = 1  # x in c's scope
      x      # Resolves to local x
    end
  end
end
```

---

**End of Edge-Case Audit**

**Key Findings:**
- 3 critical issues requiring fixes before diagnostics work
- 5 moderate issues to address in Stage 3
- 4 patterns verified as safe

**Next Steps:**
1. Fix parameter node_id issue (prerequisite)
2. Implement diagnostic infrastructure (from design doc)
3. Emit diagnostics for incompatible redefinitions
4. Add test coverage for edge cases
