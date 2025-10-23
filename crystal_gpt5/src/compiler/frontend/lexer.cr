require "./rope"
require "./lexer/token"

module CrystalGPT5
  module Compiler
    module Frontend
      class Lexer
        def initialize(source : String)
          @rope = Rope.new(source)
          @offset = 0
          @line = 1
          @column = 1
        end

        def each_token(&block : Token ->)
          while token = next_token
            block.call token
            break if token.kind == Token::Kind::EOF
          end
        end

        private def next_token : Token
          return eof_token if @offset >= @rope.size

          byte = current_byte

          case
          when whitespace?(byte)
            lex_whitespace
          when byte == NEWLINE
            lex_newline
          when byte == AT_SIGN
            lex_instance_var
          when identifier_start?(byte)
            lex_identifier
          when ascii_number?(byte)
            lex_number
          when byte == DOUBLE_QUOTE
            lex_string
          when byte == HASH
            lex_comment
          else
            lex_operator
          end
        end

        private def eof_token
          Token.new(Token::Kind::EOF, Slice(UInt8).new(0), current_point_span)
        end

        private def capture_position
          {@offset, @line, @column}
        end

        private def current_byte
          @rope.bytes[@offset]
        end

        private def advance(count : Int32 = 1)
          count.times do
            byte = current_byte
            @offset += 1
            if byte == NEWLINE
              @line += 1
              @column = 1
            else
              @column += 1
            end
          end
        end

        private def lex_whitespace
          start_offset, start_line, start_column = capture_position
          from = @offset
          while @offset < @rope.size && whitespace?(current_byte)
            advance
          end
          Token.new(
            Token::Kind::Whitespace,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column)
          )
        end

        private def lex_newline
          start_offset, start_line, start_column = capture_position
          advance
          Token.new(
            Token::Kind::Newline,
            @rope.bytes[start_offset...@offset],
            build_span(start_offset, start_line, start_column)
          )
        end

        private def lex_identifier
          start_offset, start_line, start_column = capture_position
          from = @offset
          while @offset < @rope.size && identifier_char?(current_byte)
            advance
          end
          if @offset < @rope.size && identifier_suffix?(current_byte)
            advance
          end

          slice = @rope.bytes[from...@offset]

          # Check if this is a keyword
          kind = case String.new(slice)
          when "if"     then Token::Kind::If
          when "elsif"  then Token::Kind::Elsif
          when "else"   then Token::Kind::Else
          when "end"    then Token::Kind::End
          when "while"  then Token::Kind::While
          when "do"     then Token::Kind::Do
          when "then"   then Token::Kind::Then
          when "def"    then Token::Kind::Def
          when "class"  then Token::Kind::Class
          when "true"   then Token::Kind::True
          when "false"  then Token::Kind::False
          when "nil"    then Token::Kind::Nil
          when "return" then Token::Kind::Return
          else
            Token::Kind::Identifier
          end

          Token.new(
            kind,
            slice,
            build_span(start_offset, start_line, start_column)
          )
        end

        private def lex_instance_var
          start_offset, start_line, start_column = capture_position
          from = @offset

          # Consume @
          advance

          # Instance variable must start with identifier character
          if @offset >= @rope.size || !identifier_start?(current_byte)
            # Invalid instance variable - just @, return as operator
            return Token.new(
              Token::Kind::Operator,
              @rope.bytes[from...@offset],
              build_span(start_offset, start_line, start_column)
            )
          end

          # Read identifier part
          while @offset < @rope.size && identifier_char?(current_byte)
            advance
          end

          # Instance variables can have suffix (?, !)
          if @offset < @rope.size && identifier_suffix?(current_byte)
            advance
          end

          Token.new(
            Token::Kind::InstanceVar,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column)
          )
        end

        private def lex_number
          start_offset, start_line, start_column = capture_position
          from = @offset

          # Read integer part
          while @offset < @rope.size && ascii_number?(current_byte)
            advance
          end

          # Check for decimal point (float)
          has_decimal = false
          if @offset < @rope.size && current_byte == '.'.ord.to_u8
            # Peek ahead to ensure next char is a digit (not method call like 42.abs)
            if @offset + 1 < @rope.size && ascii_number?(@rope.bytes[@offset + 1])
              has_decimal = true
              advance  # consume '.'
              # Read fractional part
              while @offset < @rope.size && ascii_number?(current_byte)
                advance
              end
            end
          end

          # Check for suffix (_i32, _i64, _f64)
          number_kind : NumberKind? = nil
          if @offset < @rope.size && current_byte == '_'.ord.to_u8
            suffix_start = @offset
            advance  # consume '_'

            # Read suffix characters
            suffix_from = @offset
            while @offset < @rope.size && (ascii_letter?(current_byte) || ascii_number?(current_byte))
              advance
            end

            suffix = String.new(@rope.bytes[suffix_from...@offset])
            number_kind = case suffix
            when "i32" then NumberKind::I32
            when "i64" then NumberKind::I64
            when "f64" then NumberKind::F64
            else
              # Unknown suffix - ignore and treat as separate token
              # Reset to before underscore
              @offset = suffix_start
              nil
            end
          end

          # Infer NumberKind if not explicitly specified
          if number_kind.nil?
            number_kind = has_decimal ? NumberKind::F64 : NumberKind::I32
          end

          Token.new(
            Token::Kind::Number,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column),
            number_kind: number_kind
          )
        end

        private def lex_string
          start_offset, start_line, start_column = capture_position
          advance # opening quote
          from = @offset
          while @offset < @rope.size && current_byte != DOUBLE_QUOTE
            advance
          end
          advance if @offset < @rope.size # closing quote
          Token.new(
            Token::Kind::String,
            @rope.bytes[from...@offset - 1],
            build_span(start_offset, start_line, start_column)
          )
        end

        private def lex_comment
          start_offset, start_line, start_column = capture_position
          from = @offset
          while @offset < @rope.size && current_byte != NEWLINE
            advance
          end
          Token.new(
            Token::Kind::Comment,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column)
          )
        end

        private def lex_operator
          start_offset, start_line, start_column = capture_position
          from = @offset

          # Read first character
          first = current_byte
          advance

          # Determine token kind based on operator
          kind : Token::Kind = case first
          when '+'.ord.to_u8
            Token::Kind::Plus
          when '-'.ord.to_u8
            Token::Kind::Minus
          when '*'.ord.to_u8
            Token::Kind::Star
          when '/'.ord.to_u8
            Token::Kind::Slash
          when '('.ord.to_u8
            Token::Kind::LParen
          when ')'.ord.to_u8
            Token::Kind::RParen
          when '['.ord.to_u8
            Token::Kind::LBracket
          when ']'.ord.to_u8
            Token::Kind::RBracket
          when ','.ord.to_u8
            Token::Kind::Comma
          when ';'.ord.to_u8
            Token::Kind::Semicolon
          when ':'.ord.to_u8
            Token::Kind::Colon
          when '{'.ord.to_u8, '}'.ord.to_u8
            # Keep {} as generic Operator for macro parsing compatibility
            Token::Kind::Operator
          when '<'.ord.to_u8
            # Check for <=
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::LessEq
            else
              Token::Kind::Less
            end
          when '>'.ord.to_u8
            # Check for >=
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::GreaterEq
            else
              Token::Kind::Greater
            end
          when '='.ord.to_u8
            # Check for ==
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::EqEq
            else
              Token::Kind::Eq
            end
          when '!'.ord.to_u8
            # Check for !=
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::NotEq
            else
              # Standalone ! - use generic Operator for now
              Token::Kind::Operator
            end
          when '&'.ord.to_u8
            # Check for &&
            if @offset < @rope.size && current_byte == '&'.ord.to_u8
              advance
              Token::Kind::AndAnd
            else
              # Standalone & - use generic Operator for now
              Token::Kind::Operator
            end
          when '|'.ord.to_u8
            # Check for ||
            if @offset < @rope.size && current_byte == '|'.ord.to_u8
              advance
              Token::Kind::OrOr
            else
              # Standalone | - use generic Operator for now
              Token::Kind::Operator
            end
          else
            # Unknown operator - use generic fallback
            Token::Kind::Operator
          end

          Token.new(
            kind,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column)
          )
        end

        private def whitespace?(byte : UInt8) : Bool
          byte == SPACE || byte == TAB
        end

        private def identifier_start?(byte : UInt8) : Bool
          ascii_letter?(byte) || byte == UNDERSCORE
        end

        private def identifier_char?(byte : UInt8) : Bool
          ascii_letter?(byte) || ascii_number?(byte) || byte == UNDERSCORE
        end

        private def identifier_suffix?(byte : UInt8) : Bool
          byte == QUESTION || byte == EXCLAMATION
        end

        private def ascii_letter?(byte : UInt8) : Bool
          (byte >= 'a'.ord && byte <= 'z'.ord) || (byte >= 'A'.ord && byte <= 'Z'.ord)
        end

        private def ascii_number?(byte : UInt8) : Bool
          byte >= '0'.ord && byte <= '9'.ord
        end

        SPACE        = 0x20_u8
        TAB          = 0x09_u8
        NEWLINE      = 0x0A_u8
        DOUBLE_QUOTE = '"'.ord.to_u8
        HASH         = '#'.ord.to_u8
        UNDERSCORE   = '_'.ord.to_u8
        QUESTION     = '?'.ord.to_u8
        EXCLAMATION  = '!'.ord.to_u8
        AT_SIGN      = '@'.ord.to_u8

        private def build_span(start_offset, start_line, start_column)
          Span.new(
            start_offset,
            @offset,
            start_line,
            start_column,
            @line,
            @column
          )
        end

        private def current_point_span
          Span.new(
            @offset,
            @offset,
            @line,
            @column,
            @line,
            @column
          )
        end
      end
    end
  end
end
