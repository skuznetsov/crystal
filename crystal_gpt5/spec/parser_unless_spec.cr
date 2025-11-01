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
      CrystalGPT5::Compiler::Frontend.node_kind(unless_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Unless)

      # Check condition
      condition = arena[CrystalGPT5::Compiler::Frontend.node_condition(unless_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(condition).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Bool)
      CrystalGPT5::Compiler::Frontend.node_literal_string(condition).should eq("false")

      # Check then body
      then_body = CrystalGPT5::Compiler::Frontend.node_if_then(unless_node).not_nil!
      then_body.size.should eq(1)

      assign = arena[then_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Assign)
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
      CrystalGPT5::Compiler::Frontend.node_kind(unless_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Unless)

      # Check condition
      condition = arena[CrystalGPT5::Compiler::Frontend.node_condition(unless_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(condition).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Identifier)
      CrystalGPT5::Compiler::Frontend.node_literal_string(condition).should eq("condition")

      # Check then body (executed when condition is false)
      then_body = CrystalGPT5::Compiler::Frontend.node_if_then(unless_node).not_nil!
      then_body.size.should eq(1)

      # Check else body (executed when condition is true)
      else_body = CrystalGPT5::Compiler::Frontend.node_if_else(unless_node).not_nil!
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
      CrystalGPT5::Compiler::Frontend.node_kind(unless_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Unless)

      then_body = CrystalGPT5::Compiler::Frontend.node_if_then(unless_node).not_nil!
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
      CrystalGPT5::Compiler::Frontend.node_kind(unless_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Unless)

      then_body = CrystalGPT5::Compiler::Frontend.node_if_then(unless_node).not_nil!
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
      CrystalGPT5::Compiler::Frontend.node_kind(unless_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Unless)

      # Check condition is binary AND
      condition = arena[CrystalGPT5::Compiler::Frontend.node_condition(unless_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(condition).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(condition).not_nil!).should eq("&&")
    end
  end
end
