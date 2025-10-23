require "../../frontend/ast"
require "../symbol"
require "../context"
require "../symbol_table"
require "../diagnostic"

module CrystalGPT5
  module Compiler
    module Semantic
      class SymbolCollector
        alias Program = Frontend::Program
        alias ExpressionNode = Frontend::ExpressionNode

        getter diagnostics : Array(Diagnostic)

        def initialize(@program : Program, context : Context)
          @arena = @program.arena
          @table_stack = [context.symbol_table]
          @diagnostics = [] of Diagnostic
        end

        def collect
          @program.roots.each do |root_id|
            visit(root_id)
          end
          self
        end

        private def current_table
          @table_stack.last
        end

        private def push_table(table : SymbolTable)
          @table_stack << table
        end

        private def pop_table
          @table_stack.pop
        end

        private def visit(node_id : Frontend::ExprId)
          return if node_id.invalid?

          node = @arena[node_id]

          case node.kind
          when ExpressionNode::Kind::MacroDef
            handle_macro_def(node_id, node)
          when ExpressionNode::Kind::Def
            handle_def(node_id, node)
          when ExpressionNode::Kind::Class
            handle_class(node_id, node)
          end
        end

        private def handle_macro_def(node_id : Frontend::ExprId, node : ExpressionNode)
          name_slice = node.macro_name
          return unless name_slice

          name = String.new(name_slice)
          body_id = node.left
          return unless body_id

          unless body_id && @arena[body_id].kind == ExpressionNode::Kind::MacroLiteral
            return
          end

          symbol = MacroSymbol.new(name, node_id, body_id)

          table = current_table
          if existing = table.lookup_local(name)
            handle_macro_redefinition(name, symbol, existing, table)
          else
            table.define(name, symbol)
          end
        end

        private def handle_def(node_id : Frontend::ExprId, node : ExpressionNode)
          name_slice = node.def_name
          return unless name_slice

          name = String.new(name_slice)
          params = node.def_params || [] of Frontend::Parameter
          return_annotation = node.def_return_type.try { |slice| String.new(slice) }

          method_scope = SymbolTable.new(current_table)
          method_symbol = MethodSymbol.new(name, node_id, params: params, return_annotation: return_annotation, scope: method_scope)

          table = current_table
          if existing = table.lookup_local(name)
            handle_method_redefinition(name, method_symbol, existing, table)
          else
            table.define(name, method_symbol)
          end

          push_table(method_scope)

          params.each do |param|
            param_symbol = VariableSymbol.new(param.name, node_id, declared_type: param.type_annotation)

            if existing_param = method_scope.lookup_local(param.name)
              emit_duplicate_variable(param.name, param_symbol, existing_param)
            else
              if shadowed = lookup_variable_in_ancestors(method_scope.parent, param.name)
                emit_shadowing_warning(param.name, param_symbol, shadowed)
              end
              method_scope.define(param.name, param_symbol)
            end
          end

          (node.def_body || [] of Frontend::ExprId).each do |expr_id|
            visit(expr_id)
          end

          pop_table
        end

        private def handle_class(node_id : Frontend::ExprId, node : ExpressionNode)
          name_slice = node.class_name
          return unless name_slice

          name = String.new(name_slice)
          super_name = node.class_super_name.try { |slice| String.new(slice) }

          table = current_table
          existing = table.lookup_local(name)
          class_scope = existing.is_a?(ClassSymbol) ? existing.scope : SymbolTable.new(table)

          class_symbol = ClassSymbol.new(name, node_id, scope: class_scope, superclass_name: super_name)

          if existing
            handle_class_redefinition(name, class_symbol, existing, table)
          else
            table.define(name, class_symbol)
          end

          push_table(class_scope)

          # Phase 5A: Collect instance variable declarations
          collect_instance_vars(class_symbol, node.class_body || [] of Frontend::ExprId)

          (node.class_body || [] of Frontend::ExprId).each do |expr_id|
            visit(expr_id)
          end
          pop_table
        end

        # Phase 5A: Scan class body for instance variable assignments
        private def collect_instance_vars(class_symbol : ClassSymbol, body : Array(Frontend::ExprId))
          body.each do |expr_id|
            scan_for_instance_vars(class_symbol, expr_id)
          end
        end

        private def scan_for_instance_vars(class_symbol : ClassSymbol, expr_id : Frontend::ExprId)
          return if expr_id.invalid?
          node = @arena[expr_id]

          case node.kind
          when ExpressionNode::Kind::Assign
            # Check if assignment target is instance variable
            target_id = node.assign_target
            if target_id && !target_id.invalid?
              target_node = @arena[target_id]
              if target_node.kind == ExpressionNode::Kind::InstanceVar
                if name_slice = target_node.literal
                  var_name = String.new(name_slice)
                  # Remove @ prefix
                  var_name = var_name[1..-1] if var_name.starts_with?("@")
                  class_symbol.add_instance_var(var_name)
                end
              end
            end
          when ExpressionNode::Kind::Def
            # Scan method body for instance variable assignments
            def_body = node.def_body || [] of Frontend::ExprId
            def_body.each do |body_expr_id|
              scan_for_instance_vars(class_symbol, body_expr_id)
            end
          when ExpressionNode::Kind::If
            # Scan if branches
            if_then = node.if_then || [] of Frontend::ExprId
            if_then.each { |e| scan_for_instance_vars(class_symbol, e) }

            if_elsifs = node.if_elsifs || [] of Frontend::ElsifBranch
            if_elsifs.each do |elsif_branch|
              elsif_branch.body.each { |e| scan_for_instance_vars(class_symbol, e) }
            end

            if_else = node.if_else || [] of Frontend::ExprId
            if_else.each { |e| scan_for_instance_vars(class_symbol, e) }
          when ExpressionNode::Kind::While
            # Scan while body
            while_body = node.while_body || [] of Frontend::ExprId
            while_body.each { |e| scan_for_instance_vars(class_symbol, e) }
          end
        end

        private def handle_macro_redefinition(name : String, new_symbol : MacroSymbol, existing : Symbol, table : SymbolTable)
          case existing
          when MacroSymbol
            table.redefine(name, new_symbol)
          else
            emit_incompatible_redefinition(name, new_symbol, existing)
          end
        end

        private def handle_method_redefinition(name : String, new_symbol : MethodSymbol, existing : Symbol, table : SymbolTable)
          case existing
          when MethodSymbol
            # Phase 4B: Create OverloadSet for multiple methods with same name
            overload_set = OverloadSetSymbol.new(name, existing.node_id, [existing, new_symbol])
            table.redefine(name, overload_set)
          when OverloadSetSymbol
            # Phase 4B: Add to existing overload set
            existing.add_overload(new_symbol)
          when ClassSymbol, MacroSymbol, VariableSymbol
            emit_incompatible_redefinition(name, new_symbol, existing)
          else
            emit_incompatible_redefinition(name, new_symbol, existing)
          end
        end

        private def handle_class_redefinition(name : String, new_symbol : ClassSymbol, existing : Symbol, table : SymbolTable)
          case existing
          when ClassSymbol
            verify_superclass_consistency(name, new_symbol, existing)
            new_symbol = ClassSymbol.new(name, new_symbol.node_id, scope: existing.scope, superclass_name: new_symbol.superclass_name || existing.superclass_name)
            table.redefine(name, new_symbol)
          when MethodSymbol, MacroSymbol, VariableSymbol
            emit_incompatible_redefinition(name, new_symbol, existing)
          else
            emit_incompatible_redefinition(name, new_symbol, existing)
          end
        end

        private def verify_superclass_consistency(name : String, new_symbol : ClassSymbol, existing : ClassSymbol)
          previous_super = existing.superclass_name
          current_super = new_symbol.superclass_name

          if previous_super && current_super && previous_super != current_super
            @diagnostics << Diagnostic.new(
              DiagnosticLevel::Error,
              "E2003",
              "class '#{name}' already defined with superclass '#{previous_super}'",
              span_for(new_symbol.node_id),
              [SecondarySpan.new(span_for(existing.node_id), "previous superclass declared here")]
            )
          end
        end

        private def emit_incompatible_redefinition(name : String, new_symbol : Symbol, existing : Symbol)
          @diagnostics << Diagnostic.new(
            DiagnosticLevel::Error,
            "E2001",
            "cannot redefine #{symbol_kind(existing)} '#{name}' as #{symbol_kind(new_symbol)}",
            span_for(new_symbol.node_id),
            [SecondarySpan.new(span_for(existing.node_id), "previous #{symbol_kind(existing)} defined here")]
          )
        end

        private def emit_duplicate_variable(name : String, new_symbol : VariableSymbol, existing : Symbol)
          @diagnostics << Diagnostic.new(
            DiagnosticLevel::Error,
            "E2002",
            "variable '#{name}' is already defined in this scope",
            span_for(new_symbol.node_id),
            [SecondarySpan.new(span_for(existing.node_id), "previous definition here")]
          )
        end

        private def emit_shadowing_warning(name : String, new_symbol : VariableSymbol, outer_symbol : VariableSymbol)
          @diagnostics << Diagnostic.new(
            DiagnosticLevel::Warning,
            "W2001",
            "variable '#{name}' shadows outer scope variable",
            span_for(new_symbol.node_id),
            [SecondarySpan.new(span_for(outer_symbol.node_id), "outer scope definition here")]
          )
        end

        private def lookup_variable_in_ancestors(table : SymbolTable?, name : String) : VariableSymbol?
          current = table
          while current
            if symbol = current.lookup_local(name)
              return symbol if symbol.is_a?(VariableSymbol)
            end
            current = current.parent
          end
          nil
        end

        private def span_for(node_id : Frontend::ExprId) : Frontend::Span
          @arena[node_id].span
        end

        private def symbol_kind(symbol : Symbol) : String
          case symbol
          when MacroSymbol
            "macro"
          when MethodSymbol
            "method"
          when ClassSymbol
            "class"
          when VariableSymbol
            "variable"
          else
            "symbol"
          end
        end
      end
    end
  end
end
