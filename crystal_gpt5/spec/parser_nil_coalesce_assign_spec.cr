require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 82: Nil-coalescing compound assignment (??=)" do
    it "parses simple ??= assignment" do
      source = "x ??= 42"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Should desugar to: x = x ?? 42
      value = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(value).not_nil!).should eq("??")
    end

    it "parses ??= with instance variable" do
      source = "@cache ??= expensive_computation()"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target should be instance variable
      target = arena[CrystalGPT5::Compiler::Frontend.node_assign_target(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(target).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVar)

      # Value should be binary ??
      value = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(value).not_nil!).should eq("??")
    end

    it "parses ??= with class variable" do
      source = "@@config ??= load_defaults()"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target should be class variable
      target = arena[CrystalGPT5::Compiler::Frontend.node_assign_target(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(target).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ClassVar)
    end

    it "parses ??= with global variable" do
      source = "$logger ??= Logger.new"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target should be global variable
      target = arena[CrystalGPT5::Compiler::Frontend.node_assign_target(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(target).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)
    end

    it "parses ??= with hash/array index" do
      source = "config[\"key\"] ??= \"default\""

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target should be index
      target = arena[CrystalGPT5::Compiler::Frontend.node_assign_target(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(target).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Index)
    end

    it "parses ??= with complex expression on right" do
      source = "result ??= compute() + transform(data)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value should be binary ??
      value = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(value).not_nil!).should eq("??")

      # Right side of ?? should be addition
      right = arena[CrystalGPT5::Compiler::Frontend.node_right(value).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(right).not_nil!).should eq("+")
    end

    it "parses multiple ??= statements" do
      source = <<-CRYSTAL
      @cache ??= {}
      @counter ??= 0
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      assign1 = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      assign2 = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses ??= inside method" do
      source = <<-CRYSTAL
      def get_config
        @config ??= load_config()
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_def = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method_def).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      # Body should contain assignment
      body_exprs = CrystalGPT5::Compiler::Frontend.node_def_body(method_def).not_nil!
      body_exprs.size.should eq(1)

      body = arena[body_exprs[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(body).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "disambiguates ??= from ?? and ? and =" do
      source = <<-CRYSTAL
      a = b ? c : d
      e = f ?? g
      h ??= i
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First: b ? c : d (ternary)
      assign1 = arena[program.roots[0]]
      value1 = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign1).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Ternary)

      # Second: f ?? g (nil-coalescing)
      assign2 = arena[program.roots[1]]
      value2 = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign2).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(value2).not_nil!).should eq("??")

      # Third: h ??= i (compound assignment)
      assign3 = arena[program.roots[2]]
      value3 = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign3).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value3).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(value3).not_nil!).should eq("??")
      # Left side of ?? should reference 'h'
      left3 = arena[CrystalGPT5::Compiler::Frontend.node_left(value3).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left3).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
    end

    it "parses ??= with literal nil on right" do
      source = "value ??= nil"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Desugar to: value = value ?? nil
      value = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(value).not_nil!).should eq("??")

      # Right side should be nil
      right = arena[CrystalGPT5::Compiler::Frontend.node_right(value).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Nil)
    end
  end
end
