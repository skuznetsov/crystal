require "spec"
require "./ast_fixtures"

require "../../src/compiler/frontend/ast"
require "../../src/compiler/semantic/analyzer"

alias Frontend = CrystalGPT5::Compiler::Frontend
alias Semantic = CrystalGPT5::Compiler::Semantic

private def test_span
  Frontend::Span.new(0, 0, 1, 1, 1, 1)
end

describe Semantic::NameResolver do
  it "resolves identifiers to macro symbols" do
    arena = Frontend::AstArena.new

    macro_body = Frontend::ExpressionNode.new(
      Frontend::ExpressionNode::Kind::MacroLiteral,
      test_span,
      macro_pieces: [] of Frontend::MacroPiece,
      trim_left: false,
      trim_right: false
    )
    body_id = arena.add(macro_body)

    macro_def = Frontend::ExpressionNode.new(
      Frontend::ExpressionNode::Kind::MacroDef,
      test_span,
      left: body_id,
      macro_name: "greet".to_slice
    )
    macro_id = arena.add(macro_def)

    identifier = Frontend::ExpressionNode.new(
      Frontend::ExpressionNode::Kind::Identifier,
      test_span,
      literal: "greet".to_slice
    )
    callee_id = arena.add(identifier)

    call = Frontend::ExpressionNode.new(
      Frontend::ExpressionNode::Kind::Call,
      test_span,
      callee: callee_id,
      args: [] of Frontend::ExprId
    )
    call_id = arena.add(call)

    program = Frontend::Program.new(arena, [macro_id, call_id])
    analyzer = Semantic::Analyzer.new(program)
    analyzer.collect_symbols
    result = analyzer.resolve_names

    result.diagnostics.should be_empty
    result.identifier_symbols[callee_id].should be_a(Semantic::MacroSymbol)
  end

  it "emits diagnostics for undefined identifiers" do
    arena = Frontend::AstArena.new

    identifier = Frontend::ExpressionNode.new(
      Frontend::ExpressionNode::Kind::Identifier,
      test_span,
      literal: "missing".to_slice
    )
    callee_id = arena.add(identifier)

    call = Frontend::ExpressionNode.new(
      Frontend::ExpressionNode::Kind::Call,
      test_span,
      callee: callee_id,
      args: [] of Frontend::ExprId
    )
    call_id = arena.add(call)

    program = Frontend::Program.new(arena, [call_id])
    analyzer = Semantic::Analyzer.new(program)
    analyzer.collect_symbols
    result = analyzer.resolve_names

    result.identifier_symbols.should be_empty
    result.diagnostics.size.should eq(1)
    result.diagnostics.first.message.should eq("undefined local variable or method 'missing'")
  end

  it "resolves method parameters within method scope" do
    arena = Frontend::AstArena.new

    param_ref = AstFixtures.make_identifier(arena, "name")
    method_id = AstFixtures.make_def(arena, "greet", params: ["name"], body: [param_ref])

    program = Frontend::Program.new(arena, [method_id])
    analyzer = Semantic::Analyzer.new(program)
    analyzer.collect_symbols
    result = analyzer.resolve_names

    result.diagnostics.should be_empty
    result.identifier_symbols[param_ref].should be_a(Semantic::VariableSymbol)
  end

  it "resolves method calls within class scope" do
    arena = Frontend::AstArena.new

    greet_method = AstFixtures.make_def(arena, "greet")
    call_id = AstFixtures.make_call(arena, "greet")
    call_node = arena[call_id]
    callee_id = call_node.callee.not_nil!
    say_hello = AstFixtures.make_def(arena, "say_hello", body: [call_id])
    class_id = AstFixtures.make_class(arena, "Greeter", body: [greet_method, say_hello])

    program = Frontend::Program.new(arena, [class_id])
    analyzer = Semantic::Analyzer.new(program)
    analyzer.collect_symbols
    result = analyzer.resolve_names

    result.diagnostics.should be_empty
    result.identifier_symbols[callee_id].should be_a(Semantic::MethodSymbol)
  end
end
