require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 35: Constant declaration (PRODUCTION-READY)" do
    it "parses simple integer constant" do
      source = "MAX_SIZE = 100"
      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      constant_node = arena[program.roots.first]

      constant_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Constant)
      constant_node.constant_name.should_not be_nil
      String.new(constant_node.constant_name.not_nil!).should eq("MAX_SIZE")

      value_id = constant_node.constant_value.not_nil!
      value_node = arena[value_id]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
    end

    it "parses string constant" do
      source = "VERSION = \"1.0.0\""
      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      constant_node = arena[program.roots.first]

      constant_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Constant)
      String.new(constant_node.constant_name.not_nil!).should eq("VERSION")

      value_id = constant_node.constant_value.not_nil!
      value_node = arena[value_id]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
    end

    it "parses expression constant" do
      source = "DOUBLE_SIZE = MAX_SIZE * 2"
      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      constant_node = arena[program.roots.first]

      constant_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Constant)
      String.new(constant_node.constant_name.not_nil!).should eq("DOUBLE_SIZE")

      value_id = constant_node.constant_value.not_nil!
      value_node = arena[value_id]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end

    it "parses multiple constants" do
      source = <<-CRYSTAL
      MAX_SIZE = 100
      MIN_SIZE = 10
      DEFAULT_SIZE = 50
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First constant
      const1 = arena[program.roots[0]]
      const1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Constant)
      String.new(const1.constant_name.not_nil!).should eq("MAX_SIZE")

      # Second constant
      const2 = arena[program.roots[1]]
      String.new(const2.constant_name.not_nil!).should eq("MIN_SIZE")

      # Third constant
      const3 = arena[program.roots[2]]
      String.new(const3.constant_name.not_nil!).should eq("DEFAULT_SIZE")
    end

    it "parses constant in class" do
      source = <<-CRYSTAL
      class Config
        MAX_CONNECTIONS = 100
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(1)

      constant_node = arena[class_body[0]]
      constant_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Constant)
      String.new(constant_node.constant_name.not_nil!).should eq("MAX_CONNECTIONS")
    end

    it "parses constant in module" do
      source = <<-CRYSTAL
      module HTTP
        DEFAULT_PORT = 80
        SECURE_PORT = 443
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      module_node = arena[program.roots.first]

      module_body = module_node.module_body.not_nil!
      module_body.size.should eq(2)

      # First constant
      const1 = arena[module_body[0]]
      const1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Constant)
      String.new(const1.constant_name.not_nil!).should eq("DEFAULT_PORT")

      # Second constant
      const2 = arena[module_body[1]]
      String.new(const2.constant_name.not_nil!).should eq("SECURE_PORT")
    end

    it "parses constant with boolean value" do
      source = "DEBUG = true"
      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      constant_node = arena[program.roots.first]

      constant_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Constant)
      String.new(constant_node.constant_name.not_nil!).should eq("DEBUG")

      value_id = constant_node.constant_value.not_nil!
      value_node = arena[value_id]
      value_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Bool)
    end

    it "distinguishes constants from regular assignments" do
      source = <<-CRYSTAL
      MAX_SIZE = 100
      max_size = 50
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First should be constant
      const_node = arena[program.roots[0]]
      const_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Constant)
      String.new(const_node.constant_name.not_nil!).should eq("MAX_SIZE")

      # Second should be regular assignment
      assign_node = arena[program.roots[1]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end
  end
end
