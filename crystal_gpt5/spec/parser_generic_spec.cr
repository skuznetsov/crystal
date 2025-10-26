require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 60: Generic type instantiation (PRODUCTION-READY)" do
    it "parses simple generic Box(Int32)" do
      source = "x = Box(Int32)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value is Generic node
      generic = arena[assign.assign_value.not_nil!]
      generic.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)

      # Check base type name
      name = arena[generic.generic_name.not_nil!]
      name.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(name.literal.not_nil!).should eq("Box")

      # Check type arguments
      type_args = generic.generic_type_args.not_nil!
      type_args.size.should eq(1)

      type_arg = arena[type_args[0]]
      type_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(type_arg.literal.not_nil!).should eq("Int32")
    end

    it "parses generic with multiple type arguments Hash(String, Int32)" do
      source = "x = Hash(String, Int32)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      generic = arena[assign.assign_value.not_nil!]
      generic.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)

      # Check base type name
      name = arena[generic.generic_name.not_nil!]
      String.new(name.literal.not_nil!).should eq("Hash")

      # Check type arguments
      type_args = generic.generic_type_args.not_nil!
      type_args.size.should eq(2)

      type_arg1 = arena[type_args[0]]
      String.new(type_arg1.literal.not_nil!).should eq("String")

      type_arg2 = arena[type_args[1]]
      String.new(type_arg2.literal.not_nil!).should eq("Int32")
    end

    it "parses Array(String)" do
      source = "arr = Array(String)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      generic = arena[assign.assign_value.not_nil!]

      name = arena[generic.generic_name.not_nil!]
      String.new(name.literal.not_nil!).should eq("Array")

      type_args = generic.generic_type_args.not_nil!
      type_args.size.should eq(1)
      type_arg = arena[type_args[0]]
      String.new(type_arg.literal.not_nil!).should eq("String")
    end

    it "parses generic in method call" do
      source = "create(Box(Int32))"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      # Argument is generic
      generic = arena[args[0]]
      generic.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)

      name = arena[generic.generic_name.not_nil!]
      String.new(name.literal.not_nil!).should eq("Box")
    end

    it "parses generic in array literal" do
      source = "[Array(Int32), Array(String)]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      array.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      elements = array.array_elements.not_nil!
      elements.size.should eq(2)

      # First element: Array(Int32)
      generic1 = arena[elements[0]]
      generic1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)

      # Second element: Array(String)
      generic2 = arena[elements[1]]
      generic2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)
    end

    it "parses triple type arguments" do
      source = "x = Triple(Int32, String, Bool)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      generic = arena[assign.assign_value.not_nil!]

      type_args = generic.generic_type_args.not_nil!
      type_args.size.should eq(3)

      String.new(arena[type_args[0]].literal.not_nil!).should eq("Int32")
      String.new(arena[type_args[1]].literal.not_nil!).should eq("String")
      String.new(arena[type_args[2]].literal.not_nil!).should eq("Bool")
    end

    it "does not parse lowercase identifier with parens as generic" do
      source = "x = foo(42)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Should be a Call, not Generic
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
      value.kind.should_not eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)
    end

    it "parses generic with single type argument" do
      source = "x = Pointer(UInt8)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      generic = arena[assign.assign_value.not_nil!]
      generic.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)

      name = arena[generic.generic_name.not_nil!]
      String.new(name.literal.not_nil!).should eq("Pointer")

      type_args = generic.generic_type_args.not_nil!
      type_args.size.should eq(1)
      type_arg = arena[type_args[0]]
      String.new(type_arg.literal.not_nil!).should eq("UInt8")
    end

    it "parses multiple generics in statement" do
      source = <<-CRYSTAL
      a = Box(Int32)
      b = Array(String)
      c = Hash(Symbol, Float64)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # Check all three are Generic
      (0..2).each do |i|
        assign = arena[program.roots[i]]
        generic = arena[assign.assign_value.not_nil!]
        generic.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)
      end
    end
  end
end
