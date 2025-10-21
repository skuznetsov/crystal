## 2025-10-21 18:15 Claude — Phase 4 Design: Method Call Type Inference (Hybrid Approach)

### Maieutic Analysis

**[LM-1] PROBLEM_SETUP:**
- Goal: Method call type inference for Phase 4
- User requirement: "надежнее и качественнее, не торопиться"
- Production-ready philosophy: correct architecture > quick hacks

**[LM-2] STUDY_CRYSTAL:**
- Examined `src/compiler/crystal/semantic/call.cr` (1272 lines)
- Complex overload resolution with autocast, splat args, named args
- Multiple lookup strategies for different type kinds

**[LM-3] ARCHITECTURE_GAP:**
- **BLOCKER #1**: Parser doesn't parse parameter type annotations
  - Current: `def foo(x, y)` ✅
  - Missing: `def foo(x : Int32, y : String)` ❌
- **BLOCKER #2**: MethodSymbol doesn't store parameter types
  - Current: `params : Array(String)` (names only)
  - Needed: `params : Array({String, Type})` (name + type)

**[LM-DAEDALUS] DECISION_GRAPH:**

```
         [BLOCKER_FOUND]
              |
    ┌─────────┼─────────┬─────────┐
    ↓         ↓         ↓         ↓
[OPT-A]   [OPT-B]   [OPT-C]   [OPT-D] ✅
Full      Simple    Defer     Hybrid
Support   Version   Task      Approach

3-5d      1d        0d        2-3d
100%      50%       N/A       80%
Complete  Limited   Skip      CHOSEN
```

**[LM-4] HYBRID_APPROACH - Selected Strategy:**

### Phase 4A: Foundation (NOW)

#### Task 4A.1: Parser Extension - Parameter Types
**Goal:** Parse `def foo(x : Int32, y : String)`

**Current AST:**
```crystal
getter def_params : Array(String)?  # ["x", "y"]
```

**New AST:**
```crystal
struct Parameter
  getter name : String
  getter type_annotation : String?  # "Int32", "String", nil

  def initialize(@name, @type_annotation = nil)
  end
end

getter def_params : Array(Parameter)?
```

**Parser changes:**
```crystal
private def parse_method_params
  params = [] of Parameter
  # ...
  loop do
    name = parse_identifier
    type_annotation = nil

    # Check for type annotation: : Type
    if operator_token?(current_token, Token::Kind::Colon)
      advance
      skip_trivia
      type_annotation = parse_type_annotation  # NEW
    end

    params << Parameter.new(name, type_annotation)
    # ...
  end
  params
end

private def parse_type_annotation : String
  # Simple version: just identifier (Int32, String, etc.)
  # Future: handle generics Array(T), unions T | Nil
  token = current_token
  unless token.kind == Token::Kind::Identifier
    emit_error("Expected type annotation")
    return ""
  end
  type_name = token_text(token)
  advance
  type_name
end
```

#### Task 4A.2: MethodSymbol Extension

**Current:**
```crystal
class MethodSymbol < Symbol
  getter params : Array(String)
  getter return_annotation : String?
end
```

**New:**
```crystal
class MethodSymbol < Symbol
  getter params : Array(Parameter)  # Changed
  getter return_type : Type?        # New: resolved return type
  getter return_annotation : String?  # Keep for backward compat

  def param_types : Array(Type?)
    # Resolve parameter type annotations to actual Types
    params.map do |param|
      if ann = param.type_annotation
        resolve_type_name(ann)  # "Int32" → PrimitiveType(Int32)
      else
        nil  # Untyped parameter
      end
    end
  end
end
```

#### Task 4A.3: Simple Method Lookup (No Overloads)

**Algorithm:**
```crystal
def lookup_method(receiver_type : Type, method_name : String) : MethodSymbol?
  # Phase 4A: Lookup by name only
  # Phase 4B: Will add overload resolution by parameter types

  case receiver_type
  when ClassType
    # Look in class scope
    if symbol = receiver_type.class_symbol.scope.lookup(method_name)
      return symbol if symbol.is_a?(MethodSymbol)
    end

    # Look in superclass (future: walk inheritance chain)
    # Look in included modules (future)

  when PrimitiveType
    # Look in built-in methods (Int32#+, String#size, etc.)
    # For now: return nil, use fallback

  when UnionType
    # Future: find common method in all union members
  end

  nil
end
```

#### Task 4A.4: Method Call Type Inference

**In TypeInferenceEngine:**
```crystal
when .call?
  infer_call(node, expr_id)
```

**Implementation:**
```crystal
private def infer_call(node, expr_id : ExprId) : Type
  # Get receiver type
  if receiver_id = node.callee
    receiver_type = infer_expression(receiver_id)
  else
    # No receiver → call on implicit self (TODO)
    return @context.nil_type
  end

  # Get method name
  # TODO: how is method name stored in Call node?
  # For now: assume node has method_name field
  method_name = node.method_name || ""

  # Lookup method
  if method = lookup_method(receiver_type, method_name)
    # Infer argument types
    if args = node.args
      arg_types = args.map { |arg_id| infer_expression(arg_id) }
    end

    # Phase 4A: Return declared return type
    if method.return_type
      return method.return_type
    elsif ann = method.return_annotation
      return parse_type_name(ann)
    else
      # No return type declared → infer from body (Phase 4B)
      return @context.nil_type
    end
  end

  # Method not found
  emit_error("Method '#{method_name}' not found on #{receiver_type}", expr_id)
  @context.nil_type
end
```

### Phase 4B: Upgrade Path (LATER)

#### Task 4B.1: Overload Resolution
```crystal
def lookup_method(receiver_type : Type, method_name : String, arg_types : Array(Type)) : MethodSymbol?
  # Find all methods with this name
  candidates = find_all_methods(receiver_type, method_name)

  # Filter by parameter count
  candidates = candidates.select { |m| m.params.size == arg_types.size }

  # Match by parameter types
  matches = candidates.select do |method|
    method.param_types.zip(arg_types).all? do |param_type, arg_type|
      param_type.nil? || type_matches?(arg_type, param_type)
    end
  end

  # Return best match (or error if ambiguous/none)
  case matches.size
  when 0
    nil  # No matches
  when 1
    matches.first
  else
    # Ambiguous → need more sophisticated resolution
    # For now: return first
    matches.first
  end
end
```

#### Task 4B.2: Operator Overload Replacement
```crystal
when "+", "-", "*", "/"
  # Phase 4B: Check method overload FIRST
  if method = lookup_method(left_type, op, [right_type])
    return method.return_type || promote_numeric_types(left_type, right_type)
  end

  # Fallback
  promote_numeric_types(left_type, right_type)
```

### Implementation Plan

**4A.1: Parser Extension (2-3 hours)**
1. Add Parameter struct to ast.cr
2. Implement parse_type_annotation
3. Update parse_method_params
4. Add tests for `def foo(x : Int32)`

**4A.2: MethodSymbol Extension (1 hour)**
1. Update MethodSymbol to use Parameter
2. Add param_types method
3. Update SymbolCollector (if needed)

**4A.3: Method Lookup (2 hours)**
1. Implement lookup_method in TypeInferenceEngine
2. Handle ClassType receiver
3. Fallback for PrimitiveType (return nil for now)

**4A.4: Call Inference (2-3 hours)**
1. Implement infer_call
2. ✅ Checked Call AST node structure (discovered MemberAccess pattern)
3. Add tests for simple method calls

**Call AST Structure (VERIFIED):**
```crystal
# foo.bar(x) parses as:
Call(
  callee: MemberAccess(left: Identifier("foo"), member: "bar"),
  args: [Identifier("x")]
)

# bar(x) parses as:
Call(
  callee: Identifier("bar"),
  args: [Identifier("x")]
)

# Extract method name:
def get_method_info(call_node)
  callee_node = @program.arena[call_node.callee]

  case callee_node.kind
  when .member_access?
    # foo.bar(x) → receiver=left, method=member
    receiver = callee_node.left
    method_name = callee_node.member_string
    {receiver, method_name}
  when .identifier?
    # bar(x) → receiver=nil (implicit self), method=identifier
    receiver = nil
    method_name = callee_node.literal_string
    {receiver, method_name}
  else
    # Unknown call pattern
    {nil, nil}
  end
end
```

**Total: 7-9 hours (1 day)**

### Test Coverage

**Parser tests:**
```crystal
it "parses method with typed parameters" do
  source = "def foo(x : Int32, y : String); end"
  # Verify: params[0].name == "x", params[0].type_annotation == "Int32"
end

it "parses method with mixed typed/untyped parameters" do
  source = "def bar(x : Int32, y, z : Bool); end"
  # Verify: params[1].type_annotation.nil?
end
```

**Type inference tests:**
```crystal
it "infers return type from method annotation" do
  source = <<-CRYSTAL
    def foo : Int32
      42
    end

    x = foo
  CRYSTAL
  # Verify: x : Int32
end

it "infers type from method call with receiver" do
  source = <<-CRYSTAL
    class Foo
      def bar : String
        "hello"
      end
    end

    f = Foo.new
    x = f.bar
  CRYSTAL
  # Verify: x : String
end
```

### Known Limitations (4A)

1. **No overload resolution** - picks first method with matching name
2. **No generic instantiation** - Array(T) not supported
3. **No method body inference** - requires declared return type
4. **No inheritance** - doesn't search superclass methods
5. **No primitive methods** - Int32#+, String#size not available

All limitations have documented upgrade path in Phase 4B.

### Production-Ready Properties

**Foundation:**
- ✅ Correct data structures (Parameter, typed MethodSymbol)
- ✅ Working feature (method calls type inferred)
- ✅ Clear upgrade path (overloads in 4B)
- ✅ No technical debt (proper architecture)

**Safe fallbacks:**
- Missing method → error (not silent failure)
- Untyped parameters → nil type (explicit unknown)
- No return annotation → Nil (safe default)

**Extensibility:**
- Add overloads: just enhance lookup_method
- Add inheritance: walk superclass chain
- Add generics: type substitution in param_types

### Files to Modify

**Phase 4A:**
1. `src/compiler/frontend/ast.cr` - Add Parameter struct
2. `src/compiler/frontend/parser.cr` - Parse type annotations
3. `src/compiler/semantic/symbol.cr` - Update MethodSymbol
4. `src/compiler/semantic/type_inference_engine.cr` - Add infer_call, lookup_method
5. `spec/parser_spec.cr` - Parser tests for typed params
6. `spec/semantic/type_inference_spec.cr` - Method call tests

**Estimated new code:** ~300 lines (parser: 100, symbol: 50, inference: 150)

### Next Steps

1. **VERIFY Call AST node structure** - how is method name stored?
2. **Implement 4A.1** - Parser extension
3. **Run tests** - ensure no regressions
4. **Implement 4A.2-4A.4** - Symbol + Inference
5. **Add tests** - comprehensive coverage
6. **Document** - Knowledge Core entry

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
