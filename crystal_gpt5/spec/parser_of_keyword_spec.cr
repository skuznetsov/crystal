require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 91: 'of' keyword (explicit generic type specification)" do
    it "parses empty array with simple type" do
      source = <<-CRYSTAL
      [] of Int32
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array_node = arena[program.roots[0]]
      array_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      # Empty array
      elements = array_node.array_elements
      elements.should_not be_nil
      elements.not_nil!.should be_empty

      # Has type specification
      of_type = array_node.array_of_type
      of_type.should_not be_nil

      type_node = arena[of_type.not_nil!]
      type_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(type_node.literal.not_nil!).should eq("Int32")
    end

    it "parses array with elements and simple type" do
      source = <<-CRYSTAL
      [1, 2, 3] of Int32
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array_node = arena[program.roots[0]]
      array_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      # Has 3 elements
      elements = array_node.array_elements.not_nil!
      elements.size.should eq(3)

      # Has type specification
      of_type = array_node.array_of_type
      of_type.should_not be_nil

      type_node = arena[of_type.not_nil!]
      type_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(type_node.literal.not_nil!).should eq("Int32")
    end

    it "parses array with union type" do
      source = <<-CRYSTAL
      [1, 2, 3] of Int32 | String
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array_node = arena[program.roots[0]]
      array_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      # Has 3 elements
      elements = array_node.array_elements.not_nil!
      elements.size.should eq(3)

      # Has union type specification
      of_type = array_node.array_of_type
      of_type.should_not be_nil

      type_node = arena[of_type.not_nil!]
      type_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(type_node.operator.not_nil!).should eq("|")
    end

    it "parses empty array with String type" do
      source = <<-CRYSTAL
      [] of String
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array_node = arena[program.roots[0]]
      array_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      # Empty array
      array_node.array_elements.not_nil!.should be_empty

      # Type is String
      of_type = array_node.array_of_type.not_nil!
      type_node = arena[of_type]
      type_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(type_node.literal.not_nil!).should eq("String")
    end

    it "parses string array with type annotation" do
      source = <<-CRYSTAL
      ["a", "b", "c"] of String
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array_node = arena[program.roots[0]]

      # Has 3 string elements
      elements = array_node.array_elements.not_nil!
      elements.size.should eq(3)

      # Type is String
      of_type = array_node.array_of_type.not_nil!
      type_node = arena[of_type]
      String.new(type_node.literal.not_nil!).should eq("String")
    end

    it "parses empty array with union type" do
      source = <<-CRYSTAL
      [] of String | Nil
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array_node = arena[program.roots[0]]

      # Empty array
      array_node.array_elements.not_nil!.should be_empty

      # Union type
      of_type = array_node.array_of_type.not_nil!
      type_node = arena[of_type]
      type_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(type_node.operator.not_nil!).should eq("|")
    end

    it "parses array with generic type (Array)" do
      source = <<-CRYSTAL
      [[1], [2]] of Array(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array_node = arena[program.roots[0]]

      # Has 2 array elements
      elements = array_node.array_elements.not_nil!
      elements.size.should eq(2)

      # Type is Generic (Array(Int32))
      of_type = array_node.array_of_type.not_nil!
      type_node = arena[of_type]
      type_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)
    end

    it "parses array without 'of' clause" do
      source = <<-CRYSTAL
      [1, 2, 3]
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array_node = arena[program.roots[0]]

      # Has 3 elements
      elements = array_node.array_elements.not_nil!
      elements.size.should eq(3)

      # No type specification
      array_node.array_of_type.should be_nil
    end

    it "parses 'of' in variable assignment" do
      source = <<-CRYSTAL
      x = [1, 2] of Int32
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Right side is array with 'of'
      array_node = arena[assign_node.assign_value.not_nil!]
      array_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      array_node.array_of_type.should_not be_nil
    end

    it "parses 'of' in method call argument" do
      source = <<-CRYSTAL
      foo([1, 2] of Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Argument is array with 'of'
      args = call_node.args.not_nil!
      args.size.should eq(1)

      array_node = arena[args[0]]
      array_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)
      array_node.array_of_type.should_not be_nil
    end
  end
end
