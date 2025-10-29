require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 95A: asm keyword (inline assembly - parser only)" do
    it "parses simple asm with template string" do
      source = <<-CRYSTAL
      asm("nop")
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      asm_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(asm_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Asm)

      # Check template argument
      args = asm_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).asm_args.not_nil!
      args.size.should eq(1)

      template = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(template).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(template).not_nil!).should eq("nop")
    end

    it "parses asm with multiple arguments" do
      source = <<-CRYSTAL
      asm("mov", "output", "input")
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      asm_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(asm_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Asm)

      # Check all three arguments
      args = asm_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).asm_args.not_nil!
      args.size.should eq(3)

      String.new(CrystalGPT5::Compiler::Frontend.node_literal(arena[args[0]]).not_nil!).should eq("mov")
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(arena[args[1]]).not_nil!).should eq("output")
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(arena[args[2]]).not_nil!).should eq("input")
    end

    it "parses asm in method definition" do
      source = <<-CRYSTAL
      def foo
        asm("nop")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      def_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(def_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      # Check body contains asm
      body = CrystalGPT5::Compiler::Frontend.node_def_body(def_node).not_nil!
      body.size.should eq(1)

      asm_node = arena[body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(asm_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Asm)
    end

    it "parses multiple asm statements" do
      source = <<-CRYSTAL
      asm("nop")
      asm("ret")
      asm("mov")
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # All should be Asm nodes
      asm1 = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(asm1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Asm)

      asm2 = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(asm2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Asm)

      asm3 = arena[program.roots[2]]
      CrystalGPT5::Compiler::Frontend.node_kind(asm3).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Asm)

      # Check templates
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(arena[asm1.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).asm_args.not_nil![0]]).not_nil!).should eq("nop")
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(arena[asm2.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).asm_args.not_nil![0]]).not_nil!).should eq("ret")
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(arena[asm3.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).asm_args.not_nil![0]]).not_nil!).should eq("mov")
    end

    it "parses asm with variable arguments" do
      source = <<-CRYSTAL
      x = 10
      asm("template", x, "constraint")
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # Second root is asm
      asm_node = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(asm_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Asm)

      args = asm_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).asm_args.not_nil!
      args.size.should eq(3)

      # First arg: string
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(arena[args[0]]).not_nil!).should eq("template")

      # Second arg: identifier
      arg2 = arena[args[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(arg2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(arg2).not_nil!).should eq("x")

      # Third arg: string
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(arena[args[2]]).not_nil!).should eq("constraint")
    end

    it "parses asm in class method" do
      source = <<-CRYSTAL
      class Foo
        def bar
          asm("nop")
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(class_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

      # Get method from class body
      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      class_body.size.should eq(1)

      method = arena[class_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      # Check method body contains asm
      method_body = CrystalGPT5::Compiler::Frontend.node_def_body(method).not_nil!
      method_body.size.should eq(1)

      asm_node = arena[method_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(asm_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Asm)
    end
  end
end
