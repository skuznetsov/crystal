require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 47: &. safe navigation operator (PRODUCTION-READY)" do
    it "parses simple safe navigation" do
      source = <<-CRYSTAL
      x = obj&.method
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Right side is SafeNavigation node
      safe_nav_node = arena[assign_node.assign_value.not_nil!]
      safe_nav_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)

      # Check member name
      String.new(safe_nav_node.member.not_nil!).should eq("method")

      # Check receiver
      receiver = arena[safe_nav_node.left.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(receiver.literal.not_nil!).should eq("obj")
    end

    it "parses safe navigation with complex receiver" do
      source = <<-CRYSTAL
      y = (obj1 + obj2)&.method
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      safe_nav_node = arena[assign_node.assign_value.not_nil!]
      safe_nav_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)

      String.new(safe_nav_node.member.not_nil!).should eq("method")

      # Check receiver is grouping
      receiver = arena[safe_nav_node.left.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end

    it "parses chained safe navigation" do
      source = <<-CRYSTAL
      result = obj&.method1&.method2
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      outer_nav = arena[assign_node.assign_value.not_nil!]
      outer_nav.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(outer_nav.member.not_nil!).should eq("method2")

      # Inner safe navigation
      inner_nav = arena[outer_nav.left.not_nil!]
      inner_nav.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(inner_nav.member.not_nil!).should eq("method1")
    end

    it "parses safe navigation in method call arguments" do
      source = <<-CRYSTAL
      puts(obj&.value)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Check argument is safe navigation
      args = call_node.args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(arg.member.not_nil!).should eq("value")
    end

    it "parses safe navigation in array literal" do
      source = <<-CRYSTAL
      arr = [obj1&.val, obj2&.val]
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
      first.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(first.member.not_nil!).should eq("val")

      second = arena[elements[1]]
      second.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(second.member.not_nil!).should eq("val")
    end

    it "parses safe navigation in conditional" do
      source = <<-CRYSTAL
      if obj&.active
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
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(condition.member.not_nil!).should eq("active")
    end

    it "parses safe navigation with method call" do
      source = <<-CRYSTAL
      obj&.calculate(1, 2)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # After &.calculate, we expect (1, 2) to parse as call with safe navigation as callee
      call_node = arena[program.roots[0]]
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Check callee is safe navigation
      callee = arena[call_node.callee.not_nil!]
      callee.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(callee.member.not_nil!).should eq("calculate")
    end

    it "parses safe navigation in method definition" do
      source = <<-CRYSTAL
      def foo
        obj&.value
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
      body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(body.member.not_nil!).should eq("value")
    end

    it "parses safe navigation in class method" do
      source = <<-CRYSTAL
      class Foo
        def bar
          @obj&.data
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
      def_body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(def_body.member.not_nil!).should eq("data")
    end

    it "parses mixed safe and regular navigation" do
      source = <<-CRYSTAL
      obj&.method1.method2&.method3
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Outermost is &.method3
      outer_safe = arena[program.roots[0]]
      outer_safe.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(outer_safe.member.not_nil!).should eq("method3")

      # Next is .method2 (regular member access)
      regular_access = arena[outer_safe.left.not_nil!]
      regular_access.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(regular_access.member.not_nil!).should eq("method2")

      # Innermost is &.method1
      inner_safe = arena[regular_access.left.not_nil!]
      inner_safe.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(inner_safe.member.not_nil!).should eq("method1")
    end

    it "parses safe navigation with return statement" do
      source = <<-CRYSTAL
      def foo
        return obj&.value
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
      return_value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(return_value.member.not_nil!).should eq("value")
    end

    it "parses safe navigation on literal" do
      source = <<-CRYSTAL
      "hello"&.upcase
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      safe_nav_node = arena[program.roots[0]]
      safe_nav_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
      String.new(safe_nav_node.member.not_nil!).should eq("upcase")

      # Check receiver is string literal
      receiver = arena[safe_nav_node.left.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
    end
  end
end
