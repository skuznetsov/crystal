require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 48: <=> spaceship operator (three-way comparison) (PRODUCTION-READY)" do
    it "parses simple spaceship comparison" do
      source = <<-CRYSTAL
      result = a <=> b
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Right side is Binary node with <=> operator
      binary_node = arena[assign_node.assign_value.not_nil!]
      binary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      # Check operator
      String.new(binary_node.operator.not_nil!).should eq("<=>")

      # Check left operand
      left = arena[binary_node.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(left.literal.not_nil!).should eq("a")

      # Check right operand
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(right.literal.not_nil!).should eq("b")
    end

    it "parses spaceship with number literals" do
      source = <<-CRYSTAL
      x = 42 <=> 100
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      binary_node = arena[assign_node.assign_value.not_nil!]
      binary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      String.new(binary_node.operator.not_nil!).should eq("<=>")

      # Check left is number
      left = arena[binary_node.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)

      # Check right is number
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
    end

    it "parses chained spaceship comparisons" do
      source = <<-CRYSTAL
      result = (a <=> b) <=> (c <=> d)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      outer_binary = arena[assign_node.assign_value.not_nil!]
      outer_binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(outer_binary.operator.not_nil!).should eq("<=>")

      # Left is (a <=> b)
      left_binary = arena[outer_binary.left.not_nil!]
      left_binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)

      # Right is (c <=> d)
      right_binary = arena[outer_binary.right.not_nil!]
      right_binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end

    it "parses spaceship in method call arguments" do
      source = <<-CRYSTAL
      puts(a <=> b)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Check argument is spaceship comparison
      args = call_node.args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(arg.operator.not_nil!).should eq("<=>")
    end

    it "parses spaceship in array literal" do
      source = <<-CRYSTAL
      arr = [a <=> b, c <=> d]
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
      first.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(first.operator.not_nil!).should eq("<=>")

      second = arena[elements[1]]
      second.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(second.operator.not_nil!).should eq("<=>")
    end

    it "parses spaceship in conditional" do
      source = <<-CRYSTAL
      if (a <=> b) == 0
        x
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots[0]]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      # Condition is (a <=> b) == 0
      condition = arena[if_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(condition.operator.not_nil!).should eq("==")

      # Left of == is spaceship
      left = arena[condition.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end

    it "parses spaceship with complex expressions" do
      source = <<-CRYSTAL
      result = (x + 1) <=> (y * 2)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      binary_node = arena[assign_node.assign_value.not_nil!]
      binary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      String.new(binary_node.operator.not_nil!).should eq("<=>")

      # Left is (x + 1)
      left = arena[binary_node.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)

      # Right is (y * 2)
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end

    it "parses spaceship in method definition" do
      source = <<-CRYSTAL
      def compare
        a <=> b
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
      body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(body.operator.not_nil!).should eq("<=>")
    end

    it "parses spaceship in class method" do
      source = <<-CRYSTAL
      class Foo
        def compare
          @x <=> @y
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
      def_body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(def_body.operator.not_nil!).should eq("<=>")
    end

    it "parses spaceship with strings" do
      source = <<-CRYSTAL
      "apple" <=> "banana"
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary_node = arena[program.roots[0]]
      binary_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary_node.operator.not_nil!).should eq("<=>")

      # Check left is string
      left = arena[binary_node.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)

      # Check right is string
      right = arena[binary_node.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
    end

    it "parses spaceship in return statement" do
      source = <<-CRYSTAL
      def compare
        return a <=> b
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
      return_value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(return_value.operator.not_nil!).should eq("<=>")
    end

    it "correctly distinguishes <=> from <= and >=" do
      source = <<-CRYSTAL
      a = x <= y
      b = x >= y
      c = x <=> y
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First: x <= y
      assign1 = arena[program.roots[0]]
      binary1 = arena[assign1.assign_value.not_nil!]
      String.new(binary1.operator.not_nil!).should eq("<=")

      # Second: x >= y
      assign2 = arena[program.roots[1]]
      binary2 = arena[assign2.assign_value.not_nil!]
      String.new(binary2.operator.not_nil!).should eq(">=")

      # Third: x <=> y
      assign3 = arena[program.roots[2]]
      binary3 = arena[assign3.assign_value.not_nil!]
      String.new(binary3.operator.not_nil!).should eq("<=>")
    end
  end
end
