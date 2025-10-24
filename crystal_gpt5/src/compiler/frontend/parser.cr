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
              node = case current_token.kind
                when Token::Kind::Def
                  parse_def
                when Token::Kind::Class
                  parse_class
                else
                  PREFIX_ERROR
                end
              roots << node unless node.invalid?
              consume_newlines
              next
            end

            expr = parse_statement
            roots << expr unless expr.invalid?
            consume_newlines
          end
          Program.new(@arena, roots)
        end

        # Parse a statement (assignment or expression)
        private def parse_statement : ExprId
          # Phase 6: Check for return statement
          if current_token.kind == Token::Kind::Return
            stmt = parse_return
            return parse_postfix_if_modifier(stmt)
          end

          # Phase 10: yield statements
          if current_token.kind == Token::Kind::Yield
            stmt = parse_yield
            return parse_postfix_if_modifier(stmt)
          end

          # Phase 12: break statements
          if current_token.kind == Token::Kind::Break
            stmt = parse_break
            return parse_postfix_if_modifier(stmt)
          end

          # Phase 12: next statements
          if current_token.kind == Token::Kind::Next
            stmt = parse_next
            return parse_postfix_if_modifier(stmt)
          end

          # Parse left side (could be identifier or expression)
          left = parse_expression(0)
          return PREFIX_ERROR if left.invalid?

          skip_trivia
          token = current_token

          # Check for assignment: identifier = value or compound assignment (+=, -=, etc.)
          if token.kind == Token::Kind::Eq ||
             token.kind == Token::Kind::PlusEq ||
             token.kind == Token::Kind::MinusEq ||
             token.kind == Token::Kind::StarEq ||
             token.kind == Token::Kind::SlashEq ||
             token.kind == Token::Kind::PercentEq ||
             token.kind == Token::Kind::StarStarEq
            # Verify left side is an identifier, instance variable, or index (Phase 14B: hash/array assignment)
            left_node = @arena[left]
            unless left_node.kind == ExpressionNode::Kind::Identifier ||
                   left_node.kind == ExpressionNode::Kind::InstanceVar ||
                   left_node.kind == ExpressionNode::Kind::Index
              @diagnostics << Diagnostic.new("Assignment target must be an identifier, instance variable, or index expression", token.span)
              return PREFIX_ERROR
            end

            # Consume assignment token
            assign_token = token
            is_compound = assign_token.kind != Token::Kind::Eq
            advance
            skip_trivia

            # Parse right-hand side expression
            rhs = parse_expression(0)
            return PREFIX_ERROR if rhs.invalid?

            # Phase 20: Desugar compound assignment
            # x += 5  =>  x = x + 5
            value = if is_compound
              # Map compound token to operator
              operator = case assign_token.kind
              when Token::Kind::PlusEq     then "+"
              when Token::Kind::MinusEq    then "-"
              when Token::Kind::StarEq     then "*"
              when Token::Kind::SlashEq    then "/"
              when Token::Kind::PercentEq  then "%"
              when Token::Kind::StarStarEq then "**"
              else
                ""
              end

              # Create binary expression: left op rhs
              # Use left node's span for the cloned left reference
              rhs_span = node_span(rhs)
              binary_span = left_node.span.cover(rhs_span)

              @arena.add(ExpressionNode.new(
                ExpressionNode::Kind::Binary,
                binary_span,
                operator: operator.to_slice,
                left: left,
                right: rhs
              ))
            else
              # Regular assignment: just use rhs
              rhs
            end

            # Create Assign node
            value_span = node_span(value)
            assign_span = left_node.span.cover(value_span)

            stmt = @arena.add(ExpressionNode.new(
              ExpressionNode::Kind::Assign,
              assign_span,
              assign_target: left,
              assign_value: value
            ))
            return parse_postfix_if_modifier(stmt)
          end

          # Not an assignment, check for postfix if
          parse_postfix_if_modifier(left)
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
          token = current_token
          token.kind == Token::Kind::Def || token.kind == Token::Kind::Class
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

          # Parse optional return type annotation: : ReturnType
          return_type = nil
          skip_trivia
          if operator_token?(current_token, Token::Kind::Colon)
            advance  # consume ':'
            skip_trivia

            # Parse return type (simple identifier for Phase 4A)
            type_token = current_token
            if type_token.kind == Token::Kind::Identifier
              return_type = type_token.slice
              advance
            else
              emit_unexpected(type_token)
            end
          end

          consume_newlines

          body_ids = [] of ExprId
          loop do
            skip_trivia
            token = current_token
            break if token.kind == Token::Kind::End
            break if token.kind == Token::Kind::EOF

            # Phase 5B: Use parse_statement to handle assignments in method bodies
            expr = parse_statement
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
              def_return_type: return_type,
              def_body: body_ids,
            )
          )
        end

        private def parse_method_params
          params = [] of Parameter
          skip_trivia
          return params unless operator_token?(current_token, Token::Kind::LParen)

          advance
          skip_trivia
          unless operator_token?(current_token, Token::Kind::RParen)
            loop do
              # Parse parameter name
              name_token = current_token
              unless name_token.kind == Token::Kind::Identifier
                emit_unexpected(name_token)
                break
              end
              param_name = token_text(name_token)
              param_name_span = name_token.span
              param_start_span = name_token.span
              advance
              skip_trivia

              # Parse optional type annotation: : Type
              type_annotation = nil
              param_type_span = nil
              if operator_token?(current_token, Token::Kind::Colon)
                advance  # consume ':'
                skip_trivia

                # Parse type name (simple identifier for Phase 4A)
                type_token = current_token
                if type_token.kind == Token::Kind::Identifier
                  type_annotation = token_text(type_token)
                  param_type_span = type_token.span
                  advance
                  skip_trivia
                else
                  emit_unexpected(type_token)
                end
              end

              # Calculate full parameter span
              param_span = if param_type_span
                param_start_span.cover(param_type_span)
              else
                param_start_span
              end

              params << Parameter.new(
                param_name,
                type_annotation,
                param_span,
                param_name_span,
                param_type_span
              )

              break unless operator_token?(current_token, Token::Kind::Comma)
              advance
              skip_trivia
            end
          end

          expect_operator(Token::Kind::RParen)
          params
        end

        private def parse_if : ExprId
          if_token = current_token
          advance
          skip_trivia

          # Parse condition
          condition = parse_expression(0)
          return PREFIX_ERROR if condition.invalid?

          skip_trivia
          # Optional "then" keyword
          token = current_token
          if token.kind == Token::Kind::Then
            advance
          end
          consume_newlines

          # Parse then body
          then_body = [] of ExprId
          loop do
            skip_trivia
            token = current_token
            break if token.kind == Token::Kind::Elsif || token.kind == Token::Kind::Else || token.kind == Token::Kind::End
            break if token.kind == Token::Kind::EOF

            expr = parse_statement
            then_body << expr unless expr.invalid?
            consume_newlines
          end

          # Parse optional elsif branches
          elsifs = [] of ElsifBranch
          loop do
            skip_trivia
            token = current_token
            break unless token.kind == Token::Kind::Elsif

            # Save elsif token for span
            elsif_token = token
            advance
            skip_trivia

            # Parse elsif condition
            elsif_condition = parse_expression(0)
            return PREFIX_ERROR if elsif_condition.invalid?

            skip_trivia
            # Optional "then" keyword
            token = current_token
            if token.kind == Token::Kind::Then
              advance
            end
            consume_newlines

            # Parse elsif body
            elsif_body = [] of ExprId
            loop do
              skip_trivia
              token = current_token
              break if token.kind == Token::Kind::Elsif || token.kind == Token::Kind::Else || token.kind == Token::Kind::End
              break if token.kind == Token::Kind::EOF

              expr = parse_statement
              elsif_body << expr unless expr.invalid?
              consume_newlines
            end

            # Capture elsif span (from elsif keyword to last expression)
            elsif_span = if elsif_body.size > 0
              last_expr = @arena[elsif_body.last]
              elsif_token.span.cover(last_expr.span)
            else
              elsif_token.span
            end

            elsifs << ElsifBranch.new(elsif_condition, elsif_body, elsif_span)
          end

          # Parse optional else body
          else_body = nil
          token = current_token
          if token.kind == Token::Kind::Else
            advance
            consume_newlines

            else_body = [] of ExprId
            loop do
              skip_trivia
              token = current_token
              break if token.kind == Token::Kind::End
              break if token.kind == Token::Kind::EOF

              expr = parse_statement
              else_body << expr unless expr.invalid?
              consume_newlines
            end
          end

          expect_identifier("end")
          end_token = previous_token
          consume_newlines

          if_span = if end_token
            if_token.span.cover(end_token.span)
          else
            if_token.span
          end

          # Set elsifs to nil if array is empty (cleaner AST)
          elsifs_field = elsifs.size > 0 ? elsifs : nil

          @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::If,
              if_span,
              if_condition: condition,
              if_then: then_body,
              if_elsifs: elsifs_field,
              if_else: else_body,
            )
          )
        end

        # Phase 11: Parse case/when expression
        # Grammar: case <value>
        #          when <cond1>, <cond2> [then]
        #            <body>
        #          [else
        #            <body>]
        #          end
        private def parse_case : ExprId
          case_token = current_token
          advance
          skip_trivia

          # Parse case value
          value = parse_expression(0)
          return PREFIX_ERROR if value.invalid?

          consume_newlines

          # Parse when branches
          when_branches = [] of WhenBranch
          loop do
            skip_trivia
            token = current_token
            break unless token.kind == Token::Kind::When

            when_token = token
            advance
            skip_trivia

            # Parse when conditions (comma-separated)
            conditions = [] of ExprId
            loop do
              cond = parse_expression(0)
              return PREFIX_ERROR if cond.invalid?
              conditions << cond

              skip_trivia
              break unless current_token.kind == Token::Kind::Comma
              advance  # consume comma
              skip_trivia
            end

            skip_trivia

            # Optional "then" keyword
            if current_token.kind == Token::Kind::Then
              advance
            end

            consume_newlines

            # Parse when body
            when_body = [] of ExprId
            loop do
              skip_trivia
              token = current_token
              break if token.kind.in?(Token::Kind::When, Token::Kind::Else, Token::Kind::End, Token::Kind::EOF)

              stmt = parse_statement
              when_body << stmt unless stmt.invalid?
              consume_newlines
            end

            # Capture when span
            when_span = if when_body.size > 0
              last_expr = @arena[when_body.last]
              when_token.span.cover(last_expr.span)
            else
              when_token.span
            end

            when_branches << WhenBranch.new(conditions, when_body, when_span)
          end

          # Parse optional else body
          else_body = nil
          token = current_token
          if token.kind == Token::Kind::Else
            advance
            consume_newlines

            else_body = [] of ExprId
            loop do
              skip_trivia
              token = current_token
              break if token.kind == Token::Kind::End
              break if token.kind == Token::Kind::EOF

              expr = parse_statement
              else_body << expr unless expr.invalid?
              consume_newlines
            end
          end

          expect_identifier("end")
          end_token = previous_token
          consume_newlines

          case_span = if end_token
            case_token.span.cover(end_token.span)
          else
            case_token.span
          end

          @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::Case,
              case_span,
              case_value: value,
              when_branches: when_branches,
              case_else: else_body,
            )
          )
        end

        private def parse_while : ExprId
          while_token = current_token
          advance
          skip_trivia

          # Parse condition
          condition = parse_expression(0)
          return PREFIX_ERROR if condition.invalid?

          skip_trivia
          # Optional "do" keyword
          token = current_token
          if token.kind == Token::Kind::Do
            advance
          end
          consume_newlines

          # Parse body
          body_ids = [] of ExprId
          loop do
            skip_trivia
            token = current_token
            break if token.kind == Token::Kind::End
            break if token.kind == Token::Kind::EOF

            expr = parse_statement
            body_ids << expr unless expr.invalid?
            consume_newlines
          end

          expect_identifier("end")
          end_token = previous_token
          consume_newlines

          while_span = if end_token
            while_token.span.cover(end_token.span)
          else
            while_token.span
          end

          @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::While,
              while_span,
              while_condition: condition,
              while_body: body_ids,
            )
          )
        end

        # Phase 6: Parse return statement
        # Grammar: return | return <expression>
        private def parse_return : ExprId
          return_token = current_token
          advance
          skip_trivia

          # Check if there's a return value
          # return without value if: newline, EOF, end, else, elsif, if (for postfix)
          token = current_token
          if token.kind.in?(Token::Kind::Newline, Token::Kind::EOF, Token::Kind::End, Token::Kind::Else, Token::Kind::Elsif, Token::Kind::If)
            # Return without value (implicit nil)
            @arena.add(
              ExpressionNode.new(
                ExpressionNode::Kind::Return,
                return_token.span,
                return_value: nil
              )
            )
          else
            # Return with value
            value = parse_expression(0)
            return PREFIX_ERROR if value.invalid?

            value_span = node_span(value)
            return_span = return_token.span.cover(value_span)

            @arena.add(
              ExpressionNode.new(
                ExpressionNode::Kind::Return,
                return_span,
                return_value: value
              )
            )
          end
        end

        # Phase 12: Parse break expression
        # Grammar: break [value]
        private def parse_break : ExprId
          break_token = current_token
          advance
          skip_trivia

          # Check if there's a break value
          # break without value if: newline, EOF, end, else, elsif, if (for postfix)
          token = current_token
          if token.kind.in?(Token::Kind::Newline, Token::Kind::EOF, Token::Kind::End, Token::Kind::Else, Token::Kind::Elsif, Token::Kind::If)
            # Break without value (returns nil from loop)
            @arena.add(
              ExpressionNode.new(
                ExpressionNode::Kind::Break,
                break_token.span,
                break_value: nil
              )
            )
          else
            # Break with value
            value = parse_expression(0)
            return PREFIX_ERROR if value.invalid?

            value_span = node_span(value)
            break_span = break_token.span.cover(value_span)

            @arena.add(
              ExpressionNode.new(
                ExpressionNode::Kind::Break,
                break_span,
                break_value: value
              )
            )
          end
        end

        # Phase 12: Parse next expression
        # Grammar: next
        private def parse_next : ExprId
          next_token = current_token
          advance

          # Next has no value in Crystal
          @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::Next,
              next_token.span
            )
          )
        end

        # Phase 10: Parse yield expression
        # Grammar: yield [arg1, arg2, ...]
        private def parse_yield : ExprId
          yield_token = current_token
          advance
          skip_trivia

          # Check if there are yield arguments
          # yield without args if: newline, EOF, end, else, elsif, if (for postfix), do, }
          token = current_token
          if token.kind.in?(Token::Kind::Newline, Token::Kind::EOF, Token::Kind::End, Token::Kind::Else, Token::Kind::Elsif, Token::Kind::If, Token::Kind::Do, Token::Kind::RBrace)
            # Yield without args
            @arena.add(
              ExpressionNode.new(
                ExpressionNode::Kind::Yield,
                yield_token.span,
                yield_args: [] of ExprId
              )
            )
          else
            # Yield with args - parse comma-separated expressions
            args = [] of ExprId
            loop do
              arg = parse_expression(0)
              return PREFIX_ERROR if arg.invalid?
              args << arg

              skip_trivia
              break if current_token.kind != Token::Kind::Comma

              advance  # consume comma
              skip_trivia
            end

            last_arg_span = node_span(args.last)
            yield_span = yield_token.span.cover(last_arg_span)

            @arena.add(
              ExpressionNode.new(
                ExpressionNode::Kind::Yield,
                yield_span,
                yield_args: args
              )
            )
          end
        end

        # Phase 10: Parse block
        # Grammar: { |params| body } or do |params| body end
        private def parse_block : ExprId
          is_brace_form = current_token.kind == Token::Kind::LBrace
          start_token = current_token
          advance  # consume { or do
          skip_trivia

          # Parse optional block parameters: |x, y|
          params = [] of Parameter
          if current_token.kind == Token::Kind::Operator && token_text(current_token) == "|"
            advance  # consume opening |
            skip_trivia

            # Parse parameter list
            loop do
              name_token = current_token
              unless name_token.kind == Token::Kind::Identifier
                emit_unexpected(name_token)
                return PREFIX_ERROR
              end

              param_name = token_text(name_token)
              param_name_span = name_token.span
              param_span = name_token.span
              advance
              skip_trivia

              # TODO: Support type annotations in block params
              # For now, block params only have name (no type annotation)
              params << Parameter.new(
                param_name,
                nil,              # no type annotation
                param_span,       # full span = name span for now
                param_name_span,  # name span
                nil               # no type span
              )

              # Check for comma or closing |
              if current_token.kind == Token::Kind::Comma
                advance
                skip_trivia
              elsif current_token.kind == Token::Kind::Operator && token_text(current_token) == "|"
                break
              else
                emit_unexpected(current_token)
                return PREFIX_ERROR
              end
            end

            advance  # consume closing |
            skip_trivia
          end

          # Parse block body
          body = [] of ExprId
          loop do
            skip_trivia

            # Skip newlines in block body
            while current_token.kind == Token::Kind::Newline
              advance
              skip_trivia
            end

            # Check for block terminator
            if is_brace_form
              break if current_token.kind == Token::Kind::RBrace
            else
              break if current_token.kind == Token::Kind::End
            end

            break if current_token.kind == Token::Kind::EOF

            stmt = parse_statement
            return PREFIX_ERROR if stmt.invalid?
            body << stmt
          end

          # Consume closing delimiter
          end_token = current_token
          unless (is_brace_form && current_token.kind == Token::Kind::RBrace) ||
                 (!is_brace_form && current_token.kind == Token::Kind::End)
            emit_unexpected(current_token)
            return PREFIX_ERROR
          end
          advance

          block_span = start_token.span.cover(end_token.span)
          @arena.add(ExpressionNode.new(
            ExpressionNode::Kind::Block,
            block_span,
            block_params: params,
            block_body: body
          ))
        end

        # Phase 10: Attach block to method call
        private def attach_block_to_call(call_expr : ExprId) : ExprId
          # Parse the block
          block_id = parse_block
          return PREFIX_ERROR if block_id.invalid?

          # Get the call node
          call_node = @arena[call_expr]
          block_span = node_span(block_id)
          call_span = call_node.span.cover(block_span)

          # If it's an identifier, convert it to a call (e.g., "three_times do |n| ... end")
          if call_node.kind == ExpressionNode::Kind::Identifier
            return @arena.add(ExpressionNode.new(
              ExpressionNode::Kind::Call,
              call_span,
              callee: call_expr,
              args: [] of ExprId,
              call_block: block_id
            ))
          end

          # Verify it's a Call or MemberAccess
          unless call_node.kind.in?(ExpressionNode::Kind::Call, ExpressionNode::Kind::MemberAccess)
            @diagnostics << Diagnostic.new("Block can only be attached to method call or identifier", call_node.span)
            return PREFIX_ERROR
          end

          # Create new Call node with block attached
          @arena.add(ExpressionNode.new(
            call_node.kind,
            call_span,
            callee: call_node.callee,
            member: call_node.member,
            args: call_node.args,
            call_block: block_id
          ))
        end

        # Phase 6: Handle postfix if modifier
        # Grammar: <statement> if <condition>
        private def parse_postfix_if_modifier(stmt : ExprId) : ExprId
          skip_trivia
          token = current_token

          # Check for postfix if
          if token.kind == Token::Kind::If
            advance  # consume 'if'
            skip_trivia

            # Parse condition
            condition = parse_expression(0)
            return PREFIX_ERROR if condition.invalid?

            # Wrap statement in an if node
            stmt_span = node_span(stmt)
            condition_span = node_span(condition)
            if_span = stmt_span.cover(condition_span)

            return @arena.add(
              ExpressionNode.new(
                ExpressionNode::Kind::If,
                if_span,
                if_condition: condition,
                if_then: [stmt],
                if_else: [] of ExprId
              )
            )
          end

          # No postfix if, return statement as-is
          stmt
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
          if current_token.kind == Token::Kind::Less
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
            break if token.kind == Token::Kind::End
            break if token.kind == Token::Kind::EOF

            # Phase 5C: Instance variable declaration (@var : Type)
            # At class body level, @var can only be a type declaration
            if token.kind == Token::Kind::InstanceVar
              expr = parse_instance_var_decl
            elsif definition_start?
              expr = case current_token.kind
                when Token::Kind::Def
                  parse_def
                when Token::Kind::Class
                  parse_class
                else
                  # Phase 5B: Use parse_statement for assignments
                  parse_statement
                end
            else
              # Phase 5B: Use parse_statement for assignments
              expr = parse_statement
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

        # Phase 5C: Parse instance variable declaration: @var : Type
        private def parse_instance_var_decl : ExprId
          ivar_token = current_token
          unless ivar_token.kind == Token::Kind::InstanceVar
            emit_unexpected(ivar_token)
            return PREFIX_ERROR
          end
          advance  # consume @var

          skip_trivia

          # Expect colon
          unless current_token.kind == Token::Kind::Colon
            emit_unexpected(current_token)
            return PREFIX_ERROR
          end
          advance  # consume :

          skip_trivia

          # Expect type identifier
          type_token = current_token
          unless type_token.kind == Token::Kind::Identifier
            emit_unexpected(type_token)
            return PREFIX_ERROR
          end
          advance  # consume type

          decl_span = ivar_token.span.cover(type_token.span)

          @arena.add(
            ExpressionNode.new(
              ExpressionNode::Kind::InstanceVarDecl,
              decl_span,
              literal: ivar_token.slice,       # @var
              ivar_decl_type: type_token.slice  # Type
            )
          )
        end

        private def skip_macro_parameters
          skip_trivia
          return unless current_token.kind == Token::Kind::LParen

          advance
          depth = 1
          while depth > 0 && current_token.kind != Token::Kind::EOF
            case current_token.kind
            when Token::Kind::LParen
              depth += 1
            when Token::Kind::RParen
              depth -= 1
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

            if control_depth == 0 && token.kind == Token::Kind::End
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

        protected def parse_expression(precedence : Int32) : ExprId
          skip_trivia
          left = parse_prefix
          return PREFIX_ERROR if left.invalid?

          loop do
            skip_trivia
            token = current_token
            if macro_terminator_reached?(token)
              break
            end

            case token.kind
            when Token::Kind::LParen
              left = parse_parenthesized_call(left)
              next
            when Token::Kind::LBracket
              left = parse_index(left)
              next
            when Token::Kind::LBrace
              # Phase 10: Block with {} syntax
              left = attach_block_to_call(left)
              next
            when Token::Kind::Do
              # Phase 10: Block with do/end syntax
              left = attach_block_to_call(left)
              next
            when Token::Kind::Operator
              # Check for operators not yet converted to enum (e.g., ".")
              case token_text(token)
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

            # Phase 13: Handle range operators specially
            if token.kind == Token::Kind::DotDot || token.kind == Token::Kind::DotDotDot
              exclusive = token.kind == Token::Kind::DotDotDot
              left = @arena.add(
                ExpressionNode.new(
                  ExpressionNode::Kind::Range,
                  cover_optional_spans(node_span(left), token.span, node_span(right)),
                  range_begin: left,
                  range_end: right,
                  range_exclusive: exclusive,
                )
              )
            else
              left = build_binary(left, token, right)
            end
          end

          left
        end

        private def parse_prefix : ExprId
          token = current_token
          case token.kind
          when Token::Kind::True, Token::Kind::False
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::Bool, token.span, literal: token.slice))
            advance
            id
          when Token::Kind::Nil
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::Nil, token.span, literal: token.slice))
            advance
            id
          when Token::Kind::Self
            # Phase 7: self keyword
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::Self, token.span))
            advance
            id
          when Token::Kind::If
            parse_if
          when Token::Kind::Case
            # Phase 11: case/when pattern matching
            parse_case
          when Token::Kind::While
            parse_while
          when Token::Kind::Identifier
            # Regular identifier
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::Identifier, token.span, literal: token.slice))
            advance
            id
          when Token::Kind::InstanceVar
            # Instance variable (@var)
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::InstanceVar, token.span, literal: token.slice))
            advance
            id
          when Token::Kind::Number
            id = @arena.add(ExpressionNode.new(
              ExpressionNode::Kind::Number,
              token.span,
              literal: token.slice,
              number_kind: token.number_kind
            ))
            advance
            id
          when Token::Kind::String
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::String, token.span, literal: token.slice))
            advance
            id
          when Token::Kind::StringInterpolation
            # Phase 8: String interpolation
            parse_string_interpolation(token)
          when Token::Kind::Symbol
            # Phase 16: Symbol literal
            id = @arena.add(ExpressionNode.new(ExpressionNode::Kind::Symbol, token.span, literal: token.slice))
            advance
            id
          when Token::Kind::Plus, Token::Kind::Minus, Token::Kind::Not, Token::Kind::Tilde
            # Unary operators (Phase 21: added Tilde for bitwise NOT)
            op = token
            advance
            right = parse_expression(UNARY_PRECEDENCE)
            return PREFIX_ERROR if right.invalid?
            operand_span = node_span(right)
            unary_span = op.span.cover(operand_span)
            @arena.add(ExpressionNode.new(ExpressionNode::Kind::Unary, unary_span, operator: op.slice, right: right))
          when Token::Kind::LParen
            parse_grouping
          when Token::Kind::LBracket
            # Phase 9: Array literal
            parse_array_literal
          when Token::Kind::LBrace
            # Phase 14/15: Hash or Tuple literal (disambiguated by presence of =>)
            parse_hash_or_tuple
          when Token::Kind::Operator
            # Generic fallback for unhandled operators (e.g., macro operators)
            op_text = token_text(token)
            if op_text == "("
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
          expect_operator(Token::Kind::RParen)
          closing_span = previous_token.try(&.span)
          grouping_span = cover_optional_spans(lparen.span, node_span(expr), closing_span)
          @arena.add(ExpressionNode.new(ExpressionNode::Kind::Grouping, grouping_span, left: expr))
        end

        # Phase 9: Parse array literal [1, 2, 3] or [] of Type
        private def parse_array_literal : ExprId
          lbracket = current_token
          advance
          skip_trivia

          elements = [] of ExprId
          of_type : Slice(UInt8)? = nil

          # Check for closing bracket (empty array)
          if current_token.kind == Token::Kind::RBracket
            advance
            skip_trivia

            # Check for "of Type" syntax
            if current_token.kind == Token::Kind::Identifier && token_text(current_token) == "of"
              advance
              skip_trivia

              # Parse type name
              type_token = current_token
              if type_token.kind == Token::Kind::Identifier
                of_type = type_token.slice
                advance
              else
                emit_unexpected(type_token)
                return PREFIX_ERROR
              end
            end

            closing_span = previous_token.try(&.span) || lbracket.span
            array_span = lbracket.span.cover(closing_span)
            return @arena.add(ExpressionNode.new(
              ExpressionNode::Kind::ArrayLiteral,
              array_span,
              array_elements: elements,
              array_of_type: of_type
            ))
          end

          # Parse array elements
          loop do
            element = parse_expression(0)
            if element.invalid?
              return PREFIX_ERROR
            end
            elements << element

            skip_trivia
            break if current_token.kind != Token::Kind::Comma

            advance  # consume comma
            skip_trivia

            # Allow trailing comma
            break if current_token.kind == Token::Kind::RBracket
          end

          # Expect closing bracket
          unless current_token.kind == Token::Kind::RBracket
            emit_unexpected(current_token)
            return PREFIX_ERROR
          end

          closing_bracket = current_token
          advance

          array_span = lbracket.span.cover(closing_bracket.span)
          @arena.add(ExpressionNode.new(
            ExpressionNode::Kind::ArrayLiteral,
            array_span,
            array_elements: elements,
            array_of_type: of_type
          ))
        end

        # Phase 14: Parse hash literal {"key" => value} or {} of K => V
        private def parse_hash_literal : ExprId
          lbrace = current_token
          advance  # consume {
          skip_trivia

          entries = [] of HashEntry
          of_key_type : Slice(UInt8)? = nil
          of_value_type : Slice(UInt8)? = nil

          # Check for closing brace (empty hash)
          if current_token.kind == Token::Kind::RBrace
            advance  # consume }
            skip_trivia

            # Check for "of K => V" syntax
            if current_token.kind == Token::Kind::Identifier && token_text(current_token) == "of"
              advance
              skip_trivia

              # Parse key type
              key_type_token = current_token
              if key_type_token.kind == Token::Kind::Identifier
                of_key_type = key_type_token.slice
                advance
                skip_trivia

                # Expect =>
                unless current_token.kind == Token::Kind::Arrow
                  emit_unexpected(current_token)
                  return PREFIX_ERROR
                end
                advance  # consume =>
                skip_trivia

                # Parse value type
                value_type_token = current_token
                if value_type_token.kind == Token::Kind::Identifier
                  of_value_type = value_type_token.slice
                  advance
                else
                  emit_unexpected(value_type_token)
                  return PREFIX_ERROR
                end
              else
                emit_unexpected(key_type_token)
                return PREFIX_ERROR
              end
            end

            closing_span = previous_token.try(&.span) || lbrace.span
            hash_span = lbrace.span.cover(closing_span)
            return @arena.add(ExpressionNode.new(
              ExpressionNode::Kind::HashLiteral,
              hash_span,
              hash_entries: entries,
              hash_of_key_type: of_key_type,
              hash_of_value_type: of_value_type
            ))
          end

          # Parse hash entries: key => value, key => value, ...
          loop do
            # Parse key
            key = parse_expression(0)
            if key.invalid?
              return PREFIX_ERROR
            end
            key_span = node_span(key)

            skip_trivia

            # Expect =>
            unless current_token.kind == Token::Kind::Arrow
              emit_unexpected(current_token)
              return PREFIX_ERROR
            end
            arrow_token = current_token
            advance  # consume =>
            skip_trivia

            # Parse value
            value = parse_expression(0)
            if value.invalid?
              return PREFIX_ERROR
            end
            value_span = node_span(value)

            # Create entry with precise spans for LSP/diagnostics
            entry_span = key_span.cover(value_span)
            entries << HashEntry.new(key, value, entry_span, arrow_token.span)

            skip_trivia
            break if !(current_token.kind == Token::Kind::Comma)

            advance  # consume comma
            skip_trivia

            # Allow trailing comma
            if current_token.kind == Token::Kind::RBrace
              break
            end
          end

          # Expect closing brace
          unless current_token.kind == Token::Kind::RBrace
            emit_unexpected(current_token)
            return PREFIX_ERROR
          end

          closing_brace = current_token
          advance

          hash_span = lbrace.span.cover(closing_brace.span)
          @arena.add(ExpressionNode.new(
            ExpressionNode::Kind::HashLiteral,
            hash_span,
            hash_entries: entries,
            hash_of_key_type: of_key_type,
            hash_of_value_type: of_value_type
          ))
        end

        # Phase 14/15: Disambiguate hash vs tuple literal
        # Hash: {"key" => value} or {} of K => V
        # Tuple: {1, 2, 3} or {value} or {value,}
        #
        # Strategy: Look ahead after first element
        # - If we see "=>" → hash
        # - If we see "," or "}" → tuple
        # - Empty "{}" → hash (existing behavior)
        private def parse_hash_or_tuple : ExprId
          lbrace = current_token
          advance  # consume {
          skip_trivia

          # Empty {} → hash
          if current_token.kind == Token::Kind::RBrace
            # Empty hash - delegate to parse_hash_literal
            return parse_hash_literal_from_lbrace(lbrace)
          end

          # Parse first element (key for hash, value for tuple)
          first_elem = parse_expression(0)
          return PREFIX_ERROR if first_elem.invalid?
          skip_trivia

          # Check what follows
          case current_token.kind
          when Token::Kind::Arrow
            # "=>" → this is a hash
            return parse_hash_literal_continued(lbrace, first_elem)
          when Token::Kind::Comma, Token::Kind::RBrace
            # "," or "}" → this is a tuple
            return parse_tuple_literal_continued(lbrace, first_elem)
          else
            # Unexpected token
            emit_unexpected(current_token)
            return PREFIX_ERROR
          end
        end

        # Phase 15: Continue parsing tuple literal after first element
        private def parse_tuple_literal_continued(lbrace : Token, first_elem : ExprId) : ExprId
          elements = [first_elem]

          # Check for comma or closing brace
          loop do
            case current_token.kind
            when Token::Kind::RBrace
              # End of tuple
              break
            when Token::Kind::Comma
              advance  # consume comma
              skip_trivia

              # Allow trailing comma
              if current_token.kind == Token::Kind::RBrace
                break
              end

              # Parse next element
              elem = parse_expression(0)
              return PREFIX_ERROR if elem.invalid?
              elements << elem
              skip_trivia
            else
              emit_unexpected(current_token)
              return PREFIX_ERROR
            end
          end

          # Expect closing brace
          unless current_token.kind == Token::Kind::RBrace
            emit_unexpected(current_token)
            return PREFIX_ERROR
          end

          closing_brace = current_token
          advance

          tuple_span = lbrace.span.cover(closing_brace.span)
          @arena.add(ExpressionNode.new(
            ExpressionNode::Kind::TupleLiteral,
            tuple_span,
            tuple_elements: elements
          ))
        end

        # Phase 14: Parse empty hash literal
        private def parse_hash_literal_from_lbrace(lbrace : Token) : ExprId
          # Current token is RBrace
          advance  # consume }
          skip_trivia

          entries = [] of HashEntry
          of_key_type : Slice(UInt8)? = nil
          of_value_type : Slice(UInt8)? = nil

          # Check for "of K => V" syntax
          if current_token.kind == Token::Kind::Identifier && token_text(current_token) == "of"
            advance
            skip_trivia

            # Parse key type
            key_type_token = current_token
            if key_type_token.kind == Token::Kind::Identifier
              of_key_type = key_type_token.slice
              advance
              skip_trivia

              # Expect =>
              unless current_token.kind == Token::Kind::Arrow
                emit_unexpected(current_token)
                return PREFIX_ERROR
              end
              advance  # consume =>
              skip_trivia

              # Parse value type
              value_type_token = current_token
              if value_type_token.kind == Token::Kind::Identifier
                of_value_type = value_type_token.slice
                advance
              else
                emit_unexpected(value_type_token)
                return PREFIX_ERROR
              end
            else
              emit_unexpected(key_type_token)
              return PREFIX_ERROR
            end
          end

          # Use lbrace span as start, current as end (after "of K => V" if present)
          closing_span = lbrace.span.cover(lbrace.span)  # Minimal span for now
          @arena.add(ExpressionNode.new(
            ExpressionNode::Kind::HashLiteral,
            closing_span,
            hash_entries: entries,
            hash_of_key_type: of_key_type,
            hash_of_value_type: of_value_type
          ))
        end

        # Phase 14: Continue parsing hash literal after first key
        private def parse_hash_literal_continued(lbrace : Token, first_key : ExprId) : ExprId
          # Current token should be Arrow
          unless current_token.kind == Token::Kind::Arrow
            emit_unexpected(current_token)
            return PREFIX_ERROR
          end
          arrow_token = current_token
          advance  # consume =>
          skip_trivia

          # Parse first value
          first_value = parse_expression(0)
          return PREFIX_ERROR if first_value.invalid?

          key_span = node_span(first_key)
          value_span = node_span(first_value)
          entry_span = key_span.cover(value_span)
          skip_trivia

          entries = [HashEntry.new(first_key, first_value, entry_span, arrow_token.span)]

          # Parse remaining entries
          loop do
            unless current_token.kind == Token::Kind::Comma
              break
            end

            advance  # consume comma
            skip_trivia

            # Allow trailing comma
            if current_token.kind == Token::Kind::RBrace
              break
            end

            # Parse key
            key = parse_expression(0)
            return PREFIX_ERROR if key.invalid?
            key_span = node_span(key)
            skip_trivia

            # Expect =>
            unless current_token.kind == Token::Kind::Arrow
              emit_unexpected(current_token)
              return PREFIX_ERROR
            end
            arrow_token = current_token
            advance  # consume =>
            skip_trivia

            # Parse value
            value = parse_expression(0)
            return PREFIX_ERROR if value.invalid?
            value_span = node_span(value)
            entry_span = key_span.cover(value_span)
            skip_trivia

            entries << HashEntry.new(key, value, entry_span, arrow_token.span)
          end

          # Expect closing brace
          unless current_token.kind == Token::Kind::RBrace
            emit_unexpected(current_token)
            return PREFIX_ERROR
          end

          closing_brace = current_token
          advance

          hash_span = lbrace.span.cover(closing_brace.span)
          @arena.add(ExpressionNode.new(
            ExpressionNode::Kind::HashLiteral,
            hash_span,
            hash_entries: entries
          ))
        end

        # Phase 8: Parse string interpolation
        # Converts "Hello, #{name}!" into StringPiece array:
        # - Text("Hello, ")
        # - Expression(name_expr_id)
        # - Text("!")
        private def parse_string_interpolation(token : Token) : ExprId
          content = String.new(token.slice)
          pieces = [] of StringPiece
          i = 0

          while i < content.size
            # Find next #{
            text_start = i
            while i < content.size
              break if i + 1 < content.size && content[i] == '#' && content[i + 1] == '{'
              i += 1
            end

            # Add text piece if any
            if i > text_start
              pieces << StringPiece.text(content[text_start...i])
            end

            break if i >= content.size

            # Skip #{
            i += 2

            # Find matching } (handle nested braces)
            expr_start = i
            brace_depth = 1
            while i < content.size && brace_depth > 0
              if content[i] == '{'
                brace_depth += 1
              elsif content[i] == '}'
                brace_depth -= 1
              end
              i += 1 if brace_depth > 0
            end

            # Parse expression
            expr_text = content[expr_start...i]
            expr_id = parse_interpolation_expression(expr_text)
            pieces << StringPiece.expression(expr_id)

            # Move past the closing }
            i += 1
          end

          advance
          @arena.add(ExpressionNode.new(
            ExpressionNode::Kind::StringInterpolation,
            token.span,
            string_pieces: pieces
          ))
        end

        # Helper: Parse expression text from interpolation
        # Creates a sub-parser and copies its arena into main arena
        private def parse_interpolation_expression(expr_text : String) : ExprId
          # Create sub-parser for the expression
          sub_lexer = Lexer.new(expr_text)
          sub_parser = Parser.new(sub_lexer)
          sub_expr_id = sub_parser.parse_expression(0)

          # Copy sub-parser's arena nodes into our arena
          copy_arena_nodes(sub_parser.@arena, sub_expr_id)
        end

        # Copy nodes from sub-arena to main arena, adjusting IDs
        private def copy_arena_nodes(sub_arena : AstArena, root_id : ExprId) : ExprId
          id_map = {} of Int32 => ExprId

          # Copy all nodes, building ID mapping
          sub_arena.nodes.each_with_index do |node, idx|
            new_id = copy_node(node, id_map)
            id_map[idx] = new_id
          end

          # Return the mapped root ID
          id_map[root_id.index]
        end

        # Copy a single node, remapping child IDs
        private def copy_node(node : ExpressionNode, id_map : Hash(Int32, ExprId)) : ExprId
          # Remap optional ExprId fields
          remap = ->(id : ExprId?) {
            id ? id_map[id.index]? || id : nil
          }

          # Remap array fields
          remap_array = ->(ids : Array(ExprId)?) {
            ids ? ids.map { |id| id_map[id.index]? || id } : nil
          }

          # Remap elsif branches
          remap_elsifs = ->(elsifs : Array(ElsifBranch)?) {
            elsifs ? elsifs.map { |branch|
              ElsifBranch.new(
                remap.call(branch.condition).not_nil!,
                remap_array.call(branch.body).not_nil!,
                branch.span
              )
            } : nil
          }

          # Remap string pieces
          remap_pieces = ->(pieces : Array(StringPiece)?) {
            pieces ? pieces.map { |piece|
              if piece.kind == StringPiece::Kind::Expression
                StringPiece.expression(remap.call(piece.expr).not_nil!)
              else
                piece
              end
            } : nil
          }

          # Remap when branches
          remap_when_branches = ->(branches : Array(WhenBranch)?) {
            branches ? branches.map { |branch|
              WhenBranch.new(
                remap_array.call(branch.conditions).not_nil!,
                remap_array.call(branch.body).not_nil!,
                branch.span
              )
            } : nil
          }

          # Remap hash entries (key/value need remapping, spans stay same)
          remap_hash_entries = ->(entries : Array(HashEntry)?) {
            entries ? entries.map { |entry|
              HashEntry.new(
                remap.call(entry.key).not_nil!,
                remap.call(entry.value).not_nil!,
                entry.span,
                entry.arrow_span
              )
            } : nil
          }

          @arena.add(ExpressionNode.new(
            node.kind,
            node.span,
            literal: node.literal,
            number_kind: node.number_kind,
            operator: node.operator,
            left: remap.call(node.left),
            right: remap.call(node.right),
            callee: remap.call(node.callee),
            args: remap_array.call(node.args),
            member: node.member,
            macro_expr: remap.call(node.macro_expr),
            macro_name: node.macro_name,
            macro_pieces: node.macro_pieces,
            trim_left: node.trim_left,
            trim_right: node.trim_right,
            def_name: node.def_name,
            def_params: node.def_params,
            def_return_type: node.def_return_type,
            def_body: remap_array.call(node.def_body),
            class_name: node.class_name,
            class_body: remap_array.call(node.class_body),
            class_super_name: node.class_super_name,
            if_condition: remap.call(node.if_condition),
            if_then: remap_array.call(node.if_then),
            if_elsifs: remap_elsifs.call(node.if_elsifs),
            if_else: remap_array.call(node.if_else),
            while_condition: remap.call(node.while_condition),
            while_body: remap_array.call(node.while_body),
            assign_target: remap.call(node.assign_target),
            assign_value: remap.call(node.assign_value),
            ivar_decl_type: node.ivar_decl_type,
            return_value: remap.call(node.return_value),
            string_pieces: remap_pieces.call(node.string_pieces),
            array_elements: remap_array.call(node.array_elements),
            array_of_type: node.array_of_type,
            block_params: node.block_params,
            block_body: remap_array.call(node.block_body),
            call_block: remap.call(node.call_block),
            yield_args: remap_array.call(node.yield_args),
            case_value: remap.call(node.case_value),
            when_branches: remap_when_branches.call(node.when_branches),
            case_else: remap_array.call(node.case_else),
            break_value: remap.call(node.break_value),
            range_begin: remap.call(node.range_begin),
            range_end: remap.call(node.range_end),
            range_exclusive: node.range_exclusive,
            hash_entries: remap_hash_entries.call(node.hash_entries),
            hash_of_key_type: node.hash_of_key_type,
            hash_of_value_type: node.hash_of_value_type
          ))
        end

        private def parse_parenthesized_call(callee : ExprId) : ExprId
          lparen = current_token
          advance
          args = [] of ExprId
          skip_trivia
          unless current_token.kind == Token::Kind::RParen
            loop do
              arg = parse_expression(0)
              args << arg unless arg.invalid?
              skip_trivia
              break unless current_token.kind == Token::Kind::Comma
              advance
              skip_trivia
            end
          end
          expect_operator(Token::Kind::RParen)
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
          unless current_token.kind == Token::Kind::RBracket
            loop do
              expr = parse_expression(0)
              indexes << expr unless expr.invalid?
              skip_trivia
              break unless current_token.kind == Token::Kind::Comma
              advance
              skip_trivia
            end
          end
          expect_operator(Token::Kind::RBracket)
          spans = [] of Span
          spans << lbracket.span
          spans << node_span(target)
          indexes.each { |idx| spans << node_span(idx) }
          if closing_span = previous_token.try(&.span)
            spans << closing_span
          end
          index_span = Span.cover_all(spans)
          @arena.add(ExpressionNode.new(ExpressionNode::Kind::Index, index_span, left: target, args: indexes))
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

        private def expect_operator(kind : Token::Kind)
          token = current_token
          if token.kind == kind
            advance
          else
            emit_unexpected(token)
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
          BINARY_PRECEDENCE.has_key?(token.kind)
        end

        private def precedence_for(token : Token) : Int32
          BINARY_PRECEDENCE[token.kind]? || 0
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
          # Check for trim marker: "-" can be either Minus or Operator
          # "~" is always Operator (not tokenized as specific kind)
          is_trim = case marker
          when '-'
            token.kind == Token::Kind::Minus ||
              (token.kind == Token::Kind::Operator && token_text(token) == "-")
          else
            token.kind == Token::Kind::Operator && token_text(token) == marker.to_s
          end

          if is_trim
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
          return false unless current.kind == Token::Kind::LBrace
          peek = peek_token
          peek.kind == Token::Kind::LBrace
        end

        private def macro_expression_left_trim?
          second = peek_token(1)
          third = peek_token(2)
          second.kind == Token::Kind::LBrace &&
            third.kind == Token::Kind::Operator && token_text(third) == "-"
        end

        private def macro_control_start?
          current = current_token
          return false unless current.kind == Token::Kind::LBrace
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

        private def operator_token?(token : Token, kind : Token::Kind)
          token.kind == kind
        end

        private def operator_token?(token : Token, value : String)
          # Special case for "-": can be Minus or Operator
          if value == "-"
            return true if token.kind == Token::Kind::Minus
          end
          # Generic check for Operator tokens
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

          if operator_token?(current_token, Token::Kind::Comma)
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
          # Check if expected is a keyword that has its own token kind
          expected_kind = case expected
          when "if"    then Token::Kind::If
          when "elsif" then Token::Kind::Elsif
          when "else"  then Token::Kind::Else
          when "end"   then Token::Kind::End
          when "while" then Token::Kind::While
          when "do"    then Token::Kind::Do
          when "then"  then Token::Kind::Then
          when "def"   then Token::Kind::Def
          when "class" then Token::Kind::Class
          when "true"  then Token::Kind::True
          when "false" then Token::Kind::False
          when "nil"   then Token::Kind::Nil
          else
            nil
          end

          if expected_kind
            if token.kind == expected_kind
              advance
            else
              emit_unexpected(token)
            end
          else
            if token.kind == Token::Kind::Identifier && token_text(token) == expected
              advance
            else
              emit_unexpected(token)
            end
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
          Token::Kind::OrOr      => 3,   # Logical OR (lowest)
          Token::Kind::AndAnd    => 4,   # Logical AND
          Token::Kind::DotDot    => 5,   # Inclusive range (Phase 13)
          Token::Kind::DotDotDot => 5,   # Exclusive range (Phase 13)
          Token::Kind::Pipe      => 6,   # Bitwise OR (Phase 21)
          Token::Kind::Caret     => 6,   # Bitwise XOR (Phase 21)
          Token::Kind::Amp       => 6,   # Bitwise AND (Phase 21)
          Token::Kind::EqEq      => 7,   # Equality
          Token::Kind::NotEq     => 7,   # Inequality
          Token::Kind::Less      => 7,   # Less than
          Token::Kind::Greater   => 7,   # Greater than
          Token::Kind::LessEq    => 7,   # Less or equal
          Token::Kind::GreaterEq => 7,   # Greater or equal
          Token::Kind::Plus      => 10,  # Addition
          Token::Kind::Minus     => 10,  # Subtraction
          Token::Kind::LShift    => 10,  # Left shift / array push (Phase 9)
          Token::Kind::RShift    => 10,  # Right shift (Phase 22)
          Token::Kind::Star      => 20,  # Multiplication
          Token::Kind::Slash     => 20,  # Division
          Token::Kind::Percent   => 20,  # Modulo (Phase 18)
          Token::Kind::StarStar  => 25,  # Exponentiation (Phase 19, highest precedence)
        }

        UNARY_OPERATORS = [Token::Kind::Plus, Token::Kind::Minus, Token::Kind::Not, Token::Kind::Tilde]
      end
    end
  end
end
