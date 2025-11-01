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
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)

      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary).not_nil!).should eq("in")
    end

    it "parses in with array literal" do
      source = "x in [1, 2, 3]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary).not_nil!).should eq("in")

      # Right side should be array literal
      right = arena[CrystalGPT5::Compiler::Frontend.node_right(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::ArrayLiteral)
    end

    it "parses in with range" do
      source = "value in (1..10)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary).not_nil!).should eq("in")

      # Right side should be grouping containing range
      right_grouping = arena[CrystalGPT5::Compiler::Frontend.node_right(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right_grouping).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Grouping)

      right = arena[CrystalGPT5::Compiler::Frontend.node_left(right_grouping).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Range)
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
      CrystalGPT5::Compiler::Frontend.node_kind(if_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::If)

      condition = arena[CrystalGPT5::Compiler::Frontend.node_condition(if_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(condition).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(condition).not_nil!).should eq("in")
    end

    it "parses negated in with not" do
      source = "!(value in list)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Parentheses force !(value in list) parsing
      unary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(unary).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Unary)

      # Operand is grouping containing the binary "in" expression
      operand_grouping = arena[CrystalGPT5::Compiler::Frontend.node_right(unary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(operand_grouping).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Grouping)

      operand = arena[CrystalGPT5::Compiler::Frontend.node_left(operand_grouping).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(operand).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(operand).not_nil!).should eq("in")
    end

    it "parses in in assignment" do
      source = "result = x in collection"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Assign)

      value = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(value).not_nil!).should eq("in")
    end

    it "parses in as method argument" do
      source = "foo(x in array)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Call)

      args = CrystalGPT5::Compiler::Frontend.node_args(call).not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(arg).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(arg).not_nil!).should eq("in")
    end

    it "parses in with complex left expression" do
      source = "obj.value in collection"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary).not_nil!).should eq("in")

      # Left side should be member access
      left = arena[CrystalGPT5::Compiler::Frontend.node_left(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::MemberAccess)
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
      CrystalGPT5::Compiler::Frontend.node_kind(binary1).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary1).not_nil!).should eq("in")

      binary2 = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary2).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary2).not_nil!).should eq("in")
    end

    it "parses in with parentheses" do
      source = "(x + 1) in array"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary).not_nil!).should eq("in")

      # Left side should be grouping
      left = arena[CrystalGPT5::Compiler::Frontend.node_left(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Grouping)
    end
  end
end
