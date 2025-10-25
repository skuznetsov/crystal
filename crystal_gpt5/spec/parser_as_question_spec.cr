require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 45: as? keyword (safe cast - nilable) (PRODUCTION-READY)" do
    it "parses simple safe cast" do
      source = <<-CRYSTAL
      x = value.as?(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Right side is AsQuestion node
      as_question_node = arena[assign_node.assign_value.not_nil!]
      as_question_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)

      # Check target type
      String.new(as_question_node.as_question_target_type.not_nil!).should eq("Int32")

      # Check value being cast
      value_node = arena[as_question_node.as_question_value.not_nil!]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(value_node.literal.not_nil!).should eq("value")
    end

    it "parses safe cast with complex expression" do
      source = <<-CRYSTAL
      y = (x + 1).as?(String)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      as_question_node = arena[assign_node.assign_value.not_nil!]
      as_question_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)

      String.new(as_question_node.as_question_target_type.not_nil!).should eq("String")

      # Check value is grouping (parenthesized expression)
      value_node = arena[as_question_node.as_question_value.not_nil!]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end

    it "parses chained safe casts" do
      source = <<-CRYSTAL
      result = value.as?(Int32).as?(String)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      outer_cast = arena[assign_node.assign_value.not_nil!]
      outer_cast.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(outer_cast.as_question_target_type.not_nil!).should eq("String")

      # Inner cast
      inner_cast = arena[outer_cast.as_question_value.not_nil!]
      inner_cast.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(inner_cast.as_question_target_type.not_nil!).should eq("Int32")
    end

    it "parses safe cast in method call arguments" do
      source = <<-CRYSTAL
      puts(value.as?(Int32))
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Check argument is safe cast
      args = call_node.args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(arg.as_question_target_type.not_nil!).should eq("Int32")
    end

    it "parses safe cast in array literal" do
      source = <<-CRYSTAL
      arr = [value.as?(Int32), other.as?(String)]
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
      first.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(first.as_question_target_type.not_nil!).should eq("Int32")

      second = arena[elements[1]]
      second.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(second.as_question_target_type.not_nil!).should eq("String")
    end

    it "parses safe cast in conditional" do
      source = <<-CRYSTAL
      if value.as?(Int32)
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
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(condition.as_question_target_type.not_nil!).should eq("Int32")
    end

    it "parses safe cast with custom type" do
      source = <<-CRYSTAL
      obj.as?(MyClass)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      as_question_node = arena[program.roots[0]]
      as_question_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(as_question_node.as_question_target_type.not_nil!).should eq("MyClass")
    end

    it "parses safe cast in method definition" do
      source = <<-CRYSTAL
      def foo
        value.as?(Int32)
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
      body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(body.as_question_target_type.not_nil!).should eq("Int32")
    end

    it "parses safe cast in class method" do
      source = <<-CRYSTAL
      class Foo
        def bar
          @x.as?(String)
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
      def_body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(def_body.as_question_target_type.not_nil!).should eq("String")
    end

    it "parses safe cast after method call" do
      source = <<-CRYSTAL
      obj.get_value.as?(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      as_question_node = arena[program.roots[0]]
      as_question_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(as_question_node.as_question_target_type.not_nil!).should eq("Int32")

      # Check receiver is member access
      receiver = arena[as_question_node.as_question_value.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
    end

    it "parses safe cast with literal" do
      source = <<-CRYSTAL
      42.as?(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      as_question_node = arena[program.roots[0]]
      as_question_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(as_question_node.as_question_target_type.not_nil!).should eq("Int32")

      # Check receiver is number literal
      receiver = arena[as_question_node.as_question_value.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
    end

    it "parses safe cast in return statement" do
      source = <<-CRYSTAL
      def foo
        return value.as?(String)
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
      return_value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::AsQuestion)
      String.new(return_value.as_question_target_type.not_nil!).should eq("String")
    end
  end
end
