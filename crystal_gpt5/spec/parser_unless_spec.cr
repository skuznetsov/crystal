require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 24: Unless" do
    it "parses basic unless without else" do
      source = <<-CRYSTAL
        unless false
          x = 10
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unless_node = arena[program.roots.first]
      unless_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unless)

      # Check condition
      condition = arena[unless_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Bool)
      condition.literal_string.should eq("false")

      # Check then body
      then_body = unless_node.if_then.not_nil!
      then_body.size.should eq(1)

      assign = arena[then_body[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses unless with else" do
      source = <<-CRYSTAL
        unless condition
          x = 10
        else
          x = 20
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unless_node = arena[program.roots.first]
      unless_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unless)

      # Check condition
      condition = arena[unless_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      condition.literal_string.should eq("condition")

      # Check then body (executed when condition is false)
      then_body = unless_node.if_then.not_nil!
      then_body.size.should eq(1)

      # Check else body (executed when condition is true)
      else_body = unless_node.if_else.not_nil!
      else_body.size.should eq(1)
    end

    it "parses unless with then keyword" do
      source = <<-CRYSTAL
        unless false then
          x = 10
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unless_node = arena[program.roots.first]
      unless_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unless)

      then_body = unless_node.if_then.not_nil!
      then_body.size.should eq(1)
    end

    it "parses unless with multiple statements in then body" do
      source = <<-CRYSTAL
        unless condition
          x = 10
          y = 20
          z = 30
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unless_node = arena[program.roots.first]
      unless_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unless)

      then_body = unless_node.if_then.not_nil!
      then_body.size.should eq(3)
    end

    it "parses unless with complex condition" do
      source = <<-CRYSTAL
        unless x == 10 && y == 20
          process()
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unless_node = arena[program.roots.first]
      unless_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unless)

      # Check condition is binary AND
      condition = arena[unless_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      condition.operator_string.should eq("&&")
    end
  end
end
