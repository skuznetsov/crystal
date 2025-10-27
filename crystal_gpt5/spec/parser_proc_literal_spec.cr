require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 74: Proc literal (->) (PRODUCTION-READY)" do
    it "parses parameterless proc with brace form" do
      source = "-> { 42 }"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      proc_node = arena[program.roots[0]]
      proc_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)

      params = proc_node.block_params
      params.should_not be_nil
      params.not_nil!.size.should eq(0)

      body = proc_node.block_body.not_nil!
      body.size.should eq(1)

      body_expr = arena[body[0]]
      body_expr.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
    end

    it "parses single parameter without type annotation" do
      source = "->(x) { x + 1 }"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      proc_node = arena[program.roots[0]]
      proc_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)

      params = proc_node.block_params.not_nil!
      params.size.should eq(1)
      params[0].name.should eq("x")
      params[0].type_annotation.should be_nil
    end

    it "parses single parameter with type annotation" do
      source = "->(x : Int32) { x + 1 }"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      proc_node = arena[program.roots[0]]
      proc_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)

      params = proc_node.block_params.not_nil!
      params.size.should eq(1)
      params[0].name.should eq("x")

      type_annotation = params[0].type_annotation.not_nil!
      type_annotation.should eq("Int32")
    end

    it "parses two parameters with type annotations" do
      source = "->(x : Int32, y : Int32) { x + y }"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      proc_node = arena[program.roots[0]]
      params = proc_node.block_params.not_nil!
      params.size.should eq(2)

      params[0].name.should eq("x")
      params[0].type_annotation.not_nil!.should eq("Int32")

      params[1].name.should eq("y")
      params[1].type_annotation.not_nil!.should eq("Int32")
    end

    it "parses two parameters without type annotations" do
      source = "->(x, y) { x + y }"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      proc_node = arena[program.roots[0]]
      params = proc_node.block_params.not_nil!
      params.size.should eq(2)

      params[0].name.should eq("x")
      params[0].type_annotation.should be_nil

      params[1].name.should eq("y")
      params[1].type_annotation.should be_nil
    end

    it "parses proc with return type annotation" do
      source = "->(x : Int32) : Int32 { x * 2 }"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      proc_node = arena[program.roots[0]]
      proc_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)

      return_type = proc_node.proc_return_type.not_nil!
      String.new(return_type).should eq("Int32")
    end

    it "parses proc with do...end form" do
      source = <<-CRYSTAL
      ->(x : Int32) do
        x + 1
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      proc_node = arena[program.roots[0]]
      proc_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)

      params = proc_node.block_params.not_nil!
      params.size.should eq(1)
      params[0].name.should eq("x")

      body = proc_node.block_body.not_nil!
      body.size.should eq(1)
    end

    it "parses proc with multi-statement body" do
      source = <<-CRYSTAL
      ->(x : Int32) {
        y = x + 1
        y * 2
      }
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      proc_node = arena[program.roots[0]]
      body = proc_node.block_body.not_nil!
      body.size.should eq(2)
    end

    it "parses nested proc literals" do
      source = "-> { ->(x) { x } }"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      outer_proc = arena[program.roots[0]]
      outer_proc.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)

      outer_body = outer_proc.block_body.not_nil!
      outer_body.size.should eq(1)

      inner_proc = arena[outer_body[0]]
      inner_proc.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)
    end

    it "parses proc as method call argument" do
      source = "foo(->(x) { x })"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      proc_arg = arena[args[0]]
      proc_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)
    end

    it "parses proc assigned to variable" do
      source = "p = ->(x) { x }"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)
    end

    it "parses proc with empty body" do
      source = "-> { }"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      proc_node = arena[program.roots[0]]
      proc_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ProcLiteral)

      body = proc_node.block_body.not_nil!
      body.size.should eq(0)
    end
  end
end
