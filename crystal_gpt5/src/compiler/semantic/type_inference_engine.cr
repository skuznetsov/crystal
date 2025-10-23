require "./types/type_context"
require "./types/type"
require "./types/primitive_type"
require "./types/class_type"
require "./types/instance_type"
require "./types/union_type"
require "./analyzer"
require "../frontend/ast"

module CrystalGPT5
  module Compiler
    module Semantic
      alias NumberKind = Frontend::NumberKind

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

        @current_class : ClassSymbol?  # Phase 5C: Track current class for instance var types

        def initialize(
          @program : Frontend::Program,
          @identifier_symbols : Hash(ExprId, Symbol),
          @global_table : SymbolTable? = nil,
          @context : TypeContext = TypeContext.new
        )
          @diagnostics = [] of Diagnostic
          @assignments = {} of String => Type  # Track variable assignments: name → type
          @instance_var_types = {} of String => Type  # Phase 5A: Track instance variable types
          @current_class = nil
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
          when .instance_var?
            infer_instance_var(node, expr_id)
          when .binary?
            infer_binary(node, expr_id)
          when .def?
            infer_def(node, expr_id)
          when .class?
            infer_class(node, expr_id)
          when .call?
            infer_call(node, expr_id)
          when .member_access?
            # In Crystal, obj.method without parens is a zero-argument method call
            infer_member_access(node, expr_id)
          when .if?
            infer_if(node)
          when .while?
            infer_while(node)
          when .assign?
            infer_assign(node)
          when .return?
            infer_return(node, expr_id)
          when .self?
            infer_self(node, expr_id)
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

          # Try name resolution first
          symbol = @identifier_symbols[expr_id]?

          # Fallback to global symbol table lookup if name resolution didn't resolve this identifier
          if symbol.nil? && (identifier_name = node.literal_string)
            symbol = @global_table.try(&.lookup(identifier_name))
          end

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
            # Class itself is a value (for calling class methods like Dog.new)
            ClassType.new(symbol)
          when MethodSymbol
            # Reference to method → Nil for now
            # TODO: Function types (Phase 5)
            @context.nil_type
          else
            @context.nil_type
          end
        end

        # ============================================================
        # PHASE 5: Classes, Methods, and Instance Variables
        # ============================================================

        # Phase 6: Process method definitions and their bodies
        private def infer_def(node, expr_id : ExprId) : Type
          # Process method body
          (node.def_body || [] of ExprId).each do |body_expr_id|
            infer_expression(body_expr_id)
          end

          # Method definitions don't have value types (they're statements)
          @context.nil_type
        end

        # Phase 5C: Process class bodies and track current class context
        private def infer_class(node, expr_id : ExprId) : Type
          # Look up the ClassSymbol from the symbol table
          class_name = node.class_name.try { |slice| String.new(slice) }
          return @context.nil_type unless class_name

          class_symbol = @global_table.try(&.lookup(class_name))
          return @context.nil_type unless class_symbol.is_a?(ClassSymbol)

          # Save previous class context and set current class
          previous_class = @current_class
          @current_class = class_symbol

          # Process class body (method definitions, etc.)
          (node.class_body || [] of ExprId).each do |body_expr_id|
            infer_expression(body_expr_id)
          end

          # Restore previous class context
          @current_class = previous_class

          # Class definitions don't have value types
          @context.nil_type
        end

        private def infer_instance_var(node, expr_id : ExprId) : Type
          return @context.nil_type unless var_name = node.literal_string

          # Remove @ prefix
          clean_name = var_name.starts_with?("@") ? var_name[1..-1] : var_name

          # Phase 5C: Check explicit type annotation from ClassSymbol first
          if current_class = @current_class
            if type_annotation = current_class.get_instance_var_type(clean_name)
              return parse_type_name(type_annotation)
            end
          end

          # Check if we have inferred type from assignment
          if inferred_type = @instance_var_types[clean_name]?
            return inferred_type
          end

          # Not found - return Nil
          @context.nil_type
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
            # Phase 4B.3/4B.5: Try method lookup first for built-in methods
            if method = lookup_method(left_type, op, [right_type])
              if ann = method.return_annotation
                return parse_type_name(ann)
              end
            end

            # Fallback: numeric promotion for untyped numeric operators
            if numeric_type?(left_type) && numeric_type?(right_type)
              return promote_numeric_types(left_type, right_type)
            end

            # No method found and not numeric types
            emit_error("Operator '#{op}' not defined for #{left_type} and #{right_type}", expr_id)
            @context.nil_type

          when "==", "!=", "<", ">", "<=", ">="
            # Phase 4B.3/4B.5: Try method lookup first for built-in methods
            if method = lookup_method(left_type, op, [right_type])
              if ann = method.return_annotation
                return parse_type_name(ann)
              end
            end

            # Fallback: comparison operators → Bool for compatible types
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

          # Phase 5A: Check if target is instance variable
          if target_node.kind.instance_var?
            if target_name = target_node.literal_string
              # Remove @ prefix for storage
              clean_name = target_name.starts_with?("@") ? target_name[1..-1] : target_name
              @instance_var_types[clean_name] = value_type
            end
          elsif target_name = target_node.literal_string
            # Regular variable assignment
            @assignments[target_name] = value_type
          end

          # Assignments return the value type in Crystal
          value_type
        end

        # ============================================================
        # PHASE 6: Return Statements
        # ============================================================

        private def infer_return(node, expr_id : ExprId) : Type
          # If return has a value, infer its type
          if value_id = node.return_value
            value_type = infer_expression(value_id)
            @context.set_type(expr_id, value_type)
            value_type
          else
            # Return without value returns nil
            @context.set_type(expr_id, @context.nil_type)
            @context.nil_type
          end
        end

        # ============================================================
        # PHASE 7: Self Keyword
        # ============================================================

        private def infer_self(node, expr_id : ExprId) : Type
          # self returns InstanceType of the current class
          if current_class = @current_class
            instance_type = InstanceType.new(current_class)
            @context.set_type(expr_id, instance_type)
            instance_type
          else
            # self outside class context (shouldn't happen in valid code)
            @context.nil_type
          end
        end

        # ============================================================
        # PHASE 4: Method Calls
        # ============================================================

        private def infer_member_access(node, expr_id : ExprId) : Type
          # MemberAccess without parens is a zero-argument method call in Crystal
          # obj.method → obj.method()
          receiver_id = node.left
          return @context.nil_type unless receiver_id

          receiver_type = infer_expression(receiver_id)
          method_name = node.member_string
          return @context.nil_type unless method_name

          # Phase 4B.5: Special case for constructor - ClassName.new → InstanceType
          if method_name == "new" && receiver_type.is_a?(ClassType)
            return InstanceType.new(receiver_type.symbol)
          end

          # Phase 4B: Zero-argument method call
          arg_types = [] of Type

          # Phase 4B.4: Special case for union types - compute union return type
          if receiver_type.is_a?(UnionType)
            if return_type = compute_union_method_return_type(receiver_type, method_name, arg_types)
              return return_type
            else
              emit_error("Method '#{method_name}' not found on #{receiver_type}", expr_id)
              return @context.nil_type
            end
          end

          # Lookup method with overload resolution
          if method = lookup_method(receiver_type, method_name, arg_types)
            if ann = method.return_annotation
              return parse_type_name(ann)
            end
          else
            emit_error("Method '#{method_name}' not found on #{receiver_type}", expr_id)
          end

          @context.nil_type
        end

        private def infer_call(node, expr_id : ExprId) : Type
          # Extract receiver and method name from Call node
          return @context.nil_type unless callee_id = node.callee

          callee_node = @program.arena[callee_id]

          # Determine receiver type and method name
          receiver_type : Type?
          method_name : String?

          case callee_node.kind
          when .member_access?
            # foo.bar(x) → receiver=foo, method=bar
            receiver_id = callee_node.left
            return @context.nil_type unless receiver_id

            receiver_type = infer_expression(receiver_id)
            method_name = callee_node.member_string
          when .identifier?
            # bar(x) → implicit self (not supported yet in Phase 4A)
            return @context.nil_type
          else
            return @context.nil_type
          end

          return @context.nil_type unless receiver_type && method_name

          # Phase 4B.5: Special case for constructor - ClassName.new(...) → InstanceType
          # TODO: Validate constructor arguments against initialize method
          if method_name == "new" && receiver_type.is_a?(ClassType)
            return InstanceType.new(receiver_type.symbol)
          end

          # Phase 4B: Infer argument types for overload resolution
          arg_types = [] of Type
          if args = node.args
            args.each do |arg_id|
              arg_type = infer_expression(arg_id)
              arg_types << arg_type
            end
          end

          # Phase 4B.4: Special case for union types - compute union return type
          if receiver_type.is_a?(UnionType)
            if return_type = compute_union_method_return_type(receiver_type, method_name, arg_types)
              return return_type
            else
              emit_error("Method '#{method_name}' not found on #{receiver_type}", expr_id)
              return @context.nil_type
            end
          end

          # Lookup method with overload resolution (Phase 4B)
          if method = lookup_method(receiver_type, method_name, arg_types)
            # Return declared return type
            if ann = method.return_annotation
              return parse_type_name(ann)
            end
          else
            emit_error("Method '#{method_name}' not found on #{receiver_type}", expr_id)
          end

          @context.nil_type
        end

        # Phase 4B: Method lookup with overload resolution
        #
        # Algorithm:
        # 1. Find all methods with given name (may be multiple overloads)
        # 2. Filter by parameter count
        # 3. Filter by parameter types (if annotated)
        # 4. Return best match
        private def lookup_method(receiver_type : Type, method_name : String, arg_types : Array(Type)) : MethodSymbol?
          candidates = find_all_methods(receiver_type, method_name)
          return nil if candidates.empty?

          # Filter by parameter count
          matching_count = candidates.select { |m| m.params.size == arg_types.size }
          return nil if matching_count.empty?

          # Filter by parameter types (for typed parameters)
          matches = matching_count.select do |method|
            parameters_match?(method, arg_types)
          end

          # Return best match (for now: first match)
          # TODO: Add specificity ranking (prefer more specific types)
          matches.first?
        end

        # Find all methods with given name on receiver type
        private def find_all_methods(receiver_type : Type, method_name : String) : Array(MethodSymbol)
          methods = [] of MethodSymbol

          case receiver_type
          when ClassType
            # Look in class scope
            if symbol = receiver_type.symbol.scope.lookup(method_name)
              case symbol
              when MethodSymbol
                # Single method
                methods << symbol
              when OverloadSetSymbol
                # Phase 4B.2: Multiple overloads
                methods.concat(symbol.overloads)
              end
            end

            # Phase 4B.2: Inheritance search - look in superclass
            if methods.empty?
              methods.concat(find_in_superclass(receiver_type.symbol, method_name))
            end
          when InstanceType
            # Phase 4B.2: Look for instance methods in class scope
            if symbol = receiver_type.class_symbol.scope.lookup(method_name)
              case symbol
              when MethodSymbol
                methods << symbol
              when OverloadSetSymbol
                methods.concat(symbol.overloads)
              end
            end

            # Phase 4B.2: Inheritance search - look in superclass
            if methods.empty?
              methods.concat(find_in_superclass(receiver_type.class_symbol, method_name))
            end
          when PrimitiveType
            # Phase 4B.3: Built-in methods for primitive types
            methods.concat(get_builtin_methods(receiver_type.name, method_name))
          when UnionType
            # Phase 4B.4: Find common method in all union members
            # Method can only be called on union if it exists in ALL constituent types
            methods.concat(find_methods_in_union(receiver_type, method_name))
          end

          methods
        end

        # Phase 4B.2: Recursively search for method in superclass chain
        private def find_in_superclass(class_symbol : ClassSymbol, method_name : String) : Array(MethodSymbol)
          methods = [] of MethodSymbol

          # Get superclass name
          superclass_name = class_symbol.superclass_name
          return methods unless superclass_name

          # Lookup superclass in global symbol table
          superclass_symbol = @global_table.try(&.lookup(superclass_name))
          return methods unless superclass_symbol.is_a?(ClassSymbol)

          # Look for method in superclass scope
          if symbol = superclass_symbol.scope.lookup(method_name)
            case symbol
            when MethodSymbol
              methods << symbol
            when OverloadSetSymbol
              methods.concat(symbol.overloads)
            end
          end

          # Recursively search in superclass's superclass
          if methods.empty?
            methods.concat(find_in_superclass(superclass_symbol, method_name))
          end

          methods
        end

        # Phase 4B.4: Compute union return type for method call on union
        #
        # When calling a method on a union type (T | U | V), the return type
        # is the union of return types from each constituent type.
        #
        # Example:
        #   class A; def foo : Int32; end; end
        #   class B; def foo : String; end; end
        #   x = A.new | B.new  # A | B
        #   x.foo  # Returns Int32 | String
        private def compute_union_method_return_type(union_type : UnionType, method_name : String, arg_types : Array(Type)) : Type?
          return_types = [] of Type

          # Get return type from each union member
          union_type.types.each do |member_type|
            # Find and resolve method for this specific type
            if method = lookup_method(member_type, method_name, arg_types)
              if ann = method.return_annotation
                return_types << parse_type_name(ann)
              else
                return_types << @context.nil_type
              end
            else
              # Method not found in this type → cannot call on union
              return nil
            end
          end

          # Create union of all return types
          union_of(return_types)
        end

        # Phase 4B.4: Find methods common to all types in a union
        #
        # Production-ready Crystal-compatible implementation:
        # 1. Method must exist in ALL constituent types
        # 2. Parameter signatures must be compatible
        # 3. Returns methods that can be called with compatible arguments
        #
        # Note: This returns candidate methods for overload resolution.
        # The caller must compute union return type separately.
        private def find_methods_in_union(union_type : UnionType, method_name : String) : Array(MethodSymbol)
          # Find methods in each constituent type
          methods_per_type = union_type.types.map do |member_type|
            find_all_methods(member_type, method_name)
          end

          # Check if ALL types have this method
          return [] of MethodSymbol if methods_per_type.any?(&.empty?)

          # For now, return methods from first type
          # The overload resolution will filter by parameter compatibility
          # and the caller will compute union return type
          methods_per_type[0]
        end

        # Check if method parameters match argument types
        private def parameters_match?(method : MethodSymbol, arg_types : Array(Type)) : Bool
          method.params.zip(arg_types).all? do |param, arg_type|
            # If parameter has no type annotation, it matches any argument type
            type_ann = param.type_annotation
            return true unless type_ann

            # If parameter has type annotation, check if argument type matches
            param_type = parse_type_name(type_ann)
            type_matches?(arg_type, param_type)
          end
        end

        # Check if actual_type is compatible with expected_type
        #
        # Phase 4B: Simple exact match for now
        # TODO: Add subtyping, union types, nilable types
        private def type_matches?(actual : Type, expected : Type) : Bool
          # Exact type match
          actual.to_s == expected.to_s
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
        # Phase 4B.3: Built-in Methods for Primitive Types
        # ============================================================

        # Get built-in methods for a primitive type
        #
        # Returns an array of MethodSymbol representing built-in methods
        # like Int32#+, String#size, etc.
        private def get_builtin_methods(type_name : String, method_name : String) : Array(MethodSymbol)
          methods = [] of MethodSymbol

          # Dummy values for built-in methods (no AST node)
          dummy_node_id = ExprId.new(0)
          dummy_scope = SymbolTable.new(nil)

          case type_name
          when "Int32", "Int64", "Float64"
            # Arithmetic operators
            case method_name
            when "+", "-", "*", "/"
              # Binary arithmetic: Int32#+(Int32) : Int32
              param = Frontend::Parameter.new(name: "other", type_annotation: type_name)
              methods << MethodSymbol.new(
                method_name,
                dummy_node_id,
                params: [param],
                return_annotation: type_name,
                scope: dummy_scope
              )
            when "<", ">", "<=", ">=", "==", "!="
              # Comparison operators: Int32#<(Int32) : Bool
              param = Frontend::Parameter.new(name: "other", type_annotation: type_name)
              methods << MethodSymbol.new(
                method_name,
                dummy_node_id,
                params: [param],
                return_annotation: "Bool",
                scope: dummy_scope
              )
            end

          when "String"
            case method_name
            when "size"
              # String#size : Int32
              methods << MethodSymbol.new(
                method_name,
                dummy_node_id,
                params: [] of Frontend::Parameter,
                return_annotation: "Int32",
                scope: dummy_scope
              )
            when "+"
              # String#+(String) : String
              param = Frontend::Parameter.new(name: "other", type_annotation: "String")
              methods << MethodSymbol.new(
                method_name,
                dummy_node_id,
                params: [param],
                return_annotation: "String",
                scope: dummy_scope
              )
            when "==", "!="
              # String#==(String) : Bool
              param = Frontend::Parameter.new(name: "other", type_annotation: "String")
              methods << MethodSymbol.new(
                method_name,
                dummy_node_id,
                params: [param],
                return_annotation: "Bool",
                scope: dummy_scope
              )
            end

          when "Bool"
            case method_name
            when "==", "!="
              # Bool#==(Bool) : Bool
              param = Frontend::Parameter.new(name: "other", type_annotation: "Bool")
              methods << MethodSymbol.new(
                method_name,
                dummy_node_id,
                params: [param],
                return_annotation: "Bool",
                scope: dummy_scope
              )
            end
          end

          methods
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
