require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 51: ||= and &&= logical compound assignment (PRODUCTION-READY)" do
    it "parses simple ||= assignment" do
      source = <<-CRYSTAL
      a ||= b
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should desugar to: a = a || b
      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target is identifier 'a'
      target_node = arena[assign_node.assign_target.not_nil!]
      target_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(target_node.literal.not_nil!).should eq("a")

      # Value is binary expression: a || b
      binary_node = arena[assign_node.assign_value.not_nil!]
      binary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary_node.operator.not_nil!).should eq("||")

      # Left side of || is 'a'
      left = arena[binary_node.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(left.literal.not_nil!).should eq("a")

      # Right side of || is 'b'
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(right.literal.not_nil!).should eq("b")
    end

    it "parses simple &&= assignment" do
      source = <<-CRYSTAL
      x &&= y
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should desugar to: x = x && y
      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target is identifier 'x'
      target_node = arena[assign_node.assign_target.not_nil!]
      target_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(target_node.literal.not_nil!).should eq("x")

      # Value is binary expression: x && y
      binary_node = arena[assign_node.assign_value.not_nil!]
      binary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary_node.operator.not_nil!).should eq("&&")

      # Left side of && is 'x'
      left = arena[binary_node.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(left.literal.not_nil!).should eq("x")

      # Right side of && is 'y'
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(right.literal.not_nil!).should eq("y")
    end

    it "parses ||= with number literal" do
      source = <<-CRYSTAL
      value ||= 42
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      binary_node = arena[assign_node.assign_value.not_nil!]
      String.new(binary_node.operator.not_nil!).should eq("||")

      # Right side is number
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
    end

    it "parses &&= with string literal" do
      source = <<-CRYSTAL
      name &&= "default"
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      binary_node = arena[assign_node.assign_value.not_nil!]
      String.new(binary_node.operator.not_nil!).should eq("&&")

      # Right side is string
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
    end

    it "parses ||= with complex expression" do
      source = <<-CRYSTAL
      result ||= compute_value()
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      binary_node = arena[assign_node.assign_value.not_nil!]
      String.new(binary_node.operator.not_nil!).should eq("||")

      # Right side is method call
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses &&= with complex expression" do
      source = <<-CRYSTAL
      flag &&= check_condition()
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      binary_node = arena[assign_node.assign_value.not_nil!]
      String.new(binary_node.operator.not_nil!).should eq("&&")

      # Right side is method call
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses ||= in method definition" do
      source = <<-CRYSTAL
      def foo
        @cache ||= expensive_operation()
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
      assign = arena[def_body[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Check it's instance variable assignment
      target_node = arena[assign.assign_target.not_nil!]
      target_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVar)
      String.new(target_node.literal.not_nil!).should eq("@cache")

      # Check desugaring: @cache = @cache || expensive_operation()
      binary = arena[assign.assign_value.not_nil!]
      String.new(binary.operator.not_nil!).should eq("||")
    end

    it "parses &&= in class method" do
      source = <<-CRYSTAL
      class Foo
        def bar
          @enabled &&= true
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
      assign = arena[method_def_body[0]]

      binary = arena[assign.assign_value.not_nil!]
      String.new(binary.operator.not_nil!).should eq("&&")
    end

    it "parses multiple ||= assignments" do
      source = <<-CRYSTAL
      a ||= 1
      b ||= 2
      c ||= 3
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # All three should be assignments with || binary
      (0..2).each do |i|
        assign = arena[program.roots[i]]
        assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

        binary = arena[assign.assign_value.not_nil!]
        String.new(binary.operator.not_nil!).should eq("||")
      end
    end

    it "parses multiple &&= assignments" do
      source = <<-CRYSTAL
      x &&= true
      y &&= false
      z &&= nil
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # All three should be assignments with && binary
      (0..2).each do |i|
        assign = arena[program.roots[i]]
        assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

        binary = arena[assign.assign_value.not_nil!]
        String.new(binary.operator.not_nil!).should eq("&&")
      end
    end

    it "correctly distinguishes ||= from || and |" do
      source = <<-CRYSTAL
      a = x || y
      b ||= z
      c = d | e
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First: x || y (binary expression)
      assign1 = arena[program.roots[0]]
      binary1 = arena[assign1.assign_value.not_nil!]
      String.new(binary1.operator.not_nil!).should eq("||")

      # Second: b ||= z (desugared to b = b || z)
      assign2 = arena[program.roots[1]]
      binary2 = arena[assign2.assign_value.not_nil!]
      String.new(binary2.operator.not_nil!).should eq("||")
      # Left of || should be 'b' (desugared)
      left2 = arena[binary2.left.not_nil!]
      String.new(left2.literal.not_nil!).should eq("b")

      # Third: d | e (bitwise or)
      assign3 = arena[program.roots[2]]
      binary3 = arena[assign3.assign_value.not_nil!]
      String.new(binary3.operator.not_nil!).should eq("|")
    end

    it "correctly distinguishes &&= from && and &" do
      source = <<-CRYSTAL
      a = x && y
      b &&= z
      c = d & e
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First: x && y (binary expression)
      assign1 = arena[program.roots[0]]
      binary1 = arena[assign1.assign_value.not_nil!]
      String.new(binary1.operator.not_nil!).should eq("&&")

      # Second: b &&= z (desugared to b = b && z)
      assign2 = arena[program.roots[1]]
      binary2 = arena[assign2.assign_value.not_nil!]
      String.new(binary2.operator.not_nil!).should eq("&&")
      # Left of && should be 'b' (desugared)
      left2 = arena[binary2.left.not_nil!]
      String.new(left2.literal.not_nil!).should eq("b")

      # Third: d & e (bitwise and)
      assign3 = arena[program.roots[2]]
      binary3 = arena[assign3.assign_value.not_nil!]
      String.new(binary3.operator.not_nil!).should eq("&")
    end
  end
end
