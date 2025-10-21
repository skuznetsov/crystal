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
          @assignments = {} of String => Type  # Track variable assignments: name → type
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
            infer_binary(node, expr_id)
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
          when .assign?
            infer_assign(node)
          else
            # Unknown expression kind
            @context.nil_type
          end
        end

        # ============================================================
        # PHASE 1: Literals
        # ============================================================

        private def infer_number(node) : Type
          # Use NumberKind from lexer/parser
          case node.number_kind
          when NumberKind::I32
            @context.int32_type
          when NumberKind::I64
            @context.int64_type
          when NumberKind::F64
            @context.float64_type
          else
            # Fallback to Int32 if NumberKind is nil (shouldn't happen)
            @context.int32_type
          end
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
          # First, check if this identifier has a tracked assignment
          if identifier_name = node.literal_string
            if assigned_type = @assignments[identifier_name]?
              return assigned_type
            end
          end

          # Fallback to symbol lookup from name resolution
          symbol = @identifier_symbols[expr_id]?

          return @context.nil_type unless symbol

          case symbol
          when VariableSymbol
            # Explicit type annotation: var : Int32
            if declared_type_name = symbol.declared_type
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

        private def infer_binary(node, expr_id : ExprId) : Type
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
              emit_error("Operator '#{op}' requires numeric types, got #{left_type} and #{right_type}", expr_id)
              return @context.nil_type
            end
            # Production-ready fallback: widest type wins (safe, no precision loss)
            # TODO Phase 4: Check method overload first, then fallback to this
            promote_numeric_types(left_type, right_type)

          when "==", "!=", "<", ">", "<=", ">="
            # Comparison operators → Bool
            @context.bool_type

          when "&&", "||"
            # Logical operators
            unless bool_type?(left_type) && bool_type?(right_type)
              emit_error("Operator '#{op}' requires bool types, got #{left_type} and #{right_type}", expr_id)
              return @context.nil_type
            end
            @context.bool_type

          else
            emit_error("Unknown operator '#{op}'", expr_id)
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

        # Promote two numeric types to their widest common type
        #
        # PRODUCTION-READY FALLBACK STRATEGY:
        # This is a SAFE DEFAULT used when method resolution is not available.
        # In Phase 4, this will be replaced by exact Crystal behavior:
        #   1. Check method overload: left_type.+(right_type)
        #   2. If found: use method's return type (Crystal-exact)
        #   3. If not found: use this fallback (safe, no precision loss)
        #
        # Promotion rules (fallback):
        #   I32 < I64 < F64 (width ordering)
        #   Always return widest type to prevent precision loss
        #
        # Examples:
        #   promote(I32, I32) → I32
        #   promote(I32, I64) → I64  (safe: preserves Int64 range)
        #   promote(I32, F64) → F64  (safe: preserves float precision)
        #   promote(I64, F64) → F64
        #
        # TODO Phase 4: Replace with method overload lookup when available
        private def promote_numeric_types(left : Type, right : Type) : Type
          return @context.nil_type unless left.is_a?(PrimitiveType) && right.is_a?(PrimitiveType)

          # Type width values for ordering
          left_width = numeric_type_width(left.name)
          right_width = numeric_type_width(right.name)

          # Return widest type
          if left_width >= right_width
            left
          else
            right
          end
        end

        # Get numeric type width for promotion
        # I32 = 32, I64 = 64, F64 = 128 (floats wider than ints)
        private def numeric_type_width(type_name : String) : Int32
          case type_name
          when "Int32"   then 32
          when "Int64"   then 64
          when "Float64" then 128  # Floats wider than any integer
          else 0
          end
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
        # PHASE 2: Assignments
        # ============================================================

        private def infer_assign(node) : Type
          # Get target and value expression IDs
          target_id = node.assign_target
          value_id = node.assign_value

          return @context.nil_type unless target_id && value_id

          # Infer value type
          value_type = infer_expression(value_id)

          # Get target identifier name
          target_node = @program.arena[target_id]
          if target_name = target_node.literal_string
            # Track this assignment: identifier name → type
            @assignments[target_name] = value_type
          end

          # Assignments return the value type in Crystal
          value_type
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
          # Get actual span from node if available
          span = if node_id
            node = @program.arena[node_id]
            node.span
          else
            # Fallback to dummy span if node not available
            Frontend::Span.new(
              start_offset: 0,
              end_offset: 0,
              start_line: 1,
              start_column: 1,
              end_line: 1,
              end_column: 1
            )
          end

          diagnostic = Diagnostic.new(
            level: DiagnosticLevel::Error,
            code: "E3001",  # Type error codes start at E3xxx
            message: message,
            primary_span: span
          )
          @diagnostics << diagnostic
        end
      end
    end
  end
end
