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
          @processed_strings = [] of Bytes  # Phase 54: storage for escape-processed strings
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
          when byte == SINGLE_QUOTE
            # Phase 56: Character literals
            lex_char
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

          # Phase 53: Check for hex (0x), binary (0b), or octal (0o) prefix
          if current_byte == '0'.ord.to_u8 && @offset + 1 < @rope.size
            next_byte = @rope.bytes[@offset + 1]
            case next_byte
            when 'x'.ord.to_u8, 'X'.ord.to_u8
              return lex_hex_number(start_offset, start_line, start_column, from)
            when 'b'.ord.to_u8, 'B'.ord.to_u8
              return lex_binary_number(start_offset, start_line, start_column, from)
            when 'o'.ord.to_u8, 'O'.ord.to_u8
              return lex_octal_number(start_offset, start_line, start_column, from)
            end
          end

          # Phase 55: Read integer part (with underscore separators)
          while @offset < @rope.size && (ascii_number?(current_byte) || current_byte == UNDERSCORE)
            advance
          end

          # Phase 55: Skip trailing underscores (so suffix parser can see them)
          while @offset > from && @rope.bytes[@offset - 1] == UNDERSCORE
            @offset -= 1
          end

          # Check for decimal point (float)
          has_decimal = false
          if @offset < @rope.size && current_byte == '.'.ord.to_u8
            # Peek ahead to ensure next char is a digit (not method call like 42.abs)
            if @offset + 1 < @rope.size && ascii_number?(@rope.bytes[@offset + 1])
              has_decimal = true
              advance  # consume '.'
              # Phase 55: Read fractional part (with underscore separators)
              while @offset < @rope.size && (ascii_number?(current_byte) || current_byte == UNDERSCORE)
                advance
              end
              # Phase 55: Skip trailing underscores (so suffix parser can see them)
              while @offset > from && @rope.bytes[@offset - 1] == UNDERSCORE
                @offset -= 1
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

        # Phase 53: Hexadecimal number literals (0xFF, 0x1A2B)
        private def lex_hex_number(start_offset : Int32, start_line : Int32, start_column : Int32, from : Int32)
          advance  # Skip '0'
          advance  # Skip 'x' or 'X'

          # Phase 55: Read hex digits (with underscore separators)
          while @offset < @rope.size && (hex_digit?(current_byte) || current_byte == UNDERSCORE)
            advance
          end

          # Phase 55: Skip trailing underscores (so suffix parser can see them)
          while @offset > from && @rope.bytes[@offset - 1] == UNDERSCORE
            @offset -= 1
          end

          # Check for suffix (_i32, _i64, _f64)
          number_kind = lex_number_suffix

          # Infer NumberKind if not explicitly specified
          number_kind ||= NumberKind::I32

          Token.new(
            Token::Kind::Number,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column),
            number_kind: number_kind
          )
        end

        # Phase 53: Binary number literals (0b1010, 0B1111)
        private def lex_binary_number(start_offset : Int32, start_line : Int32, start_column : Int32, from : Int32)
          advance  # Skip '0'
          advance  # Skip 'b' or 'B'

          # Phase 55: Read binary digits (with underscore separators)
          while @offset < @rope.size && (binary_digit?(current_byte) || current_byte == UNDERSCORE)
            advance
          end

          # Phase 55: Skip trailing underscores (so suffix parser can see them)
          while @offset > from && @rope.bytes[@offset - 1] == UNDERSCORE
            @offset -= 1
          end

          # Check for suffix (_i32, _i64, _f64)
          number_kind = lex_number_suffix

          # Infer NumberKind if not explicitly specified
          number_kind ||= NumberKind::I32

          Token.new(
            Token::Kind::Number,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column),
            number_kind: number_kind
          )
        end

        # Phase 53: Octal number literals (0o755, 0O644)
        private def lex_octal_number(start_offset : Int32, start_line : Int32, start_column : Int32, from : Int32)
          advance  # Skip '0'
          advance  # Skip 'o' or 'O'

          # Phase 55: Read octal digits (with underscore separators)
          while @offset < @rope.size && (octal_digit?(current_byte) || current_byte == UNDERSCORE)
            advance
          end

          # Phase 55: Skip trailing underscores (so suffix parser can see them)
          while @offset > from && @rope.bytes[@offset - 1] == UNDERSCORE
            @offset -= 1
          end

          # Check for suffix (_i32, _i64, _f64)
          number_kind = lex_number_suffix

          # Infer NumberKind if not explicitly specified
          number_kind ||= NumberKind::I32

          Token.new(
            Token::Kind::Number,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column),
            number_kind: number_kind
          )
        end

        # Phase 53: Extract number suffix parsing to helper
        private def lex_number_suffix : NumberKind?
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

            return number_kind
          end

          nil
        end

        private def lex_string
          start_offset, start_line, start_column = capture_position
          advance # opening quote
          from = @offset
          has_interpolation = false
          has_escapes = false

          # Phase 54: Check if string contains escapes or interpolation
          # First pass: detect escapes/interpolation
          scan_offset = @offset
          while scan_offset < @rope.size && @rope.bytes[scan_offset] != DOUBLE_QUOTE
            byte = @rope.bytes[scan_offset]
            if byte == HASH && scan_offset + 1 < @rope.size && @rope.bytes[scan_offset + 1] == LEFT_BRACE
              has_interpolation = true
            elsif byte == '\\'.ord.to_u8
              has_escapes = true
            end
            scan_offset += 1
          end

          # If no escapes, use original fast path
          if !has_escapes
            while @offset < @rope.size && current_byte != DOUBLE_QUOTE
              advance
            end
            advance if @offset < @rope.size # closing quote

            kind = has_interpolation ? Token::Kind::StringInterpolation : Token::Kind::String
            return Token.new(
              kind,
              @rope.bytes[from...@offset - 1],
              build_span(start_offset, start_line, start_column)
            )
          end

          # Phase 54: Process escape sequences
          processed = Bytes.new(scan_offset - from)  # Allocate with estimated size
          buffer = IO::Memory.new

          while @offset < @rope.size && current_byte != DOUBLE_QUOTE
            if current_byte == '\\'.ord.to_u8 && @offset + 1 < @rope.size
              # Escape sequence
              advance  # Skip backslash
              case current_byte
              when 'n'.ord.to_u8
                buffer.write_byte '\n'.ord.to_u8
              when 't'.ord.to_u8
                buffer.write_byte '\t'.ord.to_u8
              when 'r'.ord.to_u8
                buffer.write_byte '\r'.ord.to_u8
              when '\\'.ord.to_u8
                buffer.write_byte '\\'.ord.to_u8
              when '"'.ord.to_u8
                buffer.write_byte '"'.ord.to_u8
              when '0'.ord.to_u8
                buffer.write_byte '\0'.ord.to_u8
              else
                # Unknown escape - keep as is
                buffer.write_byte '\\'.ord.to_u8
                buffer.write_byte current_byte
              end
              advance
            else
              buffer.write_byte current_byte
              advance
            end
          end

          advance if @offset < @rope.size # closing quote

          # Store processed string
          processed_bytes = buffer.to_slice
          @processed_strings << processed_bytes

          # Return token with processed string
          kind = has_interpolation ? Token::Kind::StringInterpolation : Token::Kind::String
          Token.new(
            kind,
            processed_bytes,
            build_span(start_offset, start_line, start_column)
          )
        end

        # Phase 56: Character literals ('a', '\n', etc.)
        private def lex_char
          start_offset, start_line, start_column = capture_position
          advance  # Skip opening '

          # Character literals must have exactly one character or escape sequence
          if @offset >= @rope.size
            # TODO: Error - empty character literal
            return Token.new(Token::Kind::Char, Slice(UInt8).new(0), build_span(start_offset, start_line, start_column))
          end

          # Check if it's an escape sequence
          if current_byte == '\\'.ord.to_u8 && @offset + 1 < @rope.size
            # Process escape sequence
            buffer = IO::Memory.new
            advance  # Skip backslash

            case current_byte
            when 'n'.ord.to_u8
              buffer.write_byte '\n'.ord.to_u8
            when 't'.ord.to_u8
              buffer.write_byte '\t'.ord.to_u8
            when 'r'.ord.to_u8
              buffer.write_byte '\r'.ord.to_u8
            when '\\'.ord.to_u8
              buffer.write_byte '\\'.ord.to_u8
            when '\''.ord.to_u8
              buffer.write_byte '\''.ord.to_u8
            when '0'.ord.to_u8
              buffer.write_byte '\0'.ord.to_u8
            else
              # Unknown escape - keep as is
              buffer.write_byte '\\'.ord.to_u8
              buffer.write_byte current_byte
            end
            advance

            # Expect closing '
            if @offset < @rope.size && current_byte == SINGLE_QUOTE
              advance
            end

            # Store processed character
            processed_bytes = buffer.to_slice
            @processed_strings << processed_bytes

            return Token.new(
              Token::Kind::Char,
              processed_bytes,
              build_span(start_offset, start_line, start_column)
            )
          else
            # Simple character - no escape
            from = @offset
            advance  # Consume the character

            # Expect closing '
            if @offset < @rope.size && current_byte == SINGLE_QUOTE
              advance
            end

            return Token.new(
              Token::Kind::Char,
              @rope.bytes[from...from + 1],
              build_span(start_offset, start_line, start_column)
            )
          end
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
            # Check for <<=, <<, <=>, or <=
            if @offset < @rope.size
              next_byte = current_byte
              if next_byte == '<'.ord.to_u8
                advance  # consume second '<'
                # Check for <<= (Phase 52)
                if @offset < @rope.size && current_byte == '='.ord.to_u8
                  advance  # consume '='
                  Token::Kind::LShiftEq
                else
                  Token::Kind::LShift
                end
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
            # Check for >>=, >>, or >=
            if @offset < @rope.size
              next_byte = current_byte
              if next_byte == '>'.ord.to_u8
                advance  # consume second '>'
                # Check for >>= (Phase 52)
                if @offset < @rope.size && current_byte == '='.ord.to_u8
                  advance  # consume '='
                  Token::Kind::RShiftEq
                else
                  Token::Kind::RShift  # Phase 22: Right shift
                end
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
            # Check for &&= and &&
            elsif @offset < @rope.size && current_byte == '&'.ord.to_u8
              advance  # consume second '&'
              # Check for &&= (Phase 51)
              if @offset < @rope.size && current_byte == '='.ord.to_u8
                advance  # consume '='
                Token::Kind::AndAndEq
              else
                Token::Kind::AndAnd
              end
            else
              # Check for &= (Phase 52)
              if @offset < @rope.size && current_byte == '='.ord.to_u8
                advance  # consume '='
                Token::Kind::AmpEq
              else
                # Phase 21: Bitwise AND
                Token::Kind::Amp
              end
            end
          when '|'.ord.to_u8
            # Check for ||= and ||
            if @offset < @rope.size && current_byte == '|'.ord.to_u8
              advance  # consume second '|'
              # Check for ||= (Phase 51)
              if @offset < @rope.size && current_byte == '='.ord.to_u8
                advance  # consume '='
                Token::Kind::OrOrEq
              else
                Token::Kind::OrOr
              end
            else
              # Check for |= (Phase 52)
              if @offset < @rope.size && current_byte == '='.ord.to_u8
                advance  # consume '='
                Token::Kind::PipeEq
              else
                # Phase 21: Bitwise OR
                Token::Kind::Pipe
              end
            end
          when '^'.ord.to_u8
            # Check for ^= (Phase 52)
            if @offset < @rope.size && current_byte == '='.ord.to_u8
              advance  # consume '='
              Token::Kind::CaretEq
            else
              # Phase 21: Bitwise XOR
              Token::Kind::Caret
            end
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

        # Phase 53: Hexadecimal digit check (0-9, a-f, A-F)
        private def hex_digit?(byte : UInt8) : Bool
          ascii_number?(byte) || (byte >= 'a'.ord && byte <= 'f'.ord) || (byte >= 'A'.ord && byte <= 'F'.ord)
        end

        # Phase 53: Binary digit check (0-1)
        private def binary_digit?(byte : UInt8) : Bool
          byte == '0'.ord || byte == '1'.ord
        end

        # Phase 53: Octal digit check (0-7)
        private def octal_digit?(byte : UInt8) : Bool
          byte >= '0'.ord && byte <= '7'.ord
        end

        SPACE        = 0x20_u8
        TAB          = 0x09_u8
        NEWLINE      = 0x0A_u8
        DOUBLE_QUOTE = '"'.ord.to_u8
        SINGLE_QUOTE = '\''.ord.to_u8  # Phase 56: character literals
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
