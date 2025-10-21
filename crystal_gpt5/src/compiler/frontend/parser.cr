require "./ast"
require "./lexer"
require "./lexer/token"
require "./parser/diagnostic"

module CrystalGPT5
  module Compiler
    module Frontend
      class Parser
        PREFIX_ERROR = ExprId.new(-1)
        UNARY_PRECEDENCE = 30

        @macro_terminator : Symbol?
        @previous_token : Token?

        def initialize(lexer : Lexer)
          @tokens = [] of Token
          lexer.each_token { |token| @tokens << token }
          @index = 0
          @arena = AstArena.new
          @diagnostics = [] of Diagnostic
          @macro_terminator = nil
          @previous_token = nil
        end

        def parse_program : Program
          roots = [] of ExprId
          while current_token.kind != Token::Kind::EOF
            skip_trivia
            break if current_token.kind == Token::Kind::EOF

            if macro_definition_start?
              macro_def = parse_macro_definition
              roots << macro_def unless macro_def.invalid?
              consume_newlines
              next
            end

            if definition_start?
              node = case token_text(current_token)
                when "def"
                  parse_def
                when "class"
                  parse_class
                else
                  PREFIX_ERROR
                end
              roots << node unless node.invalid?
              consume_newlines
              next
            end

            expr = parse_expression(0)
            roots << expr unless expr.invalid?
            consume_newlines
          end
          Program.new(@arena, roots)
        end

        def arena
          @arena
        end

        def diagnostics
          @diagnostics
        end

        private def current_token
          @tokens[@index]
        end

        private def previous_token
          @previous_token
        end

        private def advance
          @previous_token = current_token
          @index += 1 if @index < @tokens.size - 1
        end

        private def skip_trivia
          loop do
            case current_token.kind
            when Token::Kind::Whitespace, Token::Kind::Comment
              advance
            else
              break
            end
          end
        end

        private def consume_newlines
          loop do
            case current_token.kind
            when Token::Kind::Newline
              advance
            when Token::Kind::Whitespace, Token::Kind::Comment
              advance
            else
              break
            end
          end
        end

        private def macro_definition_start?
          current_token.kind == Token::Kind::Identifier && token_text(current_token) == "macro"
        end

        private def definition_start?
          return false unless current_token.kind == Token::Kind::Identifier
          keyword = token_text(current_token)
          keyword == "def" || keyword == "class"
        end

        private def parse_macro_definition : ExprId
          macro_token = current_token
          advance
          skip_trivia

          name_token = current_token
          unless name_token.kind == Token::Kind::Identifier
            emit_unexpected(name_token)
            return PREFIX_ERROR
          end
          advance

          skip_macro_parameters
          consume_newlines

          pieces, trim_left, trim_right = parse_macro_body
          expect_identifier("end")
          end_token = previous_token
          consume_newlines

          end_span = end_token.try(&.span)
          body_span = end_span ? name_token.span.cover(end_span) : name_token.span
          macro_span = end_span ? macro_token.span.cover(end_span) : macro_token.span

          body_id = @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::MacroLiteral,
              body_span,
              macro_pieces: pieces,
              trim_left: trim_left,
              trim_right: trim_right
            )
          )

          @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::MacroDef,
              macro_span,
              left: body_id,
              macro_name: name_token.slice
            )
          )
        end

        private def parse_def : ExprId
          def_token = current_token
          advance
          skip_trivia

          name_token = current_token
          unless name_token.kind == Token::Kind::Identifier
            emit_unexpected(name_token)
            return PREFIX_ERROR
          end
          advance

          params = parse_method_params

          consume_newlines

          body_ids = [] of ExprId
          loop do
            skip_trivia
            token = current_token
            break if token.kind == Token::Kind::Identifier && token_text(token) == "end"
            break if token.kind == Token::Kind::EOF

            expr = parse_expression(0)
            body_ids << expr unless expr.invalid?
            consume_newlines
          end

          expect_identifier("end")
          end_token = previous_token
          consume_newlines

          def_span = if end_token
            def_token.span.cover(end_token.span)
          else
            def_token.span
          end
          @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::Def,
              def_span,
              def_name: name_token.slice,
              def_params: params,
              def_body: body_ids,
            )
          )
        end

        private def parse_method_params
          params = [] of String
          skip_trivia
          return params unless operator_token?(current_token, "(")

          advance
          skip_trivia
          unless operator_token?(current_token, ")")
            loop do
              token = current_token
              unless token.kind == Token::Kind::Identifier
                emit_unexpected(token)
                break
              end
              params << token_text(token)
              advance
              skip_trivia
              break unless operator_token?(current_token, ",")
              advance
              skip_trivia
            end
          end

          expect_operator(")")
          params
        end

        private def parse_class : ExprId
          class_token = current_token
          advance
          skip_trivia

          name_token = current_token
          unless name_token.kind == Token::Kind::Identifier
            emit_unexpected(name_token)
            return PREFIX_ERROR
          end
          advance

          # Parse optional superclass: < SuperClass
          skip_trivia
          super_name_token = nil
          if current_token.kind == Token::Kind::Operator && token_text(current_token) == "<"
            advance  # Skip <
            skip_trivia
            super_name_token = current_token
            unless super_name_token.kind == Token::Kind::Identifier
              emit_unexpected(super_name_token)
              return PREFIX_ERROR
            end
            advance
          end

          consume_newlines

          body_ids = [] of ExprId
          loop do
            skip_trivia
            token = current_token
            break if token.kind == Token::Kind::Identifier && token_text(token) == "end"
            break if token.kind == Token::Kind::EOF

            # Check for definitions inside class body
            if definition_start?
              expr = case token_text(current_token)
                when "def"
                  parse_def
                when "class"
                  parse_class
                else
                  parse_expression(0)
                end
            else
              expr = parse_expression(0)
            end
            body_ids << expr unless expr.invalid?
            consume_newlines
          end

          expect_identifier("end")
          end_token = previous_token
          consume_newlines

          class_span = if end_token
            class_token.span.cover(end_token.span)
          else
            class_token.span
          end
          @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::Class,
              class_span,
              class_name: name_token.slice,
              class_body: body_ids,
              class_super_name: super_name_token.try(&.slice),
            )
          )
        end

        private def skip_macro_parameters
          skip_trivia
          return unless current_token.kind == Token::Kind::Operator && token_text(current_token) == "("

          advance
          depth = 1
          while depth > 0 && current_token.kind != Token::Kind::EOF
            if current_token.kind == Token::Kind::Operator
              case token_text(current_token)
              when "("
                depth += 1
              when ")"
                depth -= 1
              end
            end
            advance
          end
        end

        private def parse_macro_body
          pieces = [] of MacroPiece
          buffer = IO::Memory.new
          buffer_start_token : Token? = nil
          control_depth = 0
          macro_trim_left = false
          macro_trim_right = false
          trim_next_left = false
          trim_final = false

          loop do
            if trim_next_left
              skip_macro_whitespace_after_escape
              trim_final = true  # Remember for final flush
              trim_next_left = false
            end

            token = current_token
            break if token.kind == Token::Kind::EOF

            if control_depth == 0 && token.kind == Token::Kind::Identifier && token_text(token) == "end"
              break
            end

            if macro_control_start?
              left_trim = macro_control_left_trim?
              already_empty = pieces.empty?
              trim_applied = left_trim
              flush_macro_text(buffer, pieces, trim_applied, buffer_start_token, previous_token)
              buffer_start_token = nil
              macro_trim_left ||= already_empty && trim_applied

              piece, effect, skip_whitespace = parse_macro_control_piece
              pieces << piece

              # Special handling for comment blocks - skip content
              if piece.control_keyword == "comment" && effect == :push
                comment_depth = 1
                # Skip tokens until matching {% end %}
                loop do
                  break if comment_depth == 0
                  break if current_token.kind == Token::Kind::EOF

                  if macro_control_start?
                    inner_piece, inner_effect, _ = parse_macro_control_piece
                    case inner_effect
                    when :push
                      comment_depth += 1
                    when :pop
                      comment_depth -= 1
                      if comment_depth == 0
                        pieces << inner_piece  # Add the closing {% end %}
                      end
                    end
                  else
                    # Skip any other tokens
                    advance
                  end
                end
                trim_next_left = skip_whitespace
                next
              end

              case effect
              when :push
                control_depth += 1
              when :pop
                break if control_depth == 0
                control_depth -= 1
              end

              macro_trim_right ||= skip_whitespace
              macro_trim_right ||= skip_whitespace
              trim_next_left = skip_whitespace
              next
            elsif macro_expression_start?
              left_trim = macro_expression_left_trim?
              already_empty = pieces.empty?
              trim_applied = left_trim
              flush_macro_text(buffer, pieces, trim_applied, buffer_start_token, previous_token)
              buffer_start_token = nil
              macro_trim_left ||= already_empty && trim_applied

              piece, skip_whitespace = parse_macro_expression_piece
              pieces << piece

              trim_next_left = skip_whitespace
              next
            end

            # Track start of text buffer
            if buffer_start_token.nil? && buffer.size == 0
              buffer_start_token = token
            end

            buffer.write(token.slice)
            advance
          end

          flush_macro_text(buffer, pieces, trim_final, buffer_start_token, previous_token)
          {
            pieces,
            macro_trim_left || pieces.first?.try(&.trim_left) || false,
            macro_trim_right || pieces.last?.try(&.trim_right) || false,
          }
        end
        private def flush_macro_text(buffer, pieces, trim_trailing = false, start_token : Token? = nil, end_token : Token? = nil)
          return if buffer.size == 0
          text = String.new(buffer.to_slice)
          text = text.rstrip if trim_trailing

          # Capture span if we have start and end tokens
          span = if start_token && end_token
            start_token.span.cover(end_token.span)
          elsif start_token
            start_token.span
          end

          pieces << MacroPiece.text(text, span)
          buffer.clear
        end

        private def parse_expression(precedence : Int32) : ExprId
          skip_trivia
          left = parse_prefix
          return PREFIX_ERROR if left.invalid?

          loop do
            skip_trivia
            token = current_token
            if macro_terminator_reached?(token)
              break
            end

            if token.kind == Token::Kind::Operator
              case token_text(token)
              when "("
                left = parse_parenthesized_call(left)
                next
              when "["
                left = parse_index(left)
                next
              when "."
                left = parse_member_access(left)
                next
              end
            end

            break unless infix?(token)
            current_precedence = precedence_for(token)
            break if current_precedence < precedence

            advance
            right = parse_expression(current_precedence + 1)
            if right.invalid?
              left = PREFIX_ERROR
              break
            end
            left = build_binary(left, token, right)
          end

          left
        end

        private def parse_prefix : ExprId
          token = current_token
          case token.kind
          when Token::Kind::Identifier
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::Identifier, token.span, literal: token.slice))
            advance
            id
          when Token::Kind::Number
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::Number, token.span, literal: token.slice))
            advance
            id
          when Token::Kind::String
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::String, token.span, literal: token.slice))
            advance
            id
          when Token::Kind::Operator
            op_text = token_text(token)
            if UNARY_OPERATORS.includes?(op_text)
              op = token
              advance
              right = parse_expression(UNARY_PRECEDENCE)
              return PREFIX_ERROR if right.invalid?
              operand_span = node_span(right)
              unary_span = op.span.cover(operand_span)
              @arena.add(ExpressionNode.new(ExpressionNode::Kind::Unary, unary_span, operator: op.slice, right: right))
            elsif op_text == "("
              parse_grouping
            else
              emit_unexpected(token)
              advance
              PREFIX_ERROR
            end
          when Token::Kind::EOF
            PREFIX_ERROR
          else
            emit_unexpected(token)
            advance
            PREFIX_ERROR
          end
        end

        private def parse_grouping : ExprId
          lparen = current_token
          advance
          expr = parse_expression(0)
          return PREFIX_ERROR if expr.invalid?
          expect_operator(")")
          closing_span = previous_token.try(&.span)
          grouping_span = cover_optional_spans(lparen.span, node_span(expr), closing_span)
          @arena.add(ExpressionNode.new(ExpressionNode::Kind::Grouping, grouping_span, left: expr))
        end

        private def parse_parenthesized_call(callee : ExprId) : ExprId
          lparen = current_token
          advance
          args = [] of ExprId
          skip_trivia
          unless current_token.kind == Token::Kind::Operator && token_text(current_token) == ")"
            loop do
              arg = parse_expression(0)
              args << arg unless arg.invalid?
              skip_trivia
              break unless current_token.kind == Token::Kind::Operator && token_text(current_token) == ","
              advance
              skip_trivia
            end
          end
          expect_operator(")")
          spans = [] of Span
          spans << lparen.span
          spans << node_span(callee)
          args.each { |arg| spans << node_span(arg) }
          if closing_span = previous_token.try(&.span)
            spans << closing_span
          end
          call_span = Span.cover_all(spans)
          @arena.add(ExpressionNode.new(ExpressionNode::Kind::Call, call_span, callee: callee, args: args))
        end

        private def parse_index(target : ExprId) : ExprId
          lbracket = current_token
          advance
          indexes = [] of ExprId
          skip_trivia
          unless current_token.kind == Token::Kind::Operator && token_text(current_token) == "]"
            loop do
              expr = parse_expression(0)
              indexes << expr unless expr.invalid?
              skip_trivia
              break unless current_token.kind == Token::Kind::Operator && token_text(current_token) == ","
              advance
              skip_trivia
            end
          end
          expect_operator("]")
          spans = [] of Span
          spans << lbracket.span
          spans << node_span(target)
          indexes.each { |idx| spans << node_span(idx) }
          if closing_span = previous_token.try(&.span)
            spans << closing_span
          end
          index_span = Span.cover_all(spans)
          @arena.add(ExpressionNode.new(ExpressionNode::Kind::Index, index_span, callee: target, args: indexes))
        end

        private def parse_member_access(receiver : ExprId) : ExprId
          dot = current_token
          advance
          skip_trivia
          member_token = current_token
          if member_token.kind == Token::Kind::Identifier
            spans = [] of Span
            spans << node_span(receiver)
            spans << dot.span
            spans << member_token.span
            member_span = Span.cover_all(spans)
            node = @arena.add(
              ExpressionNode.new(
                ExpressionNode::Kind::MemberAccess,
                member_span,
                left: receiver,
                member: member_token.slice,
              )
            )
            advance
            node
          else
            emit_unexpected(member_token)
            receiver
          end
        end

        private def expect_operator(symbol : String)
          token = current_token
          if token.kind == Token::Kind::Operator && token_text(token) == symbol
            advance
          else
            emit_unexpected(token)
          end
        end

        private def build_binary(left : ExprId, token : Token, right : ExprId) : ExprId
          @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::Binary,
              cover_optional_spans(node_span(left), token.span, node_span(right)),
              operator: token.slice,
              left: left,
              right: right,
            )
          )
        end

        private def infix?(token : Token)
          token.kind == Token::Kind::Operator && BINARY_PRECEDENCE.has_key?(token_text(token))
        end

        private def precedence_for(token : Token) : Int32
          BINARY_PRECEDENCE[token_text(token)]? || 0
        end

        private def emit_unexpected(token : Token)
          @diagnostics << Diagnostic.new("unexpected #{token.kind}", token.span)
        end

        private def token_text(token : Token) : String
          String.new(token.slice)
        end

        private def peek_token(offset = 1)
          index = @index + offset
          if index < @tokens.size
            @tokens[index]
          else
            @tokens.last
          end
        end

        private def consume_trim_marker?(marker : Char = '-')
          token = current_token
          if token.kind == Token::Kind::Operator && token_text(token) == marker.to_s
            advance
            true
          else
            false
          end

        end

        private def consume_macro_newline_escape?
          if operator_token?(current_token, "\\")
            advance
            true
          else
            false
          end
        end

        private def macro_expression_start?
          current = current_token
          return false unless current.kind == Token::Kind::Operator && token_text(current) == "{"
          peek = peek_token
          peek.kind == Token::Kind::Operator && token_text(peek) == "{"
        end

        private def macro_expression_left_trim?
          second = peek_token(1)
          third = peek_token(2)
          second.kind == Token::Kind::Operator && token_text(second) == "{" &&
            third.kind == Token::Kind::Operator && token_text(third) == "-"
        end

        private def macro_control_start?
          current = current_token
          return false unless current.kind == Token::Kind::Operator && token_text(current) == "{"
          peek = peek_token
          peek.kind == Token::Kind::Operator && token_text(peek) == "%"
        end

        private def macro_control_left_trim?
          second = peek_token(1)
          third = peek_token(2)
          second.kind == Token::Kind::Operator && token_text(second) == "%" &&
            third.kind == Token::Kind::Operator && token_text(third) == "-"
        end

        private def macro_terminator_reached?(token : Token)
          case @macro_terminator
          when :expression
            return true if operator_token?(token, "}")
            return true if operator_token?(token, "-") && operator_token?(peek_token(1), "}")
          when :control
            return true if operator_token?(token, "%")
            return true if operator_token?(token, "-") && operator_token?(peek_token(1), "%")
          end
          false
        end

        private def operator_token?(token : Token, value : String)
          token.kind == Token::Kind::Operator && token_text(token) == value
        end

        private def with_macro_terminator(terminator : Symbol)
          previous = @macro_terminator
          @macro_terminator = terminator
          result = yield
          @macro_terminator = previous
          result
        end

        private def skip_macro_whitespace
          while current_token.kind == Token::Kind::Whitespace
            advance
          end
        end

        private def skip_macro_whitespace_after_escape
          # After backslash escape, consume newline + leading whitespace
          if current_token.kind == Token::Kind::Newline
            advance
            while current_token.kind == Token::Kind::Whitespace
              advance
            end
          end
        end

        private def whitespace_token?(token : Token)
          token.kind == Token::Kind::Whitespace || token.kind == Token::Kind::Newline
        end

        private def parse_macro_for_header
          # Parse: identifier [, identifier] in expression
          vars = [] of String

          if current_token.kind == Token::Kind::Identifier
            vars << token_text(current_token)
            advance
          else
            emit_unexpected(current_token)
            return {vars, nil}
          end

          skip_macro_whitespace

          if operator_token?(current_token, ",")
            advance
            skip_macro_whitespace
            if current_token.kind == Token::Kind::Identifier
              vars << token_text(current_token)
              advance
            else
              emit_unexpected(current_token)
            end
            skip_macro_whitespace
          end

          if current_token.kind == Token::Kind::Identifier && token_text(current_token) == "in"
            advance
          else
            emit_unexpected(current_token)
            return {vars, nil}
          end

          skip_macro_whitespace

          iterable = with_macro_terminator(:control) { parse_expression(0) }

          {vars, iterable}
        end

        private def parse_macro_control_piece
          start_token = current_token
          expect_operator("{")
          expect_operator("%")
          trim_left = consume_trim_marker?
          skip_macro_whitespace

          keyword_token = current_token
          keyword = token_text(keyword_token)
          advance

          expr = nil
          iter_vars = nil
          iterable = nil

          case keyword
          when "for"
            skip_macro_whitespace
            iter_vars, iterable = parse_macro_for_header
          when "if", "unless", "while", "elsif"
            skip_macro_whitespace
            expr = with_macro_terminator(:control) { parse_expression(0) }
          when "else", "end", "comment"
            # no expression
          else
            emit_unexpected(keyword_token)
          end

          skip_macro_whitespace
          trim_right = false
          if (operator_token?(current_token, "-") || operator_token?(current_token, "~")) && operator_token?(peek_token(1), "%")
            advance
            trim_right = true
          end

          expect_operator("%")
          expect_operator("}")
          end_token = previous_token

          newline_escape = consume_macro_newline_escape?
          skip_whitespace = trim_right || newline_escape

          kind = case keyword
            when "else"
              MacroPiece::Kind::ControlElse
            when "elsif"
              MacroPiece::Kind::ControlElseIf
            when "end"
              MacroPiece::Kind::ControlEnd
            else
              MacroPiece::Kind::ControlStart
            end

          # Capture span covering full {% ... %} section
          control_span = if end_token
            start_token.span.cover(end_token.span)
          else
            start_token.span
          end

          piece = MacroPiece.control(kind, keyword, expr, trim_left, trim_right, iter_vars, iterable, control_span)
          # store trim flags later if needed

          effect = case keyword
            when "if", "unless", "for", "while", "comment"
              :push
            when "end"
              :pop
            else
              :none
            end

          {piece, effect, skip_whitespace}
        end

        private def expect_identifier(expected : String)
          token = current_token
          if token.kind == Token::Kind::Identifier && token_text(token) == expected
            advance
          else
            emit_unexpected(token)
          end
        end

        private def parse_macro_expression_piece
          start_token = current_token
          expect_operator("{")
          expect_operator("{")
          left_trim = consume_trim_marker?('-') || consume_trim_marker?('~')
          skip_macro_whitespace
          expr = with_macro_terminator(:expression) { parse_expression(0) }
          skip_macro_whitespace

          right_trim = false
          if (operator_token?(current_token, "-") || operator_token?(current_token, "~")) && operator_token?(peek_token(1), "}")
            advance
            right_trim = true
          end
          advance if right_trim

          expect_operator("}")
          expect_operator("}")
          closing_span = previous_token.try(&.span)

          newline_escape = consume_macro_newline_escape?
          skip_whitespace = right_trim || newline_escape

          macro_span = closing_span ? start_token.span.cover(closing_span) : start_token.span
          macro_expr_id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::MacroExpression, macro_span, macro_expr: expr))
          piece = MacroPiece.expression(macro_expr_id, left_trim, right_trim, macro_span)
          {piece, skip_whitespace}
        end

        private def node_span(id : ExprId) : Span
          @arena[id].span
        end

        private def cover_optional_spans(*spans : Span?) : Span
          filtered = spans.to_a.compact
          raise ArgumentError.new("cover_optional_spans requires at least one span") if filtered.empty?
          Span.cover_all(filtered)
        end

        BINARY_PRECEDENCE = {
          "+" => 10,
          "-" => 10,
          "*" => 20,
          "/" => 20,
        }

        UNARY_OPERATORS = {"+", "-"}
      end
    end
  end
end
