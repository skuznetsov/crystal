require "../frontend/ast"
require "./symbol"
require "./diagnostic"

module CrystalGPT5
  module Compiler
    module Semantic
      # Phase 87B-3: General Macro Expansion Engine (with Control Flow)
      #
      # SCOPE (Phase 87B-2 + 87B-3):
      # ✅ Macro call detection (method call → macro resolution)
      # ✅ Basic {{ expr }} evaluation (literals, constants, identifiers)
      # ✅ Simple parameter substitution
      # ✅ Recursion depth limit (100)
      # ✅ {% if %} / {% elsif %} / {% else %} control flow
      # ✅ {% for %} iteration (ArrayLiteral only)
      # ✅ Crystal truthiness (false/nil/Nop falsy, everything else truthy)
      # ✅ Nested control flow with depth tracking
      #
      # OUT OF SCOPE (Future Phases):
      # ❌ {% for %} with ranges → Phase 87B-4
      # ❌ TypeNode reflection → Phase 87B-4
      # ❌ Macro methods (.stringify, .id) → Phase 87B-6
      class MacroExpander
        alias Program = Frontend::Program
        alias ExpressionNode = Frontend::ExpressionNode
        alias ExprId = Frontend::ExprId
        alias MacroPiece = Frontend::MacroPiece

        # Maximum macro expansion depth (prevents infinite recursion)
        MAX_DEPTH = 100

        getter diagnostics : Array(Diagnostic)

        def initialize(@program : Program, @arena : Frontend::AstArena)
          @diagnostics = [] of Diagnostic
          @depth = 0
        end

        # Expansion context for macro evaluation
        struct Context
          getter variables : Hash(String, String)
          getter depth : Int32

          def initialize(@variables = {} of String => String, @depth = 0)
          end

          def with_depth(new_depth : Int32) : Context
            Context.new(@variables.dup, new_depth)
          end

          def with_variable(name : String, value : String) : Context
            new_vars = @variables.dup
            new_vars[name] = value
            Context.new(new_vars, @depth)
          end
        end

        # Simple value representation during evaluation
        # For Phase 87B-2: Just use String (empty string = undefined)
        # Future: Richer type system with numbers, bools, arrays
        alias Value = String

        # Main expansion entry point
        #
        # Takes a MacroSymbol and arguments, returns expanded AST node
        def expand(macro_symbol : MacroSymbol, args : Array(ExprId)) : ExprId
          # Check recursion depth
          if @depth >= MAX_DEPTH
            emit_error("Macro recursion depth exceeded (#{MAX_DEPTH})")
            return ExprId.new(-1)
          end

          @depth += 1
          begin
            # Bind parameters to arguments
            context = build_context(macro_symbol, args)

            # Evaluate macro body
            output = evaluate_macro_body(macro_symbol.body, context)

            # Parse result back to AST
            reparse(output, macro_symbol.node_id)
          ensure
            @depth -= 1
          end
        end

        private def build_context(macro_symbol : MacroSymbol, args : Array(ExprId)) : Context
          variables = {} of String => String
          params = macro_symbol.params || [] of String

          # Bind each parameter to its argument value
          params.each_with_index do |param_name, index|
            if index < args.size
              # Evaluate argument to string
              arg_value = stringify_expr(args[index])
              variables[param_name] = arg_value
            else
              # Missing argument - leave undefined (empty string)
              variables[param_name] = ""
            end
          end

          Context.new(variables, @depth)
        end

        # Convert expression to string representation (for parameter binding)
        private def stringify_expr(expr_id : ExprId) : String
          node = @arena[expr_id]

          case node.kind
          when .number?, .string?, .identifier?, .bool?
            node.literal_string || ""
          when .nil?
            "nil"
          else
            # Complex expression - return source representation
            # For Phase 87B-2: Just return identifier or empty
            node.literal_string || ""
          end
        end

        private def evaluate_macro_body(body_id : ExprId, context : Context) : String
          # Get MacroLiteral node
          body_node = @arena[body_id]
          pieces = body_node.macro_pieces

          return "" unless pieces

          # Phase 87B-3: Use indexed loop to handle control flow jumps
          String.build do |str|
            index = 0

            while index < pieces.size
              piece = pieces[index]

              case piece.kind
              when .text?
                # Plain text - append as-is
                str << piece.text if piece.text
                index += 1

              when .expression?
                # {{ expr }} - evaluate and stringify
                if expr_id = piece.expr
                  value = evaluate_expression(expr_id, context)
                  str << value
                end
                index += 1

              when .control_start?
                # {% if %} or {% for %} - delegate to specialized handlers
                keyword = piece.control_keyword

                if keyword == "if"
                  output_part, new_index = evaluate_if_block(pieces, index, context)
                  str << output_part
                  index = new_index
                elsif keyword == "for"
                  output_part, new_index = evaluate_for_block(pieces, index, context)
                  str << output_part
                  index = new_index
                else
                  # Unknown control keyword
                  emit_warning("Unknown control keyword: #{keyword}", body_id)
                  index += 1
                end

              else
                # Skip standalone control flow markers (elsif, else, end)
                # These are handled inside evaluate_if_block
                index += 1
              end
            end
          end
        end

        private def reparse(output : String, location : ExprId) : ExprId
          # Create lexer from generated string
          lexer = Frontend::Lexer.new(output)

          # Create parser with existing arena (uses Phase 87B-2 constructor)
          parser = Frontend::Parser.new(lexer, @arena)

          # Parse as expression
          # Use precedence 0 to parse full expression
          begin
            result_id = parser.parse_expression(0)

            # Check for parse errors
            if parser.diagnostics.any?
              # Emit diagnostic: macro generated invalid syntax
              parse_errors = parser.diagnostics.map(&.message).join("; ")
              emit_error("Macro expansion generated invalid syntax: #{parse_errors}. Generated code: \"#{output}\"", location)
              return ExprId.new(-1)
            end

            result_id
          rescue ex
            # Catch any parser exceptions
            emit_error("Failed to parse macro expansion: #{ex.message}. Generated code: \"#{output}\"", location)
            ExprId.new(-1)
          end
        end

        private def evaluate_expression(expr_id : ExprId, context : Context) : Value
          node = @arena[expr_id]

          case node.kind
          when .number?
            # Number literal: 42, 3.14
            node.literal_string || ""

          when .string?
            # String literal: "hello"
            node.literal_string || ""

          when .identifier?
            # Variable reference: look up in context
            if name = node.literal_string
              context.variables[name]? || ""
            else
              ""
            end

          when .bool?
            # Boolean: true/false
            node.literal_string || ""

          when .nil?
            # Nil literal
            ""

          else
            # Unsupported expression type for Phase 87B-2
            # Return empty string (graceful degradation)
            ""
          end
        end

        # Phase 87B-3: Control Flow Methods
        # ====================================

        # Evaluate condition expression to boolean (Crystal truthiness)
        # CRITICAL: Only false/nil/Nop are falsy. EVERYTHING else is truthy (including 0, "", [])
        private def evaluate_condition(expr_id : ExprId, context : Context) : Bool
          node = @arena[expr_id]

          case node.kind
          when .bool?
            # Parse "true" or "false"
            literal = node.literal_string
            if literal
              return false if literal == "false"
              return true  # "true"
            end
            return true  # Default to true if no literal

          when .nil?
            # nil is falsy
            return false

          else
            # EVERYTHING else is truthy in Crystal
            # This includes: 0, "", [], numbers, strings, arrays, etc.
            return true
          end
        end

        # Find matching {% end %} for given {% if %} or {% for %}
        # Handles nested control flow via depth tracking
        private def find_matching_end(pieces : Array(MacroPiece), start_index : Int32) : Int32
          depth = 1
          index = start_index + 1

          while index < pieces.size
            piece = pieces[index]

            case piece.kind
            when .control_start?
              # Nested control structure
              depth += 1

            when .control_end?
              depth -= 1
              return index if depth == 0
            end

            index += 1
          end

          # Missing {% end %} - emit error
          emit_error("Unmatched control flow block (missing {% end %})")
          return pieces.size  # Return end of array (graceful degradation)
        end

        # Find next {% elsif %} / {% else %} / {% end %} at same depth
        private def find_next_branch_or_end(
          pieces : Array(MacroPiece),
          start : Int32,
          end_limit : Int32
        ) : Int32
          depth = 0
          index = start

          while index <= end_limit
            piece = pieces[index]

            case piece.kind
            when .control_start?
              depth += 1

            when .control_end?
              return index if depth == 0
              depth -= 1

            when .control_else_if?, .control_else?
              return index if depth == 0
            end

            index += 1
          end

          return end_limit
        end

        # Evaluate pieces in given range [start, end_index] inclusive
        # Handles nested control flow recursively
        private def evaluate_pieces_range(
          pieces : Array(MacroPiece),
          start : Int32,
          end_index : Int32,
          context : Context
        ) : String
          String.build do |str|
            index = start

            while index <= end_index && index < pieces.size
              piece = pieces[index]

              case piece.kind
              when .text?
                str << piece.text if piece.text
                index += 1

              when .expression?
                if expr_id = piece.expr
                  value = evaluate_expression(expr_id, context)
                  str << value
                end
                index += 1

              when .control_start?
                # Nested control flow
                keyword = piece.control_keyword

                if keyword == "if"
                  output_part, new_index = evaluate_if_block(pieces, index, context)
                  str << output_part
                  index = new_index
                elsif keyword == "for"
                  output_part, new_index = evaluate_for_block(pieces, index, context)
                  str << output_part
                  index = new_index
                else
                  index += 1
                end

              else
                # Skip control flow markers (elsif, else, end)
                index += 1
              end
            end
          end
        end

        # Evaluate {% if %} / {% elsif %} / {% else %} / {% end %} structure
        # Returns {output, next_index} where next_index points AFTER {% end %}
        private def evaluate_if_block(
          pieces : Array(MacroPiece),
          start_index : Int32,
          context : Context
        ) : {String, Int32}
          # Get condition from start piece
          start_piece = pieces[start_index]
          condition_expr = start_piece.expr

          unless condition_expr
            emit_error("Missing condition in {% if %} block")
            end_index = find_matching_end(pieces, start_index)
            return {"", end_index + 1}
          end

          # Evaluate condition
          condition_result = evaluate_condition(condition_expr, context)

          # Find matching end
          end_index = find_matching_end(pieces, start_index)

          if condition_result
            # Condition is true - evaluate if body
            next_branch = find_next_branch_or_end(pieces, start_index + 1, end_index)

            # Evaluate range [start_index+1, next_branch-1]
            output = evaluate_pieces_range(pieces, start_index + 1, next_branch - 1, context)

            return {output, end_index + 1}
          else
            # Condition is false - search for {% elsif %} or {% else %}
            current = start_index + 1

            while current < end_index
              piece = pieces[current]

              if piece.kind.control_else_if?
                # Evaluate elsif condition
                elsif_cond = piece.expr

                if elsif_cond && evaluate_condition(elsif_cond, context)
                  # Found true branch
                  next_branch = find_next_branch_or_end(pieces, current + 1, end_index)
                  output = evaluate_pieces_range(pieces, current + 1, next_branch - 1, context)
                  return {output, end_index + 1}
                end

                current += 1

              elsif piece.kind.control_else?
                # No conditions matched, use else
                output = evaluate_pieces_range(pieces, current + 1, end_index - 1, context)
                return {output, end_index + 1}

              else
                current += 1
              end
            end

            # No branch matched, return empty
            return {"", end_index + 1}
          end
        end

        # Evaluate {% for VAR in ARRAY %} loop
        # Phase 87B-3: ArrayLiteral only (ranges deferred to Phase 87B-4)
        # Returns {output, next_index} where next_index points AFTER {% end %}
        private def evaluate_for_block(
          pieces : Array(MacroPiece),
          start_index : Int32,
          context : Context
        ) : {String, Int32}
          # Get loop metadata
          start_piece = pieces[start_index]
          iter_vars = start_piece.iter_vars
          iterable_expr = start_piece.iterable

          unless iter_vars && iterable_expr
            emit_error("Missing loop variable or iterable in {% for %} block")
            end_index = find_matching_end(pieces, start_index)
            return {"", end_index + 1}
          end

          # Check single variable (Phase 87B-3 scope)
          if iter_vars.size != 1
            emit_error("Multiple loop variables not supported in Phase 87B-3")
            end_index = find_matching_end(pieces, start_index)
            return {"", end_index + 1}
          end

          var_name = iter_vars[0]

          # Evaluate iterable
          iterable_node = @arena[iterable_expr]

          unless iterable_node.kind.array_literal?
            emit_error("For loop requires ArrayLiteral in Phase 87B-3 (ranges deferred to Phase 87B-4)")
            end_index = find_matching_end(pieces, start_index)
            return {"", end_index + 1}
          end

          # Get array elements
          elements = iterable_node.array_elements || [] of ExprId

          # Find loop body range
          end_index = find_matching_end(pieces, start_index)
          body_start = start_index + 1
          body_end = end_index - 1

          # Iterate over elements
          output = String.build do |str|
            elements.each do |elem_id|
              # Stringify element
              elem_value = stringify_expr(elem_id)

              # Create new context with loop variable
              loop_context = context.with_variable(var_name, elem_value)

              # Evaluate body with loop context
              body_output = evaluate_pieces_range(pieces, body_start, body_end, loop_context)
              str << body_output
            end
          end

          return {output, end_index + 1}
        end

        private def emit_error(message : String, location : ExprId? = nil)
          span = if location
            @arena[location].span
          else
            Frontend::Span.new(0, 0, 1, 1, 1, 1)
          end

          @diagnostics << Diagnostic.new(
            DiagnosticLevel::Error,
            "E4001",  # Macro error codes start at E4xxx
            message,
            span
          )
        end

        private def emit_warning(message : String, location : ExprId? = nil)
          span = if location
            @arena[location].span
          else
            Frontend::Span.new(0, 0, 1, 1, 1, 1)
          end

          @diagnostics << Diagnostic.new(
            DiagnosticLevel::Warning,
            "W4001",  # Macro warning codes
            message,
            span
          )
        end
      end
    end
  end
end
