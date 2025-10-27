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
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Should desugar to: x = x ?? 42
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("??")
    end

    it "parses ??= with instance variable" do
      source = "@cache ??= expensive_computation()"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target should be instance variable
      target = arena[assign.assign_target.not_nil!]
      target.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVar)

      # Value should be binary ??
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("??")
    end

    it "parses ??= with class variable" do
      source = "@@config ??= load_defaults()"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target should be class variable
      target = arena[assign.assign_target.not_nil!]
      target.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ClassVar)
    end

    it "parses ??= with global variable" do
      source = "$logger ??= Logger.new"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target should be global variable
      target = arena[assign.assign_target.not_nil!]
      target.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)
    end

    it "parses ??= with hash/array index" do
      source = "config[\"key\"] ??= \"default\""

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Target should be index
      target = arena[assign.assign_target.not_nil!]
      target.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Index)
    end

    it "parses ??= with complex expression on right" do
      source = "result ??= compute() + transform(data)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value should be binary ??
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("??")

      # Right side of ?? should be addition
      right = arena[value.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(right.operator.not_nil!).should eq("+")
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
      assign1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      assign2 = arena[program.roots[1]]
      assign2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
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
      method_def.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      # Body should contain assignment
      body_exprs = method_def.def_body.not_nil!
      body_exprs.size.should eq(1)

      body = arena[body_exprs[0]]
      body.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
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
      value1 = arena[assign1.assign_value.not_nil!]
      value1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Ternary)

      # Second: f ?? g (nil-coalescing)
      assign2 = arena[program.roots[1]]
      value2 = arena[assign2.assign_value.not_nil!]
      value2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value2.operator.not_nil!).should eq("??")

      # Third: h ??= i (compound assignment)
      assign3 = arena[program.roots[2]]
      value3 = arena[assign3.assign_value.not_nil!]
      value3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value3.operator.not_nil!).should eq("??")
      # Left side of ?? should reference 'h'
      left3 = arena[value3.left.not_nil!]
      left3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
    end

    it "parses ??= with literal nil on right" do
      source = "value ??= nil"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Desugar to: value = value ?? nil
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("??")

      # Right side should be nil
      right = arena[value.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Nil)
    end
  end
end
