require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 49: responds_to? method (PRODUCTION-READY)" do
    it "parses simple responds_to? check with symbol" do
      source = <<-CRYSTAL
      result = obj.responds_to?(:to_s)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Right side is RespondsTo node
      responds_to_node = arena[assign_node.assign_value.not_nil!]
      responds_to_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)

      # Check receiver (obj)
      receiver = arena[responds_to_node.responds_to_value.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(receiver.literal.not_nil!).should eq("obj")

      # Check method name (symbol :to_s)
      method_name = arena[responds_to_node.responds_to_method_name.not_nil!]
      method_name.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Symbol)
    end

    it "parses responds_to? with string argument" do
      source = <<-CRYSTAL
      obj.responds_to?("method_name")
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      responds_to_node = arena[program.roots[0]]
      responds_to_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)

      # Check method name is string
      method_name = arena[responds_to_node.responds_to_method_name.not_nil!]
      method_name.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
    end

    it "parses responds_to? in conditional" do
      source = <<-CRYSTAL
      if obj.responds_to?(:foo)
        obj.foo
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots[0]]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      # Condition is responds_to?
      condition = arena[if_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)
    end

    it "parses chained responds_to? calls" do
      source = <<-CRYSTAL
      obj.foo.responds_to?(:bar)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      responds_to_node = arena[program.roots[0]]
      responds_to_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)

      # Receiver should be member access (obj.foo)
      receiver = arena[responds_to_node.responds_to_value.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
    end

    it "parses responds_to? in method call arguments" do
      source = <<-CRYSTAL
      puts(obj.responds_to?(:to_s))
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Argument is responds_to?
      args = call_node.args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)
    end

    it "parses responds_to? in array literal" do
      source = <<-CRYSTAL
      [a.responds_to?(:x), b.responds_to?(:y)]
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array_node = arena[program.roots[0]]
      array_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      elements = array_node.array_elements.not_nil!
      elements.size.should eq(2)

      # Both elements are responds_to?
      first = arena[elements[0]]
      first.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)

      second = arena[elements[1]]
      second.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)
    end

    it "parses responds_to? in binary expression" do
      source = <<-CRYSTAL
      a.responds_to?(:foo) && b.responds_to?(:bar)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary_node = arena[program.roots[0]]
      binary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary_node.operator.not_nil!).should eq("&&")

      # Left side is responds_to?
      left = arena[binary_node.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)

      # Right side is responds_to?
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)
    end

    it "parses responds_to? in return statement" do
      source = <<-CRYSTAL
      def check
        return obj.responds_to?(:method)
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
      return_value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)
    end

    it "parses responds_to? with instance variable" do
      source = <<-CRYSTAL
      @obj.responds_to?(:size)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      responds_to_node = arena[program.roots[0]]
      responds_to_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)

      # Receiver is instance variable
      receiver = arena[responds_to_node.responds_to_value.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVar)
    end

    it "parses responds_to? in unless statement" do
      source = <<-CRYSTAL
      unless obj.responds_to?(:method)
        puts "missing"
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unless_node = arena[program.roots[0]]
      unless_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unless)

      # Condition is responds_to? (Unless reuses if_condition field)
      condition = arena[unless_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)
    end

    it "parses responds_to? in ternary expression" do
      source = <<-CRYSTAL
      obj.responds_to?(:foo) ? obj.foo : nil
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      ternary_node = arena[program.roots[0]]
      ternary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Ternary)

      # Condition is responds_to?
      condition = arena[ternary_node.ternary_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)
    end

    it "parses nested responds_to? calls" do
      source = <<-CRYSTAL
      class Foo
        def check
          @obj.responds_to?(:bar)
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
      def_body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::RespondsTo)
    end
  end
end
