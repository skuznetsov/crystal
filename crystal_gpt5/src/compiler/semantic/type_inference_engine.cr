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
          when .bool?
            infer_bool(node)
          when .nil?
            infer_nil(node)
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
          when .if?
            infer_if(node)
          when .while?
            infer_while(node)
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

        private def infer_bool(node) : Type
          @context.bool_type
        end

        private def infer_nil(node) : Type
          @context.nil_type
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
        # PHASE 3: Control Flow
        # ============================================================

        private def infer_if(node) : Type
          # Infer condition type
          condition_id = node.if_condition
          return @context.nil_type unless condition_id

          condition_type = infer_expression(condition_id)

          # Check condition is Bool
          unless bool_type?(condition_type)
            emit_error("If condition must be Bool, got #{condition_type}", condition_id)
          end

          # Infer then body (type of last expression)
          then_type = if then_body = node.if_then
            if then_body.size > 0
              # Infer all expressions in body, save type of last
              result_type = @context.nil_type
              then_body.each do |expr_id|
                result_type = infer_expression(expr_id)
                @context.set_type(expr_id, result_type)
              end
              result_type
            else
              @context.nil_type
            end
          else
            @context.nil_type
          end

          # Infer elsif branches
          elsif_types = [] of Type
          if elsifs = node.if_elsifs
            elsifs.each do |elsif_branch|
              # Infer elsif condition
              elsif_condition_type = infer_expression(elsif_branch.condition)
              unless bool_type?(elsif_condition_type)
                emit_error("Elsif condition must be Bool, got #{elsif_condition_type}", elsif_branch.condition)
              end

              # Infer elsif body (type of last expression)
              elsif_type = if elsif_branch.body.size > 0
                result_type = @context.nil_type
                elsif_branch.body.each do |expr_id|
                  result_type = infer_expression(expr_id)
                  @context.set_type(expr_id, result_type)
                end
                result_type
              else
                @context.nil_type
              end

              elsif_types << elsif_type
            end
          end

          # Infer else body (or Nil if no else)
          else_type = if else_body = node.if_else
            if else_body.size > 0
              # Infer all expressions in body, save type of last
              result_type = @context.nil_type
              else_body.each do |expr_id|
                result_type = infer_expression(expr_id)
                @context.set_type(expr_id, result_type)
              end
              result_type
            else
              @context.nil_type
            end
          else
            # No else branch → implicit Nil
            @context.nil_type
          end

          # Create union type of all branches: then + elsifs + else
          all_types = [then_type] + elsif_types + [else_type]
          union_of(all_types)
        end

        private def infer_while(node) : Type
          # Infer condition type
          condition_id = node.while_condition
          return @context.nil_type unless condition_id

          condition_type = infer_expression(condition_id)

          # Check condition is Bool
          unless bool_type?(condition_type)
            emit_error("While condition must be Bool, got #{condition_type}", condition_id)
          end

          # Infer body expressions (result not used)
          if body = node.while_body
            body.each { |expr_id| infer_expression(expr_id) }
          end

          # While loops always return Nil in Crystal
          @context.nil_type
        end

        # ============================================================
        # Helper Methods
        # ============================================================

        # Creates a union type from constituent types
        #
        # Normalizes the union (flattens, removes duplicates, sorts).
        # If only one type remains after normalization, returns that type directly.
        private def union_of(types : Array(Type)) : Type
          normalized = UnionType.normalize(types)
          if normalized.size == 1
            normalized[0]
          else
            UnionType.new(types)
          end
        end

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
