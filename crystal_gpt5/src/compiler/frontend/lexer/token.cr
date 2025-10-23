require "../span"
require "../ast"  # For NumberKind

module CrystalGPT5
  module Compiler
    module Frontend
      struct Token
        getter kind : Kind
        getter slice : Slice(UInt8)
        getter span : Span
        getter number_kind : NumberKind?

        def initialize(@kind : Kind, @slice : Slice(UInt8), @span : Span, @number_kind : NumberKind? = nil)
        end

        def lexeme : String
          String.new(@slice)
        end

        enum Kind
          # Literals
          Identifier
          InstanceVar  # @var
          Number
          String
          StringInterpolation  # Phase 8: "text #{expr} text"

          # Keywords
          If
          Elsif
          Else
          End
          While
          Do
          Then
          Def
          Class
          True
          False
          Nil
          Return  # Phase 6
          Self    # Phase 7
          Yield   # Phase 10
          Case    # Phase 11
          When    # Phase 11
          Break   # Phase 12
          Next    # Phase 12

          # Arithmetic operators
          Plus        # +
          Minus       # -
          Star        # *
          Slash       # /

          # Comparison operators
          Less        # <
          Greater     # >
          LessEq      # <=
          GreaterEq   # >=
          EqEq        # ==
          NotEq       # !=

          # Shift/append operators
          LShift      # << (Phase 9: array push)

          # Range operators
          DotDot      # .. (Phase 13: inclusive range)
          DotDotDot   # ... (Phase 13: exclusive range)

          # Hash operators
          Arrow       # => (Phase 14: hash arrow)

          # Logical operators
          AndAnd      # &&
          OrOr        # ||

          # Grouping and delimiters
          LParen      # (
          RParen      # )
          LBracket    # [
          RBracket    # ]
          LBrace      # {
          RBrace      # }
          Comma       # ,
          Semicolon   # ;
          Colon       # :

          # Assignment (future)
          Eq          # =

          # Other operators (keep for now, will migrate gradually)
          Operator    # Generic fallback for unhandled operators

          # Trivia
          Newline
          Whitespace
          Comment
          EOF
        end
      end
    end
  end
end
