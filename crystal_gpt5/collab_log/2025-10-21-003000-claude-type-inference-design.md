## 2025-10-21 00:30 Claude — Type Inference Algorithm Design

### Maieutic Design Process

Used **[LM-CASSANDRA-0] PREVENTIVE PATTERN SEARCH** to check Knowledge Core first.

**Findings from Knowledge Core:**
- Crystal compiler has complex type inference with unification
- Real bottleneck often in codegen (70%), not semantic (30%)
- Small-n optimizations can add overhead
- Stateful unbind/rebind lifecycle in Crystal

**Key Insight**: crystal_gpt5 is **educational compiler** - prioritize clarity over completeness.

---

## Algorithm Choice: Simple Bottom-Up Type Inference

### Decision Graph

```
         [LM-2] ALGORITHM_CHOICE
              |
    ┌─────────┼─────────┬─────────┐
    ↓         ↓         ↓         ↓
[Hindley-  [Bidirec-  [Constraint [Simple
 Milner]    tional]    -based]    Bottom-Up]
   |          |           |          |
Complex   Medium      Medium      Simple
Full      Flow-sens   Generate    Leaves→Root
inference  Mix        constraints  No unif

   ❌         ⚠️          ⚠️          ✅
Too complex Med effort  Med effort  CHOSEN
```

**Reasoning:**
- **Complexity**: HM requires type variables, unification, substitution
- **Bidirectional**: Needs explicit type annotations, checking vs inference modes
- **Constraint-based**: Requires constraint solver, complex error reporting
- **Bottom-up**: Simple recursion, clear rules, easy to understand

**Trade-offs accepted:**
- ❌ No full type inference (e.g., can't infer `foo(x) = x + 1` as Int32 → Int32)
- ❌ No polymorphic types initially
- ✅ But: Clear semantics, easy to test, good foundation for GPT-5 to extend

---

## Architecture Design

### Core Component: TypeInferenceEngine

```crystal
class TypeInferenceEngine
  def initialize(
    @program : Program,
    @analyzer : Analyzer,     # Has SymbolTable, identifier_symbols
    @context : TypeContext    # Stores inferred types
  )
  end

  # Main entry point
  def infer_types
    @program.roots.each do |root_id|
      type = infer_expression(root_id)
      @context.set_type(root_id, type)
    end
  end

  # Recursive type inference
  private def infer_expression(expr_id : ExprId) : Type
    node = @program.arena[expr_id]

    case node.kind
    when .number_literal?    then infer_number_literal(node)
    when .string_literal?    then infer_string_literal(node)
    when .bool_literal?      then infer_bool_literal(node)
    when .nil_literal?       then infer_nil_literal(node)
    when .identifier?        then infer_identifier(node, expr_id)
    when .call?              then infer_call(node, expr_id)
    when .binary_op?         then infer_binary_op(node)
    when .if?                then infer_if(node)
    when .while?             then infer_while(node)
    when .def?               then infer_def(node, expr_id)
    when .class?             then infer_class(node, expr_id)
    else
      # Unknown expression - return error type or nil
      @context.nil_type
    end
  end
end
```

---

## Typing Rules (Bottom-Up Approach)

### 1. Literals

**Number Literal** → `Int32`
```crystal
def infer_number_literal(node)
  @context.int32_type
end
```

**String Literal** → `String`
```crystal
def infer_string_literal(node)
  @context.string_type
end
```

**Bool Literal** → `Bool`
```crystal
def infer_bool_literal(node)
  @context.bool_type
end
```

**Nil Literal** → `Nil`
```crystal
def infer_nil_literal(node)
  @context.nil_type
end
```

---

### 2. Variables (Identifiers)

**Lookup symbol** → **Symbol's type**

```crystal
def infer_identifier(node, expr_id)
  # Get resolved symbol from Analyzer
  symbol = @analyzer.identifier_symbols[expr_id]?

  return @context.nil_type unless symbol

  case symbol
  when VariableSymbol
    # Variable type from declaration or previous assignment
    if declared_type = symbol.declared_type
      # Explicit type: var : Int32 = ...
      parse_type_annotation(declared_type)
    else
      # Inferred from assignment: var = 42
      # Need to track assignments...
      @context.nil_type  # TODO: track assignments
    end
  when MethodSymbol
    # Reference to method → method type (future: function types)
    @context.nil_type  # TODO: method reference types
  when ClassSymbol
    # Reference to class → class type (metaclass)
    ClassType.new(symbol)
  else
    @context.nil_type
  end
end
```

**Challenge**: Variables without explicit types need assignment tracking.
**Solution for now**: Require explicit type annotations, or use Nil as placeholder.

---

### 3. Binary Operators

**Numeric operators** (`+`, `-`, `*`, `/`):
- Infer both operands
- Check both are numeric types
- Return numeric type (prefer Int32 for simplicity)

```crystal
def infer_binary_op(node)
  left_type = infer_expression(node.binary_left)
  right_type = infer_expression(node.binary_right)

  # Get operator
  op = node.binary_op_text(@program.source)

  case op
  when "+", "-", "*", "/"
    # Check numeric types
    unless numeric_type?(left_type) && numeric_type?(right_type)
      emit_error("Operator #{op} requires numeric types")
      return @context.nil_type
    end

    # For simplicity: always return Int32
    # TODO: proper numeric promotion (Int32 + Int64 → Int64)
    @context.int32_type

  when "==", "!=", "<", ">", "<=", ">="
    # Comparison operators → Bool
    @context.bool_type

  when "&&", "||"
    # Logical operators → Bool
    unless bool_type?(left_type) && bool_type?(right_type)
      emit_error("Operator #{op} requires bool types")
      return @context.nil_type
    end
    @context.bool_type

  else
    emit_error("Unknown operator #{op}")
    @context.nil_type
  end
end

def numeric_type?(type : Type) : Bool
  type.is_a?(PrimitiveType) &&
    (type.name == "Int32" || type.name == "Int64" || type.name == "Float64")
end

def bool_type?(type : Type) : Bool
  type.is_a?(PrimitiveType) && type.name == "Bool"
end
```

---

### 4. Method Calls (Complex)

**Challenge**: Method overload resolution
- Find all methods with matching name
- Filter by argument count
- Check argument types
- Select best match

```crystal
def infer_call(node, expr_id)
  # Get method name
  name = node.call_name_text(@program.source)

  # Infer argument types
  arg_types = node.call_args.map { |arg_id| infer_expression(arg_id) }

  # Find receiver type
  receiver_type = if receiver_id = node.call_receiver
    infer_expression(receiver_id)
  else
    # No receiver → implicit self or top-level
    @context.nil_type  # TODO: handle implicit self
  end

  # Resolve method
  method = resolve_method(receiver_type, name, arg_types)

  if method
    # Return method's return type
    # For now: assume Nil (no return type annotations yet)
    @context.nil_type  # TODO: parse return type annotations
  else
    emit_error("No method '#{name}' found")
    @context.nil_type
  end
end

def resolve_method(receiver_type : Type, name : String, arg_types : Array(Type)) : MethodSymbol?
  # TODO: Implement method resolution
  # 1. Get all methods from receiver type's class
  # 2. Filter by name
  # 3. Filter by argument count
  # 4. Check argument type compatibility
  # 5. Return best match
  nil
end
```

**For MVP**: Skip method calls initially, focus on literals and variables.

---

### 5. Control Flow (If Statements)

**Union types** for different branches:

```crystal
def infer_if(node)
  # Infer condition (should be Bool)
  cond_type = infer_expression(node.if_condition)
  unless bool_type?(cond_type)
    emit_error("If condition must be Bool, got #{cond_type}")
  end

  # Infer then branch
  then_type = infer_expression(node.if_then)

  # Infer else branch (if present)
  else_type = if else_id = node.if_else
    infer_expression(else_id)
  else
    @context.nil_type  # No else → implicit nil
  end

  # Union of both branches
  @context.union_of([then_type, else_type])
end
```

**Example**:
```crystal
x = if condition
  42        # Int32
else
  "hello"   # String
end
# x : Int32 | String
```

---

### 6. Definitions (Methods, Classes)

**Method definitions**:
```crystal
def infer_def(node, expr_id)
  # Method defines a new symbol, doesn't have a "value type"
  # Return Nil (methods are statements, not expressions in our design)

  # TODO: Infer method body for return type checking
  @context.nil_type
end
```

**Class definitions**:
```crystal
def infer_class(node, expr_id)
  # Class defines a new symbol
  # Return Nil (classes are statements)
  @context.nil_type
end
```

---

## Type Checking vs Type Inference

**Distinction**:
- **Type Inference**: Determine type of expression
- **Type Checking**: Verify types are compatible

**Strategy**: Combine both
- Infer bottom-up
- Check compatibility at each step
- Emit diagnostics for mismatches

**Example**: Binary operator type checking (already shown above)

---

## Error Handling Strategy

### Diagnostic Emission

```crystal
def emit_error(message : String, node_id : ExprId? = nil)
  # Create diagnostic and add to analyzer
  diagnostic = Diagnostic.new(
    level: DiagnosticLevel::Error,
    code: "E3001",  # Type error codes start at E3xxx
    message: message,
    spans: [...]
  )
  @analyzer.diagnostics << diagnostic
end
```

### Recovery Strategy

**On error**: Return `Nil` type or special `ErrorType`
- Allows inference to continue
- Prevents cascading errors
- Better error messages

---

## Implementation Phases

### Phase 1: Literals + Variables (MVP)
- ✅ Type context already implemented
- → Implement TypeInferenceEngine skeleton
- → Add literal type inference (trivial)
- → Add variable lookup (use Analyzer.identifier_symbols)
- **Test**: `x : Int32 = 42` should infer Int32

### Phase 2: Binary Operators
- → Implement numeric operators (+, -, *, /)
- → Implement comparison operators (==, <, >)
- → Implement logical operators (&&, ||)
- **Test**: `1 + 2` → Int32, `x < 5` → Bool

### Phase 3: Control Flow
- → Implement if expressions with union types
- → Implement while loops
- **Test**: `if cond then 1 else "hi" end` → Int32 | String

### Phase 4: Method Calls (Complex)
- → Implement method resolution
- → Handle overloads
- → Check argument types
- **Test**: `foo(42)` resolves to correct overload

### Phase 5: Definitions
- → Infer method body types
- → Check return type annotations
- → Infer class types

---

## What's NOT Implemented (GPT-5 Can Extend)

**Type Variables**:
```crystal
def identity(x)  # Can't infer: forall T. T → T
  x
end
```

**Generic Instantiation**:
```crystal
class Array(T)  # Can't infer T from usage
end
```

**Subtyping/Coercion**:
```crystal
x : Int32 = 5
y : Int64 = x  # Should auto-convert?
```

**Higher-Order Functions**:
```crystal
def map(arr, fn)  # fn is function type
end
```

**Nilable Sugar**:
```crystal
x : Int32? = nil  # Syntax sugar for Int32 | Nil
```

---

## Design Review Questions for GPT-5

### Q1: Algorithm Choice
Is simple bottom-up approach reasonable for educational compiler?
- Alternative: Should we use bidirectional typing?
- Trade-off: Simplicity vs expressiveness

### Q2: Variable Type Tracking
How to handle variables without explicit types?
```crystal
x = 42    # Need to track assignment to infer type
y = x + 1 # Need previous inference
```
- Option A: Require explicit types for now
- Option B: Track assignments in second pass
- Option C: Use constraint-based approach

### Q3: Method Overload Resolution
What's the best-match algorithm?
- Most specific parameter types?
- Exact match preferred over conversion?
- How to handle ambiguity?

### Q4: Error Recovery
Should we use `ErrorType` to prevent cascading errors?
```crystal
class ErrorType < Type
  # Represents a type error, compatible with anything
  def ==(other) true end
end
```

### Q5: Integration with Analyzer
TypeInferenceEngine needs:
- Program (AST)
- Analyzer (SymbolTable, identifier_symbols)
- TypeContext

Should TypeInferenceEngine be part of Analyzer or separate?

---

## Next Steps

**Phase 1 Implementation**:
1. Create TypeInferenceEngine skeleton
2. Implement literal type inference
3. Implement variable type lookup
4. Write specs for Phase 1
5. Verify full pipeline works

**Estimated Effort**: 2-3 hours for Phase 1

**Ready for GPT-5 Review**: Architecture design, ask for feedback before implementing.

---

## Maieutic Reflection

**[LM-3] VERIFICATION**:
- ✅ Searched Knowledge Core first (CASSANDRA)
- ✅ Considered multiple approaches (graph branching)
- ✅ Documented trade-offs clearly
- ✅ Left complex parts for GPT-5 review

**Key Decision**: Chose simplicity over completeness
- Rationale: Educational compiler, clear semantics
- Risk: Limited expressiveness (acceptable)
- Benefit: Easy to understand and extend

**Questions raised for GPT-5**:
- Variable tracking strategy
- Method resolution algorithm
- Error recovery approach
- Integration architecture

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
