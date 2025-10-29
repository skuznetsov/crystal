require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 25: Until" do
    it "parses basic until loop" do
      source = <<-CRYSTAL
        until false
          x = 10
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      until_node = arena[program.roots.first]
      CrystalGPT5::Compiler::Frontend.node_kind(until_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Until)

      # Check condition
      condition = arena[CrystalGPT5::Compiler::Frontend.node_condition(until_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(condition).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Bool)
      CrystalGPT5::Compiler::Frontend.node_literal_string(condition).should eq("false")

      # Check body
      body = CrystalGPT5::Compiler::Frontend.node_while_body(until_node).not_nil!
      body.size.should eq(1)

      assign = arena[body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses until with empty body" do
      source = <<-CRYSTAL
        until true
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      until_node = arena[program.roots.first]
      CrystalGPT5::Compiler::Frontend.node_kind(until_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Until)

      # Check condition is Bool
      condition = arena[CrystalGPT5::Compiler::Frontend.node_condition(until_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(condition).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Bool)
      CrystalGPT5::Compiler::Frontend.node_literal_string(condition).should eq("true")

      body = CrystalGPT5::Compiler::Frontend.node_while_body(until_node).not_nil!
      body.size.should eq(0)
    end

    it "parses until with multiple statements" do
      source = <<-CRYSTAL
        until x == 10
          x = x + 1
          y = y + 2
          z = z + 3
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      until_node = arena[program.roots.first]
      CrystalGPT5::Compiler::Frontend.node_kind(until_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Until)

      body = CrystalGPT5::Compiler::Frontend.node_while_body(until_node).not_nil!
      body.size.should eq(3)
    end

    it "parses until with complex condition" do
      source = <<-CRYSTAL
        until x > 10 && y < 20
          process()
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      until_node = arena[program.roots.first]
      CrystalGPT5::Compiler::Frontend.node_kind(until_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Until)

      # Check condition is binary AND
      condition = arena[CrystalGPT5::Compiler::Frontend.node_condition(until_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(condition).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(CrystalGPT5::Compiler::Frontend.node_operator(condition).not_nil!).should eq("&&")
    end

    it "parses until with break inside" do
      source = <<-CRYSTAL
        until false
          break
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      until_node = arena[program.roots.first]
      CrystalGPT5::Compiler::Frontend.node_kind(until_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Until)

      body = CrystalGPT5::Compiler::Frontend.node_while_body(until_node).not_nil!
      body.size.should eq(1)

      # Body contains break statement
      break_node = arena[body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(break_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Break)
    end
  end
end
