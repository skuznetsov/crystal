require "../span"

module CrystalGPT5
  module Compiler
    module Frontend
      struct Token
        getter kind : Kind
        getter slice : Slice(UInt8)
        getter span : Span

        def initialize(@kind : Kind, @slice : Slice(UInt8), @span : Span)
        end

        def lexeme : String
          String.new(@slice)
        end

        enum Kind
          # Literals
          Identifier
          Number
          String

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
