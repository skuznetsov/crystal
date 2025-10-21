require "./types/type_context"
require "./types/type"
require "./types/primitive_type"
require "./types/class_type"
require "./types/union_type"
require "./analyzer"
require "../frontend/ast"

module CrystalGPT5
  module Compiler
    module Semantic
      # Type Inference Engine for Stage 3
      #
      # Implements simple bottom-up type inference:
      # - Infer types from leaves to root
      # - Check type compatibility
      # - Emit type error diagnostics
      #
      # Algorithm: See collab_log/2025-10-21-003000-claude-type-inference-design.md
      #
      # Phase 1 (MVP): Literals + Variables
      # Phase 2: Binary operators
      # Phase 3: Control flow (if/while with unions)
      # Phase 4: Method calls with overload resolution
      # Phase 5: Definitions (method/class bodies)
      class TypeInferenceEngine
        getter context : TypeContext
        getter diagnostics : Array(Diagnostic)

        def initialize(
          @program : Frontend::Program,
          @identifier_symbols : Hash(ExprId, Symbol),
          @context : TypeContext = TypeContext.new
        )
          @diagnostics = [] of Diagnostic
        end

        # Main entry point: Infer types for all root expressions
        def infer_types
          @program.roots.each do |root_id|
            type = infer_expression(root_id)
            @context.set_type(root_id, type)
          end
        end

        # Recursive type inference for a single expression
        private def infer_expression(expr_id : ExprId) : Type
          node = @program.arena[expr_id]

          case node.kind
          when .number?
            infer_number(node)
          when .string?
            infer_string(node)
          when .identifier?
            infer_identifier(node, expr_id)
          when .binary?
            infer_binary(node)
          when .def?
            # Method definitions don't have value types (they're statements)
            @context.nil_type
          when .class?
            # Class definitions don't have value types (they're statements)
            @context.nil_type
          when .call?
            # TODO: Implement method call type inference (Phase 4)
            @context.nil_type
          else
            # Unknown expression kind
            @context.nil_type
          end
        end

        # ============================================================
        # PHASE 1: Literals
        # ============================================================

        private def infer_number(node) : Type
          # TODO: Parse literal to determine if Int32, Int64, Float64
          # For now: assume all numbers are Int32
          @context.int32_type
        end

        private def infer_string(node) : Type
          @context.string_type
        end

        # ============================================================
        # PHASE 1: Variables
        # ============================================================

        private def infer_identifier(node, expr_id : ExprId) : Type
          # Lookup resolved symbol from name resolution
          symbol = @identifier_symbols[expr_id]?

          return @context.nil_type unless symbol

          case symbol
          when VariableSymbol
            # For Phase 1: Variables without explicit types return Nil
            # TODO Phase 2: Track assignments for implicit type inference
            if declared_type_name = symbol.declared_type
              # Explicit type annotation: var : Int32
              parse_type_name(declared_type_name)
            else
              @context.nil_type
            end
          when ClassSymbol
            # Reference to class → ClassType
            ClassType.new(symbol)
          when MethodSymbol
            # Reference to method → Nil for now
            # TODO: Function types (Phase 5)
            @context.nil_type
          else
            @context.nil_type
          end
        end

        # Parse simple type name (e.g., "Int32", "String")
        # For Phase 1: Only built-in primitive types
        private def parse_type_name(name : String) : Type
          case name
          when "Int32"   then @context.int32_type
          when "Int64"   then @context.int64_type
          when "Float64" then @context.float64_type
          when "String"  then @context.string_type
          when "Bool"    then @context.bool_type
          when "Nil"     then @context.nil_type
          when "Char"    then @context.char_type
          else
            # Unknown type → emit error and return Nil
            emit_error("Unknown type '#{name}'")
            @context.nil_type
          end
        end

        # ============================================================
        # PHASE 2: Binary Operators
        # ============================================================

        private def infer_binary(node) : Type
          # Binary node has left, right, operator fields
          left_id = node.left
          right_id = node.right

          return @context.nil_type unless left_id && right_id

          left_type = infer_expression(left_id)
          right_type = infer_expression(right_id)

          # Get operator text
          op = node.operator_string || ""

          case op
          when "+", "-", "*", "/"
            # Numeric operators
            unless numeric_type?(left_type) && numeric_type?(right_type)
              emit_error("Operator '#{op}' requires numeric types, got #{left_type} and #{right_type}")
              return @context.nil_type
            end
            # For simplicity: always return Int32
            # TODO: Proper numeric promotion (Int32 + Int64 → Int64)
            @context.int32_type

          when "==", "!=", "<", ">", "<=", ">="
            # Comparison operators → Bool
            @context.bool_type

          when "&&", "||"
            # Logical operators
            unless bool_type?(left_type) && bool_type?(right_type)
              emit_error("Operator '#{op}' requires bool types, got #{left_type} and #{right_type}")
              return @context.nil_type
            end
            @context.bool_type

          else
            emit_error("Unknown operator '#{op}'")
            @context.nil_type
          end
        end

        private def numeric_type?(type : Type) : Bool
          type.is_a?(PrimitiveType) &&
            (type.name == "Int32" || type.name == "Int64" || type.name == "Float64")
        end

        private def bool_type?(type : Type) : Bool
          type.is_a?(PrimitiveType) && type.name == "Bool"
        end

        # ============================================================
        # PHASE 3: Control Flow (TODO: Parser doesn't support if/while yet)
        # ============================================================

        # TODO: Add when parser supports if/while/case

        # ============================================================
        # Error Handling
        # ============================================================

        private def emit_error(message : String, node_id : ExprId? = nil)
          # Create diagnostic with primary span
          # TODO: Use actual node span when available
          dummy_span = Frontend::Span.new(
            start_offset: 0,
            end_offset: 0,
            start_line: 1,
            start_column: 1,
            end_line: 1,
            end_column: 1
          )

          diagnostic = Diagnostic.new(
            level: DiagnosticLevel::Error,
            code: "E3001",  # Type error codes start at E3xxx
            message: message,
            primary_span: dummy_span
          )
          @diagnostics << diagnostic
        end
      end
    end
  end
end
