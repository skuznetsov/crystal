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
      CrystalGPT5::Compiler::Frontend.node_kind(assign_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Assign)

      # Right side is SafeNavigation node
      safe_nav_node = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(safe_nav_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)

      # Check member name
      String.new(CrystalGPT5::Compiler::Frontend.node_member(safe_nav_node).not_nil!).should eq("method")

      # Check receiver
      receiver = arena[CrystalGPT5::Compiler::Frontend.node_left(safe_nav_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(receiver).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Identifier)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(receiver).not_nil!).should eq("obj")
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
      safe_nav_node = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(safe_nav_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)

      String.new(CrystalGPT5::Compiler::Frontend.node_member(safe_nav_node).not_nil!).should eq("method")

      # Check receiver is grouping
      receiver = arena[CrystalGPT5::Compiler::Frontend.node_left(safe_nav_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(receiver).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Grouping)
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
      outer_nav = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(outer_nav).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(outer_nav).not_nil!).should eq("method2")

      # Inner safe navigation
      inner_nav = arena[CrystalGPT5::Compiler::Frontend.node_left(outer_nav).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(inner_nav).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(inner_nav).not_nil!).should eq("method1")
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
      CrystalGPT5::Compiler::Frontend.node_kind(call_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Call)

      # Check argument is safe navigation
      args = CrystalGPT5::Compiler::Frontend.node_args(call_node).not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(arg).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(arg).not_nil!).should eq("value")
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
      array_node = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(array_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::ArrayLiteral)

      elements = CrystalGPT5::Compiler::Frontend.node_array_elements(array_node).not_nil!
      elements.size.should eq(2)

      first = arena[elements[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(first).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(first).not_nil!).should eq("val")

      second = arena[elements[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(second).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(second).not_nil!).should eq("val")
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
      CrystalGPT5::Compiler::Frontend.node_kind(if_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::If)

      condition = arena[CrystalGPT5::Compiler::Frontend.node_condition(if_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(condition).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(condition).not_nil!).should eq("active")
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
      CrystalGPT5::Compiler::Frontend.node_kind(call_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Call)

      # Check callee is safe navigation
      callee = arena[CrystalGPT5::Compiler::Frontend.node_callee(call_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(callee).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(callee).not_nil!).should eq("calculate")
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
      CrystalGPT5::Compiler::Frontend.node_kind(method_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Def)

      def_body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      def_body.size.should eq(1)
      body = arena[def_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(body).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(body).not_nil!).should eq("value")
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
      CrystalGPT5::Compiler::Frontend.node_kind(class_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Class)

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      class_body.size.should eq(1)
      method = arena[class_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Def)

      method_def_body = CrystalGPT5::Compiler::Frontend.node_def_body(method).not_nil!
      method_def_body.size.should eq(1)
      def_body = arena[method_def_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(def_body).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(def_body).not_nil!).should eq("data")
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
      CrystalGPT5::Compiler::Frontend.node_kind(outer_safe).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(outer_safe).not_nil!).should eq("method3")

      # Next is .method2 (regular member access)
      regular_access = arena[CrystalGPT5::Compiler::Frontend.node_left(outer_safe).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(regular_access).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::MemberAccess)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(regular_access).not_nil!).should eq("method2")

      # Innermost is &.method1
      inner_safe = arena[CrystalGPT5::Compiler::Frontend.node_left(regular_access).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(inner_safe).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(inner_safe).not_nil!).should eq("method1")
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
      CrystalGPT5::Compiler::Frontend.node_kind(method_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Def)

      def_body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      def_body.size.should eq(1)
      body = arena[def_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(body).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Return)

      return_value = arena[CrystalGPT5::Compiler::Frontend.node_return_value(body).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(return_value).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(return_value).not_nil!).should eq("value")
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
      CrystalGPT5::Compiler::Frontend.node_kind(safe_nav_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::SafeNavigation)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(safe_nav_node).not_nil!).should eq("upcase")

      # Check receiver is string literal
      receiver = arena[CrystalGPT5::Compiler::Frontend.node_left(safe_nav_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(receiver).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::String)
    end
  end
end
