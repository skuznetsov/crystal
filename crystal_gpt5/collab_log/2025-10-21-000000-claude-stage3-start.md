## 2025-10-21 00:00 Claude — Stage 3 Foundation Start

### Maieutic Trace
- **Goal check**: Begin Stage 3 (Type Inference) while GPT-5 on weekly limit - avoid blocking progress
- **State inspection**: Stage 2 complete (symbol collection + name resolution done); diagnostics working
- **Strategy**: Start with non-controversial type system foundation - basic types, type context, infrastructure
- **Hypothesis**: Building core type system won't conflict with GPT-5's plans; he can layer type inference logic on top

### Coordination Protocol
**What I'm building** (safe to start):
- Basic type representation (Type abstract class, primitive types, class types)
- TypeContext for storing type information
- Infrastructure only - NO type inference algorithms yet

**What I'm NOT doing** (wait for GPT-5):
- Type inference logic (unification, constraint solving)
- Method overload resolution algorithms
- Generic instantiation
- Complex type checking rules

**Rationale**: Infrastructure is stable contract; algorithms are where GPT-5's expertise shines

---

## Stage 3 Plan Overview

### What is Stage 3?
**Type Inference & Checking**: Given AST with symbols resolved, infer types for all expressions and validate type safety.

**Input** (from Stage 2):
- AST with all nodes
- SymbolTable with all symbols
- identifier_symbols map (ExprId → Symbol)

**Output**:
- expression_types map (ExprId → Type)
- Type-checked program ready for codegen
- Type errors as diagnostics

### Core Components

**1. Type System** (what I'm starting):
```crystal
abstract class Type
class PrimitiveType < Type  # Int32, String, Bool, etc.
class ClassType < Type      # User-defined classes
class UnionType < Type      # T | U
class NilableType < Type    # T?
class GenericType < Type    # Foo(T)
class TypeVar < Type        # Unbound type variable
```

**2. Type Context** (what I'm starting):
```crystal
class TypeContext
  # Maps ExprId → inferred Type
  getter expression_types : Hash(ExprId, Type)

  # Built-in primitive types
  getter int32_type : PrimitiveType
  getter string_type : PrimitiveType
  # ...
end
```

**3. Type Inference** (GPT-5 will design):
- Constraint generation from expressions
- Unification algorithm
- Type variable substitution
- Error reporting

**4. Method Resolution** (GPT-5 will design):
- Overload selection based on argument types
- Generic method instantiation
- Best-match algorithm

---

## Phase 1: Type System Foundation (Starting Now)

### Goals
- Define type hierarchy
- Create built-in primitive types
- Basic type operations (equality, subtyping)

### Files to Create

**1. src/compiler/semantic/types/type.cr** (base class)
**2. src/compiler/semantic/types/primitive_type.cr**
**3. src/compiler/semantic/types/class_type.cr**
**4. src/compiler/semantic/types/union_type.cr**
**5. src/compiler/semantic/types/type_context.cr**

### Non-Goals (Leave for GPT-5)
- Type inference algorithms
- Constraint solving
- Generic instantiation
- Method signature matching

---

## Implementation Strategy

**Step 1**: Basic type representation
- Abstract Type base class
- PrimitiveType for Int32, String, Bool, Nil
- to_s for debugging

**Step 2**: ClassType
- Links to ClassSymbol
- Stores type arguments (for generics later)
- Basic equality checking

**Step 3**: UnionType
- Stores set of constituent types
- Normalized form (flatten nested unions)
- Equality checking

**Step 4**: TypeContext
- Singleton for built-in types
- expression_types hash (empty for now)
- Helper methods for type creation

**Step 5**: Basic specs
- Type equality tests
- Union normalization tests
- Context initialization tests

---

## Design Decisions (For GPT-5 Review)

### Question 1: Type Identity
**Options**:
- A) Structural equality (two Int32 are same if both Int32)
- B) Nominal equality (types need unique IDs)

**My choice**: A (structural) for primitives, B (nominal via ClassSymbol) for classes
**Rationale**: Matches Crystal semantics; simple to implement

### Question 2: Union Normalization
**Example**: `(Int32 | String) | Bool` → `Int32 | String | Bool`

**My choice**: Flatten on creation
**Rationale**: Simpler equality checks, canonical form

### Question 3: Nil Representation
**Options**:
- A) NilType as separate primitive
- B) Nilable(T) as wrapper type

**My choice**: Both - NilType exists, T? is sugar for T | NilType
**Rationale**: Matches Crystal; NilType is singleton

---

## Test Strategy

**Specs to add**:
```crystal
# spec/semantic/types/type_spec.cr
describe Type do
  it "primitive types have identity"
  it "class types compare by symbol"
  it "unions flatten nested unions"
  it "unions normalize order (Int32 | String == String | Int32)"
end
```

**Not testing yet**:
- Type inference (no algorithms yet)
- Subtyping (complex, defer to GPT-5)
- Generic instantiation (Stage 3 Phase 2)

---

## Integration Points (Future)

**How Type Inference will use this**:

```crystal
# Future: TypeInferenceEngine (GPT-5 will build)
class TypeInferenceEngine
  def initialize(@program : Program, @symbols : SymbolTable, @context : TypeContext)
  end

  def infer_types
    @program.roots.each do |root_id|
      inferred = infer_expression(root_id)
      @context.expression_types[root_id] = inferred
    end
  end

  private def infer_expression(expr_id : ExprId) : Type
    node = @program.arena[expr_id]
    case node.kind
    when .number_literal?
      @context.int32_type  # Using type from context
    when .string_literal?
      @context.string_type
    # ... GPT-5 implements rest
    end
  end
end
```

**How Method Resolution will use this**:

```crystal
# Future: MethodResolver (GPT-5 will build)
class MethodResolver
  def resolve_call(call_id : ExprId, arg_types : Array(Type)) : MethodSymbol?
    # Use type information to select best overload
  end
end
```

---

## Safety Checklist

Before committing, verify:
- ✅ No conflicts with GPT-5's files (symbol_collector, analyzer, etc.)
- ✅ No type inference logic (just data structures)
- ✅ All tests pass (existing + new type specs)
- ✅ Clear TODO comments for GPT-5 integration points
- ✅ Documented design decisions for review

---

## Timeline

**Today (Session 1)**:
- Type base class + primitive types
- Basic specs
- TypeContext skeleton

**Tomorrow (Session 2)**:
- ClassType + UnionType
- Union normalization
- Comprehensive type specs

**Wait for GPT-5**:
- Type inference algorithms
- Method overload resolution
- Generic instantiation

---

**Starting implementation now...**
