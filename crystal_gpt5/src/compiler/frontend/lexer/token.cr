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
          Symbol  # Phase 16: :symbol

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
          Unless  # Phase 24
          Until   # Phase 25
          Begin   # Phase 28
          Rescue  # Phase 29: exception handling
          Ensure  # Phase 29: exception handling
          Raise   # Phase 29: raise exception
          Getter  # Phase 30: getter macro
          Setter  # Phase 30: setter macro
          Property  # Phase 30: property macro
          Module  # Phase 31: module definition
          Include  # Phase 31: include module
          Extend  # Phase 31: extend module
          Struct  # Phase 32: struct definition
          Enum  # Phase 33: enum definition
          Alias  # Phase 34: type alias

          # Arithmetic operators
          Plus        # +
          Minus       # -
          Star        # *
          StarStar    # ** (Phase 19: exponentiation)
          Slash       # /
          Percent     # % (Phase 18: modulo)

          # Comparison operators
          Less        # <
          Greater     # >
          LessEq      # <=
          GreaterEq   # >=
          EqEq        # ==
          NotEq       # !=

          # Shift/append operators
          LShift      # << (Phase 9: array push / left shift)
          RShift      # >> (Phase 22: right shift)

          # Range operators
          DotDot      # .. (Phase 13: inclusive range)
          DotDotDot   # ... (Phase 13: exclusive range)

          # Hash operators
          Arrow       # => (Phase 14: hash arrow)

          # Logical operators
          AndAnd      # &&
          OrOr        # ||
          Not         # ! (Phase 17: logical not)

          # Bitwise operators (Phase 21)
          Amp         # & (bitwise AND)
          Pipe        # | (bitwise OR)
          Caret       # ^ (bitwise XOR)
          Tilde       # ~ (bitwise NOT)

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
          Question    # ? (Phase 23: ternary operator)

          # Assignment
          Eq          # =
          PlusEq      # += (Phase 20: compound assignment)
          MinusEq     # -= (Phase 20: compound assignment)
          StarEq      # *= (Phase 20: compound assignment)
          SlashEq     # /= (Phase 20: compound assignment)
          PercentEq   # %= (Phase 20: compound assignment)
          StarStarEq  # **= (Phase 20: compound assignment)

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
