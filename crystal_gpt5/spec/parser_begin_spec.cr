require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 28: Begin/end blocks" do
    it "parses basic begin/end block" do
      source = <<-CRYSTAL
        begin
          x = 10
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      begin_node = arena[program.roots.first]
      begin_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Begin)

      # Check body
      body = begin_node.begin_body.not_nil!
      body.size.should eq(1)

      assign = arena[body[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses begin with empty body" do
      source = <<-CRYSTAL
        begin
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      begin_node = arena[program.roots.first]
      begin_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Begin)

      body = begin_node.begin_body.not_nil!
      body.size.should eq(0)
    end

    it "parses begin with multiple statements" do
      source = <<-CRYSTAL
        begin
          x = 10
          y = 20
          z = 30
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      begin_node = arena[program.roots.first]
      begin_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Begin)

      body = begin_node.begin_body.not_nil!
      body.size.should eq(3)
    end

    it "parses nested begin blocks" do
      source = <<-CRYSTAL
        begin
          x = 10
          begin
            y = 20
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      outer_begin = arena[program.roots.first]
      outer_begin.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Begin)

      outer_body = outer_begin.begin_body.not_nil!
      outer_body.size.should eq(2)

      # First statement is assignment
      assign = arena[outer_body[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Second statement is nested begin block
      inner_begin = arena[outer_body[1]]
      inner_begin.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Begin)

      inner_body = inner_begin.begin_body.not_nil!
      inner_body.size.should eq(1)
    end

    it "parses begin with various statement types" do
      source = <<-CRYSTAL
        begin
          x = 10
          if true
            y = 20
          end
          z = 30
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      begin_node = arena[program.roots.first]
      begin_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Begin)

      body = begin_node.begin_body.not_nil!
      body.size.should eq(3)

      # First is assignment
      arena[body[0]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Second is if
      arena[body[1]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      # Third is assignment
      arena[body[2]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end
  end
end
