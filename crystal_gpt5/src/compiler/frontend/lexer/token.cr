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
          Identifier
          Number
          String
          Operator
          Newline
          Whitespace
          Comment
          EOF
        end
      end
    end
  end
end
