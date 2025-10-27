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
          Global  # Phase 75: $var (global variable)
          Number
          String
          Char  # Phase 56: character literal 'a'
          Regex  # Phase 57: regex literal /pattern/flags
          Bool
          Nil
          Unary
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
          Typeof  # Phase 40: typeof (type introspection)
          Sizeof  # Phase 41: sizeof (size in bytes)
          Pointerof  # Phase 42: pointerof (pointer to variable/expression)
          StringInterpolation  # Phase 8: string interpolation
          ArrayLiteral  # Phase 9: array literals [1, 2, 3]
          Block  # Phase 10: block {|x| ... } or do |x| ... end
          ProcLiteral  # Phase 74: proc literal ->(x) { ... }
          Yield  # Phase 10: yield keyword
          Case  # Phase 11: case/when pattern matching
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
          Enum  # Phase 33: enum definition (enumerated type)
          Alias  # Phase 34: type alias
          Constant  # Phase 35: constant declaration
          Lib  # Phase 38: lib (C bindings)
          Fun  # Phase 64: fun (C function declaration)
          As  # Phase 44: type cast (value.as(Type))
          AsQuestion  # Phase 45: safe cast (value.as?(Type))
          IsA  # Phase 46: type check (value.is_a?(Type))
          RespondsTo  # Phase 49: method check (value.responds_to?(:method))
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
        getter class_is_abstract : Bool?  # Phase 36: true for abstract class
        getter def_is_abstract : Bool?  # Phase 36: true for abstract method
        getter def_visibility : Visibility?  # Phase 37: nil = public (default)
        getter if_condition : ExprId?
        getter if_then : Array(ExprId)?
        getter if_elsifs : Array(ElsifBranch)?
        getter if_else : Array(ExprId)?
        getter while_condition : ExprId?
        getter while_body : Array(ExprId)?
        getter assign_target : ExprId?
        getter assign_value : ExprId?
        getter assign_targets : Array(ExprId)?  # Phase 73: multiple assignment targets (a, b, c)
        getter ivar_decl_type : Slice(UInt8)?  # Phase 5C: @var : Type
        getter return_value : ExprId?  # Phase 6: return statements
        getter string_pieces : Array(StringPiece)?  # Phase 8: string interpolation
        getter array_elements : Array(ExprId)?  # Phase 9: array literal elements
        getter array_of_type : Slice(UInt8)?  # Phase 9: explicit type for [] of Type
        getter block_params : Array(Parameter)?  # Phase 10: block parameters
        getter block_body : Array(ExprId)?  # Phase 10: block body
        getter call_block : ExprId?  # Phase 10: block attached to call
        getter proc_return_type : Slice(UInt8)?  # Phase 74: proc return type annotation
        getter yield_args : Array(ExprId)?  # Phase 10: yield arguments
        getter super_args : Array(ExprId)?  # Phase 39: super arguments
        getter typeof_args : Array(ExprId)?  # Phase 40: typeof arguments (expressions to get type of)
        getter sizeof_args : Array(ExprId)?  # Phase 41: sizeof arguments (type or expression to get size of)
        getter pointerof_args : Array(ExprId)?  # Phase 42: pointerof arguments (variable or expression to get pointer of)
        getter case_value : ExprId?  # Phase 11: value to match against
        getter when_branches : Array(WhenBranch)?  # Phase 11: when branches
        getter case_else : Array(ExprId)?  # Phase 11: else clause
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
        getter alias_value : Slice(UInt8)?  # Phase 34: aliased type
        getter constant_name : Slice(UInt8)?  # Phase 35: constant name
        getter constant_value : ExprId?  # Phase 35: constant value expression
        getter as_value : ExprId?  # Phase 44: expression being cast
        getter as_target_type : Slice(UInt8)?  # Phase 44: target type for cast
        getter as_question_value : ExprId?  # Phase 45: expression being safely cast
        getter as_question_target_type : Slice(UInt8)?  # Phase 45: target type for safe cast
        getter is_a_value : ExprId?  # Phase 46: expression being type-checked
        getter is_a_target_type : Slice(UInt8)?  # Phase 46: target type for type check
        getter responds_to_value : ExprId?  # Phase 49: expression being checked for method
        getter responds_to_method_name : ExprId?  # Phase 49: method name (Symbol or String)
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
          @class_is_abstract : Bool? = nil,
          @def_is_abstract : Bool? = nil,
          @def_visibility : Visibility? = nil,
          @if_condition : ExprId? = nil,
          @if_then : Array(ExprId)? = nil,
          @if_elsifs : Array(ElsifBranch)? = nil,
          @if_else : Array(ExprId)? = nil,
          @while_condition : ExprId? = nil,
          @while_body : Array(ExprId)? = nil,
          @assign_target : ExprId? = nil,
          @assign_value : ExprId? = nil,
          @assign_targets : Array(ExprId)? = nil,
          @ivar_decl_type : Slice(UInt8)? = nil,
          @return_value : ExprId? = nil,
          @string_pieces : Array(StringPiece)? = nil,
          @array_elements : Array(ExprId)? = nil,
          @array_of_type : Slice(UInt8)? = nil,
          @block_params : Array(Parameter)? = nil,
          @block_body : Array(ExprId)? = nil,
          @call_block : ExprId? = nil,
          @proc_return_type : Slice(UInt8)? = nil,
          @yield_args : Array(ExprId)? = nil,
          @super_args : Array(ExprId)? = nil,
          @typeof_args : Array(ExprId)? = nil,
          @sizeof_args : Array(ExprId)? = nil,
          @pointerof_args : Array(ExprId)? = nil,
          @case_value : ExprId? = nil,
          @when_branches : Array(WhenBranch)? = nil,
          @case_else : Array(ExprId)? = nil,
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

      class AstArena
        getter nodes : Array(ExpressionNode)

        def initialize
          @nodes = [] of ExpressionNode
        end

        def add(node : ExpressionNode) : ExprId
          id = ExprId.new(@nodes.size)
          @nodes << node
          id
        end

        def [](id : ExprId) : ExpressionNode
          @nodes[id.index]
        end

        def size
          @nodes.size
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
