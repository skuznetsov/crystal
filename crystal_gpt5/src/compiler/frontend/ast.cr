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

      struct ExpressionNode
        enum Kind
          Identifier
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
          MacroExpression
          MacroLiteral
          MacroDef
          Def
          Class
        end

        getter kind : Kind
        getter span : Span
        getter literal : Slice(UInt8)?
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
        getter def_params : Array(String)?
        getter def_body : Array(ExprId)?
        getter class_name : Slice(UInt8)?
        getter class_body : Array(ExprId)?
        getter class_super_name : Slice(UInt8)?

        def initialize(
          @kind : Kind,
          @span : Span,
          @literal : Slice(UInt8)? = nil,
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
          @def_params : Array(String)? = nil,
          @def_body : Array(ExprId)? = nil,
          @class_name : Slice(UInt8)? = nil,
          @class_body : Array(ExprId)? = nil,
          @class_super_name : Slice(UInt8)? = nil,
        )
        end

        def literal_string
          literal.try { |slice| String.new(slice) }
        end

        def operator_string
          operator.try { |slice| String.new(slice) }
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
