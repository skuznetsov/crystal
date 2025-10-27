require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 85: Uninitialized keyword (uninitialized variables)" do
    it "parses uninitialized with simple type" do
      source = "x = uninitialized(Int32)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value should be uninitialized
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)

      # Type should be Int32 (identifier)
      type_expr = arena[value.uninitialized_type.not_nil!]
      type_expr.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(type_expr.literal.not_nil!).should eq("Int32")
    end

    it "parses uninitialized with pointer type" do
      source = "ptr = uninitialized(Pointer(UInt8))"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)

      # Type should be Pointer(UInt8) - generic instantiation
      type_expr = arena[value.uninitialized_type.not_nil!]
      type_expr.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)
    end

    it "parses uninitialized with custom type" do
      source = "obj = uninitialized(MyClass)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)

      type_expr = arena[value.uninitialized_type.not_nil!]
      type_expr.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(type_expr.literal.not_nil!).should eq("MyClass")
    end

    it "parses uninitialized with array type" do
      source = "arr = uninitialized(Array(Int32))"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)

      # Type is Array(Int32) - generic instantiation
      type_expr = arena[value.uninitialized_type.not_nil!]
      type_expr.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)
    end

    it "parses uninitialized inside method" do
      source = <<-CRYSTAL
      def allocate_buffer
        buffer = uninitialized(UInt8)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_def = arena[program.roots[0]]
      method_def.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      # Method body should contain assignment
      body_exprs = method_def.def_body.not_nil!
      body_exprs.size.should eq(1)

      assign = arena[body_exprs[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)
    end

    it "parses multiple uninitialized statements" do
      source = <<-CRYSTAL
      x = uninitialized(Int32)
      y = uninitialized(Int64)
      z = uninitialized(String)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # All three should be assignments with uninitialized values
      assign1 = arena[program.roots[0]]
      value1 = arena[assign1.assign_value.not_nil!]
      value1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)

      assign2 = arena[program.roots[1]]
      value2 = arena[assign2.assign_value.not_nil!]
      value2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)

      assign3 = arena[program.roots[2]]
      value3 = arena[assign3.assign_value.not_nil!]
      value3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)
    end

    it "parses uninitialized with union type" do
      source = "val = uninitialized(Int32 | String)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)

      # Type is Int32 | String - binary expression with |
      type_expr = arena[value.uninitialized_type.not_nil!]
      type_expr.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end

    it "parses uninitialized as method argument" do
      source = "process(uninitialized(Buffer))"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Argument should be uninitialized
      args = call.args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)
    end

    it "parses uninitialized in array literal" do
      source = "[uninitialized(Int32), uninitialized(Int32)]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      array.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      # Both elements should be uninitialized
      elements = array.array_elements.not_nil!
      elements.size.should eq(2)

      elem1 = arena[elements[0]]
      elem1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)

      elem2 = arena[elements[1]]
      elem2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Uninitialized)
    end
  end
end
