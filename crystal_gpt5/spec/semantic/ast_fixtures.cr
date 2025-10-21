require "../../src/compiler/frontend/ast"

module AstFixtures
  extend self

  alias Frontend = CrystalGPT5::Compiler::Frontend
  alias ExprId = Frontend::ExprId
  alias ExpressionNode = Frontend::ExpressionNode
  alias AstArena = Frontend::AstArena
  alias Span = Frontend::Span

  private def span
    Span.new(0, 0, 1, 1, 1, 1)
  end

  # Helper: Create a def node
  # Example: make_def(arena, "greet", params: ["name"], body: [body_id])
  def make_def(arena : AstArena, name : String, params : Array(String) = [] of String, body : Array(ExprId) = [] of ExprId) : ExprId
    arena.add(ExpressionNode.new(
      ExpressionNode::Kind::Def,
      span,
      def_name: name.to_slice,
      def_params: params,
      def_body: body
    ))
  end

  # Helper: Create a class node
  # Example: make_class(arena, "Person", body: [method_id1, method_id2])
  def make_class(arena : AstArena, name : String, body : Array(ExprId) = [] of ExprId, superclass : String? = nil) : ExprId
    arena.add(ExpressionNode.new(
      ExpressionNode::Kind::Class,
      span,
      class_name: name.to_slice,
      class_body: body,
      class_super_name: superclass.try &.to_slice
    ))
  end

  # Helper: Create an identifier node
  # Example: make_identifier(arena, "x")
  def make_identifier(arena : AstArena, name : String) : ExprId
    arena.add(ExpressionNode.new(
      ExpressionNode::Kind::Identifier,
      span,
      literal: name.to_slice
    ))
  end

  # Helper: Create a call node
  # Example: make_call(arena, "greet", args: [arg1_id, arg2_id])
  def make_call(arena : AstArena, callee_name : String, args : Array(ExprId) = [] of ExprId) : ExprId
    callee_id = make_identifier(arena, callee_name)
    arena.add(ExpressionNode.new(
      ExpressionNode::Kind::Call,
      span,
      callee: callee_id,
      args: args
    ))
  end

  # Helper: Create a number literal node
  # Example: make_number(arena, 42)
  def make_number(arena : AstArena, value : Int64) : ExprId
    arena.add(ExpressionNode.new(
      ExpressionNode::Kind::Number,
      span,
      number_value: value
    ))
  end

  # Helper: Create a string literal node
  # Example: make_string(arena, "hello")
  def make_string(arena : AstArena, value : String) : ExprId
    arena.add(ExpressionNode.new(
      ExpressionNode::Kind::String,
      span,
      literal: value.to_slice
    ))
  end

  # Helper: Create a macro definition
  # Example: make_macro(arena, "greet", body: body_id)
  def make_macro(arena : AstArena, name : String, body : ExprId? = nil) : ExprId
    body_id = body || arena.add(ExpressionNode.new(
      ExpressionNode::Kind::MacroLiteral,
      span,
      macro_pieces: [] of Frontend::MacroPiece,
      trim_left: false,
      trim_right: false
    ))

    arena.add(ExpressionNode.new(
      ExpressionNode::Kind::MacroDef,
      span,
      left: body_id,
      macro_name: name.to_slice
    ))
  end
end
