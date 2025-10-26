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
          when byte == COLON
            # Phase 16: Check if this is a symbol literal
            lex_symbol_or_colon
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
          when "self"   then Token::Kind::Self
          when "super"  then Token::Kind::Super  # Phase 39
          when "typeof" then Token::Kind::Typeof  # Phase 40
          when "sizeof" then Token::Kind::Sizeof  # Phase 41
          when "pointerof" then Token::Kind::Pointerof  # Phase 42
          when "yield"  then Token::Kind::Yield
          when "case"   then Token::Kind::Case
          when "when"   then Token::Kind::When
          when "break"  then Token::Kind::Break
          when "next"   then Token::Kind::Next
          when "unless" then Token::Kind::Unless  # Phase 24
          when "until"  then Token::Kind::Until   # Phase 25
          when "begin"  then Token::Kind::Begin   # Phase 28
          when "rescue" then Token::Kind::Rescue  # Phase 29
          when "ensure" then Token::Kind::Ensure  # Phase 29
          when "raise"  then Token::Kind::Raise   # Phase 29
          when "getter" then Token::Kind::Getter  # Phase 30
          when "setter" then Token::Kind::Setter  # Phase 30
          when "property" then Token::Kind::Property  # Phase 30
          when "module" then Token::Kind::Module  # Phase 31
          when "include" then Token::Kind::Include  # Phase 31
          when "extend" then Token::Kind::Extend  # Phase 31
          when "struct" then Token::Kind::Struct  # Phase 32
          when "enum" then Token::Kind::Enum  # Phase 33
          when "alias" then Token::Kind::Alias  # Phase 34
          when "abstract" then Token::Kind::Abstract  # Phase 36
          when "private" then Token::Kind::Private  # Phase 37
          when "protected" then Token::Kind::Protected  # Phase 37
          when "lib" then Token::Kind::Lib  # Phase 38
          when "as" then Token::Kind::As  # Phase 44
          when "as?" then Token::Kind::AsQuestion  # Phase 45
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

        # Phase 16: Lex symbol literal or colon
        # :identifier → Symbol token with slice ":identifier"
        # : (not followed by identifier) → Colon token
        private def lex_symbol_or_colon
          start_offset, start_line, start_column = capture_position
          from = @offset

          # Consume :
          advance

          # Check if followed by identifier start
          if @offset >= @rope.size || !identifier_start?(current_byte)
            # Just a colon (for type annotations)
            return Token.new(
              Token::Kind::Colon,
              @rope.bytes[from...@offset],
              build_span(start_offset, start_line, start_column)
            )
          end

          # Read identifier part
          while @offset < @rope.size && identifier_char?(current_byte)
            advance
          end

          # Symbols can have suffix (?, !)
          if @offset < @rope.size && identifier_suffix?(current_byte)
            advance
          end

          Token.new(
            Token::Kind::Symbol,
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
          has_interpolation = false

          # Scan string content, detecting interpolation
          while @offset < @rope.size && current_byte != DOUBLE_QUOTE
            # Check for interpolation marker #{
            if current_byte == HASH && @offset + 1 < @rope.size && @rope.bytes[@offset + 1] == LEFT_BRACE
              has_interpolation = true
            end
            advance
          end

          advance if @offset < @rope.size # closing quote

          # Return appropriate token kind
          kind = has_interpolation ? Token::Kind::StringInterpolation : Token::Kind::String
          Token.new(
            kind,
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
            # Check for +=
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::PlusEq  # Phase 20: Compound assignment
            else
              Token::Kind::Plus
            end
          when '-'.ord.to_u8
            # Check for -=
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::MinusEq  # Phase 20: Compound assignment
            else
              Token::Kind::Minus
            end
          when '*'.ord.to_u8
            # Check for ** or *= or **=
            if @offset < @rope.size && current_byte == '*'.ord.to_u8
              advance
              # Check for **=
              if @offset < @rope.size && current_byte == '='.ord.to_u8
                advance
                Token::Kind::StarStarEq  # Phase 20: Compound assignment
              else
                Token::Kind::StarStar  # Phase 19: Exponentiation
              end
            elsif @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::StarEq  # Phase 20: Compound assignment
            else
              Token::Kind::Star
            end
          when '/'.ord.to_u8
            # Check for /=
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::SlashEq  # Phase 20: Compound assignment
            else
              Token::Kind::Slash
            end
          when '%'.ord.to_u8
            # Check for %=
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::PercentEq  # Phase 20: Compound assignment
            else
              Token::Kind::Percent  # Phase 18: Modulo operator
            end
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
          when '{'.ord.to_u8
            Token::Kind::LBrace
          when '}'.ord.to_u8
            Token::Kind::RBrace
          when '<'.ord.to_u8
            # Check for <<, <=>, or <=
            if @offset < @rope.size
              next_byte = current_byte
              if next_byte == '<'.ord.to_u8
                advance
                Token::Kind::LShift
              elsif next_byte == '='.ord.to_u8
                # Check for <=>
                advance  # consume '='
                if @offset < @rope.size && current_byte == '>'.ord.to_u8
                  advance  # consume '>'
                  Token::Kind::Spaceship  # Phase 48
                else
                  Token::Kind::LessEq
                end
              else
                Token::Kind::Less
              end
            else
              Token::Kind::Less
            end
          when '>'.ord.to_u8
            # Check for >> or >=
            if @offset < @rope.size
              next_byte = current_byte
              if next_byte == '>'.ord.to_u8
                advance
                Token::Kind::RShift  # Phase 22: Right shift
              elsif next_byte == '='.ord.to_u8
                advance
                Token::Kind::GreaterEq
              else
                Token::Kind::Greater
              end
            else
              Token::Kind::Greater
            end
          when '='.ord.to_u8
            # Check for =>, ===, and ==
            if @offset < @rope.size
              next_byte = current_byte
              if next_byte == '>'.ord.to_u8
                advance
                Token::Kind::Arrow  # =>
              elsif next_byte == '='.ord.to_u8
                # Check for === (Phase 50)
                advance  # consume second '='
                if @offset < @rope.size && current_byte == '='.ord.to_u8
                  advance  # consume third '='
                  Token::Kind::EqEqEq  # ===
                else
                  Token::Kind::EqEq  # ==
                end
              else
                Token::Kind::Eq  # =
              end
            else
              Token::Kind::Eq
            end
          when '!'.ord.to_u8
            # Check for !=
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance
              Token::Kind::NotEq
            else
              # Phase 17: Logical not operator
              Token::Kind::Not
            end
          when '&'.ord.to_u8
            # Check for &. (safe navigation)
            if @offset < @rope.size && current_byte == '.'.ord.to_u8
              advance  # consume '.'
              Token::Kind::AmpDot
            # Check for &&
            elsif @offset < @rope.size && current_byte == '&'.ord.to_u8
              advance  # consume '&'
              Token::Kind::AndAnd
            else
              # Phase 21: Bitwise AND
              Token::Kind::Amp
            end
          when '|'.ord.to_u8
            # Check for ||
            if @offset < @rope.size && current_byte == '|'.ord.to_u8
              advance
              Token::Kind::OrOr
            else
              # Phase 21: Bitwise OR
              Token::Kind::Pipe
            end
          when '^'.ord.to_u8
            # Phase 21: Bitwise XOR
            Token::Kind::Caret
          when '~'.ord.to_u8
            # Phase 21: Bitwise NOT
            Token::Kind::Tilde
          when '.'.ord.to_u8
            # Check for .. and ...
            if @offset < @rope.size && current_byte == '.'.ord.to_u8
              advance  # consume second '.'
              # Check for third '.'
              if @offset < @rope.size && current_byte == '.'.ord.to_u8
                advance  # consume third '.'
                Token::Kind::DotDotDot  # ...
              else
                Token::Kind::DotDot  # ..
              end
            else
              # Standalone . - use generic Operator for now (member access)
              Token::Kind::Operator
            end
          when '?'.ord.to_u8
            # Phase 23: Ternary operator
            Token::Kind::Question
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
        LEFT_BRACE   = '{'.ord.to_u8  # Phase 8: for interpolation detection
        COLON        = ':'.ord.to_u8  # Phase 16: for symbol literals

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
