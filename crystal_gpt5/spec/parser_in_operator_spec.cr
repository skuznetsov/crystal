require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 79: In operator (containment check)" do
    it "parses simple in expression" do
      source = "5 in array"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      String.new(binary.operator.not_nil!).should eq("in")
    end

    it "parses in with array literal" do
      source = "x in [1, 2, 3]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("in")

      # Right side should be array literal
      right = arena[binary.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)
    end

    it "parses in with range" do
      source = "value in (1..10)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("in")

      # Right side should be grouping containing range
      right_grouping = arena[binary.right.not_nil!]
      right_grouping.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)

      right = arena[right_grouping.left.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Range)
    end

    it "parses in within if condition" do
      source = <<-CRYSTAL
      if x in list
        puts "found"
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots[0]]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      condition = arena[if_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(condition.operator.not_nil!).should eq("in")
    end

    it "parses negated in with not" do
      source = "!(value in list)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Parentheses force !(value in list) parsing
      unary = arena[program.roots[0]]
      unary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unary)

      # Operand is grouping containing the binary "in" expression
      operand_grouping = arena[unary.right.not_nil!]
      operand_grouping.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)

      operand = arena[operand_grouping.left.not_nil!]
      operand.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(operand.operator.not_nil!).should eq("in")
    end

    it "parses in in assignment" do
      source = "result = x in collection"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("in")
    end

    it "parses in as method argument" do
      source = "foo(x in array)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(arg.operator.not_nil!).should eq("in")
    end

    it "parses in with complex left expression" do
      source = "obj.value in collection"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("in")

      # Left side should be member access
      left = arena[binary.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
    end

    it "parses multiple in expressions" do
      source = <<-CRYSTAL
      a in list1
      b in list2
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      binary1 = arena[program.roots[0]]
      binary1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary1.operator.not_nil!).should eq("in")

      binary2 = arena[program.roots[1]]
      binary2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary2.operator.not_nil!).should eq("in")
    end

    it "parses in with parentheses" do
      source = "(x + 1) in array"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("in")

      # Left side should be grouping
      left = arena[binary.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end
  end
end
