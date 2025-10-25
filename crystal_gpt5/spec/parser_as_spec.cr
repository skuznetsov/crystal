require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 44: as keyword (type casting) (PRODUCTION-READY)" do
    it "parses simple type cast" do
      source = <<-CRYSTAL
      x = value.as(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Right side is As node
      as_node = arena[assign_node.assign_value.not_nil!]
      as_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)

      # Check target type
      String.new(as_node.as_target_type.not_nil!).should eq("Int32")

      # Check value being cast
      value_node = arena[as_node.as_value.not_nil!]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(value_node.literal.not_nil!).should eq("value")
    end

    it "parses type cast with complex expression" do
      source = <<-CRYSTAL
      y = (x + 1).as(String)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      as_node = arena[assign_node.assign_value.not_nil!]
      as_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)

      String.new(as_node.as_target_type.not_nil!).should eq("String")

      # Value is a grouping with binary expression inside
      grouping_node = arena[as_node.as_value.not_nil!]
      grouping_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end

    it "parses chained type casts" do
      source = <<-CRYSTAL
      z = x.as(Int32).as(Int64)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]

      # Outer cast to Int64
      outer_as = arena[assign_node.assign_value.not_nil!]
      outer_as.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(outer_as.as_target_type.not_nil!).should eq("Int64")

      # Inner cast to Int32
      inner_as = arena[outer_as.as_value.not_nil!]
      inner_as.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(inner_as.as_target_type.not_nil!).should eq("Int32")

      # Original value
      value_node = arena[inner_as.as_value.not_nil!]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(value_node.literal.not_nil!).should eq("x")
    end

    it "parses type cast in method call" do
      source = <<-CRYSTAL
      foo(x.as(String))
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Check argument is type cast
      args = call_node.args.not_nil!
      args.size.should eq(1)

      as_node = arena[args[0]]
      as_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(as_node.as_target_type.not_nil!).should eq("String")
    end

    it "parses type cast in array literal" do
      source = <<-CRYSTAL
      arr = [x.as(Int32), y.as(Int32)]
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      array_node = arena[assign_node.assign_value.not_nil!]
      array_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      elements = array_node.array_elements.not_nil!
      elements.size.should eq(2)

      # First element
      first_as = arena[elements[0]]
      first_as.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(first_as.as_target_type.not_nil!).should eq("Int32")

      # Second element
      second_as = arena[elements[1]]
      second_as.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(second_as.as_target_type.not_nil!).should eq("Int32")
    end

    it "parses type cast in conditional" do
      source = <<-CRYSTAL
      if value.as(Bool)
        1
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots[0]]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      # Condition is type cast
      condition_node = arena[if_node.if_condition.not_nil!]
      condition_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(condition_node.as_target_type.not_nil!).should eq("Bool")
    end

    it "parses type cast with custom type" do
      source = <<-CRYSTAL
      obj = value.as(MyClass)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      as_node = arena[assign_node.assign_value.not_nil!]
      as_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)

      String.new(as_node.as_target_type.not_nil!).should eq("MyClass")
    end

    it "parses type cast in method definition" do
      source = <<-CRYSTAL
      def foo
        x.as(Int32)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      method_body = method_node.def_body.not_nil!
      method_body.size.should eq(1)

      as_node = arena[method_body[0]]
      as_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(as_node.as_target_type.not_nil!).should eq("Int32")
    end

    it "parses type cast in class" do
      source = <<-CRYSTAL
      class Foo
        def bar
          @value.as(String)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]
      method_body = method_node.def_body.not_nil!

      as_node = arena[method_body[0]]
      as_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(as_node.as_target_type.not_nil!).should eq("String")

      # Value is instance variable
      ivar_node = arena[as_node.as_value.not_nil!]
      ivar_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVar)
    end

    it "parses type cast after method call" do
      source = <<-CRYSTAL
      result = obj.method.as(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      as_node = arena[assign_node.assign_value.not_nil!]
      as_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(as_node.as_target_type.not_nil!).should eq("Int32")

      # Value is method call (actually MemberAccess without parens)
      member_node = arena[as_node.as_value.not_nil!]
      member_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(member_node.member.not_nil!).should eq("method")
    end

    it "parses type cast with number literal" do
      source = <<-CRYSTAL
      x = 42.as(Int64)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      as_node = arena[assign_node.assign_value.not_nil!]
      as_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(as_node.as_target_type.not_nil!).should eq("Int64")

      # Value is number literal
      number_node = arena[as_node.as_value.not_nil!]
      number_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
    end

    it "parses type cast in return statement" do
      source = <<-CRYSTAL
      def foo
        return x.as(String)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      method_body = method_node.def_body.not_nil!

      return_node = arena[method_body[0]]
      return_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Return)

      # Return value is type cast
      as_node = arena[return_node.return_value.not_nil!]
      as_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::As)
      String.new(as_node.as_target_type.not_nil!).should eq("String")
    end
  end
end
