require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 86: Offsetof keyword (field offset in type)" do
    it "parses offsetof with type and symbol field" do
      source = "x = offsetof(Person, :name)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value should be offsetof
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Offsetof)

      # Should have exactly 2 arguments
      args = value.offsetof_args.not_nil!
      args.size.should eq(2)

      # First argument should be Person (identifier)
      type_arg = arena[args[0]]
      type_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(type_arg.literal.not_nil!).should eq("Person")

      # Second argument should be :name (symbol)
      field_arg = arena[args[1]]
      field_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Symbol)
    end

    it "parses offsetof with different field name" do
      source = "offset = offsetof(MyStruct, :field)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Offsetof)

      args = value.offsetof_args.not_nil!
      args.size.should eq(2)

      # Type argument
      type_arg = arena[args[0]]
      type_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(type_arg.literal.not_nil!).should eq("MyStruct")

      # Field argument (symbol)
      field_arg = arena[args[1]]
      field_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Symbol)
    end

    it "parses offsetof with generic type" do
      source = "x = offsetof(Array(Int32), :size)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Offsetof)

      args = value.offsetof_args.not_nil!
      args.size.should eq(2)

      # Type argument should be generic
      type_arg = arena[args[0]]
      type_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Generic)

      # Field argument should be symbol
      field_arg = arena[args[1]]
      field_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Symbol)
    end

    it "parses offsetof as function argument" do
      source = "puts(offsetof(Point, :x))"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Root should be a call
      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Argument should be offsetof
      arg = arena[call.args.not_nil![0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Offsetof)

      args = arg.offsetof_args.not_nil!
      args.size.should eq(2)
    end

    it "parses offsetof in return statement" do
      source = "return offsetof(User, :age)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      ret = arena[program.roots[0]]
      ret.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Return)

      # Return value should be offsetof
      value = arena[ret.return_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Offsetof)

      args = value.offsetof_args.not_nil!
      args.size.should eq(2)
    end

    it "parses offsetof with namespaced type" do
      source = "x = offsetof(Foo::Bar, :field)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Offsetof)

      args = value.offsetof_args.not_nil!
      args.size.should eq(2)

      # Type argument should be path expression (Foo::Bar)
      type_arg = arena[args[0]]
      type_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
    end

    it "parses offsetof in if condition" do
      source = <<-CRYSTAL
        if offsetof(Data, :size) > 0
          puts "yes"
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots[0]]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      # Condition should be comparison with offsetof on left
      condition = arena[if_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      left = arena[condition.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Offsetof)

      args = left.offsetof_args.not_nil!
      args.size.should eq(2)
    end

    it "parses multiple offsetof calls" do
      source = <<-CRYSTAL
        x = offsetof(A, :f1)
        y = offsetof(B, :f2)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First assignment
      assign1 = arena[program.roots[0]]
      value1 = arena[assign1.assign_value.not_nil!]
      value1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Offsetof)
      args1 = value1.offsetof_args.not_nil!
      args1.size.should eq(2)

      # Second assignment
      assign2 = arena[program.roots[1]]
      value2 = arena[assign2.assign_value.not_nil!]
      value2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Offsetof)
      args2 = value2.offsetof_args.not_nil!
      args2.size.should eq(2)
    end
  end
end
