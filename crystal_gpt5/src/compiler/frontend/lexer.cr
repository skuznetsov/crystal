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
          Token.new(
            Token::Kind::Identifier,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column)
          )
        end

        private def lex_number
          start_offset, start_line, start_column = capture_position
          from = @offset
          while @offset < @rope.size && ascii_number?(current_byte)
            advance
          end
          Token.new(
            Token::Kind::Number,
            @rope.bytes[from...@offset],
            build_span(start_offset, start_line, start_column)
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
          advance
          Token.new(
            Token::Kind::Operator,
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
