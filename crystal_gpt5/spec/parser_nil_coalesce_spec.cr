require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 81: Nil-coalescing operator (??)" do
    it "parses simple nil-coalescing" do
      source = "value ?? default"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary).not_nil!).should eq("??")
    end

    it "parses nil-coalescing with literals" do
      source = "nil ?? 42"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary).not_nil!).should eq("??")

      # Left side should be nil
      left = arena[CrystalGPT5::Compiler::Frontend.node_left(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Nil)

      # Right side should be number
      right = arena[CrystalGPT5::Compiler::Frontend.node_right(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
    end

    it "parses nil-coalescing in assignment" do
      source = "name = user.name ?? \"Anonymous\""

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(value).not_nil!).should eq("??")
    end

    it "parses nil-coalescing with method call" do
      source = "result = find_user() ?? create_user()"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(value).not_nil!).should eq("??")

      # Both sides should be method calls
      left = arena[CrystalGPT5::Compiler::Frontend.node_left(value).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      right = arena[CrystalGPT5::Compiler::Frontend.node_right(value).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses chained nil-coalescing" do
      source = "a ?? b ?? c"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should parse as (a ?? b) ?? c due to left-associativity
      outer = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(outer).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(outer).not_nil!).should eq("??")

      # Left side should be another ??
      inner = arena[CrystalGPT5::Compiler::Frontend.node_left(outer).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(inner).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(inner).not_nil!).should eq("??")
    end

    it "parses nil-coalescing in if condition" do
      source = <<-CRYSTAL
      if value ?? false
        puts "yes"
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(if_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      condition = arena[CrystalGPT5::Compiler::Frontend.node_condition(if_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(condition).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(condition).not_nil!).should eq("??")
    end

    it "parses nil-coalescing as method argument" do
      source = "process(input ?? default_value)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = CrystalGPT5::Compiler::Frontend.node_args(call).not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(arg).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(arg).not_nil!).should eq("??")
    end

    it "parses nil-coalescing with array/hash access" do
      source = "config[\"key\"] ?? default"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary).not_nil!).should eq("??")

      # Left side should be index access
      left = arena[CrystalGPT5::Compiler::Frontend.node_left(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Index)
    end

    it "disambiguates ?? from ? (ternary)" do
      source = <<-CRYSTAL
      a = b ? c : d
      e = f ?? g
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First: b ? c : d (ternary)
      assign1 = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      ternary = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign1).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(ternary).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Ternary)

      # Second: f ?? g (nil-coalescing)
      assign2 = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      nil_coalesce = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign2).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(nil_coalesce).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(nil_coalesce).not_nil!).should eq("??")
    end

    it "parses nil-coalescing with complex expressions" do
      source = "(obj.method + 5) ?? default_value"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(binary).not_nil!).should eq("??")

      # Left side should be grouping
      left = arena[CrystalGPT5::Compiler::Frontend.node_left(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end
  end
end
