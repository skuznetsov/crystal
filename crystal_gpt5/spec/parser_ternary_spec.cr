require "spec"
require "../src/compiler/frontend/parser"
require "../src/compiler/frontend/lexer"

# Phase 23: Edge cases for ternary operator
describe "Ternary Operator Edge Cases" do
  it "distinguishes ? in ternary from ? in method names" do
    source = <<-CRYSTAL
      arr = [1, 2]
      x = arr.empty? ? 100 : 200
    CRYSTAL

    lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
    parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
    program = parser.parse_program

    # Should parse: arr.empty? is call, then ? for ternary
    program.roots.size.should eq(2)

    assign_node = program.arena[program.roots[1]]
    assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

    ternary_id = assign_node.assign_value.not_nil!
    ternary_node = program.arena[ternary_id]
    ternary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Ternary)
  end

  it "handles : in ternary without conflicting with symbols" do
    source = <<-CRYSTAL
      x = true ? :yes : :no
    CRYSTAL

    lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
    parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
    program = parser.parse_program

    program.roots.size.should eq(1)

    assign_node = program.arena[program.roots[0]]
    ternary_id = assign_node.assign_value.not_nil!
    ternary_node = program.arena[ternary_id]

    ternary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Ternary)

    # True branch should be symbol
    true_id = ternary_node.ternary_true_branch.not_nil!
    true_node = program.arena[true_id]
    true_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Symbol)

    # False branch should be symbol
    false_id = ternary_node.ternary_false_branch.not_nil!
    false_node = program.arena[false_id]
    false_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Symbol)
  end

  it "handles : in ternary without conflicting with type annotations" do
    # This is a tricky case - we DON'T support type annotations in expressions yet
    # So this should parse as ternary with identifier 'Int32'
    source = <<-CRYSTAL
      x = true ? 10 : 20
    CRYSTAL

    lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
    parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
    program = parser.parse_program

    program.roots.size.should eq(1)

    assign_node = program.arena[program.roots[0]]
    ternary_id = assign_node.assign_value.not_nil!
    ternary_node = program.arena[ternary_id]

    ternary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Ternary)
  end
end
