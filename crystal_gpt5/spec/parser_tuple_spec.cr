require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 69: Tuple literals {1, 2, 3} (DISCOVERED - Testing)" do
    it "parses simple tuple with multiple elements" do
      source = "{1, 2, 3}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(tuple).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = CrystalGPT5::Compiler::Frontend.node_tuple_elements(tuple).not_nil!
      elements.size.should eq(3)
    end

    it "parses single element tuple" do
      source = "{42}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(tuple).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = CrystalGPT5::Compiler::Frontend.node_tuple_elements(tuple).not_nil!
      elements.size.should eq(1)
    end

    it "parses single element tuple with trailing comma" do
      source = "{42,}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(tuple).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = CrystalGPT5::Compiler::Frontend.node_tuple_elements(tuple).not_nil!
      elements.size.should eq(1)
    end

    it "parses tuple with trailing comma" do
      source = "{1, 2, 3,}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(tuple).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = CrystalGPT5::Compiler::Frontend.node_tuple_elements(tuple).not_nil!
      elements.size.should eq(3)
    end

    it "parses nested tuples" do
      source = "{{1, 2}, {3, 4}}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      outer_tuple = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(outer_tuple).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      outer_elements = CrystalGPT5::Compiler::Frontend.node_tuple_elements(outer_tuple).not_nil!
      outer_elements.size.should eq(2)

      # Check first inner tuple
      inner1 = arena[outer_elements[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(inner1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      # Check second inner tuple
      inner2 = arena[outer_elements[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(inner2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "parses tuple with expressions" do
      source = "{1 + 1, 2 * 2, 3 - 1}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(tuple).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = CrystalGPT5::Compiler::Frontend.node_tuple_elements(tuple).not_nil!
      elements.size.should eq(3)

      # First element is binary expression
      elem1 = arena[elements[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(elem1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end

    it "parses tuple in assignment" do
      source = "x = {1, 2, 3}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "parses tuple in method call" do
      source = "foo({1, 2})"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(arg).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "parses tuple in array literal" do
      source = "[{1, 2}, {3, 4}]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(array).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      array_elements = CrystalGPT5::Compiler::Frontend.node_array_elements(array).not_nil!
      array_elements.size.should eq(2)

      # Both elements are tuples
      elem1 = arena[array_elements[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(elem1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elem2 = arena[array_elements[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(elem2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "disambiguates tuple from hash (tuple has comma)" do
      source = "{1, 2}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "disambiguates hash from tuple (hash has arrow)" do
      source = "{1 => 2}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::HashLiteral)
    end

    it "parses empty braces as hash not tuple" do
      source = "{}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      # Empty {} is hash by default
      CrystalGPT5::Compiler::Frontend.node_kind(node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::HashLiteral)
    end

    it "parses tuple with identifier elements" do
      source = "{x, y, z}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(tuple).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = CrystalGPT5::Compiler::Frontend.node_tuple_elements(tuple).not_nil!
      elements.size.should eq(3)

      # All elements are identifiers
      elem1 = arena[elements[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(elem1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
    end
  end
end
