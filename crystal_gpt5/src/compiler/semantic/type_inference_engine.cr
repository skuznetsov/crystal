require "./types/type_context"
require "./types/type"
require "./types/primitive_type"
require "./types/class_type"
require "./types/instance_type"
require "./types/union_type"
require "./types/array_type"
require "./types/range_type"
require "./types/hash_type"
require "./types/tuple_type"
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

          result_type = case node.kind
          when .number?
            infer_number(node)
          when .string?
            infer_string(node)
          when .string_interpolation?
            infer_string_interpolation(node, expr_id)
          when .symbol?
            # Phase 16: Symbol literals
            infer_symbol(node)
          when .array_literal?
            infer_array_literal(node, expr_id)
          when .bool?
            infer_bool(node)
          when .nil?
            infer_nil(node)
          when .identifier?
            infer_identifier(node, expr_id)
          when .instance_var?
            infer_instance_var(node, expr_id)
          when .instance_var_decl?
            # Phase 5C/77: Instance variable declaration (@var : Type)
            infer_instance_var_decl(node, expr_id)
          when .class_var?
            # Phase 76: Class variables
            infer_class_var(node, expr_id)
          when .class_var_decl?
            # Phase 77: Class variable declaration (@@var : Type)
            infer_class_var_decl(node, expr_id)
          when .global?
            # Phase 75: Global variables
            infer_global(node, expr_id)
          when .global_var_decl?
            # Phase 77: Global variable declaration ($var : Type)
            infer_global_var_decl(node, expr_id)
          when .unary?
            # Phase 17: Unary operators (+x, -x, !x)
            infer_unary(node, expr_id)
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
          when .index?
            # Phase 9: Array indexing arr[0]
            infer_index(node, expr_id)
          when .if?
            infer_if(node)
          when .unless?
            # Phase 24: unless condition
            infer_unless(node)
          when .while?
            infer_while(node)
          when .until?
            # Phase 25: until loop
            infer_until(node)
          when .begin?
            # Phase 28/29: begin/end blocks with rescue/ensure
            infer_begin(node)
          when .raise?
            # Phase 29: raise exception
            infer_raise(node)
          when .require?
            # Phase 65: require statement
            infer_require(node)
          when .type_declaration?
            # Phase 66: type declaration
            infer_type_declaration(node)
          when .with?
            # Phase 67: with context block
            infer_with(node)
          when .getter?
            # Phase 30: getter macro
            infer_accessor(node)
          when .setter?
            # Phase 30: setter macro
            infer_accessor(node)
          when .property?
            # Phase 30: property macro
            infer_accessor(node)
          when .assign?
            infer_assign(node, expr_id)
          when .multiple_assign?
            infer_multiple_assign(node, expr_id)
          when .return?
            infer_return(node, expr_id)
          when .self?
            infer_self(node, expr_id)
          when .super?
            # Phase 39: Super expressions
            infer_super(node, expr_id)
          when .typeof?
            # Phase 40: Typeof expressions
            infer_typeof(node, expr_id)
          when .sizeof?
            # Phase 41: Sizeof expressions
            infer_sizeof(node, expr_id)
          when .pointerof?
            # Phase 42: Pointerof expressions
            infer_pointerof(node, expr_id)
          when ExpressionNode::Kind::As
            # Phase 44: Type cast expressions (can't use .as? due to keyword collision)
            infer_as(node, expr_id)
          when ExpressionNode::Kind::AsQuestion
            # Phase 45: Safe cast expressions (nilable)
            infer_as_question(node, expr_id)
          when ExpressionNode::Kind::IsA
            # Phase 46: Type check expressions (returns Bool)
            infer_is_a(node, expr_id)
          when ExpressionNode::Kind::RespondsTo
            # Phase 49: Method check expressions (returns Bool)
            infer_responds_to(node, expr_id)
          when ExpressionNode::Kind::Generic
            # Phase 60: Generic type instantiation
            infer_generic(node, expr_id)
          when ExpressionNode::Kind::Path
            # Phase 63: Path expressions (Foo::Bar)
            infer_path(node, expr_id)
          when ExpressionNode::Kind::SafeNavigation
            # Phase 47: Safe navigation expressions (returns nilable)
            infer_safe_navigation(node, expr_id)
          when .block?
            # Phase 10: Block literals
            infer_block(node, expr_id)
          when .proc_literal?
            # Phase 74: Proc literals
            infer_proc_literal(node, expr_id)
          when .yield?
            # Phase 10: Yield expressions
            infer_yield(node, expr_id)
          when .case?
            # Phase 11: Case/when pattern matching
            infer_case(node, expr_id)
          when .break?
            # Phase 12: Break expressions
            infer_break(node, expr_id)
          when .next?
            # Phase 12: Next expressions
            infer_next(node, expr_id)
          when .range?
            # Phase 13: Range expressions
            infer_range(node, expr_id)
          when .hash_literal?
            # Phase 14: Hash literals
            infer_hash_literal(node, expr_id)
          when .tuple_literal?
            # Phase 15: Tuple literals
            infer_tuple_literal(node, expr_id)
          when .named_tuple_literal?
            # Phase 70: Named tuple literals
            infer_named_tuple_literal(node, expr_id)
          when .ternary?
            # Phase 23: Ternary operator
            infer_ternary(node, expr_id)
          when .module?
            # Phase 31: Module definition
            infer_module(node, expr_id)
          when .include?
            # Phase 31: Include module
            infer_include(node)
          when .extend?
            # Phase 31: Extend module
            infer_extend(node)
          when .struct?
            # Phase 32: Struct definition (value type)
            # At parsing stage, handled identically to class
            infer_class(node, expr_id)
          when .enum?
            # Phase 33: Enum definition (enumerated type)
            infer_enum(node)
          when .alias?
            # Phase 34: Type alias definition
            infer_alias(node)
          when .constant?
            # Phase 35: Constant declaration
            infer_constant(node)
          when .lib?
            # Phase 38: Lib definition (C bindings)
            infer_lib(node, expr_id)
          when .fun?
            # Phase 64: Fun declaration (C function)
            infer_fun(node)
          when .grouping?
            # Grouping expressions: (expr)
            # Type is the type of the wrapped expression
            infer_expression(node.left.not_nil!)
          else
            # Unknown expression kind
            @context.nil_type
          end

          # Always set type for this expression (some infer_* methods already do this,
          # but this ensures ALL expressions have types set, even for nested calls)
          @context.set_type(expr_id, result_type)
          result_type
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

        # Phase 16: Symbol literal type inference
        private def infer_symbol(node) : Type
          @context.symbol_type
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
          # Phase 71: Process default parameter values
          if params = node.def_params
            params.each do |param|
              if default_value = param.default_value
                infer_expression(default_value)
              end
            end
          end

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

        # Phase 31: Type inference for module definition
        private def infer_module(node, expr_id : ExprId) : Type
          # In a full implementation, we would:
          # 1. Look up ModuleSymbol from symbol table
          # 2. Save current module context
          # 3. Process module body
          # 4. Restore previous module context
          # For now, just process the body
          (node.module_body || [] of ExprId).each do |body_expr_id|
            infer_expression(body_expr_id)
          end

          # Module definitions don't have value types
          @context.nil_type
        end

        # Phase 31: Type inference for include statement
        private def infer_include(node) : Type
          # In a full implementation, we would:
          # 1. Look up the module being included
          # 2. Mix the module's methods into the current class/module
          # 3. Verify module exists
          # For now, include statements just return Nil
          @context.nil_type
        end

        # Phase 31: Type inference for extend statement
        private def infer_extend(node) : Type
          # In a full implementation, we would:
          # 1. Look up the module being extended
          # 2. Mix the module's methods as class methods
          # 3. Verify module exists
          # For now, extend statements just return Nil
          @context.nil_type
        end

        # Phase 33: Type inference for enum definition
        private def infer_enum(node) : Type
          # In a full implementation, we would:
          # 1. Create an EnumType with members
          # 2. Process member values (if any) and infer their types
          # 3. Validate base type compatibility
          # For now, process member values and return Nil
          if members = node.enum_members
            members.each do |member|
              if value_expr = member.value
                infer_expression(value_expr)
              end
            end
          end

          # Enum definitions don't have value types
          @context.nil_type
        end

        private def infer_alias(node) : Type
          # Phase 34: Type alias definition
          # Type aliases are compile-time constructs with no runtime value
          # For now, we just acknowledge the alias exists and return Nil
          # In future, this would register the alias in a type registry
          @context.nil_type
        end

        # Phase 38: Type inference for lib definition
        private def infer_lib(node, expr_id : ExprId) : Type
          # In a full implementation, we would:
          # 1. Look up LibSymbol from symbol table
          # 2. Save current lib context
          # 3. Process lib body (fun, type declarations)
          # 4. Restore previous context
          # For now, just process the body
          (node.lib_body || [] of ExprId).each do |body_expr_id|
            infer_expression(body_expr_id)
          end

          # Lib definitions don't have value types
          @context.nil_type
        end

        # Phase 64: Type inference for fun declaration (C function)
        private def infer_fun(node) : Type
          # Fun declarations are external C functions with no body
          # They specify:
          # - def_name: function name
          # - def_params: parameters (typed)
          # - def_return_type: return type annotation
          # - def_body: nil (no implementation)
          #
          # In a full implementation, we would:
          # 1. Register the function signature in the current lib context
          # 2. Resolve parameter types and return type
          # 3. Make the function available for calls
          #
          # For now, fun declarations have no runtime value (they're declarations)
          @context.nil_type
        end

        private def infer_constant(node) : Type
          # Phase 35: Constant declaration
          # Infer type from the assigned value expression
          if value_expr = node.constant_value
            infer_expression(value_expr)
          else
            @context.nil_type
          end
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

        # Phase 76: Infer type of class variable
        private def infer_class_var(node, expr_id : ExprId) : Type
          # For now, return nil_type as placeholder
          # Future: Track class variable types in class scope
          # (Type will be set by infer_expression)
          @context.nil_type
        end

        # Phase 75: Infer type of global variable
        private def infer_global(node, expr_id : ExprId) : Type
          # For now, return nil_type as placeholder
          # Future: Track global variable types in global scope
          # (Type will be set by infer_expression)
          @context.nil_type
        end

        # Phase 5C/77: Infer type of instance variable declaration (@var : Type)
        private def infer_instance_var_decl(node, expr_id : ExprId) : Type
          # Type declarations have no runtime value, return nil_type
          # The type annotation is stored in ivar_decl_type for semantic analysis
          @context.nil_type
        end

        # Phase 77: Infer type of class variable declaration (@@var : Type)
        private def infer_class_var_decl(node, expr_id : ExprId) : Type
          # Type declarations have no runtime value, return nil_type
          # The type annotation is stored in ivar_decl_type for semantic analysis
          @context.nil_type
        end

        # Phase 77: Infer type of global variable declaration ($var : Type)
        private def infer_global_var_decl(node, expr_id : ExprId) : Type
          # Type declarations have no runtime value, return nil_type
          # The type annotation is stored in ivar_decl_type for semantic analysis
          @context.nil_type
        end

        # Parse simple type name (e.g., "Int32", "String")
        # For Phase 1: Only built-in primitive types
        private def parse_type_name(name : String) : Type
          # Check for generic type syntax: Array(T)
          if name.includes?('(') && name.includes?(')')
            # Extract base type and type argument
            paren_start = name.index('(').not_nil!
            paren_end = name.rindex(')').not_nil!

            base_type = name[0...paren_start]
            type_arg = name[(paren_start + 1)...paren_end]

            case base_type
            when "Array"
              element_type = parse_type_name(type_arg)
              return ArrayType.new(element_type)
            else
              emit_error("Unknown generic type '#{base_type}'")
              return @context.nil_type
            end
          end

          # Handle primitive types
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

          result_type = case op
          when "+", "-", "*", "/", "//", "%", "**", "<<", ">>", "&", "|", "^"
            # Phase 4B.3/4B.5/18/19/21/22/78: Try method lookup first for built-in methods
            if method = lookup_method(left_type, op, [right_type])
              if ann = method.return_annotation
                parse_type_name(ann)
              else
                @context.nil_type
              end
            # Fallback: numeric promotion for untyped numeric operators
            # Exclude << (array push operator) as it has specific semantics
            elsif op != "<<" && numeric_type?(left_type) && numeric_type?(right_type)
              promote_numeric_types(left_type, right_type)
            else
              # No method found and not numeric types
              emit_error("Operator '#{op}' not defined for #{left_type} and #{right_type}", expr_id)
              @context.nil_type
            end

          when "==", "!=", "<", ">", "<=", ">=", "===", "=~", "!~", "in"
            # Phase 4B.3/4B.5/50/79/80: Try method lookup first for built-in methods
            # Phase 50: === (case equality) returns Bool like ==
            # Phase 79: in (containment) returns Bool
            # Phase 80: =~ (regex match), !~ (regex not match) return Bool
            if method = lookup_method(left_type, op, [right_type])
              if ann = method.return_annotation
                parse_type_name(ann)
              else
                @context.bool_type
              end
            else
              # Fallback: comparison operators → Bool for compatible types
              @context.bool_type
            end

          when "<=>"
            # Phase 48: Spaceship operator (three-way comparison)
            # Returns Int32: -1 (less), 0 (equal), or 1 (greater)
            # Try method lookup first
            if method = lookup_method(left_type, op, [right_type])
              if ann = method.return_annotation
                parse_type_name(ann)
              else
                @context.int32_type
              end
            else
              # Fallback: spaceship operator → Int32
              @context.int32_type
            end

          when "&&", "||"
            # Logical operators
            unless bool_type?(left_type) && bool_type?(right_type)
              emit_error("Operator '#{op}' requires bool types, got #{left_type} and #{right_type}", expr_id)
              @context.nil_type
            else
              @context.bool_type
            end

          when "??"
            # Phase 81: Nil-coalescing operator
            # value ?? default - returns value if not nil, otherwise default
            # Type: Simplified - return union of left and right types
            # More accurate: return non-nil version of left type | right type
            # For now: return right type (the fallback type)
            right_type

          else
            emit_error("Unknown operator '#{op}'", expr_id)
            @context.nil_type
          end

          # Type will be set by infer_expression
          result_type
        end

        # Phase 17: Unary operator type inference
        private def infer_unary(node, expr_id : ExprId) : Type
          # Unary node has right (operand) and operator fields
          operand_id = node.right
          return @context.nil_type unless operand_id

          operand_type = infer_expression(operand_id)
          op = node.operator_string || ""

          result_type = case op
          when "!"
            # Logical not: always returns Bool
            # In Crystal: nil and false are falsy, everything else is truthy
            @context.bool_type
          when "+"
            # Unary plus: identity for numeric types
            if numeric_type?(operand_type)
              operand_type
            else
              emit_error("Unary '+' not defined for #{operand_type}", expr_id)
              @context.nil_type
            end
          when "-"
            # Unary minus: negation for numeric types
            if numeric_type?(operand_type)
              operand_type
            else
              emit_error("Unary '-' not defined for #{operand_type}", expr_id)
              @context.nil_type
            end
          when "~"
            # Phase 21: Bitwise NOT for integer types
            if numeric_type?(operand_type)
              operand_type
            else
              emit_error("Bitwise '~' not defined for #{operand_type}", expr_id)
              @context.nil_type
            end
          else
            emit_error("Unknown unary operator '#{op}'", expr_id)
            @context.nil_type
          end

          result_type
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
              # (infer_expression sets types automatically)
              result_type = @context.nil_type
              then_body.each do |expr_id|
                result_type = infer_expression(expr_id)
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
              # (infer_expression sets types automatically)
              elsif_type = if elsif_branch.body.size > 0
                result_type = @context.nil_type
                elsif_branch.body.each do |expr_id|
                  result_type = infer_expression(expr_id)
                end
                result_type
              else
                @context.nil_type
              end

              elsif_types << elsif_type
            end
          end

          # Infer else body (or Nil if no else)
          # (infer_expression sets types automatically)
          else_type = if else_body = node.if_else
            if else_body.size > 0
              # Infer all expressions in body, save type of last
              result_type = @context.nil_type
              else_body.each do |expr_id|
                result_type = infer_expression(expr_id)
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

        # Phase 24: Type inference for unless (similar to if but without elsif)
        private def infer_unless(node) : Type
          # Infer condition type
          condition_id = node.if_condition
          return @context.nil_type unless condition_id

          condition_type = infer_expression(condition_id)

          # Check condition is Bool
          unless bool_type?(condition_type)
            emit_error("Unless condition must be Bool, got #{condition_type}", condition_id)
          end

          # Infer then body (executed when condition is false)
          then_type = if then_body = node.if_then
            if then_body.size > 0
              result_type = @context.nil_type
              then_body.each do |expr_id|
                result_type = infer_expression(expr_id)
              end
              result_type
            else
              @context.nil_type
            end
          else
            @context.nil_type
          end

          # Infer else body (executed when condition is true)
          else_type = if else_body = node.if_else
            if else_body.size > 0
              result_type = @context.nil_type
              else_body.each do |expr_id|
                result_type = infer_expression(expr_id)
              end
              result_type
            else
              @context.nil_type
            end
          else
            # No else branch → implicit Nil
            @context.nil_type
          end

          # Create union type of both branches: then + else
          union_of([then_type, else_type])
        end

        # Phase 25: Type inference for until loop (inverse of while)
        private def infer_until(node) : Type
          # Infer condition type
          condition_id = node.while_condition  # Reuse while_condition field
          return @context.nil_type unless condition_id

          condition_type = infer_expression(condition_id)

          # Check condition is Bool
          unless bool_type?(condition_type)
            emit_error("Until condition must be Bool, got #{condition_type}", condition_id)
          end

          # Infer body expressions (result not used)
          if body = node.while_body  # Reuse while_body field
            body.each { |expr_id| infer_expression(expr_id) }
          end

          # Until loops always return Nil in Crystal (like while)
          @context.nil_type
        end

        # Phase 28/29: Type inference for begin/end blocks with rescue/ensure
        # Begin blocks return the type of the last expression, or Nil if empty
        # With rescue: union of begin body type and all rescue body types
        # Ensure doesn't affect type (always runs but doesn't change return value)
        private def infer_begin(node) : Type
          # Infer begin body type
          body = node.begin_body
          begin_type = if body && body.size > 0
            result_type = @context.nil_type
            body.each do |expr_id|
              result_type = infer_expression(expr_id)
            end
            result_type
          else
            @context.nil_type
          end

          # Phase 29: Infer rescue clause types
          types = [begin_type]
          if rescue_clauses = node.rescue_clauses
            rescue_clauses.each do |rescue_clause|
              rescue_type = if rescue_clause.body.size > 0
                result_type = @context.nil_type
                rescue_clause.body.each do |expr_id|
                  result_type = infer_expression(expr_id)
                end
                result_type
              else
                @context.nil_type
              end
              types << rescue_type
            end
          end

          # Phase 29: Infer ensure body (for side effects only, doesn't affect type)
          if ensure_body = node.ensure_body
            ensure_body.each { |expr_id| infer_expression(expr_id) }
          end

          # Return union of begin and all rescue types
          union_of(types)
        end

        # Phase 29: Type inference for raise statement
        # Raise always returns Nil (it never actually returns, but we use Nil for simplicity)
        # In a full compiler, this would be NoReturn type
        private def infer_raise(node) : Type
          # Infer the raise value (if present)
          if raise_value = node.raise_value
            infer_expression(raise_value)
          end

          # Raise never returns, but we use Nil as type
          @context.nil_type
        end

        # Phase 65: Type inference for require statement
        private def infer_require(node) : Type
          # Infer the require path expression (typically a string literal)
          if require_path = node.require_path
            infer_expression(require_path)
          end

          # Require statements are executed at compile-time for imports
          # They don't have a runtime value, so return Nil type
          @context.nil_type
        end

        # Phase 66: Type inference for type declaration
        private def infer_type_declaration(node) : Type
          # Type declarations like `x : Int32` declare a variable with an explicit type
          # but don't assign a value. They are compile-time type annotations.
          #
          # In a full implementation:
          # - Register the variable name with its declared type in the scope
          # - Use this type for subsequent references to the variable
          # - Verify assignments match the declared type
          #
          # For now, type declarations have no runtime value (they're declarations)
          @context.nil_type
        end

        # Phase 67: Type inference for with context block
        private def infer_with(node) : Type
          # With block changes the self context to the receiver expression
          # Example: with obj; method1; method2; end
          # Inside the block, self = obj
          #
          # In a full implementation:
          # - Infer the type of the receiver expression
          # - Save current self context
          # - Set self to receiver type
          # - Process body with new self context
          # - Restore previous self context
          # - Return type of last expression in body (or nil if empty)

          # Infer receiver expression
          if receiver = node.with_receiver
            infer_expression(receiver)
          end

          # Process body expressions
          result_type = @context.nil_type
          if body = node.with_body
            body.each do |expr_id|
              result_type = infer_expression(expr_id)
            end
          end

          # Return type of last expression (or nil if no body)
          result_type
        end

        # Phase 30: Type inference for accessor macros (getter/setter/property)
        # These are declarations, not expressions - they return Nil
        # In a full compiler with macro expansion, they would:
        #   1. Declare instance variable (@name : Type)
        #   2. Generate getter method (def name : Type; @name; end)
        #   3. Generate setter method (def name=(@name : Type); end)
        # For now, we parse and type-check the structure only
        private def infer_accessor(node) : Type
          # Future: infer default value types if present
          if specs = node.accessor_specs
            specs.each do |spec|
              if default_value = spec.default_value
                infer_expression(default_value)
              end
            end
          end

          # Accessor macros return Nil as they are declarations
          @context.nil_type
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

        private def infer_assign(node, expr_id : ExprId) : Type
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
          # Phase 14B: Index assignment (h["key"] = value) - no tracking needed,
          # just return value type

          # Assignments return the value type in Crystal
          # Type will be set by infer_expression
          value_type
        end

        # Phase 73: Multiple assignment (a, b = 1, 2)
        private def infer_multiple_assign(node, expr_id : ExprId) : Type
          # Get targets and value
          targets = node.assign_targets
          value_id = node.assign_value

          return @context.nil_type unless targets && value_id

          # Infer value type (typically a tuple)
          value_type = infer_expression(value_id)

          # For each target, store the value type
          # Future: Extract individual types from tuple
          targets.each do |target_id|
            target_node = @program.arena[target_id]
            if target_name = target_node.literal_string
              @assignments[target_name] = value_type
            end
          end

          # Multiple assignment returns the value type
          value_type
        end

        # ============================================================
        # PHASE 6: Return Statements
        # ============================================================

        private def infer_return(node, expr_id : ExprId) : Type
          # If return has a value, infer its type
          # (Type will be set by infer_expression)
          if value_id = node.return_value
            value_type = infer_expression(value_id)
            value_type
          else
            # Return without value returns nil
            @context.nil_type
          end
        end

        # ============================================================
        # PHASE 7: Self Keyword
        # ============================================================

        private def infer_self(node, expr_id : ExprId) : Type
          # self returns InstanceType of the current class
          # (Type will be set by infer_expression)
          if current_class = @current_class
            instance_type = InstanceType.new(current_class)
            instance_type
          else
            # self outside class context (shouldn't happen in valid code)
            @context.nil_type
          end
        end

        # Phase 39: Type inference for super (call parent method)
        private def infer_super(node, expr_id : ExprId) : Type
          # In a full implementation, we would:
          # 1. Look up the current method name
          # 2. Look up the parent class's method with same name
          # 3. Type check the arguments
          # 4. Return the parent method's return type

          # For now, infer types of provided arguments
          if args = node.super_args
            args.each do |arg_expr_id|
              infer_expression(arg_expr_id)
            end
          end

          # Return Nil for now (in full implementation, would return parent method's return type)
          # If super_args is nil, it means implicit args (pass all method args)
          @context.nil_type
        end

        # Phase 40: Type inference for typeof (type introspection)
        private def infer_typeof(node, expr_id : ExprId) : Type
          # typeof returns the type of its argument(s) at compile time
          # In a full implementation:
          # - typeof(x) returns the type of x (e.g., Int32)
          # - typeof(x, y) returns the union type (e.g., Int32 | String)

          # For now, infer types of arguments and return a placeholder
          if args = node.typeof_args
            arg_types = [] of Type
            args.each do |arg_expr_id|
              arg_type = infer_expression(arg_expr_id)
              arg_types << arg_type
            end

            # In full implementation, would return Type metaclass
            # For now, return nil_type as placeholder
          end

          @context.nil_type
        end

        # Phase 41: Type inference for sizeof (size in bytes)
        private def infer_sizeof(node, expr_id : ExprId) : Type
          # sizeof returns the size of a type or expression in bytes
          # In a full implementation:
          # - sizeof(Int32) returns 4 (32 bits = 4 bytes)
          # - sizeof(Type) returns the size of that type
          # - sizeof(expr) returns the size of expr's type

          # For now, infer types of arguments and return Int32
          if args = node.sizeof_args
            args.each do |arg_expr_id|
              infer_expression(arg_expr_id)
            end
          end

          # sizeof always returns Int32 (number of bytes)
          @context.int32_type
        end

        # Phase 42: pointerof (pointer to variable/expression)
        private def infer_pointerof(node, expr_id : ExprId) : Type
          # pointerof returns a pointer to a variable or expression
          # In a full implementation:
          # - pointerof(x) returns Pointer(T) where T is the type of x
          # - pointerof(@ivar) returns pointer to instance variable
          # - pointerof(expr) returns pointer to expression's result

          # For now, infer types of arguments and return nil as placeholder
          if args = node.pointerof_args
            args.each do |arg_expr_id|
              infer_expression(arg_expr_id)
            end
          end

          # Return nil_type as placeholder (full implementation would return Pointer(T))
          @context.nil_type
        end

        # Phase 44: as keyword (type cast)
        private def infer_as(node, expr_id : ExprId) : Type
          # Type cast: value.as(Type)
          # In a full implementation:
          # - Infer type of value being cast
          # - Look up target type in type registry
          # - Verify cast is valid (runtime or compile-time)
          # - Return target type

          # For now, infer type of value and return nil as placeholder
          if value_expr = node.as_value
            infer_expression(value_expr)
          end

          # Return nil_type as placeholder (full implementation would return target type)
          @context.nil_type
        end

        # Phase 45: as? keyword (safe cast - nilable)
        private def infer_as_question(node, expr_id : ExprId) : Type
          # Safe cast: value.as?(Type)
          # Returns Type? (nilable) instead of Type
          # In a full implementation:
          # - Infer type of value being cast
          # - Look up target type in type registry
          # - Return Union(target_type, Nil) - nilable version
          # - Unlike .as, this doesn't panic on invalid cast, returns nil

          # For now, infer type of value and return nil as placeholder
          if value_expr = node.as_question_value
            infer_expression(value_expr)
          end

          # Return nil_type as placeholder (full implementation would return target_type | Nil)
          @context.nil_type
        end

        # Phase 46: is_a? keyword (type check - returns Bool)
        private def infer_is_a(node, expr_id : ExprId) : Type
          # Type check: value.is_a?(Type)
          # Returns Bool (true if value is instance of Type, false otherwise)
          # In a full implementation:
          # - Infer type of value being checked
          # - Look up target type in type registry
          # - Return Bool type
          # - Unlike .as, this doesn't cast, just checks
          # - Can enable type narrowing in conditional branches

          # For now, infer type of value and return bool type
          if value_expr = node.is_a_value
            infer_expression(value_expr)
          end

          # Return Bool type (is_a? always returns boolean)
          @context.bool_type
        end

        # Phase 49: responds_to? method (method check - returns Bool)
        private def infer_responds_to(node, expr_id : ExprId) : Type
          # Method check: value.responds_to?(:method_name)
          # Returns Bool (true if value has method, false otherwise)
          # In a full implementation:
          # - Infer type of value being checked
          # - Extract method name from Symbol/String argument
          # - Look up method in value's type
          # - Return Bool based on whether method exists
          # - Unlike .is_a?, this checks for method availability

          # For now, infer type of value and method name, return bool type
          if value_expr = node.responds_to_value
            infer_expression(value_expr)
          end

          if method_name_expr = node.responds_to_method_name
            infer_expression(method_name_expr)
          end

          # Return Bool type (responds_to? always returns boolean)
          @context.bool_type
        end

        # Phase 60: Generic type instantiation
        private def infer_generic(node, expr_id : ExprId) : Type
          # Generic instantiation: Box(Int32), Hash(String, Int32)
          # Returns the specialized generic type
          # In a full implementation:
          # - Infer base type (Box, Array, Hash)
          # - Infer each type argument
          # - Create specialized generic instance type
          # - Track type parameters for validation

          # For now, infer base name and type arguments, return placeholder
          if name_expr = node.generic_name
            infer_expression(name_expr)
          end

          if type_args = node.generic_type_args
            type_args.each do |arg|
              infer_expression(arg)
            end
          end

          # Return placeholder type (nil_type for now)
          # Future: return specialized generic type like Box<Int32>
          @context.nil_type
        end

        # Phase 63: Type inference for path expressions (Foo::Bar)
        private def infer_path(node, expr_id : ExprId) : Type
          # Path expression: navigating nested types/modules
          # Examples: HTTP::Server, Foo::Bar::Baz, ::TopLevel
          #
          # In a full implementation:
          # - Resolve left side to namespace/type
          # - Look up right identifier within that namespace
          # - Return the resolved type
          # - Handle absolute paths (left = nil)
          #
          # For now, infer left (if present) and right, return placeholder

          # Infer left side (if not absolute path)
          if left_expr = node.left
            infer_expression(left_expr)
          end

          # Infer right side
          if right_expr = node.right
            infer_expression(right_expr)
          end

          # Return placeholder type (nil_type for now)
          # Future: return resolved type from namespace lookup
          @context.nil_type
        end

        # Phase 47: &. safe navigation operator (returns nilable)
        private def infer_safe_navigation(node, expr_id : ExprId) : Type
          # Safe navigation: receiver&.member
          # Returns member_type | Nil (nilable)
          # If receiver is nil, returns nil without calling method
          # Otherwise, calls method and returns its result
          # In a full implementation:
          # - Infer type of receiver
          # - Look up member in receiver's type
          # - Return Union(member_type, Nil) - nilable version

          # For now, infer receiver type and return nil as placeholder
          if receiver_expr = node.left
            infer_expression(receiver_expr)
          end

          # Return nil_type as placeholder (full implementation would return member_type | Nil)
          @context.nil_type
        end

        # ============================================================
        # PHASE 8: String Interpolation
        # ============================================================

        private def infer_string_interpolation(node, expr_id : ExprId) : Type
          # String interpolation always evaluates to String type
          # Infer types for all interpolated expressions
          if pieces = node.string_pieces
            pieces.each do |piece|
              if piece.kind == Frontend::StringPiece::Kind::Expression
                if expr = piece.expr
                  infer_expression(expr)
                end
              end
            end
          end

          # Type will be set by infer_expression
          @context.string_type
        end

        # ============================================================
        # PHASE 9: Array Literals
        # ============================================================

        private def infer_array_literal(node, expr_id : ExprId) : Type
          # Determine element type
          element_type : Type

          # Case 1: Explicit "of Type" syntax ([] of Int32)
          if of_type_slice = node.array_of_type
            type_name = String.new(of_type_slice)
            element_type = parse_type_name(type_name)
          # Case 2: Infer from elements
          elsif elements = node.array_elements
            if elements.empty?
              # Empty array without type annotation - default to Nil
              # (In real Crystal this would be an error, but we'll allow it for now)
              element_type = @context.nil_type
            else
              # Infer type of each element
              element_types = elements.map { |elem_id| infer_expression(elem_id) }

              # Union all element types
              element_type = @context.union_of(element_types)
            end
          else
            # Empty array without elements or type - shouldn't happen
            element_type = @context.nil_type
          end

          # Create Array(T) type
          # (Type will be set by infer_expression)
          array_type = ArrayType.new(element_type)
          array_type
        end

        private def infer_index(node, expr_id : ExprId) : Type
          # Get target (array/hash) and index types
          target_id = node.left
          index_id = node.args.try(&.first)

          return @context.nil_type unless target_id && index_id

          target_type = infer_expression(target_id)
          _index_type = infer_expression(index_id)

          # Phase 9: Array indexing
          if target_type.is_a?(ArrayType)
            element_type = target_type.element_type
            # Type will be set by infer_expression
            element_type
          # Phase 14B: Hash indexing
          elsif target_type.is_a?(HashType)
            value_type = target_type.value_type
            # Type will be set by infer_expression
            value_type
          # Phase 15: Tuple indexing
          elsif target_type.is_a?(TupleType)
            # Tuple indexing requires compile-time constant index
            # For now, support only integer literals
            index_node = @program.arena[index_id]
            if index_node.kind == ExpressionNode::Kind::Number
              # Parse literal index
              index_text = index_node.literal_string
              if index_text
                index_value = index_text.to_i32? || 0
                # Get type at specific index
                if elem_type = target_type.type_at(index_value)
                  elem_type
                else
                  emit_error("Tuple index #{index_value} out of bounds (size: #{target_type.size})", expr_id)
                  @context.nil_type
                end
              else
                emit_error("Invalid tuple index literal", expr_id)
                @context.nil_type
              end
            else
              emit_error("Tuple indexing requires compile-time constant integer", expr_id)
              @context.nil_type
            end
          else
            # Not an array, hash, or tuple - emit error
            emit_error("Cannot index type #{target_type}", expr_id)
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

          # Phase 10: Infer block type if present
          if block_id = node.call_block
            infer_expression(block_id)
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

          # Lookup method with overload resolution
          result_type = if method = lookup_method(receiver_type, method_name, arg_types)
            if ann = method.return_annotation
              parse_type_name(ann)
            else
              @context.nil_type
            end
          else
            emit_error("Method '#{method_name}' not found on #{receiver_type}", expr_id)
            @context.nil_type
          end

          # Type will be set by infer_expression
          result_type
        end

        private def infer_call(node, expr_id : ExprId) : Type
          # Phase 10: Infer block type if present (do this FIRST, even for unsupported calls)
          if block_id = node.call_block
            infer_expression(block_id)
          end

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
            # But we still inferred the block above, so return nil_type for the call itself
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

          # Phase 72: Infer named argument value types
          if named_args = node.named_args
            named_args.each do |named_arg|
              infer_expression(named_arg.value)
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
          result_type = if method = lookup_method(receiver_type, method_name, arg_types)
            # Return declared return type
            if ann = method.return_annotation
              parse_type_name(ann)
            else
              @context.nil_type
            end
          else
            emit_error("Method '#{method_name}' not found on #{receiver_type}", expr_id)
            @context.nil_type
          end

          # Type will be set by infer_expression
          result_type
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
          when ArrayType
            # Phase 9: Built-in methods for arrays
            methods.concat(get_array_builtin_methods(receiver_type, method_name))
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
            when "+", "-", "*", "/", "//"
              # Binary arithmetic: Int32#+(Int32) : Int32
              # Phase 78: // floor division
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

        # Phase 9: Built-in methods for Array(T)
        private def get_array_builtin_methods(array_type : ArrayType, method_name : String) : Array(MethodSymbol)
          methods = [] of MethodSymbol

          # Dummy values for built-in methods
          dummy_node_id = ExprId.new(0)
          dummy_scope = SymbolTable.new(nil)

          element_type_name = array_type.element_type.to_s

          case method_name
          when "size"
            # Array(T)#size : Int32
            methods << MethodSymbol.new(
              method_name,
              dummy_node_id,
              params: [] of Frontend::Parameter,
              return_annotation: "Int32",
              scope: dummy_scope
            )
          when "empty?"
            # Array(T)#empty? : Bool
            methods << MethodSymbol.new(
              method_name,
              dummy_node_id,
              params: [] of Frontend::Parameter,
              return_annotation: "Bool",
              scope: dummy_scope
            )
          when "first", "last"
            # Array(T)#first : T
            # Array(T)#last : T
            # Return element type
            methods << MethodSymbol.new(
              method_name,
              dummy_node_id,
              params: [] of Frontend::Parameter,
              return_annotation: element_type_name,
              scope: dummy_scope
            )
          when "<<"
            # Array(T)#<<(T) : Array(T)
            # Push returns the array itself
            param = Frontend::Parameter.new(name: "value", type_annotation: element_type_name)
            methods << MethodSymbol.new(
              method_name,
              dummy_node_id,
              params: [param],
              return_annotation: "Array(#{element_type_name})",
              scope: dummy_scope
            )
          end

          methods
        end

        # ============================================================
        # PHASE 10: Blocks and Yield
        # ============================================================

        private def infer_block(node, expr_id : ExprId) : Type
          # Infer types of block body expressions
          body = node.block_body || [] of ExprId

          # Type of block is the type of its last expression
          # (Type will be set by infer_expression)
          block_type = if body.empty?
            @context.nil_type
          else
            body.each { |stmt_id| infer_expression(stmt_id) }
            infer_expression(body.last)
          end

          block_type
        end

        private def infer_yield(node, expr_id : ExprId) : Type
          # Infer types of yield arguments
          if args = node.yield_args
            args.each { |arg_id| infer_expression(arg_id) }
          end

          # For now, yield returns Nil
          # TODO: In full implementation, yield should return the block's return type
          # (Type will be set by infer_expression)
          @context.nil_type
        end

        # Phase 74: Proc literal type inference
        private def infer_proc_literal(node, expr_id : ExprId) : Type
          # Infer parameter types (if annotated)
          params = node.block_params || [] of Parameter

          # Infer body type
          body = node.block_body || [] of ExprId
          body_type = if body.empty?
            @context.nil_type
          else
            body.each { |stmt_id| infer_expression(stmt_id) }
            infer_expression(body.last)
          end

          # If return type is annotated, use it
          # Otherwise use inferred body type
          # For now, we return a simple Proc type
          # TODO: Full implementation should create Proc(Arg1, Arg2, ... -> ReturnType)

          # Return a generic Proc type
          # In a full implementation, this would be Proc(T1, T2 -> R)
          @context.proc_type
        end

        # ============================================================
        # PHASE 11: Case/When
        # ============================================================

        private def infer_case(node, expr_id : ExprId) : Type
          # Infer type of case value
          if value_id = node.case_value
            infer_expression(value_id)
          end

          # Collect types from all branches
          branch_types = [] of Type

          # Infer types from when branches
          if branches = node.when_branches
            branches.each do |branch|
              # Infer types of conditions
              branch.conditions.each { |cond_id| infer_expression(cond_id) }

              # Type of branch is the type of its last expression
              branch_type = if branch.body.empty?
                @context.nil_type
              else
                branch.body.each { |stmt_id| infer_expression(stmt_id) }
                infer_expression(branch.body.last)
              end

              branch_types << branch_type
            end
          end

          # Infer type from else clause
          if else_body = node.case_else
            else_type = if else_body.empty?
              @context.nil_type
            else
              else_body.each { |stmt_id| infer_expression(stmt_id) }
              infer_expression(else_body.last)
            end
            branch_types << else_type
          else
            # No else clause means case can return nil if no when matches
            branch_types << @context.nil_type
          end

          # Case type is union of all branch types
          # (Type will be set by infer_expression)
          case_type = if branch_types.size == 1
            branch_types[0]
          else
            @context.union_of(branch_types)
          end

          case_type
        end

        # ============================================================
        # PHASE 12: Break/Next
        # ============================================================

        private def infer_break(node, expr_id : ExprId) : Type
          # Break can have an optional value
          # (Type will be set by infer_expression)
          break_type = if value_id = node.break_value
            infer_expression(value_id)
          else
            @context.nil_type
          end

          break_type
        end

        private def infer_next(node, expr_id : ExprId) : Type
          # Next has no value in Crystal, always returns Nil
          # (Type will be set by infer_expression)
          @context.nil_type
        end

        # ============================================================
        # PHASE 13: Range Expressions
        # ============================================================

        private def infer_range(node, expr_id : ExprId) : Type
          # Infer types of begin and end expressions
          begin_id = node.range_begin.not_nil!
          end_id = node.range_end.not_nil!

          begin_type = infer_expression(begin_id)
          end_type = infer_expression(end_id)

          # Create Range(B, E) type
          # (Type will be set by infer_expression)
          range_type = RangeType.new(begin_type, end_type)
          range_type
        end

        # ============================================================
        # PHASE 14: Hash Literals
        # ============================================================

        private def infer_hash_literal(node, expr_id : ExprId) : Type
          # Type will be set by infer_expression
          entries = node.hash_entries

          # Empty hash with explicit type annotation
          if entries.nil? || entries.empty?
            if key_type_slice = node.hash_of_key_type
              value_type_slice = node.hash_of_value_type.not_nil!

              # Parse type names and lookup types
              key_type_name = String.new(key_type_slice)
              value_type_name = String.new(value_type_slice)

              key_type = lookup_type_by_name(key_type_name)
              value_type = lookup_type_by_name(value_type_name)

              hash_type = HashType.new(key_type, value_type)
              return hash_type
            else
              # Empty hash without type annotation - error
              # For now, default to Hash(Nil, Nil) as placeholder
              hash_type = HashType.new(@context.nil_type, @context.nil_type)
              return hash_type
            end
          end

          # Infer types from entries
          key_types = [] of Type
          value_types = [] of Type

          entries.each do |entry|
            key_type = infer_expression(entry.key)
            value_type = infer_expression(entry.value)
            key_types << key_type
            value_types << value_type
          end

          # Create union types for keys and values
          final_key_type = if key_types.size == 1
            key_types[0]
          else
            # All keys should be same type, but if mixed, create union
            @context.union_of(key_types)
          end

          final_value_type = if value_types.size == 1
            value_types[0]
          else
            @context.union_of(value_types)
          end

          hash_type = HashType.new(final_key_type, final_value_type)
          hash_type
        end

        # ============================================================
        # PHASE 15: Tuple Literals
        # ============================================================

        private def infer_tuple_literal(node, expr_id : ExprId) : Type
          # Type will be set by infer_expression
          elements = node.tuple_elements

          # Empty tuple (shouldn't happen, but handle gracefully)
          if elements.nil? || elements.empty?
            return TupleType.new([] of Type)
          end

          # Infer type of each element
          element_types = elements.map { |elem_id| infer_expression(elem_id) }

          # Create Tuple(T1, T2, ..., Tn) type
          tuple_type = TupleType.new(element_types)
          tuple_type
        end

        # PHASE 70: Named Tuple Literals
        # ============================================================

        private def infer_named_tuple_literal(node, expr_id : ExprId) : Type
          # Named tuple: {name: "Alice", age: 30}
          # Type: NamedTuple(name: String, age: Int32)
          entries = node.named_tuple_entries

          # Empty named tuple (shouldn't happen with current parser, but handle)
          if entries.nil? || entries.empty?
            # Empty named tuple is valid in Crystal
            return @context.nil_type  # Placeholder for future NamedTupleType with no fields
          end

          # Infer type of each value
          # For full type system, we'd create:
          # NamedTupleType with fields: [(key, value_type), ...]
          # For now, just infer all values
          entries.each do |entry|
            infer_expression(entry.value)
          end

          # Return placeholder type
          # Future: return NamedTupleType.new(entries.map { |e| {e.key, infer_expression(e.value)} })
          @context.nil_type
        end

        # Phase 23: Infer type of ternary operator
        #
        # condition ? true_branch : false_branch
        #
        # Returns the union of true_branch and false_branch types
        private def infer_ternary(node, expr_id : ExprId) : Type
          condition_id = node.ternary_condition.not_nil!
          true_id = node.ternary_true_branch.not_nil!
          false_id = node.ternary_false_branch.not_nil!

          # Infer all three expressions
          condition_type = infer_expression(condition_id)
          true_type = infer_expression(true_id)
          false_type = infer_expression(false_id)

          # In Crystal, condition can be any type (truthy/falsy semantics)
          # We don't need to check condition_type

          # Return union of both branches
          union_of([true_type, false_type])
        end

        # ============================================================
        # Helper Methods
        # ============================================================

        private def lookup_type_by_name(name : String) : Type
          case name
          when "Int32"
            @context.int32_type
          when "Int64"
            @context.int64_type
          when "Float64"
            @context.float64_type
          when "String"
            @context.string_type
          when "Bool"
            @context.bool_type
          when "Nil"
            @context.nil_type
          when "Char"
            @context.char_type
          else
            # Unknown type, default to Nil
            @context.nil_type
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
