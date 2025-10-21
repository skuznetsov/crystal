require "../../frontend/ast"
require "../../frontend/parser/diagnostic"
require "../symbol_table"
require "../symbol"

module CrystalGPT5
  module Compiler
    module Semantic
      class NameResolver
        alias Program = Frontend::Program
        alias ExprId = Frontend::ExprId
        alias ExpressionNode = Frontend::ExpressionNode
        alias Diagnostic = Frontend::Diagnostic

        @root_table : SymbolTable
        @current_table : SymbolTable

        struct Result
          getter identifier_symbols : Hash(ExprId, Symbol)
          getter diagnostics : Array(Diagnostic)

          def initialize(@identifier_symbols : Hash(ExprId, Symbol), @diagnostics : Array(Diagnostic))
          end
        end

        def initialize(@program : Program, root_table : SymbolTable)
          @arena = @program.arena
          @root_table = root_table
          @identifier_symbols = {} of ExprId => Symbol
          @diagnostics = [] of Diagnostic
          @current_table = @root_table
        end

        def resolve : Result
          @current_table = @root_table
          @program.roots.each do |root_id|
            visit(root_id)
          end
          Result.new(@identifier_symbols, @diagnostics)
        end

        private def visit(node_id : ExprId)
          return if node_id.invalid?
          node = @arena[node_id]

          case node.kind
          when ExpressionNode::Kind::Identifier
            resolve_identifier(node_id, node)
          when ExpressionNode::Kind::Call
            visit(node.callee.not_nil!) if node.callee
            node.args.try &.each { |arg| visit(arg) }
          when ExpressionNode::Kind::Unary
            visit(node.right.not_nil!) if node.right
          when ExpressionNode::Kind::Binary
            visit(node.left.not_nil!) if node.left
            visit(node.right.not_nil!) if node.right
          when ExpressionNode::Kind::Grouping
            visit(node.left.not_nil!) if node.left
          when ExpressionNode::Kind::MacroExpression
            visit(node.macro_expr.not_nil!) if node.macro_expr
          when ExpressionNode::Kind::MacroLiteral
            visit_macro_literal(node)
          when ExpressionNode::Kind::MacroDef
            # Body handled via MacroLiteral; skip definition node
          when ExpressionNode::Kind::Def
            visit_def(node)
          when ExpressionNode::Kind::Class
            visit_class(node)
          else
            # Other kinds currently unsupported; ignore
          end
        end

        private def resolve_identifier(node_id : ExprId, node : ExpressionNode)
          slice = node.literal
          return unless slice
          name = String.new(slice)

          if symbol = @current_table.lookup(name)
            @identifier_symbols[node_id] = symbol
          else
            @diagnostics << Diagnostic.new("undefined local variable or method '#{name}'", node.span)
          end
        end

        private def visit_macro_literal(node : ExpressionNode)
          pieces = node.macro_pieces
          return unless pieces

          pieces.each do |piece|
            case piece.kind
            when Frontend::MacroPiece::Kind::Expression
              visit(piece.expr.not_nil!) if piece.expr
            when Frontend::MacroPiece::Kind::ControlStart,
                 Frontend::MacroPiece::Kind::ControlElseIf,
                 Frontend::MacroPiece::Kind::ControlElse,
                 Frontend::MacroPiece::Kind::ControlEnd
              # TODO: Handle control flow bodies once semantic stages support them
            when Frontend::MacroPiece::Kind::Text
              # No identifiers to resolve
            end
          end
        end

        private def visit_def(node : ExpressionNode)
          name_slice = node.def_name
          return unless name_slice

          name = String.new(name_slice)
          symbol = @current_table.lookup(name)
          unless symbol.is_a?(MethodSymbol)
            return
          end

          method_scope = symbol.scope
          prev_table = @current_table
          @current_table = method_scope

          (node.def_body || [] of ExprId).each do |expr_id|
            visit(expr_id)
          end

          @current_table = prev_table
        end

        private def visit_class(node : ExpressionNode)
          name_slice = node.class_name
          return unless name_slice

          name = String.new(name_slice)
          symbol = @current_table.lookup(name)
          unless symbol.is_a?(ClassSymbol)
            return
          end

          class_scope = symbol.scope
          prev_table = @current_table
          @current_table = class_scope

          (node.class_body || [] of ExprId).each do |expr_id|
            visit(expr_id)
          end

          @current_table = prev_table
        end
      end
    end
  end
end
