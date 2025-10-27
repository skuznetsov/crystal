require "../frontend/ast"
require "./symbol"
require "./diagnostic"

module CrystalGPT5
  module Compiler
    module Semantic
      # Phase 87B-2: General Macro Expansion Engine
      #
      # SCOPE (Phase 87B-2):
      # ✅ Macro call detection (method call → macro resolution)
      # ✅ Basic {{ expr }} evaluation (literals, constants, identifiers)
      # ✅ Simple parameter substitution
      # ✅ Recursion depth limit (100)
      #
      # OUT OF SCOPE (Future Phases):
      # ❌ {% if %} control flow → Phase 87B-3
      # ❌ {% for %} iteration → Phase 87B-3
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

          # Build output by processing each piece
          output = String.build do |str|
            pieces.each do |piece|
              case piece.kind
              when MacroPiece::Kind::Text
                # Plain text - append as-is
                str << piece.text if piece.text

              when MacroPiece::Kind::Expression
                # {{ expr }} - evaluate and stringify
                if expr_id = piece.expr
                  value = evaluate_expression(expr_id, context)
                  str << value
                end

              when MacroPiece::Kind::ControlStart,
                   MacroPiece::Kind::ControlElseIf,
                   MacroPiece::Kind::ControlElse,
                   MacroPiece::Kind::ControlEnd
                # Control flow not implemented in Phase 87B-2
                # Emit warning and skip
                emit_warning("Control flow ({% #{piece.control_keyword} %}) not implemented in Phase 87B-2", body_id)
              end
            end
          end

          output
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
