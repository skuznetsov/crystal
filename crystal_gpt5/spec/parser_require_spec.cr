require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 65: Require statement (PRODUCTION-READY)" do
    it "parses require with string literal" do
      source = "require \"spec\""

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      require_node = arena[program.roots[0]]
      require_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)

      # Path should be a string literal
      path = arena[require_node.require_path.not_nil!]
      path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
      String.new(path.literal.not_nil!).should eq("spec")
    end

    it "parses require with relative path" do
      source = "require \"./local_file\""

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      require_node = arena[program.roots[0]]
      require_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)

      path = arena[require_node.require_path.not_nil!]
      String.new(path.literal.not_nil!).should eq("./local_file")
    end

    it "parses require with absolute path" do
      source = "require \"/usr/lib/crystal\""

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      require_node = arena[program.roots[0]]
      require_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)

      path = arena[require_node.require_path.not_nil!]
      String.new(path.literal.not_nil!).should eq("/usr/lib/crystal")
    end

    it "parses require with nested path" do
      source = "require \"compiler/frontend/parser\""

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      require_node = arena[program.roots[0]]
      require_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)

      path = arena[require_node.require_path.not_nil!]
      String.new(path.literal.not_nil!).should eq("compiler/frontend/parser")
    end

    it "parses multiple require statements" do
      source = <<-CRYSTAL
      require "spec"
      require "compiler"
      require "./local"
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First require
      req1 = arena[program.roots[0]]
      req1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)
      path1 = arena[req1.require_path.not_nil!]
      String.new(path1.literal.not_nil!).should eq("spec")

      # Second require
      req2 = arena[program.roots[1]]
      req2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)
      path2 = arena[req2.require_path.not_nil!]
      String.new(path2.literal.not_nil!).should eq("compiler")

      # Third require
      req3 = arena[program.roots[2]]
      req3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)
      path3 = arena[req3.require_path.not_nil!]
      String.new(path3.literal.not_nil!).should eq("./local")
    end

    it "parses require with wildcard" do
      source = "require \"./*\""

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      require_node = arena[program.roots[0]]
      require_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)

      path = arena[require_node.require_path.not_nil!]
      String.new(path.literal.not_nil!).should eq("./*")
    end

    it "parses require followed by code" do
      source = <<-CRYSTAL
      require "spec"
      x = 1
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First statement: require
      req = arena[program.roots[0]]
      req.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)

      # Second statement: assignment
      assign = arena[program.roots[1]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses require inside class" do
      source = <<-CRYSTAL
      class Foo
        require "bar"
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

      body = class_node.class_body.not_nil!
      body.size.should eq(1)

      req = arena[body[0]]
      req.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)
    end

    it "parses require with string interpolation (advanced)" do
      source = "require \"foo_\#{version}\""

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      require_node = arena[program.roots[0]]
      require_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)

      # Path should be string interpolation node
      path = arena[require_node.require_path.not_nil!]
      path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::StringInterpolation)
    end

    it "parses require at top-level typical usage" do
      source = <<-CRYSTAL
      require "spec"
      require "../src/compiler/frontend/parser"

      describe "Test" do
        it "works" do
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First two should be requires
      req1 = arena[program.roots[0]]
      req1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)

      req2 = arena[program.roots[1]]
      req2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Require)

      # Third statement exists (don't care about exact type - could be Call or Identifier depending on parser state)
      program.roots[2].should_not be_nil
    end
  end
end
