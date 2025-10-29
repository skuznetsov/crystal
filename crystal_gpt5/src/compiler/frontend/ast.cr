require "./span"

module CrystalGPT5
  module Compiler
    module Frontend
      struct ExprId
        getter index : Int32

        def initialize(@index : Int32)
        end

        def invalid?
          @index < 0
        end
      end

      # Numeric literal kind for precise type inference
      #
      # Simplified version covering main use cases:
      # - I32: Default for integer literals (42)
      # - I64: Explicit _i64 suffix or large integers
      # - F64: Decimal point (3.14) or _f64 suffix
      enum NumberKind
        I32
        I64
        F64

        def to_s : String
          case self
          when I32 then "Int32"
          when I64 then "Int64"
          when F64 then "Float64"
          end
        end
      end

      # Phase 37: Visibility modifier for methods
      enum Visibility
        Public
        Private
        Protected
      end

      # Represents an elsif branch in an if expression
      #
      # For production compiler with IDE support, we track:
      # - condition: The condition expression
      # - body: The body expressions
      # - span: Exact source location for diagnostics and IDE tools
      struct ElsifBranch
        getter condition : ExprId
        getter body : Array(ExprId)
        getter span : Span

        def initialize(@condition : ExprId, @body : Array(ExprId), @span : Span)
        end
      end

      # Represents a when branch in a case expression
      #
      # Phase 11: Case/when pattern matching
      # - conditions: Multiple values to match (e.g., when 1, 2, 3)
      # - body: The body expressions for this branch
      # - span: Exact source location
      struct WhenBranch
        getter conditions : Array(ExprId)
        getter body : Array(ExprId)
        getter span : Span

        def initialize(@conditions : Array(ExprId), @body : Array(ExprId), @span : Span)
        end
      end

      # Represents a when branch in a select expression
      #
      # Phase 90A: Select/when for concurrent channel operations
      # - condition: Single condition (channel operation: receive/send/timeout)
      # - body: The body expressions for this branch
      # - span: Exact source location
      struct SelectBranch
        getter condition : ExprId
        getter body : Array(ExprId)
        getter span : Span

        def initialize(@condition : ExprId, @body : Array(ExprId), @span : Span)
        end
      end

      # Represents a key-value pair in a hash literal
      #
      # Phase 14: Hash literals
      # For production compiler with IDE support, we track:
      # - key: The key expression
      # - value: The value expression
      # - span: Exact source location for entire entry (key => value)
      # - arrow_span: Location of => operator for precise diagnostics/hover
      struct HashEntry
        getter key : ExprId
        getter value : ExprId
        getter span : Span
        getter arrow_span : Span

        def initialize(@key : ExprId, @value : ExprId, @span : Span, @arrow_span : Span)
        end
      end

      # Represents a method parameter with optional type annotation
      #
      # Phase 4A: Parameter types for method resolution (PRODUCTION-READY)
      # For production compiler with IDE support, we track:
      # - name: Parameter name (e.g., "x", "y")
      # - type_annotation: Optional type (e.g., "Int32", "String", nil)
      # - span: Full parameter span ("x : Int32")
      # - name_span: Just name ("x") for rename refactoring
      # - type_span: Just type ("Int32") for hover, optional like type_annotation
      #
      # Examples:
      #   def foo(x)           → Parameter("x", nil, span, name_span, nil)
      #   def foo(x : Int32)   → Parameter("x", "Int32", span, name_span, type_span)
      struct Parameter
        getter name : String
        getter type_annotation : String?
        getter default_value : ExprId?  # Phase 71: default parameter value
        getter span : Span              # Full "x : Int32 = 5" span
        getter name_span : Span         # Just "x" for rename
        getter type_span : Span?        # Just "Int32" for hover (optional)
        getter default_span : Span?     # Phase 71: Just default value span
        getter is_splat : Bool          # Phase 68: *args (single splat)
        getter is_double_splat : Bool   # Phase 68: **kwargs (double splat)

        def initialize(
          @name : String,
          @type_annotation : String? = nil,
          @default_value : ExprId? = nil,
          @span : Span = Span.new(0, 0, 0, 0, 0, 0),
          @name_span : Span = Span.new(0, 0, 0, 0, 0, 0),
          @type_span : Span? = nil,
          @default_span : Span? = nil,
          @is_splat : Bool = false,
          @is_double_splat : Bool = false
        )
        end
      end

      # Represents a named tuple entry (key: value pair)
      #
      # Phase 70: Named tuple literals
      # For {name: "Alice", age: 30}:
      # - key: Entry key as identifier ("name", "age")
      # - value: Expression for the value
      # - key_span: Just key for navigation
      # - value_span: Just value for hover
      # - span: Full "key: value" span
      struct NamedTupleEntry
        getter key : String
        getter value : ExprId
        getter span : Span              # Full "key: value" span
        getter key_span : Span          # Just "key"
        getter value_span : Span        # Just value expression

        def initialize(
          @key : String,
          @value : ExprId,
          @span : Span,
          @key_span : Span,
          @value_span : Span
        )
        end
      end

      # Represents a named argument in method call (name: value)
      #
      # Phase 72: Named arguments at call site
      # For foo(x: 10, y: 20):
      # - name: Argument name as identifier ("x", "y")
      # - value: Expression for the argument value
      # - name_span: Just name for navigation
      # - value_span: Just value for hover
      # - span: Full "name: value" span
      struct NamedArgument
        getter name : String
        getter value : ExprId
        getter span : Span              # Full "name: value" span
        getter name_span : Span         # Just "name"
        getter value_span : Span        # Just value expression

        def initialize(
          @name : String,
          @value : ExprId,
          @span : Span,
          @name_span : Span,
          @value_span : Span
        )
        end
      end

      # Represents an accessor specification (getter/setter/property)
      #
      # Phase 30: Accessor macros (PRODUCTION-READY)
      # For production compiler with IDE support, we track:
      # - name: Accessor name (e.g., "name", "age")
      # - type_annotation: Optional type (e.g., "String", "Int32", nil)
      # - default_value: Optional default value expression
      # - span: Full accessor span ("name : String = value")
      # - name_span: Just name ("name") for rename refactoring
      # - type_span: Just type ("String") for hover, optional like type_annotation
      #
      # Examples:
      #   getter name              → AccessorSpec("name", nil, nil, ...)
      #   getter name : String     → AccessorSpec("name", "String", nil, ...)
      #   getter name = "default"  → AccessorSpec("name", nil, default_expr_id, ...)
      #   getter name : String = "default" → AccessorSpec("name", "String", default_expr_id, ...)
      struct AccessorSpec
        getter name : String
        getter type_annotation : String?
        getter default_value : ExprId?
        getter span : Span              # Full "name : String = value" span
        getter name_span : Span         # Just "name" for rename
        getter type_span : Span?        # Just "String" for hover (optional)

        def initialize(
          @name : String,
          @type_annotation : String? = nil,
          @default_value : ExprId? = nil,
          @span : Span = Span.new(0, 0, 0, 0, 0, 0),
          @name_span : Span = Span.new(0, 0, 0, 0, 0, 0),
          @type_span : Span? = nil
        )
        end
      end

      # Represents a rescue clause in exception handling
      #
      # Phase 29: Exception handling
      # - exception_type: Optional exception type to catch (e.g., "RuntimeError")
      # - variable_name: Optional variable to bind exception (e.g., "e")
      # - body: The rescue handler body expressions
      # - span: Exact source location
      struct RescueClause
        getter exception_type : Slice(UInt8)?
        getter variable_name : Slice(UInt8)?
        getter body : Array(ExprId)
        getter span : Span

        def initialize(@exception_type : Slice(UInt8)?, @variable_name : Slice(UInt8)?, @body : Array(ExprId), @span : Span)
        end
      end

      # Represents an enum member in enum definition
      #
      # Phase 33: Enum definition
      # - name: Member name (e.g., "Red")
      # - value: Optional explicit value (e.g., Red = 1)
      # - name_span: Exact location of member name
      # - value_span: Exact location of value expression (optional)
      struct EnumMember
        getter name : String
        getter value : ExprId?
        getter name_span : Span
        getter value_span : Span?

        def initialize(
          @name : String,
          @value : ExprId? = nil,
          @name_span : Span = Span.new(0, 0, 0, 0, 0, 0),
          @value_span : Span? = nil
        )
        end
      end

      struct ExpressionNode
        enum Kind
          Identifier
          InstanceVar  # @var
          InstanceVarDecl  # @var : Type (Phase 5C)
          ClassVar  # Phase 76: @@var (class variable)
          ClassVarDecl  # Phase 77: @@var : Type (class variable declaration)
          Global  # Phase 75: $var (global variable)
          GlobalVarDecl  # Phase 77: $var : Type (global variable declaration)
          Number
          String
          Char  # Phase 56: character literal 'a'
          Regex  # Phase 57: regex literal /pattern/flags
          Bool
          Nil
          Unary
          Out  # Phase 98: out keyword (C bindings output parameter)
          Binary
          Call
          Index
          MemberAccess
          SafeNavigation  # Phase 47: safe navigation (&.)
          Grouping
          If
          Unless  # Phase 24: unless condition
          While
          Until   # Phase 25: until condition
          For     # Phase 99: for loop (iteration)
          Loop    # Phase 83: infinite loop
          Spawn   # Phase 84: spawn fiber (concurrency)
          Assign
          MultipleAssign  # Phase 73: multiple assignment (a, b = 1, 2)
          MacroExpression
          MacroLiteral
          MacroDef
          Def
          Class
          Return  # Phase 6: return statements
          Self    # Phase 7: self keyword
          Super   # Phase 39: super keyword (call parent method)
          PreviousDef  # Phase 96: previous_def keyword (call previous definition before reopening/redefining)
          Typeof  # Phase 40: typeof (type introspection)
          Sizeof  # Phase 41: sizeof (size in bytes)
          Pointerof  # Phase 42: pointerof (pointer to variable/expression)
          Uninitialized  # Phase 85: uninitialized variable
          Offsetof  # Phase 86: offset of field in type
          Alignof  # Phase 88: ABI alignment in bytes
          InstanceAlignof  # Phase 88: instance alignment
          Asm  # Phase 95: inline assembly
          StringInterpolation  # Phase 8: string interpolation
          ArrayLiteral  # Phase 9: array literals [1, 2, 3]
          Block  # Phase 10: block {|x| ... } or do |x| ... end
          ProcLiteral  # Phase 74: proc literal ->(x) { ... }
          Yield  # Phase 10: yield keyword
          Case  # Phase 11: case/when pattern matching
          Select  # Phase 90A: select/when concurrent channel operations
          Break  # Phase 12: break [value]
          Next   # Phase 12: next
          Range  # Phase 13: range literals (1..10, 1...10)
          HashLiteral  # Phase 14: hash literals {"k"=>v}
          TupleLiteral  # Phase 15: tuple literals {1, 2, 3}
          NamedTupleLiteral  # Phase 70: named tuple literals {name: "value"}
          Symbol  # Phase 16: symbol literals :hello
          Ternary  # Phase 23: ternary operator (cond ? true : false)
          Begin  # Phase 28: begin/end blocks
          Raise  # Phase 29: raise exception
          Require  # Phase 65: require (import file/library)
          TypeDeclaration  # Phase 66: type declaration (x : Type)
          With  # Phase 67: with (context block)
          Getter  # Phase 30: getter macro
          Setter  # Phase 30: setter macro
          Property  # Phase 30: property macro (getter + setter)
          Module  # Phase 31: module definition
          Include  # Phase 31: include module into class/module
          Extend  # Phase 31: extend module into class/module
          Struct  # Phase 32: struct definition (value type)
          Union  # Phase 97: union definition (C bindings)
          Enum  # Phase 33: enum definition (enumerated type)
          Alias  # Phase 34: type alias
          Annotation  # Phase 92: annotation definition
          Constant  # Phase 35: constant declaration
          Lib  # Phase 38: lib (C bindings)
          Fun  # Phase 64: fun (C function declaration)
          As  # Phase 44: type cast (value.as(Type))
          AsQuestion  # Phase 45: safe cast (value.as?(Type))
          IsA  # Phase 93: type check (value.is_a?(Type))
          RespondsTo  # Phase 94: method check (value.responds_to?(:method))
          Generic  # Phase 60: generic type instantiation (Box(Int32))
          Path  # Phase 63: path expression (Foo::Bar)
        end

        getter kind : Kind
        getter span : Span
        getter literal : Slice(UInt8)?
        getter number_kind : NumberKind?
        getter operator : Slice(UInt8)?
        getter left : ExprId?
        getter right : ExprId?
        getter callee : ExprId?
        getter args : Array(ExprId)?
        getter named_args : Array(NamedArgument)?  # Phase 72: named arguments (x: 10, y: 20)
        getter member : Slice(UInt8)?
        getter macro_expr : ExprId?
        getter macro_name : Slice(UInt8)?
        getter macro_pieces : Array(MacroPiece)?
        getter trim_left : Bool?
        getter trim_right : Bool?
        getter def_name : Slice(UInt8)?
        getter def_params : Array(Parameter)?
        getter def_return_type : Slice(UInt8)?
        getter def_body : Array(ExprId)?
        getter class_name : Slice(UInt8)?
        getter class_body : Array(ExprId)?
        getter class_super_name : Slice(UInt8)?
        getter class_is_struct : Bool?  # Phase 32: true for struct, false/nil for class
        getter class_is_union : Bool?  # Phase 97: true for union, false/nil for class/struct
        getter class_is_abstract : Bool?  # Phase 36: true for abstract class
        getter def_is_abstract : Bool?  # Phase 36: true for abstract method
        getter def_visibility : Visibility?  # Phase 37: nil = public (default)
        getter if_condition : ExprId?
        getter if_then : Array(ExprId)?
        getter if_elsifs : Array(ElsifBranch)?
        getter if_else : Array(ExprId)?
        getter while_condition : ExprId?
        getter while_body : Array(ExprId)?
        getter for_variable : Slice(UInt8)?  # Phase 99: iteration variable
        getter for_collection : ExprId?  # Phase 99: collection to iterate over
        getter for_body : Array(ExprId)?  # Phase 99: for loop body
        getter loop_body : Array(ExprId)?  # Phase 83: infinite loop
        getter spawn_expression : ExprId?  # Phase 84: spawn expr
        getter spawn_body : Array(ExprId)?  # Phase 84: spawn do...end
        getter assign_target : ExprId?
        getter assign_value : ExprId?
        getter assign_targets : Array(ExprId)?  # Phase 73: multiple assignment targets (a, b, c)
        getter ivar_decl_type : Slice(UInt8)?  # Phase 5C: @var : Type
        getter return_value : ExprId?  # Phase 6: return statements
        getter string_pieces : Array(StringPiece)?  # Phase 8: string interpolation
        getter array_elements : Array(ExprId)?  # Phase 9: array literal elements
        getter array_of_type : ExprId?  # Phase 91: explicit type ([1,2,3] of Int32 | String)
        getter block_params : Array(Parameter)?  # Phase 10: block parameters
        getter block_body : Array(ExprId)?  # Phase 10: block body
        getter call_block : ExprId?  # Phase 10: block attached to call
        getter proc_return_type : Slice(UInt8)?  # Phase 74: proc return type annotation
        getter yield_args : Array(ExprId)?  # Phase 10: yield arguments
        getter super_args : Array(ExprId)?  # Phase 39: super arguments
        getter previous_def_args : Array(ExprId)?  # Phase 96: previous_def arguments
        getter typeof_args : Array(ExprId)?  # Phase 40: typeof arguments (expressions to get type of)
        getter sizeof_args : Array(ExprId)?  # Phase 41: sizeof arguments (type or expression to get size of)
        getter pointerof_args : Array(ExprId)?  # Phase 42: pointerof arguments (variable or expression to get pointer of)
        getter uninitialized_type : ExprId?  # Phase 85: uninitialized type expression
        getter offsetof_args : Array(ExprId)?  # Phase 86: offsetof arguments (type, field)
        getter alignof_args : Array(ExprId)?  # Phase 88: alignof arguments (type)
        getter instance_alignof_args : Array(ExprId)?  # Phase 88: instance_alignof arguments (type)
        getter asm_args : Array(ExprId)?  # Phase 95: asm arguments (template + optional sections)
        getter out_identifier : Slice(UInt8)?  # Phase 98: identifier after out keyword (C bindings output parameter)
        getter case_value : ExprId?  # Phase 11: value to match against
        getter when_branches : Array(WhenBranch)?  # Phase 11: when branches
        getter case_else : Array(ExprId)?  # Phase 11: else clause
        getter select_branches : Array(SelectBranch)?  # Phase 90A: select when branches
        getter select_else : Array(ExprId)?  # Phase 90A: select else clause
        getter break_value : ExprId?  # Phase 12: optional break value
        # Note: next has no value in Crystal
        getter range_begin : ExprId?  # Phase 13: range start (1..10)
        getter range_end : ExprId?  # Phase 13: range end (1..10)
        getter range_exclusive : Bool?  # Phase 13: true for ..., false for ..
        getter hash_entries : Array(HashEntry)?  # Phase 14: hash key-value pairs
        getter hash_of_key_type : Slice(UInt8)?  # Phase 14: explicit key type for {} of K => V
        getter hash_of_value_type : Slice(UInt8)?  # Phase 14: explicit value type for {} of K => V
        getter tuple_elements : Array(ExprId)?  # Phase 15: tuple literal elements
        getter named_tuple_entries : Array(NamedTupleEntry)?  # Phase 70: named tuple entries
        getter ternary_condition : ExprId?  # Phase 23: ternary condition
        getter ternary_true_branch : ExprId?  # Phase 23: ternary true branch
        getter ternary_false_branch : ExprId?  # Phase 23: ternary false branch
        getter begin_body : Array(ExprId)?  # Phase 28: begin block body
        getter rescue_clauses : Array(RescueClause)?  # Phase 29: rescue handlers
        getter ensure_body : Array(ExprId)?  # Phase 29: ensure block body
        getter raise_value : ExprId?  # Phase 29: expression to raise
        getter require_path : ExprId?  # Phase 65: path to require (string literal or expression)
        getter type_decl_name : Slice(UInt8)?  # Phase 66: variable name in type declaration
        getter type_decl_type : Slice(UInt8)?  # Phase 66: type name in type declaration
        getter with_receiver : ExprId?  # Phase 67: receiver expression for with block
        getter with_body : Array(ExprId)?  # Phase 67: body of with block
        getter accessor_specs : Array(AccessorSpec)?  # Phase 30: getter/setter/property specifications
        getter module_name : Slice(UInt8)?  # Phase 31: module name
        getter module_body : Array(ExprId)?  # Phase 31: module body
        getter include_name : Slice(UInt8)?  # Phase 31: include module name
        getter extend_name : Slice(UInt8)?  # Phase 31: extend module name
        getter lib_name : Slice(UInt8)?  # Phase 38: lib name
        getter lib_body : Array(ExprId)?  # Phase 38: lib body
        getter enum_name : Slice(UInt8)?  # Phase 33: enum name
        getter enum_base_type : Slice(UInt8)?  # Phase 33: enum base type (: Int32)
        getter enum_members : Array(EnumMember)?  # Phase 33: enum members
        getter alias_name : Slice(UInt8)?  # Phase 34: alias name
        getter annotation_name : Slice(UInt8)?  # Phase 92: annotation name
        getter alias_value : Slice(UInt8)?  # Phase 34: aliased type
        getter constant_name : Slice(UInt8)?  # Phase 35: constant name
        getter constant_value : ExprId?  # Phase 35: constant value expression
        getter as_value : ExprId?  # Phase 44: expression being cast
        getter as_target_type : Slice(UInt8)?  # Phase 44: target type for cast
        getter as_question_value : ExprId?  # Phase 45: expression being safely cast
        getter as_question_target_type : Slice(UInt8)?  # Phase 45: target type for safe cast
        getter is_a_value : ExprId?  # Phase 93: expression being type-checked
        getter is_a_target_type : Slice(UInt8)?  # Phase 93: target type for type check
        getter responds_to_value : ExprId?  # Phase 94: expression being checked for method
        getter responds_to_method_name : ExprId?  # Phase 94: method name (Symbol or String)
        getter generic_name : ExprId?  # Phase 60: base type name (Box in Box(Int32))
        getter generic_type_args : Array(ExprId)?  # Phase 60: type arguments ([Int32] in Box(Int32))
        getter class_type_params : Array(Slice(UInt8))?  # Phase 60: type parameters (["T", "K"] in class Box(T, K))
        getter module_type_params : Array(Slice(UInt8))?  # Phase 60: type parameters for modules

        def initialize(
          @kind : Kind,
          @span : Span,
          @literal : Slice(UInt8)? = nil,
          @number_kind : NumberKind? = nil,
          @operator : Slice(UInt8)? = nil,
          @left : ExprId? = nil,
          @right : ExprId? = nil,
          @callee : ExprId? = nil,
          @args : Array(ExprId)? = nil,
          @named_args : Array(NamedArgument)? = nil,
          @member : Slice(UInt8)? = nil,
          @macro_expr : ExprId? = nil,
          @macro_name : Slice(UInt8)? = nil,
          @macro_pieces : Array(MacroPiece)? = nil,
          @trim_left : Bool? = nil,
          @trim_right : Bool? = nil,
          @def_name : Slice(UInt8)? = nil,
          @def_params : Array(Parameter)? = nil,
          @def_return_type : Slice(UInt8)? = nil,
          @def_body : Array(ExprId)? = nil,
          @class_name : Slice(UInt8)? = nil,
          @class_body : Array(ExprId)? = nil,
          @class_super_name : Slice(UInt8)? = nil,
          @class_is_struct : Bool? = nil,
          @class_is_union : Bool? = nil,
          @class_is_abstract : Bool? = nil,
          @def_is_abstract : Bool? = nil,
          @def_visibility : Visibility? = nil,
          @if_condition : ExprId? = nil,
          @if_then : Array(ExprId)? = nil,
          @if_elsifs : Array(ElsifBranch)? = nil,
          @if_else : Array(ExprId)? = nil,
          @while_condition : ExprId? = nil,
          @while_body : Array(ExprId)? = nil,
          @for_variable : Slice(UInt8)? = nil,  # Phase 99
          @for_collection : ExprId? = nil,  # Phase 99
          @for_body : Array(ExprId)? = nil,  # Phase 99
          @loop_body : Array(ExprId)? = nil,  # Phase 83
          @spawn_expression : ExprId? = nil,  # Phase 84
          @spawn_body : Array(ExprId)? = nil,  # Phase 84
          @assign_target : ExprId? = nil,
          @assign_value : ExprId? = nil,
          @assign_targets : Array(ExprId)? = nil,
          @ivar_decl_type : Slice(UInt8)? = nil,
          @return_value : ExprId? = nil,
          @string_pieces : Array(StringPiece)? = nil,
          @array_elements : Array(ExprId)? = nil,
          @array_of_type : ExprId? = nil,  # Phase 91: explicit type expression
          @block_params : Array(Parameter)? = nil,
          @block_body : Array(ExprId)? = nil,
          @call_block : ExprId? = nil,
          @proc_return_type : Slice(UInt8)? = nil,
          @yield_args : Array(ExprId)? = nil,
          @super_args : Array(ExprId)? = nil,
          @previous_def_args : Array(ExprId)? = nil,
          @typeof_args : Array(ExprId)? = nil,
          @sizeof_args : Array(ExprId)? = nil,
          @pointerof_args : Array(ExprId)? = nil,
          @uninitialized_type : ExprId? = nil,  # Phase 85
          @offsetof_args : Array(ExprId)? = nil,  # Phase 86
          @alignof_args : Array(ExprId)? = nil,  # Phase 88
          @instance_alignof_args : Array(ExprId)? = nil,  # Phase 88
          @asm_args : Array(ExprId)? = nil,  # Phase 95
          @out_identifier : Slice(UInt8)? = nil,  # Phase 98
          @case_value : ExprId? = nil,
          @when_branches : Array(WhenBranch)? = nil,
          @case_else : Array(ExprId)? = nil,
          @select_branches : Array(SelectBranch)? = nil,  # Phase 90A
          @select_else : Array(ExprId)? = nil,  # Phase 90A
          @break_value : ExprId? = nil,
          @range_begin : ExprId? = nil,
          @range_end : ExprId? = nil,
          @range_exclusive : Bool? = nil,
          @hash_entries : Array(HashEntry)? = nil,
          @hash_of_key_type : Slice(UInt8)? = nil,
          @hash_of_value_type : Slice(UInt8)? = nil,
          @tuple_elements : Array(ExprId)? = nil,
          @named_tuple_entries : Array(NamedTupleEntry)? = nil,
          @ternary_condition : ExprId? = nil,
          @ternary_true_branch : ExprId? = nil,
          @ternary_false_branch : ExprId? = nil,
          @begin_body : Array(ExprId)? = nil,
          @rescue_clauses : Array(RescueClause)? = nil,
          @ensure_body : Array(ExprId)? = nil,
          @raise_value : ExprId? = nil,
          @require_path : ExprId? = nil,
          @type_decl_name : Slice(UInt8)? = nil,
          @type_decl_type : Slice(UInt8)? = nil,
          @with_receiver : ExprId? = nil,
          @with_body : Array(ExprId)? = nil,
          @accessor_specs : Array(AccessorSpec)? = nil,
          @module_name : Slice(UInt8)? = nil,
          @module_body : Array(ExprId)? = nil,
          @include_name : Slice(UInt8)? = nil,
          @extend_name : Slice(UInt8)? = nil,
          @lib_name : Slice(UInt8)? = nil,
          @lib_body : Array(ExprId)? = nil,
          @enum_name : Slice(UInt8)? = nil,
          @enum_base_type : Slice(UInt8)? = nil,
          @enum_members : Array(EnumMember)? = nil,
          @alias_name : Slice(UInt8)? = nil,
          @annotation_name : Slice(UInt8)? = nil,  # Phase 92
          @alias_value : Slice(UInt8)? = nil,
          @constant_name : Slice(UInt8)? = nil,
          @constant_value : ExprId? = nil,
          @as_value : ExprId? = nil,
          @as_target_type : Slice(UInt8)? = nil,
          @as_question_value : ExprId? = nil,
          @as_question_target_type : Slice(UInt8)? = nil,
          @is_a_value : ExprId? = nil,
          @is_a_target_type : Slice(UInt8)? = nil,
          @responds_to_value : ExprId? = nil,
          @responds_to_method_name : ExprId? = nil,
          @generic_name : ExprId? = nil,
          @generic_type_args : Array(ExprId)? = nil,
          @class_type_params : Array(Slice(UInt8))? = nil,
          @module_type_params : Array(Slice(UInt8))? = nil,
        )
        end

        def literal_string
          literal.try { |slice| String.new(slice) }
        end

        def operator_string
          operator.try { |slice| String.new(slice) }
        end

        def member_string
          member.try { |slice| String.new(slice) }
        end
      end

      struct MacroPiece
        enum Kind
          Text
          Expression
          ControlStart
          ControlElseIf
          ControlElse
          ControlEnd
        end

        getter kind : Kind
        getter text : String?
        getter expr : ExprId?
        getter control_keyword : String?
        getter trim_left : Bool
        getter trim_right : Bool
        getter iter_vars : Array(String)?
        getter iterable : ExprId?
        getter span : Span?

        def self.text(value : String, span : Span? = nil)
          new(Kind::Text, value, nil, nil, false, false, nil, nil, span)
        end

        def self.expression(expr : ExprId, trim_left : Bool = false, trim_right : Bool = false, span : Span? = nil)
          new(Kind::Expression, nil, expr, nil, trim_left, trim_right, nil, nil, span)
        end

        def self.control(kind : Kind, keyword : String, expr : ExprId? = nil, trim_left : Bool = false, trim_right : Bool = false, iter_vars : Array(String)? = nil, iterable : ExprId? = nil, span : Span? = nil)
          new(kind, nil, expr, keyword, trim_left, trim_right, iter_vars, iterable, span)
        end

        def initialize(@kind : Kind, @text : String?, @expr : ExprId?, @control_keyword : String?, @trim_left : Bool = false, @trim_right : Bool = false, @iter_vars : Array(String)? = nil, @iterable : ExprId? = nil, @span : Span? = nil)
        end
      end

      # Represents a piece of an interpolated string
      #
      # Phase 8: String interpolation support
      # For "Hello, #{name}!" we have:
      # - Text("Hello, ")
      # - Expression(name_expr_id)
      # - Text("!")
      struct StringPiece
        enum Kind
          Text
          Expression
        end

        getter kind : Kind
        getter text : String?
        getter expr : ExprId?

        def self.text(value : String)
          new(Kind::Text, value, nil)
        end

        def self.expression(expr : ExprId)
          new(Kind::Expression, nil, expr)
        end

        def initialize(@kind : Kind, @text : String?, @expr : ExprId?)
        end
      end

      # ============================================================================
      # Phase B: Typed Arena Prototype - Memory-efficient node structures
      # ============================================================================
      #
      # Specialized struct types for 5 representative AST nodes as a prototype
      # for measuring memory improvements vs the monolithic ExpressionNode
      # (1024 bytes with 100+ fields where 96% are nil).
      #
      # Design Principles:
      # 1. Minimal fields: Only what each node type actually needs
      # 2. Shared span: All nodes have Span for diagnostics
      # 3. ExprId references: Maintain Arena architecture (indices not pointers)
      # 4. Immutable structs: Same as ExpressionNode (thread-safe)
      #
      # Memory Comparison:
      # | Node       | Legacy  | Typed | Savings |
      # |------------|---------|-------|---------|
      # | Number     | 1024 B  | ~48 B | 21x     |
      # | Identifier | 1024 B  | ~40 B | 25x     |
      # | Binary     | 1024 B  | ~56 B | 18x     |
      # | Call       | 1024 B  | ~64 B | 16x     |
      # | If         | 1024 B  | ~88 B | 11x     |
      #
      # Average: ~60 B vs 1024 B = 17x memory improvement

      # NumberNode: Integer and floating-point literals
      # Examples: 42, 3.14, 0x2A
      # Size: ~48 bytes
      struct NumberNode
        getter span : Span
        getter value : Slice(UInt8)
        getter kind : NumberKind

        def initialize(@span : Span, @value : Slice(UInt8), @kind : NumberKind)
        end
      end

      # IdentifierNode: Variable and method names
      # Examples: foo, self, initialize
      # Size: ~40 bytes
      struct IdentifierNode
        getter span : Span
        getter name : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8))
        end
      end

      # BinaryNode: Binary operations
      # Examples: a + b, x * y, foo == bar
      # Size: ~56 bytes
      struct BinaryNode
        getter span : Span
        getter operator : Slice(UInt8)
        getter left : ExprId
        getter right : ExprId

        def initialize(@span : Span, @operator : Slice(UInt8), @left : ExprId, @right : ExprId)
        end
      end

      # CallNode: Method and function calls
      # Examples: foo(a, b), obj.method, bar { |x| x + 1 }
      # Size: ~64 bytes
      struct CallNode
        getter span : Span
        getter callee : ExprId
        getter args : Array(ExprId)
        getter block : ExprId?

        def initialize(@span : Span, @callee : ExprId, @args : Array(ExprId), @block : ExprId? = nil)
        end
      end

      # IfNode: Conditional expressions
      # Examples: if condition then body end
      # Size: ~88 bytes
      struct IfNode
        getter span : Span
        getter condition : ExprId
        getter then_body : Array(ExprId)
        getter elsifs : Array(ElsifBranch)?
        getter else_body : Array(ExprId)?

        def initialize(
          @span : Span,
          @condition : ExprId,
          @then_body : Array(ExprId),
          @elsifs : Array(ElsifBranch)? = nil,
          @else_body : Array(ExprId)? = nil
        )
        end
      end

      # ============================================================================
      # Week 1 Batch 1: Literals Group (completing with NumberNode)
      # ============================================================================

      # StringNode: String literals
      # Examples: "hello", "world"
      # Size: ~40 bytes
      struct StringNode
        getter span : Span
        getter value : Slice(UInt8)

        def initialize(@span : Span, @value : Slice(UInt8))
        end
      end

      # CharNode: Character literals
      # Examples: 'a', 'z', '\n'
      # Size: ~40 bytes
      struct CharNode
        getter span : Span
        getter value : Slice(UInt8)

        def initialize(@span : Span, @value : Slice(UInt8))
        end
      end

      # RegexNode: Regular expression literals
      # Examples: /pattern/, /test/i
      # Size: ~40 bytes
      struct RegexNode
        getter span : Span
        getter pattern : Slice(UInt8)

        def initialize(@span : Span, @pattern : Slice(UInt8))
        end
      end

      # BoolNode: Boolean literals
      # Examples: true, false
      # Size: ~32 bytes
      struct BoolNode
        getter span : Span
        getter value : Bool

        def initialize(@span : Span, @value : Bool)
        end
      end

      # NilNode: Nil literal
      # Example: nil
      # Size: ~24 bytes (just span)
      struct NilNode
        getter span : Span

        def initialize(@span : Span)
        end
      end

      # SymbolNode: Symbol literals
      # Examples: :foo, :bar, :hello
      # Size: ~40 bytes
      struct SymbolNode
        getter span : Span
        getter name : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8))
        end
      end

      # ArrayLiteralNode: Array literals
      # Examples: [1, 2, 3], [] of Int32
      # Size: ~56 bytes
      struct ArrayLiteralNode
        getter span : Span
        getter elements : Array(ExprId)
        getter of_type : ExprId?  # Phase 91: explicit type

        def initialize(@span : Span, @elements : Array(ExprId), @of_type : ExprId? = nil)
        end
      end

      # HashLiteralNode: Hash literals
      # Examples: {"key" => value}, {} of String => Int32
      # Size: ~56 bytes
      struct HashLiteralNode
        getter span : Span
        getter entries : Array(HashEntry)
        getter of_key_type : Slice(UInt8)?
        getter of_value_type : Slice(UInt8)?

        def initialize(
          @span : Span,
          @entries : Array(HashEntry),
          @of_key_type : Slice(UInt8)? = nil,
          @of_value_type : Slice(UInt8)? = nil
        )
        end
      end

      # TupleLiteralNode: Tuple literals
      # Examples: {1, 2, 3}, {1, "hello", true}
      # Size: ~48 bytes
      struct TupleLiteralNode
        getter span : Span
        getter elements : Array(ExprId)

        def initialize(@span : Span, @elements : Array(ExprId))
        end
      end

      # NamedTupleLiteralNode: Named tuple literals
      # Examples: {name: "Alice", age: 30}
      # Size: ~48 bytes
      struct NamedTupleLiteralNode
        getter span : Span
        getter entries : Array(NamedTupleEntry)

        def initialize(@span : Span, @entries : Array(NamedTupleEntry))
        end
      end

      # RangeNode: Range literals
      # Examples: 1..10, 1...10
      # Size: ~48 bytes
      struct RangeNode
        getter span : Span
        getter begin_expr : ExprId
        getter end_expr : ExprId
        getter exclusive : Bool

        def initialize(@span : Span, @begin_expr : ExprId, @end_expr : ExprId, @exclusive : Bool)
        end
      end

      # Week 1 Batch 2: Operators Group (completing with BinaryNode from Phase B)

      struct UnaryNode
        getter span : Span
        getter operator : Slice(UInt8)  # -, !, ~, +, etc.
        getter operand : ExprId

        def initialize(@span : Span, @operator : Slice(UInt8), @operand : ExprId)
        end
      end

      struct TernaryNode
        getter span : Span
        getter condition : ExprId
        getter true_branch : ExprId
        getter false_branch : ExprId

        def initialize(@span : Span, @condition : ExprId, @true_branch : ExprId, @false_branch : ExprId)
        end
      end

      # Week 1 Batch 3: Variables Group (completing with IdentifierNode from Phase B)

      struct InstanceVarNode
        getter span : Span
        getter name : Slice(UInt8)  # @var

        def initialize(@span : Span, @name : Slice(UInt8))
        end
      end

      struct ClassVarNode
        getter span : Span
        getter name : Slice(UInt8)  # @@var

        def initialize(@span : Span, @name : Slice(UInt8))
        end
      end

      struct GlobalNode
        getter span : Span
        getter name : Slice(UInt8)  # $var

        def initialize(@span : Span, @name : Slice(UInt8))
        end
      end

      struct SelfNode
        getter span : Span

        def initialize(@span : Span)
        end
      end

      # Week 1 Batch 4: Control Flow Group (completing with IfNode from Phase B)

      struct UnlessNode
        getter span : Span
        getter condition : ExprId
        getter then_branch : Array(ExprId)
        getter else_branch : Array(ExprId)?

        def initialize(@span : Span, @condition : ExprId, @then_branch : Array(ExprId), @else_branch : Array(ExprId)? = nil)
        end
      end

      struct WhileNode
        getter span : Span
        getter condition : ExprId
        getter body : Array(ExprId)

        def initialize(@span : Span, @condition : ExprId, @body : Array(ExprId))
        end
      end

      struct UntilNode
        getter span : Span
        getter condition : ExprId
        getter body : Array(ExprId)

        def initialize(@span : Span, @condition : ExprId, @body : Array(ExprId))
        end
      end

      struct ForNode
        getter span : Span
        getter variable : Slice(UInt8)
        getter collection : ExprId
        getter body : Array(ExprId)

        def initialize(@span : Span, @variable : Slice(UInt8), @collection : ExprId, @body : Array(ExprId))
        end
      end

      struct LoopNode
        getter span : Span
        getter body : Array(ExprId)

        def initialize(@span : Span, @body : Array(ExprId))
        end
      end

      struct CaseNode
        getter span : Span
        getter value : ExprId?
        getter when_branches : Array(WhenBranch)
        getter else_branch : Array(ExprId)?

        def initialize(@span : Span, @value : ExprId?, @when_branches : Array(WhenBranch), @else_branch : Array(ExprId)? = nil)
        end
      end

      struct BreakNode
        getter span : Span
        getter value : ExprId?

        def initialize(@span : Span, @value : ExprId? = nil)
        end
      end

      struct NextNode
        getter span : Span

        def initialize(@span : Span)
        end
      end

      struct ReturnNode
        getter span : Span
        getter value : ExprId?

        def initialize(@span : Span, @value : ExprId? = nil)
        end
      end

      struct YieldNode
        getter span : Span
        getter args : Array(ExprId)?

        def initialize(@span : Span, @args : Array(ExprId)? = nil)
        end
      end

      struct SpawnNode
        getter span : Span
        getter expression : ExprId?
        getter body : Array(ExprId)?

        def initialize(@span : Span, @expression : ExprId? = nil, @body : Array(ExprId)? = nil)
        end
      end

      # Week 1 Batch 5: Calls Group (completing with CallNode from Phase B)

      struct IndexNode
        getter span : Span
        getter object : ExprId
        getter index : ExprId

        def initialize(@span : Span, @object : ExprId, @index : ExprId)
        end
      end

      struct MemberAccessNode
        getter span : Span
        getter object : ExprId
        getter member : Slice(UInt8)

        def initialize(@span : Span, @object : ExprId, @member : Slice(UInt8))
        end
      end

      struct SafeNavigationNode
        getter span : Span
        getter object : ExprId
        getter member : Slice(UInt8)

        def initialize(@span : Span, @object : ExprId, @member : Slice(UInt8))
        end
      end

      # Week 1 Batch 6: Assignment Group

      struct AssignNode
        getter span : Span
        getter target : ExprId
        getter value : ExprId

        def initialize(@span : Span, @target : ExprId, @value : ExprId)
        end
      end

      struct MultipleAssignNode
        getter span : Span
        getter targets : Array(ExprId)
        getter value : ExprId

        def initialize(@span : Span, @targets : Array(ExprId), @value : ExprId)
        end
      end

      # Week 1 Batch 7: Block/Proc and String Interpolation

      struct BlockNode
        getter span : Span
        getter params : Array(Parameter)?
        getter body : Array(ExprId)

        def initialize(@span : Span, @params : Array(Parameter)?, @body : Array(ExprId))
        end
      end

      struct ProcLiteralNode
        getter span : Span
        getter params : Array(Parameter)?
        getter return_type : Slice(UInt8)?
        getter body : Array(ExprId)

        def initialize(@span : Span, @params : Array(Parameter)?, @return_type : Slice(UInt8)?, @body : Array(ExprId))
        end
      end

      struct StringInterpolationNode
        getter span : Span
        getter pieces : Array(StringPiece)

        def initialize(@span : Span, @pieces : Array(StringPiece))
        end
      end

      struct GroupingNode
        getter span : Span
        getter expression : ExprId

        def initialize(@span : Span, @expression : ExprId)
        end
      end

      # Week 1 Batch 8: Definition Nodes

      struct DefNode
        getter span : Span
        getter name : Slice(UInt8)
        getter params : Array(Parameter)?
        getter return_type : Slice(UInt8)?
        getter body : Array(ExprId)?
        getter is_abstract : Bool?
        getter visibility : Visibility?

        def initialize(@span : Span, @name : Slice(UInt8), @params : Array(Parameter)?,
                       @return_type : Slice(UInt8)?, @body : Array(ExprId)?,
                       @is_abstract : Bool? = nil, @visibility : Visibility? = nil)
        end
      end

      struct ClassNode
        getter span : Span
        getter name : Slice(UInt8)
        getter super_name : Slice(UInt8)?
        getter body : Array(ExprId)?
        getter is_abstract : Bool?

        def initialize(@span : Span, @name : Slice(UInt8), @super_name : Slice(UInt8)?,
                       @body : Array(ExprId)?, @is_abstract : Bool? = nil)
        end
      end

      struct ModuleNode
        getter span : Span
        getter name : Slice(UInt8)
        getter body : Array(ExprId)?

        def initialize(@span : Span, @name : Slice(UInt8), @body : Array(ExprId)?)
        end
      end

      struct StructNode
        getter span : Span
        getter name : Slice(UInt8)
        getter body : Array(ExprId)?

        def initialize(@span : Span, @name : Slice(UInt8), @body : Array(ExprId)?)
        end
      end

      struct UnionNode
        getter span : Span
        getter name : Slice(UInt8)
        getter body : Array(ExprId)?

        def initialize(@span : Span, @name : Slice(UInt8), @body : Array(ExprId)?)
        end
      end

      struct EnumNode
        getter span : Span
        getter name : Slice(UInt8)
        getter base_type : Slice(UInt8)?
        getter members : Array(EnumMember)

        def initialize(@span : Span, @name : Slice(UInt8), @base_type : Slice(UInt8)?, @members : Array(EnumMember))
        end
      end

      struct AliasNode
        getter span : Span
        getter name : Slice(UInt8)
        getter value : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8), @value : Slice(UInt8))
        end
      end

      struct ConstantNode
        getter span : Span
        getter name : Slice(UInt8)
        getter value : ExprId

        def initialize(@span : Span, @name : Slice(UInt8), @value : ExprId)
        end
      end

      struct IncludeNode
        getter span : Span
        getter name : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8))
        end
      end

      struct ExtendNode
        getter span : Span
        getter name : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8))
        end
      end

      struct GetterNode
        getter span : Span
        getter specs : Array(AccessorSpec)

        def initialize(@span : Span, @specs : Array(AccessorSpec))
        end
      end

      struct SetterNode
        getter span : Span
        getter specs : Array(AccessorSpec)

        def initialize(@span : Span, @specs : Array(AccessorSpec))
        end
      end

      struct PropertyNode
        getter span : Span
        getter specs : Array(AccessorSpec)

        def initialize(@span : Span, @specs : Array(AccessorSpec))
        end
      end

      struct AnnotationNode
        getter span : Span
        getter name : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8))
        end
      end

      # Week 1 Batch 9: Special Operators

      struct AsNode
        getter span : Span
        getter expression : ExprId
        getter target_type : Slice(UInt8)

        def initialize(@span : Span, @expression : ExprId, @target_type : Slice(UInt8))
        end
      end

      struct AsQuestionNode
        getter span : Span
        getter expression : ExprId
        getter target_type : Slice(UInt8)

        def initialize(@span : Span, @expression : ExprId, @target_type : Slice(UInt8))
        end
      end

      struct IsANode
        getter span : Span
        getter expression : ExprId
        getter target_type : Slice(UInt8)

        def initialize(@span : Span, @expression : ExprId, @target_type : Slice(UInt8))
        end
      end

      struct RespondsToNode
        getter span : Span
        getter expression : ExprId
        getter method_name : Slice(UInt8)

        def initialize(@span : Span, @expression : ExprId, @method_name : Slice(UInt8))
        end
      end

      struct TypeofNode
        getter span : Span
        getter args : Array(ExprId)

        def initialize(@span : Span, @args : Array(ExprId))
        end
      end

      struct SizeofNode
        getter span : Span
        getter args : Array(ExprId)

        def initialize(@span : Span, @args : Array(ExprId))
        end
      end

      struct PointerofNode
        getter span : Span
        getter args : Array(ExprId)

        def initialize(@span : Span, @args : Array(ExprId))
        end
      end

      struct UninitializedNode
        getter span : Span
        getter type : ExprId

        def initialize(@span : Span, @type : ExprId)
        end
      end

      struct OffsetofNode
        getter span : Span
        getter args : Array(ExprId)

        def initialize(@span : Span, @args : Array(ExprId))
        end
      end

      struct AlignofNode
        getter span : Span
        getter args : Array(ExprId)

        def initialize(@span : Span, @args : Array(ExprId))
        end
      end

      struct InstanceAlignofNode
        getter span : Span
        getter args : Array(ExprId)

        def initialize(@span : Span, @args : Array(ExprId))
        end
      end

      struct SuperNode
        getter span : Span
        getter args : Array(ExprId)?

        def initialize(@span : Span, @args : Array(ExprId)? = nil)
        end
      end

      struct PreviousDefNode
        getter span : Span
        getter args : Array(ExprId)?

        def initialize(@span : Span, @args : Array(ExprId)? = nil)
        end
      end

      struct OutNode
        getter span : Span
        getter identifier : Slice(UInt8)

        def initialize(@span : Span, @identifier : Slice(UInt8))
        end
      end

      # Week 1 Batch 10: Advanced Nodes

      struct BeginNode
        getter span : Span
        getter body : Array(ExprId)
        getter rescue_clauses : Array(RescueClause)?
        getter ensure_body : Array(ExprId)?

        def initialize(@span : Span, @body : Array(ExprId), @rescue_clauses : Array(RescueClause)? = nil, @ensure_body : Array(ExprId)? = nil)
        end
      end

      struct RaiseNode
        getter span : Span
        getter value : ExprId?

        def initialize(@span : Span, @value : ExprId? = nil)
        end
      end

      struct RequireNode
        getter span : Span
        getter path : ExprId

        def initialize(@span : Span, @path : ExprId)
        end
      end

      struct TypeDeclarationNode
        getter span : Span
        getter name : Slice(UInt8)
        getter type : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8), @type : Slice(UInt8))
        end
      end

      struct InstanceVarDeclNode
        getter span : Span
        getter name : Slice(UInt8)
        getter type : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8), @type : Slice(UInt8))
        end
      end

      struct ClassVarDeclNode
        getter span : Span
        getter name : Slice(UInt8)
        getter type : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8), @type : Slice(UInt8))
        end
      end

      struct GlobalVarDeclNode
        getter span : Span
        getter name : Slice(UInt8)
        getter type : Slice(UInt8)

        def initialize(@span : Span, @name : Slice(UInt8), @type : Slice(UInt8))
        end
      end

      struct WithNode
        getter span : Span
        getter receiver : ExprId
        getter body : Array(ExprId)

        def initialize(@span : Span, @receiver : ExprId, @body : Array(ExprId))
        end
      end

      struct LibNode
        getter span : Span
        getter name : Slice(UInt8)
        getter body : Array(ExprId)?

        def initialize(@span : Span, @name : Slice(UInt8), @body : Array(ExprId)?)
        end
      end

      struct FunNode
        getter span : Span
        getter name : Slice(UInt8)
        getter params : Array(Parameter)?
        getter return_type : Slice(UInt8)?

        def initialize(@span : Span, @name : Slice(UInt8), @params : Array(Parameter)?, @return_type : Slice(UInt8)?)
        end
      end

      struct GenericNode
        getter span : Span
        getter base_type : ExprId
        getter type_args : Array(ExprId)

        def initialize(@span : Span, @base_type : ExprId, @type_args : Array(ExprId))
        end
      end

      struct PathNode
        getter span : Span
        getter segments : Array(Slice(UInt8))

        def initialize(@span : Span, @segments : Array(Slice(UInt8)))
        end
      end

      struct MacroExpressionNode
        getter span : Span
        getter expression : ExprId

        def initialize(@span : Span, @expression : ExprId)
        end
      end

      struct MacroLiteralNode
        getter span : Span
        getter value : Slice(UInt8)

        def initialize(@span : Span, @value : Slice(UInt8))
        end
      end

      struct MacroDefNode
        getter span : Span
        getter name : Slice(UInt8)
        getter pieces : Array(MacroPiece)

        def initialize(@span : Span, @name : Slice(UInt8), @pieces : Array(MacroPiece))
        end
      end

      struct SelectNode
        getter span : Span
        getter branches : Array(SelectBranch)
        getter else_branch : Array(ExprId)?

        def initialize(@span : Span, @branches : Array(SelectBranch), @else_branch : Array(ExprId)? = nil)
        end
      end

      struct AsmNode
        getter span : Span
        getter args : Array(ExprId)

        def initialize(@span : Span, @args : Array(ExprId))
        end
      end

      # ============================================================================

      # TypedNode: Discriminated union of typed node types
      # Crystal adds a tag (4-8 bytes) to identify which type is stored.
      # Total size = tag + max(all structs) = 8 + 88 = 96 bytes worst case
      # Still 10x better than 1024-byte ExpressionNode!
      alias TypedNode = NumberNode | IdentifierNode | BinaryNode | CallNode | IfNode |
                        StringNode | CharNode | RegexNode | BoolNode | NilNode | SymbolNode |
                        ArrayLiteralNode | HashLiteralNode | TupleLiteralNode | NamedTupleLiteralNode | RangeNode |
                        UnaryNode | TernaryNode |
                        InstanceVarNode | ClassVarNode | GlobalNode | SelfNode |
                        UnlessNode | WhileNode | UntilNode | ForNode | LoopNode | CaseNode |
                        BreakNode | NextNode | ReturnNode | YieldNode | SpawnNode |
                        IndexNode | MemberAccessNode | SafeNavigationNode |
                        AssignNode | MultipleAssignNode |
                        BlockNode | ProcLiteralNode | StringInterpolationNode | GroupingNode |
                        DefNode | ClassNode | ModuleNode | StructNode | UnionNode | EnumNode |
                        AliasNode | ConstantNode | IncludeNode | ExtendNode |
                        GetterNode | SetterNode | PropertyNode | AnnotationNode |
                        AsNode | AsQuestionNode | IsANode | RespondsToNode |
                        TypeofNode | SizeofNode | PointerofNode | UninitializedNode |
                        OffsetofNode | AlignofNode | InstanceAlignofNode |
                        SuperNode | PreviousDefNode | OutNode |
                        BeginNode | RaiseNode | RequireNode | TypeDeclarationNode |
                        InstanceVarDeclNode | ClassVarDeclNode | GlobalVarDeclNode |
                        WithNode | LibNode | FunNode | GenericNode | PathNode |
                        MacroExpressionNode | MacroLiteralNode | MacroDefNode |
                        SelectNode | AsmNode

      # ============================================================================
      # Helper: Get Kind for any node type (ExpressionNode or TypedNode)
      # This allows gradual migration from .kind checks to pattern matching
      # ============================================================================

      def self.node_kind(node : ExpressionNode) : ExpressionNode::Kind
        node.kind
      end

      def self.node_kind(node : NumberNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Number
      end

      def self.node_kind(node : IdentifierNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Identifier
      end

      def self.node_kind(node : BinaryNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Binary
      end

      def self.node_kind(node : CallNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Call
      end

      def self.node_kind(node : IfNode) : ExpressionNode::Kind
        ExpressionNode::Kind::If
      end

      def self.node_kind(node : StringNode) : ExpressionNode::Kind
        ExpressionNode::Kind::String
      end

      def self.node_kind(node : CharNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Char
      end

      def self.node_kind(node : RegexNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Regex
      end

      def self.node_kind(node : BoolNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Bool
      end

      def self.node_kind(node : NilNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Nil
      end

      def self.node_kind(node : SymbolNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Symbol
      end

      def self.node_kind(node : ArrayLiteralNode) : ExpressionNode::Kind
        ExpressionNode::Kind::ArrayLiteral
      end

      def self.node_kind(node : HashLiteralNode) : ExpressionNode::Kind
        ExpressionNode::Kind::HashLiteral
      end

      def self.node_kind(node : TupleLiteralNode) : ExpressionNode::Kind
        ExpressionNode::Kind::TupleLiteral
      end

      def self.node_kind(node : NamedTupleLiteralNode) : ExpressionNode::Kind
        ExpressionNode::Kind::NamedTupleLiteral
      end

      def self.node_kind(node : RangeNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Range
      end

      def self.node_kind(node : UnaryNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Unary
      end

      def self.node_kind(node : TernaryNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Ternary
      end

      def self.node_kind(node : InstanceVarNode) : ExpressionNode::Kind
        ExpressionNode::Kind::InstanceVar
      end

      def self.node_kind(node : ClassVarNode) : ExpressionNode::Kind
        ExpressionNode::Kind::ClassVar
      end

      def self.node_kind(node : GlobalNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Global
      end

      def self.node_kind(node : SelfNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Self
      end

      def self.node_kind(node : UnlessNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Unless
      end

      def self.node_kind(node : WhileNode) : ExpressionNode::Kind
        ExpressionNode::Kind::While
      end

      def self.node_kind(node : UntilNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Until
      end

      def self.node_kind(node : ForNode) : ExpressionNode::Kind
        ExpressionNode::Kind::For
      end

      def self.node_kind(node : LoopNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Loop
      end

      def self.node_kind(node : CaseNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Case
      end

      def self.node_kind(node : BreakNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Break
      end

      def self.node_kind(node : NextNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Next
      end

      def self.node_kind(node : ReturnNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Return
      end

      def self.node_kind(node : YieldNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Yield
      end

      def self.node_kind(node : SpawnNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Spawn
      end

      def self.node_kind(node : IndexNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Index
      end

      def self.node_kind(node : MemberAccessNode) : ExpressionNode::Kind
        ExpressionNode::Kind::MemberAccess
      end

      def self.node_kind(node : SafeNavigationNode) : ExpressionNode::Kind
        ExpressionNode::Kind::SafeNavigation
      end

      def self.node_kind(node : AssignNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Assign
      end

      def self.node_kind(node : MultipleAssignNode) : ExpressionNode::Kind
        ExpressionNode::Kind::MultipleAssign
      end

      def self.node_kind(node : BlockNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Block
      end

      def self.node_kind(node : ProcLiteralNode) : ExpressionNode::Kind
        ExpressionNode::Kind::ProcLiteral
      end

      def self.node_kind(node : StringInterpolationNode) : ExpressionNode::Kind
        ExpressionNode::Kind::StringInterpolation
      end

      def self.node_kind(node : GroupingNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Grouping
      end

      def self.node_kind(node : DefNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Def
      end

      def self.node_kind(node : ClassNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Class
      end

      def self.node_kind(node : ModuleNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Module
      end

      def self.node_kind(node : StructNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Struct
      end

      def self.node_kind(node : UnionNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Union
      end

      def self.node_kind(node : EnumNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Enum
      end

      def self.node_kind(node : AliasNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Alias
      end

      def self.node_kind(node : ConstantNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Constant
      end

      def self.node_kind(node : IncludeNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Include
      end

      def self.node_kind(node : ExtendNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Extend
      end

      def self.node_kind(node : GetterNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Getter
      end

      def self.node_kind(node : SetterNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Setter
      end

      def self.node_kind(node : PropertyNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Property
      end

      def self.node_kind(node : AnnotationNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Annotation
      end

      def self.node_kind(node : AsNode) : ExpressionNode::Kind
        ExpressionNode::Kind::As
      end

      def self.node_kind(node : AsQuestionNode) : ExpressionNode::Kind
        ExpressionNode::Kind::AsQuestion
      end

      def self.node_kind(node : IsANode) : ExpressionNode::Kind
        ExpressionNode::Kind::IsA
      end

      def self.node_kind(node : RespondsToNode) : ExpressionNode::Kind
        ExpressionNode::Kind::RespondsTo
      end

      def self.node_kind(node : TypeofNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Typeof
      end

      def self.node_kind(node : SizeofNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Sizeof
      end

      def self.node_kind(node : PointerofNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Pointerof
      end

      def self.node_kind(node : UninitializedNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Uninitialized
      end

      def self.node_kind(node : OffsetofNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Offsetof
      end

      def self.node_kind(node : AlignofNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Alignof
      end

      def self.node_kind(node : InstanceAlignofNode) : ExpressionNode::Kind
        ExpressionNode::Kind::InstanceAlignof
      end

      def self.node_kind(node : SuperNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Super
      end

      def self.node_kind(node : PreviousDefNode) : ExpressionNode::Kind
        ExpressionNode::Kind::PreviousDef
      end

      def self.node_kind(node : OutNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Out
      end

      def self.node_kind(node : BeginNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Begin
      end

      def self.node_kind(node : RaiseNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Raise
      end

      def self.node_kind(node : RequireNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Require
      end

      def self.node_kind(node : TypeDeclarationNode) : ExpressionNode::Kind
        ExpressionNode::Kind::TypeDeclaration
      end

      def self.node_kind(node : InstanceVarDeclNode) : ExpressionNode::Kind
        ExpressionNode::Kind::InstanceVarDecl
      end

      def self.node_kind(node : ClassVarDeclNode) : ExpressionNode::Kind
        ExpressionNode::Kind::ClassVarDecl
      end

      def self.node_kind(node : GlobalVarDeclNode) : ExpressionNode::Kind
        ExpressionNode::Kind::GlobalVarDecl
      end

      def self.node_kind(node : WithNode) : ExpressionNode::Kind
        ExpressionNode::Kind::With
      end

      def self.node_kind(node : LibNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Lib
      end

      def self.node_kind(node : FunNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Fun
      end

      def self.node_kind(node : GenericNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Generic
      end

      def self.node_kind(node : PathNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Path
      end

      def self.node_kind(node : MacroExpressionNode) : ExpressionNode::Kind
        ExpressionNode::Kind::MacroExpression
      end

      def self.node_kind(node : MacroLiteralNode) : ExpressionNode::Kind
        ExpressionNode::Kind::MacroLiteral
      end

      def self.node_kind(node : MacroDefNode) : ExpressionNode::Kind
        ExpressionNode::Kind::MacroDef
      end

      def self.node_kind(node : SelectNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Select
      end

      def self.node_kind(node : AsmNode) : ExpressionNode::Kind
        ExpressionNode::Kind::Asm
      end

      # ============================================================================
      # Helper: Get literal/name for nodes that have string data
      # ============================================================================

      def self.node_literal(node : ExpressionNode) : Slice(UInt8)?
        node.literal
      end

      def self.node_literal(node : IdentifierNode) : Slice(UInt8)?
        node.name
      end

      def self.node_literal(node : InstanceVarNode) : Slice(UInt8)?
        node.name
      end

      def self.node_literal(node : ClassVarNode) : Slice(UInt8)?
        node.name
      end

      def self.node_literal(node : GlobalNode) : Slice(UInt8)?
        node.name
      end

      def self.node_literal(node : CharNode) : Slice(UInt8)?
        node.value
      end

      def self.node_literal(node : StringNode) : Slice(UInt8)?
        node.value
      end

      def self.node_literal(node : SymbolNode) : Slice(UInt8)?
        node.name
      end

      def self.node_literal(node : NumberNode) : Slice(UInt8)?
        node.value
      end

      # Helper: Get NumberNode kind (I32, F64, etc.)
      def self.node_number_kind(node : ExpressionNode) : NumberKind?
        nil
      end

      def self.node_number_kind(node : NumberNode) : NumberKind?
        node.kind
      end

      def self.node_number_kind(node : TypedNode) : NumberKind?
        nil
      end

      def self.node_literal(node : RegexNode) : Slice(UInt8)?
        node.pattern
      end

      def self.node_literal(node : ConstantNode) : Slice(UInt8)?
        node.name
      end

      def self.node_literal(node : InstanceVarDeclNode) : Slice(UInt8)?
        node.name
      end

      # Default: return nil for nodes that don't have literal data
      def self.node_literal(node : TypedNode) : Slice(UInt8)?
        nil
      end

      # Helper: Get literal as String (convenience method)
      def self.node_literal_string(node : ExpressionNode | TypedNode) : String?
        # Special case: BoolNode stores Bool value, not Slice(UInt8)
        if node.is_a?(BoolNode)
          return node.value ? "true" : "false"
        end

        node_literal(node).try { |slice| String.new(slice) }
      end

      # ============================================================================
      # Field access helpers for typed nodes (polymorphic dispatch)
      # ============================================================================

      # assign_value: Get value from assignment
      def self.node_assign_value(node : ExpressionNode) : ExprId?
        node.assign_value
      end

      def self.node_assign_value(node : AssignNode) : ExprId
        node.value
      end

      def self.node_assign_value(node : TypedNode) : ExprId?
        nil  # Other typed nodes don't have assign_value
      end

      # assign_target: Get target from assignment
      def self.node_assign_target(node : ExpressionNode) : ExprId?
        node.assign_target
      end

      def self.node_assign_target(node : AssignNode) : ExprId
        node.target
      end

      def self.node_assign_target(node : TypedNode) : ExprId?
        nil
      end

      # left: Get left operand (binary operations)
      def self.node_left(node : ExpressionNode) : ExprId?
        node.left
      end

      def self.node_left(node : BinaryNode) : ExprId
        node.left
      end

      def self.node_left(node : TypedNode) : ExprId?
        nil
      end

      # right: Get right operand (binary operations)
      def self.node_right(node : ExpressionNode) : ExprId?
        node.right
      end

      def self.node_right(node : BinaryNode) : ExprId
        node.right
      end

      def self.node_right(node : UnaryNode) : ExprId
        node.operand  # UnaryNode uses 'operand' instead of 'right'
      end

      def self.node_right(node : TypedNode) : ExprId?
        nil
      end

      # macro_expr: Get macro expression (MacroExpressionNode.expression vs ExpressionNode.macro_expr)
      def self.node_macro_expr(node : ExpressionNode) : ExprId?
        node.macro_expr
      end

      def self.node_macro_expr(node : MacroExpressionNode) : ExprId?
        node.expression  # Different field name!
      end

      def self.node_macro_expr(node : TypedNode) : ExprId?
        nil
      end

      # condition: Get condition (if/while/until/etc)
      def self.node_condition(node : ExpressionNode) : ExprId?
        node.if_condition || node.while_condition
      end

      def self.node_condition(node : IfNode) : ExprId
        node.condition
      end

      def self.node_condition(node : WhileNode) : ExprId
        node.condition
      end

      def self.node_condition(node : UntilNode) : ExprId
        node.condition
      end

      def self.node_condition(node : UnlessNode) : ExprId
        node.condition
      end

      def self.node_condition(node : TernaryNode) : ExprId
        node.condition
      end

      def self.node_condition(node : TypedNode) : ExprId?
        nil
      end

      # return_value: Get return value
      def self.node_return_value(node : ExpressionNode) : ExprId?
        node.return_value
      end

      def self.node_return_value(node : ReturnNode) : ExprId?
        node.value
      end

      def self.node_return_value(node : TypedNode) : ExprId?
        nil
      end

      # if_elsifs: Get elsif branches
      def self.node_if_elsifs(node : ExpressionNode) : Array(ElsifBranch)?
        node.if_elsifs
      end

      def self.node_if_elsifs(node : IfNode) : Array(ElsifBranch)?
        node.elsifs
      end

      def self.node_if_elsifs(node : TypedNode) : Array(ElsifBranch)?
        nil
      end

      # operator_string: Get operator as string (convenience method)
      def self.node_operator_string(node : ExpressionNode) : String?
        node.operator.try { |slice| String.new(slice) }
      end

      def self.node_operator_string(node : BinaryNode) : String?
        String.new(node.operator)
      end

      def self.node_operator_string(node : UnaryNode) : String?
        String.new(node.operator)
      end

      def self.node_operator_string(node : TypedNode) : String?
        nil
      end

      # string_pieces: Get string interpolation pieces
      def self.node_string_pieces(node : ExpressionNode) : Array(StringPiece)?
        node.string_pieces
      end

      def self.node_string_pieces(node : TypedNode) : Array(StringPiece)?
        nil
      end


      # asm_args: Get asm args
      def self.node_asm_args(node : ExpressionNode)
        node.asm_args
      end

      def self.node_asm_args(node : TypedNode)
        nil
      end

      # assign_targets: Get assign targets
      def self.node_assign_targets(node : ExpressionNode)
        node.assign_targets
      end

      def self.node_assign_targets(node : TypedNode)
        nil
      end

      # break_value: Get break value
      def self.node_break_value(node : ExpressionNode)
        node.break_value
      end

      def self.node_break_value(node : BreakNode)
        node.value
      end

      def self.node_hash_entries(node : HashLiteralNode)
        node.entries
      end

      def self.node_hash_of_key_type(node : HashLiteralNode)
        node.of_key_type
      end

      def self.node_hash_of_value_type(node : HashLiteralNode)
        node.of_value_type
      end

      def self.node_break_value(node : TypedNode)
        nil
      end

      # call_block: Get call block
      def self.node_call_block(node : ExpressionNode)
        node.call_block
      end

      def self.node_call_block(node : TypedNode)
        nil
      end

      # case_else: Get case else
      def self.node_case_else(node : ExpressionNode)
        node.case_else
      end

      def self.node_case_else(node : TypedNode)
        nil
      end

      # case_value: Get case value
      def self.node_case_value(node : ExpressionNode)
        node.case_value
      end

      def self.node_case_value(node : TypedNode)
        nil
      end

      # for_body: Get for body
      def self.node_for_body(node : ExpressionNode)
        node.for_body
      end

      def self.node_for_body(node : TypedNode)
        nil
      end

      # for_collection: Get for collection
      def self.node_for_collection(node : ExpressionNode)
        node.for_collection
      end

      def self.node_for_collection(node : TypedNode)
        nil
      end

      # hash_entries: Get hash entries
      def self.node_hash_entries(node : ExpressionNode)
        node.hash_entries
      end

      def self.node_hash_entries(node : TypedNode)
        nil
      end

      # hash_of_key_type: Get hash of key type
      def self.node_hash_of_key_type(node : ExpressionNode)
        node.hash_of_key_type
      end

      def self.node_hash_of_key_type(node : TypedNode)
        nil
      end

      # hash_of_value_type: Get hash of value type
      def self.node_hash_of_value_type(node : ExpressionNode)
        node.hash_of_value_type
      end

      def self.node_hash_of_value_type(node : TypedNode)
        nil
      end

      # member_string: Get member string
      def self.node_member_string(node : ExpressionNode)
        node.member_string
      end

      def self.node_member_string(node : TypedNode)
        nil
      end

      # named_args: Get named args
      def self.node_named_args(node : ExpressionNode)
        node.named_args
      end

      def self.node_named_args(node : TypedNode)
        nil
      end

      # when_branches: Get when branches
      def self.node_when_branches(node : ExpressionNode)
        node.when_branches
      end

      def self.node_when_branches(node : TypedNode)
        nil
      end

      # yield_args: Get yield args
      def self.node_yield_args(node : ExpressionNode)
        node.yield_args
      end

      def self.node_yield_args(node : TypedNode)
        nil
      end

      # as_question_target_type: Get target type for safe cast
      def self.node_as_question_target_type(node : ExpressionNode) : Slice(UInt8)?
        node.as_question_target_type
      end

      def self.node_as_question_target_type(node : AsQuestionNode) : Slice(UInt8)?
        node.target_type
      end

      def self.node_as_question_target_type(node : TypedNode) : Slice(UInt8)?
        nil
      end

      # case_whens: Get when branches (note: different name!)
      def self.node_case_whens(node : ExpressionNode)
        node.case_whens
      end

      def self.node_case_whens(node : CaseNode)
        node.when_branches
      end

      def self.node_case_whens(node : TypedNode)
        nil
      end

      # array_elements: Get array elements
      def self.node_array_elements(node : ExpressionNode)
        node.array_elements
      end

      def self.node_array_elements(node : ArrayLiteralNode)
        node.elements
      end

      def self.node_array_elements(node : TypedNode)
        nil
      end

      # tuple_elements: Get tuple elements
      def self.node_tuple_elements(node : ExpressionNode)
        node.tuple_elements
      end

      def self.node_tuple_elements(node : TupleLiteralNode)
        node.elements
      end

      def self.node_tuple_elements(node : TypedNode)
        nil
      end

      # operand: Get operand for unary operations
      def self.node_operand(node : ExpressionNode) : ExprId?
        node.operand
      end

      def self.node_operand(node : UnaryNode) : ExprId
        node.operand
      end

      def self.node_operand(node : TypedNode) : ExprId?
        nil
      end

# Generated helpers for fields actually used in tests
# ============================================================================

# accessor_specs
def self.node_accessor_specs(node : ExpressionNode)
  node.accessor_specs
end

def self.node_accessor_specs(node : GetterNode)
  node.specs
end

def self.node_accessor_specs(node : SetterNode)
  node.specs
end

def self.node_accessor_specs(node : PropertyNode)
  node.specs
end

def self.node_accessor_specs(node : TypedNode)
  nil
end

# alias_name
def self.node_alias_name(node : ExpressionNode)
  node.alias_name
end

def self.node_alias_name(node : AliasNode)
  node.name
end

def self.node_alias_name(node : TypedNode)
  nil
end

# alias_value
def self.node_alias_value(node : ExpressionNode)
  node.alias_value
end

def self.node_alias_value(node : AliasNode)
  node.value
end

def self.node_alias_value(node : TypedNode)
  nil
end

# alignof_args
def self.node_alignof_args(node : ExpressionNode)
  node.alignof_args
end

def self.node_alignof_args(node : AlignofNode)
  node.args
end

def self.node_alignof_args(node : TypedNode)
  nil
end

# annotation_name
def self.node_annotation_name(node : ExpressionNode)
  node.annotation_name
end

def self.node_annotation_name(node : AnnotationNode)
  node.name
end

def self.node_annotation_name(node : TypedNode)
  nil
end

# as_question_value
def self.node_as_question_value(node : ExpressionNode)
  node.as_question_value
end

def self.node_as_question_value(node : AsQuestionNode)
  node.expression
end

def self.node_as_question_value(node : TypedNode)
  nil
end

# as_target_type
def self.node_as_target_type(node : ExpressionNode)
  node.as_target_type
end

def self.node_as_target_type(node : AsNode)
  node.target_type
end

def self.node_as_target_type(node : TypedNode)
  nil
end

# as_value
def self.node_as_value(node : ExpressionNode)
  node.as_value
end

def self.node_as_value(node : AsNode)
  node.expression
end

def self.node_as_value(node : TypedNode)
  nil
end

# begin_body
def self.node_begin_body(node : ExpressionNode)
  node.begin_body
end

def self.node_begin_body(node : BeginNode)
  node.body
end

def self.node_begin_body(node : TypedNode)
  nil
end

# block_body
def self.node_block_body(node : ExpressionNode)
  node.block_body
end

def self.node_block_body(node : BlockNode)
  node.body
end

def self.node_block_body(node : TypedNode)
  nil
end

# block_params
def self.node_block_params(node : ExpressionNode)
  node.block_params
end

def self.node_block_params(node : BlockNode)
  node.params
end

def self.node_block_params(node : ProcLiteralNode)
  node.params
end

def self.node_block_params(node : TypedNode)
  nil
end

# class_body
def self.node_class_body(node : ExpressionNode)
  node.class_body
end

def self.node_class_body(node : ClassNode)
  node.body
end

def self.node_class_body(node : StructNode)
  node.body
end

def self.node_class_body(node : UnionNode)
  node.body
end

def self.node_class_body(node : TypedNode)
  nil
end

# class_is_abstract
def self.node_class_is_abstract(node : ExpressionNode)
  node.class_is_abstract
end

def self.node_class_is_abstract(node : ClassNode)
  node.is_abstract
end

def self.node_class_is_abstract(node : TypedNode)
  nil
end

# class_name
def self.node_class_name(node : ExpressionNode)
  node.class_name
end

def self.node_class_name(node : ClassNode)
  node.name
end

def self.node_class_name(node : StructNode)
  node.name
end

def self.node_class_name(node : UnionNode)
  node.name
end

def self.node_class_name(node : TypedNode)
  nil
end

# class_super_name
def self.node_class_super_name(node : ExpressionNode)
  node.class_super_name
end

def self.node_class_super_name(node : ClassNode)
  node.super_name
end

def self.node_class_super_name(node : TypedNode)
  nil
end

# constant_name
def self.node_constant_name(node : ExpressionNode)
  node.constant_name
end

def self.node_constant_name(node : ConstantNode)
  node.name
end

def self.node_constant_name(node : TypedNode)
  nil
end

# constant_value
def self.node_constant_value(node : ExpressionNode)
  node.constant_value
end

def self.node_constant_value(node : ConstantNode)
  node.value
end

def self.node_constant_value(node : TypedNode)
  nil
end

# def_body
def self.node_def_body(node : ExpressionNode)
  node.def_body
end

def self.node_def_body(node : DefNode)
  node.body
end

def self.node_def_body(node : TypedNode)
  nil
end

# def_is_abstract
def self.node_def_is_abstract(node : ExpressionNode)
  node.def_is_abstract
end

def self.node_def_is_abstract(node : DefNode)
  node.is_abstract
end

def self.node_def_is_abstract(node : TypedNode)
  nil
end

# def_name
def self.node_def_name(node : ExpressionNode)
  node.def_name
end

def self.node_def_name(node : DefNode)
  node.name
end

def self.node_def_name(node : TypedNode)
  nil
end

# def_params
def self.node_def_params(node : ExpressionNode)
  node.def_params
end

def self.node_def_params(node : DefNode)
  node.params
end

def self.node_def_params(node : TypedNode)
  nil
end

# def_return_type
def self.node_def_return_type(node : ExpressionNode)
  node.def_return_type
end

def self.node_def_return_type(node : DefNode)
  node.return_type
end

def self.node_def_return_type(node : TypedNode)
  nil
end

# def_visibility
def self.node_def_visibility(node : ExpressionNode)
  node.def_visibility
end

def self.node_def_visibility(node : DefNode)
  node.visibility
end

def self.node_def_visibility(node : TypedNode)
  nil
end

# ensure_body
def self.node_ensure_body(node : ExpressionNode)
  node.ensure_body
end

def self.node_ensure_body(node : BeginNode)
  node.ensure_body
end

def self.node_ensure_body(node : TypedNode)
  nil
end

# enum_base_type
def self.node_enum_base_type(node : ExpressionNode)
  node.enum_base_type
end

def self.node_enum_base_type(node : EnumNode)
  node.base_type
end

def self.node_enum_base_type(node : TypedNode)
  nil
end

# enum_members
def self.node_enum_members(node : ExpressionNode)
  node.enum_members
end

def self.node_enum_members(node : EnumNode)
  node.members
end

def self.node_enum_members(node : TypedNode)
  nil
end

# enum_name
def self.node_enum_name(node : ExpressionNode)
  node.enum_name
end

def self.node_enum_name(node : EnumNode)
  node.name
end

def self.node_enum_name(node : TypedNode)
  nil
end

# generic_name
def self.node_generic_name(node : ExpressionNode)
  node.generic_name
end

def self.node_generic_name(node : GenericNode)
  node.base_type
end

def self.node_generic_name(node : TypedNode)
  nil
end

# generic_type_args
def self.node_generic_type_args(node : ExpressionNode)
  node.generic_type_args
end

def self.node_generic_type_args(node : GenericNode)
  node.type_args
end

def self.node_generic_type_args(node : TypedNode)
  nil
end

# if_else
def self.node_if_else(node : ExpressionNode)
  node.if_else
end

def self.node_if_else(node : IfNode)
  node.else_body
end

def self.node_if_else(node : UnlessNode)
  node.else_branch
end

def self.node_if_else(node : TypedNode)
  nil
end

# if_then
def self.node_if_then(node : ExpressionNode)
  node.if_then
end

def self.node_if_then(node : IfNode)
  node.then_body
end

def self.node_if_then(node : UnlessNode)
  node.then_branch
end

def self.node_if_then(node : TypedNode)
  nil
end

# instance_alignof_args
def self.node_instance_alignof_args(node : ExpressionNode)
  node.instance_alignof_args
end

def self.node_instance_alignof_args(node : InstanceAlignofNode)
  node.args
end

def self.node_instance_alignof_args(node : TypedNode)
  nil
end

# is_a_target_type
def self.node_is_a_target_type(node : ExpressionNode)
  node.is_a_target_type
end

def self.node_is_a_target_type(node : IsANode)
  node.target_type
end

def self.node_is_a_target_type(node : TypedNode)
  nil
end

# is_a_value
def self.node_is_a_value(node : ExpressionNode)
  node.is_a_value
end

def self.node_is_a_value(node : IsANode)
  node.expression
end

def self.node_is_a_value(node : TypedNode)
  nil
end

# lib_body
def self.node_lib_body(node : ExpressionNode)
  node.lib_body
end

def self.node_lib_body(node : LibNode)
  node.body
end

def self.node_lib_body(node : TypedNode)
  nil
end

# lib_name
def self.node_lib_name(node : ExpressionNode)
  node.lib_name
end

def self.node_lib_name(node : LibNode)
  node.name
end

def self.node_lib_name(node : TypedNode)
  nil
end

# loop_body
def self.node_loop_body(node : ExpressionNode)
  node.loop_body
end

def self.node_loop_body(node : LoopNode)
  node.body
end

def self.node_loop_body(node : TypedNode)
  nil
end

# member
def self.node_member(node : ExpressionNode)
  node.member
end

def self.node_member(node : MemberAccessNode)
  node.member
end

def self.node_member(node : SafeNavigationNode)
  node.member
end

def self.node_member(node : TypedNode)
  nil
end

# module_body
def self.node_module_body(node : ExpressionNode)
  node.module_body
end

def self.node_module_body(node : ModuleNode)
  node.body
end

def self.node_module_body(node : TypedNode)
  nil
end

# module_name
def self.node_module_name(node : ExpressionNode)
  node.module_name
end

def self.node_module_name(node : ModuleNode)
  node.name
end

def self.node_module_name(node : TypedNode)
  nil
end

# named_tuple_entries
def self.node_named_tuple_entries(node : ExpressionNode)
  node.named_tuple_entries
end

def self.node_named_tuple_entries(node : NamedTupleLiteralNode)
  node.entries
end

def self.node_named_tuple_entries(node : TypedNode)
  nil
end

# offsetof_args
def self.node_offsetof_args(node : ExpressionNode)
  node.offsetof_args
end

def self.node_offsetof_args(node : OffsetofNode)
  node.args
end

def self.node_offsetof_args(node : TypedNode)
  nil
end

# out_identifier
def self.node_out_identifier(node : ExpressionNode)
  node.out_identifier
end

def self.node_out_identifier(node : OutNode)
  node.identifier
end

def self.node_out_identifier(node : TypedNode)
  nil
end

# pointerof_args
def self.node_pointerof_args(node : ExpressionNode)
  node.pointerof_args
end

def self.node_pointerof_args(node : PointerofNode)
  node.args
end

def self.node_pointerof_args(node : TypedNode)
  nil
end

# previous_def_args
def self.node_previous_def_args(node : ExpressionNode)
  node.previous_def_args
end

def self.node_previous_def_args(node : PreviousDefNode)
  node.args
end

def self.node_previous_def_args(node : TypedNode)
  nil
end

# proc_return_type
def self.node_proc_return_type(node : ExpressionNode)
  node.proc_return_type
end

def self.node_proc_return_type(node : ProcLiteralNode)
  node.return_type
end

def self.node_proc_return_type(node : TypedNode)
  nil
end

# raise_value
def self.node_raise_value(node : ExpressionNode)
  node.raise_value
end

def self.node_raise_value(node : RaiseNode)
  node.value
end

def self.node_raise_value(node : TypedNode)
  nil
end

# require_path
def self.node_require_path(node : ExpressionNode)
  node.require_path
end

def self.node_require_path(node : RequireNode)
  node.path
end

def self.node_require_path(node : TypedNode)
  nil
end

# rescue_clauses
def self.node_rescue_clauses(node : ExpressionNode)
  node.rescue_clauses
end

def self.node_rescue_clauses(node : BeginNode)
  node.rescue_clauses
end

def self.node_rescue_clauses(node : TypedNode)
  nil
end

# responds_to_method_name (RespondsTo uses ExpressionNode, not RespondsToNode typed struct)
def self.node_responds_to_method_name(node : ExpressionNode) : ExprId?
  node.responds_to_method_name
end

def self.node_responds_to_method_name(node : TypedNode) : ExprId?
  nil  # RespondsToNode exists but is unused by parser
end

# responds_to_value
def self.node_responds_to_value(node : ExpressionNode)
  node.responds_to_value
end

def self.node_responds_to_value(node : RespondsToNode)
  node.expression
end

def self.node_responds_to_value(node : TypedNode)
  nil
end

# select_branches
def self.node_select_branches(node : ExpressionNode)
  node.select_branches
end

def self.node_select_branches(node : SelectNode)
  node.branches
end

def self.node_select_branches(node : TypedNode)
  nil
end

# select_else
def self.node_select_else(node : ExpressionNode)
  node.select_else
end

def self.node_select_else(node : SelectNode)
  node.else_branch
end

def self.node_select_else(node : TypedNode)
  nil
end

# sizeof_args
def self.node_sizeof_args(node : ExpressionNode)
  node.sizeof_args
end

def self.node_sizeof_args(node : SizeofNode)
  node.args
end

def self.node_sizeof_args(node : TypedNode)
  nil
end

# spawn_body
def self.node_spawn_body(node : ExpressionNode)
  node.spawn_body
end

def self.node_spawn_body(node : SpawnNode)
  node.body
end

def self.node_spawn_body(node : TypedNode)
  nil
end

# spawn_expression
def self.node_spawn_expression(node : ExpressionNode)
  node.spawn_expression
end

def self.node_spawn_expression(node : SpawnNode)
  node.expression
end

def self.node_spawn_expression(node : TypedNode)
  nil
end

# super_args
def self.node_super_args(node : ExpressionNode)
  node.super_args
end

def self.node_super_args(node : SuperNode)
  node.args
end

def self.node_super_args(node : TypedNode)
  nil
end

# ternary_condition
def self.node_ternary_condition(node : ExpressionNode)
  node.ternary_condition
end

def self.node_ternary_condition(node : TernaryNode)
  node.condition
end

def self.node_ternary_condition(node : TypedNode)
  nil
end

# ternary_false_branch
def self.node_ternary_false_branch(node : ExpressionNode)
  node.ternary_false_branch
end

def self.node_ternary_false_branch(node : TernaryNode)
  node.false_branch
end

def self.node_ternary_false_branch(node : TypedNode)
  nil
end

# ternary_true_branch
def self.node_ternary_true_branch(node : ExpressionNode)
  node.ternary_true_branch
end

def self.node_ternary_true_branch(node : TernaryNode)
  node.true_branch
end

def self.node_ternary_true_branch(node : TypedNode)
  nil
end

# type_decl_name
def self.node_type_decl_name(node : ExpressionNode)
  node.type_decl_name
end

def self.node_type_decl_name(node : TypeDeclarationNode)
  node.name
end

def self.node_type_decl_name(node : TypedNode)
  nil
end

# type_decl_type
def self.node_type_decl_type(node : ExpressionNode)
  case node.kind
  when ExpressionNode::Kind::InstanceVarDecl
    node.ivar_decl_type
  else
    node.type_decl_type
  end
end

def self.node_type_decl_type(node : TypeDeclarationNode)
  node.type
end

def self.node_type_decl_type(node : InstanceVarDeclNode)
  node.type
end

def self.node_type_decl_type(node : TypedNode)
  nil
end

# typeof_args
def self.node_typeof_args(node : ExpressionNode)
  node.typeof_args
end

def self.node_typeof_args(node : TypeofNode)
  node.args
end

def self.node_typeof_args(node : TypedNode)
  nil
end

# uninitialized_type
def self.node_uninitialized_type(node : ExpressionNode)
  node.uninitialized_type
end

def self.node_uninitialized_type(node : UninitializedNode)
  node.type
end

def self.node_uninitialized_type(node : TypedNode)
  nil
end

# while_body
def self.node_while_body(node : ExpressionNode)
  node.while_body
end

def self.node_while_body(node : WhileNode)
  node.body
end

def self.node_while_body(node : TypedNode)
  nil
end

# with_body
def self.node_with_body(node : ExpressionNode)
  node.with_body
end

def self.node_with_body(node : WithNode)
  node.body
end

def self.node_with_body(node : TypedNode)
  nil
end

# with_receiver
def self.node_with_receiver(node : ExpressionNode)
  node.with_receiver
end

def self.node_with_receiver(node : WithNode)
  node.receiver
end

def self.node_with_receiver(node : TypedNode)
  nil
end

# ============================================================================
# PHASE C WEEK 3: Added 8 missing helpers for failing parser tests
# ============================================================================

# range_begin (RangeNode.begin_expr vs ExpressionNode.range_begin)
def self.node_range_begin(node : ExpressionNode) : ExprId?
  node.range_begin
end

def self.node_range_begin(node : RangeNode) : ExprId?
  node.begin_expr  # Different field name!
end

def self.node_range_begin(node : TypedNode) : ExprId?
  nil
end

# range_end (RangeNode.end_expr vs ExpressionNode.range_end)
def self.node_range_end(node : ExpressionNode) : ExprId?
  node.range_end
end

def self.node_range_end(node : RangeNode) : ExprId?
  node.end_expr  # Different field name!
end

def self.node_range_end(node : TypedNode) : ExprId?
  nil
end

# range_exclusive (RangeNode.exclusive vs ExpressionNode.range_exclusive)
def self.node_range_exclusive(node : ExpressionNode) : Bool?
  node.range_exclusive
end

def self.node_range_exclusive(node : RangeNode) : Bool?
  node.exclusive  # Different field name!
end

def self.node_range_exclusive(node : TypedNode) : Bool?
  nil
end

# macro_name (MacroDefNode.name vs ExpressionNode.macro_name)
def self.node_macro_name(node : ExpressionNode) : Slice(UInt8)?
  node.macro_name
end

def self.node_macro_name(node : MacroDefNode) : Slice(UInt8)?
  node.name  # Different field name!
end

def self.node_macro_name(node : TypedNode) : Slice(UInt8)?
  nil
end

# macro_pieces (only exists in ExpressionNode, MacroLiteral uses ExpressionNode not typed node)
def self.node_macro_pieces(node : ExpressionNode) : Array(MacroPiece)?
  node.macro_pieces
end

def self.node_macro_pieces(node : TypedNode) : Array(MacroPiece)?
  nil  # No typed node has this field
end

# args
def self.node_args(node : ExpressionNode) : Array(ExprId)?
  node.args
end

def self.node_args(node : CallNode) : Array(ExprId)?
  node.args
end

def self.node_args(node : TypedNode) : Array(ExprId)?
  nil
end

# array_of_type
def self.node_array_of_type(node : ExpressionNode) : ExprId?
  node.array_of_type
end

def self.node_array_of_type(node : ArrayLiteralNode) : ExprId?
  node.of_type
end

def self.node_array_of_type(node : TypedNode) : ExprId?
  nil
end

# callee
def self.node_callee(node : ExpressionNode) : ExprId?
  node.callee
end

def self.node_callee(node : CallNode) : ExprId?
  node.callee
end

def self.node_callee(node : TypedNode) : ExprId?
  nil
end

# extend_name
def self.node_extend_name(node : ExpressionNode) : Slice(UInt8)?
  node.extend_name
end

def self.node_extend_name(node : ExtendNode) : Slice(UInt8)?
  node.name
end

def self.node_extend_name(node : TypedNode) : Slice(UInt8)?
  nil
end

# include_name
def self.node_include_name(node : ExpressionNode) : Slice(UInt8)?
  node.include_name
end

def self.node_include_name(node : IncludeNode) : Slice(UInt8)?
  node.name
end

def self.node_include_name(node : TypedNode) : Slice(UInt8)?
  nil
end

# operator
def self.node_operator(node : ExpressionNode) : Slice(UInt8)?
  node.operator
end

def self.node_operator(node : BinaryNode) : Slice(UInt8)?
  node.operator
end

def self.node_operator(node : UnaryNode) : Slice(UInt8)?
  node.operator
end

def self.node_operator(node : TypedNode) : Slice(UInt8)?
  nil
end

# trim_left
def self.node_trim_left(node : ExpressionNode) : Bool?
  node.trim_left
end

def self.node_trim_left(node : TypedNode) : Bool?
  nil
end

# trim_right
def self.node_trim_right(node : ExpressionNode) : Bool?
  node.trim_right
end

def self.node_trim_right(node : TypedNode) : Bool?
  nil
end

# ============================================================================
# Total: 75 fields × ~3 overloads = 225 methods (includes 67 original + 8 new)
      # ============================================================================

      class AstArena
        getter nodes : Array(ExpressionNode)
        getter typed_nodes : Hash(Int32, TypedNode)?  # Phase B: index → TypedNode

        def initialize
          @nodes = [] of ExpressionNode
          @typed_nodes = nil  # Lazy initialization
        end

        # Add legacy ExpressionNode (default behavior)
        def add(node : ExpressionNode) : ExprId
          id = ExprId.new(@nodes.size)
          @nodes << node
          id
        end

        # Phase B: Add typed node (prototype)
        # Allocates index in @nodes array but stores in hash
        def add_typed(node : TypedNode) : ExprId
          # Lazy init hash
          typed = @typed_nodes ||= {} of Int32 => TypedNode

          # Allocate index
          index = @nodes.size

          # Store in hash (NOT in @nodes array)
          typed[index] = node

          # Increment @nodes size to reserve this index
          # Add nil marker (we'll detect this in [])
          @nodes << ExpressionNode.new(
            ExpressionNode::Kind::Identifier,  # Marker kind
            Span.new(0, 0, 0, 0, 0, 0)  # Empty span
          )

          ExprId.new(index)
        end

        # Access node - returns ExpressionNode | TypedNode union
        # Automatically detects and returns typed nodes when available
        def [](id : ExprId) : ExpressionNode | TypedNode
          if typed?(id)
            get_typed(id)
          else
            @nodes[id.index]
          end
        end

        # Phase B: Check if this ID points to typed node
        def typed?(id : ExprId) : Bool
          typed = @typed_nodes
          return false unless typed
          typed.has_key?(id.index)
        end

        # Phase B: Get typed node (caller must check typed? first)
        def get_typed(id : ExprId) : TypedNode
          typed = @typed_nodes
          raise "No typed_nodes" unless typed
          typed[id.index]
        end

        def size
          @nodes.size
        end

        # Phase B: Stats for memory measurement
        def typed_count : Int32
          typed = @typed_nodes
          typed ? typed.size : 0
        end
      end

      struct Program
        getter arena : AstArena
        getter roots : Array(ExprId)

        def initialize(@arena : AstArena, @roots : Array(ExprId))
        end
      end
    end
  end
end
