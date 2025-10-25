require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 46: is_a? method (type check - returns Bool) (PRODUCTION-READY)" do
    it "parses simple type check" do
      source = <<-CRYSTAL
      x = value.is_a?(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Right side is IsA node
      is_a_node = arena[assign_node.assign_value.not_nil!]
      is_a_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)

      # Check target type
      String.new(is_a_node.is_a_target_type.not_nil!).should eq("Int32")

      # Check value being checked
      value_node = arena[is_a_node.is_a_value.not_nil!]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(value_node.literal.not_nil!).should eq("value")
    end

    it "parses type check with complex expression" do
      source = <<-CRYSTAL
      y = (x + 1).is_a?(String)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      is_a_node = arena[assign_node.assign_value.not_nil!]
      is_a_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)

      String.new(is_a_node.is_a_target_type.not_nil!).should eq("String")

      # Check value is grouping (parenthesized expression)
      value_node = arena[is_a_node.is_a_value.not_nil!]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end

    it "parses chained type checks" do
      source = <<-CRYSTAL
      result = value.is_a?(Int32).is_a?(String)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      outer_check = arena[assign_node.assign_value.not_nil!]
      outer_check.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(outer_check.is_a_target_type.not_nil!).should eq("String")

      # Inner check
      inner_check = arena[outer_check.is_a_value.not_nil!]
      inner_check.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(inner_check.is_a_target_type.not_nil!).should eq("Int32")
    end

    it "parses type check in method call arguments" do
      source = <<-CRYSTAL
      puts(value.is_a?(Int32))
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Check argument is type check
      args = call_node.args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(arg.is_a_target_type.not_nil!).should eq("Int32")
    end

    it "parses type check in array literal" do
      source = <<-CRYSTAL
      arr = [value.is_a?(Int32), other.is_a?(String)]
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

      first = arena[elements[0]]
      first.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(first.is_a_target_type.not_nil!).should eq("Int32")

      second = arena[elements[1]]
      second.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(second.is_a_target_type.not_nil!).should eq("String")
    end

    it "parses type check in conditional" do
      source = <<-CRYSTAL
      if value.is_a?(Int32)
        x
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots[0]]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      condition = arena[if_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(condition.is_a_target_type.not_nil!).should eq("Int32")
    end

    it "parses type check with custom type" do
      source = <<-CRYSTAL
      obj.is_a?(MyClass)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      is_a_node = arena[program.roots[0]]
      is_a_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(is_a_node.is_a_target_type.not_nil!).should eq("MyClass")
    end

    it "parses type check in method definition" do
      source = <<-CRYSTAL
      def foo
        value.is_a?(Int32)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      def_body = method_node.def_body.not_nil!
      def_body.size.should eq(1)
      body = arena[def_body[0]]
      body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(body.is_a_target_type.not_nil!).should eq("Int32")
    end

    it "parses type check in class method" do
      source = <<-CRYSTAL
      class Foo
        def bar
          @x.is_a?(String)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(1)
      method = arena[class_body[0]]
      method.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      method_def_body = method.def_body.not_nil!
      method_def_body.size.should eq(1)
      def_body = arena[method_def_body[0]]
      def_body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(def_body.is_a_target_type.not_nil!).should eq("String")
    end

    it "parses type check after method call" do
      source = <<-CRYSTAL
      obj.get_value.is_a?(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      is_a_node = arena[program.roots[0]]
      is_a_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(is_a_node.is_a_target_type.not_nil!).should eq("Int32")

      # Check receiver is member access
      receiver = arena[is_a_node.is_a_value.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
    end

    it "parses type check with literal" do
      source = <<-CRYSTAL
      42.is_a?(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      is_a_node = arena[program.roots[0]]
      is_a_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(is_a_node.is_a_target_type.not_nil!).should eq("Int32")

      # Check receiver is number literal
      receiver = arena[is_a_node.is_a_value.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
    end

    it "parses type check in return statement" do
      source = <<-CRYSTAL
      def foo
        return value.is_a?(String)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      def_body = method_node.def_body.not_nil!
      def_body.size.should eq(1)
      body = arena[def_body[0]]
      body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Return)

      return_value = arena[body.return_value.not_nil!]
      return_value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::IsA)
      String.new(return_value.is_a_target_type.not_nil!).should eq("String")
    end
  end
end
