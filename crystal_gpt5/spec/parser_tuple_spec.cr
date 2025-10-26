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
      tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = tuple.tuple_elements.not_nil!
      elements.size.should eq(3)
    end

    it "parses single element tuple" do
      source = "{42}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = tuple.tuple_elements.not_nil!
      elements.size.should eq(1)
    end

    it "parses single element tuple with trailing comma" do
      source = "{42,}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = tuple.tuple_elements.not_nil!
      elements.size.should eq(1)
    end

    it "parses tuple with trailing comma" do
      source = "{1, 2, 3,}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = tuple.tuple_elements.not_nil!
      elements.size.should eq(3)
    end

    it "parses nested tuples" do
      source = "{{1, 2}, {3, 4}}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      outer_tuple = arena[program.roots[0]]
      outer_tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      outer_elements = outer_tuple.tuple_elements.not_nil!
      outer_elements.size.should eq(2)

      # Check first inner tuple
      inner1 = arena[outer_elements[0]]
      inner1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      # Check second inner tuple
      inner2 = arena[outer_elements[1]]
      inner2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "parses tuple with expressions" do
      source = "{1 + 1, 2 * 2, 3 - 1}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = tuple.tuple_elements.not_nil!
      elements.size.should eq(3)

      # First element is binary expression
      elem1 = arena[elements[0]]
      elem1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end

    it "parses tuple in assignment" do
      source = "x = {1, 2, 3}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "parses tuple in method call" do
      source = "foo({1, 2})"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "parses tuple in array literal" do
      source = "[{1, 2}, {3, 4}]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      array.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      array_elements = array.array_elements.not_nil!
      array_elements.size.should eq(2)

      # Both elements are tuples
      elem1 = arena[array_elements[0]]
      elem1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elem2 = arena[array_elements[1]]
      elem2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "disambiguates tuple from hash (tuple has comma)" do
      source = "{1, 2}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "disambiguates hash from tuple (hash has arrow)" do
      source = "{1 => 2}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::HashLiteral)
    end

    it "parses empty braces as hash not tuple" do
      source = "{}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      # Empty {} is hash by default
      node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::HashLiteral)
    end

    it "parses tuple with identifier elements" do
      source = "{x, y, z}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      tuple = arena[program.roots[0]]
      tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)

      elements = tuple.tuple_elements.not_nil!
      elements.size.should eq(3)

      # All elements are identifiers
      elem1 = arena[elements[0]]
      elem1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
    end
  end
end
