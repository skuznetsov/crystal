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
        getter span : Span              # Full "x : Int32" span
        getter name_span : Span         # Just "x" for rename
        getter type_span : Span?        # Just "Int32" for hover (optional)

        def initialize(
          @name : String,
          @type_annotation : String? = nil,
          @span : Span = Span.new(0, 0, 0, 0, 0, 0),
          @name_span : Span = Span.new(0, 0, 0, 0, 0, 0),
          @type_span : Span? = nil
        )
        end
      end

      struct ExpressionNode
        enum Kind
          Identifier
          InstanceVar  # @var
          InstanceVarDecl  # @var : Type (Phase 5C)
          Number
          String
          Bool
          Nil
          Unary
          Binary
          Call
          Index
          MemberAccess
          Grouping
          If
          While
          Assign
          MacroExpression
          MacroLiteral
          MacroDef
          Def
          Class
          Return  # Phase 6: return statements
          Self    # Phase 7: self keyword
          StringInterpolation  # Phase 8: string interpolation
          ArrayLiteral  # Phase 9: array literals [1, 2, 3]
          Block  # Phase 10: block {|x| ... } or do |x| ... end
          Yield  # Phase 10: yield keyword
          Case  # Phase 11: case/when pattern matching
          Break  # Phase 12: break [value]
          Next   # Phase 12: next
          Range  # Phase 13: range literals (1..10, 1...10)
          HashLiteral  # Phase 14: hash literals {"k"=>v}
          TupleLiteral  # Phase 15: tuple literals {1, 2, 3}
          Symbol  # Phase 16: symbol literals :hello
          Ternary  # Phase 23: ternary operator (cond ? true : false)
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
        getter if_condition : ExprId?
        getter if_then : Array(ExprId)?
        getter if_elsifs : Array(ElsifBranch)?
        getter if_else : Array(ExprId)?
        getter while_condition : ExprId?
        getter while_body : Array(ExprId)?
        getter assign_target : ExprId?
        getter assign_value : ExprId?
        getter ivar_decl_type : Slice(UInt8)?  # Phase 5C: @var : Type
        getter return_value : ExprId?  # Phase 6: return statements
        getter string_pieces : Array(StringPiece)?  # Phase 8: string interpolation
        getter array_elements : Array(ExprId)?  # Phase 9: array literal elements
        getter array_of_type : Slice(UInt8)?  # Phase 9: explicit type for [] of Type
        getter block_params : Array(Parameter)?  # Phase 10: block parameters
        getter block_body : Array(ExprId)?  # Phase 10: block body
        getter call_block : ExprId?  # Phase 10: block attached to call
        getter yield_args : Array(ExprId)?  # Phase 10: yield arguments
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
        getter ternary_condition : ExprId?  # Phase 23: ternary condition
        getter ternary_true_branch : ExprId?  # Phase 23: ternary true branch
        getter ternary_false_branch : ExprId?  # Phase 23: ternary false branch

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
          @if_condition : ExprId? = nil,
          @if_then : Array(ExprId)? = nil,
          @if_elsifs : Array(ElsifBranch)? = nil,
          @if_else : Array(ExprId)? = nil,
          @while_condition : ExprId? = nil,
          @while_body : Array(ExprId)? = nil,
          @assign_target : ExprId? = nil,
          @assign_value : ExprId? = nil,
          @ivar_decl_type : Slice(UInt8)? = nil,
          @return_value : ExprId? = nil,
          @string_pieces : Array(StringPiece)? = nil,
          @array_elements : Array(ExprId)? = nil,
          @array_of_type : Slice(UInt8)? = nil,
          @block_params : Array(Parameter)? = nil,
          @block_body : Array(ExprId)? = nil,
          @call_block : ExprId? = nil,
          @yield_args : Array(ExprId)? = nil,
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
          @ternary_condition : ExprId? = nil,
          @ternary_true_branch : ExprId? = nil,
          @ternary_false_branch : ExprId? = nil,
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
