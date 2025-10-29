require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 75: Global variables ($var) (PRODUCTION-READY)" do
    it "parses simple global variable" do
      source = "$global_var"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      global_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(global_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)

      literal = CrystalGPT5::Compiler::Frontend.node_literal(global_node).not_nil!
      String.new(literal).should eq("$global_var")
    end

    it "parses global variable with underscores" do
      source = "$my_global_var"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      global_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(global_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)

      literal = CrystalGPT5::Compiler::Frontend.node_literal(global_node).not_nil!
      String.new(literal).should eq("$my_global_var")
    end

    it "parses global variable with question mark suffix" do
      source = "$flag?"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      global_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(global_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)

      literal = CrystalGPT5::Compiler::Frontend.node_literal(global_node).not_nil!
      String.new(literal).should eq("$flag?")
    end

    it "parses global variable with exclamation mark suffix" do
      source = "$important!"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      global_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(global_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)

      literal = CrystalGPT5::Compiler::Frontend.node_literal(global_node).not_nil!
      String.new(literal).should eq("$important!")
    end

    it "parses global variable assignment" do
      source = "$count = 42"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      target = arena[CrystalGPT5::Compiler::Frontend.node_assign_target(assign_node).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(target).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)
    end

    it "parses multiple global variables" do
      source = <<-CRYSTAL
      $first = 1
      $second = 2
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

    it "parses global variable in expression" do
      source = "$count + 1"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      left = arena[CrystalGPT5::Compiler::Frontend.node_left(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)
    end

    it "parses global variable as method argument" do
      source = "foo($global)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(arg).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)
    end

    it "parses global variable inside method body" do
      source = <<-CRYSTAL
      def foo
        $global_var = 42
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      body = CrystalGPT5::Compiler::Frontend.node_def_body(method).not_nil!
      body.size.should eq(1)

      assign = arena[body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses global variable in array literal" do
      source = "[$first, $second, $third]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(array).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      elements = CrystalGPT5::Compiler::Frontend.node_array_elements(array).not_nil!
      elements.size.should eq(3)

      elem1 = arena[elements[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(elem1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)
    end

    it "distinguishes global variable from instance variable" do
      source = "$global + @instance"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      left = arena[CrystalGPT5::Compiler::Frontend.node_left(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)

      right = arena[CrystalGPT5::Compiler::Frontend.node_right(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVar)
    end

    it "parses global variable with numbers in name" do
      source = "$var123"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      global_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(global_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Global)

      literal = CrystalGPT5::Compiler::Frontend.node_literal(global_node).not_nil!
      String.new(literal).should eq("$var123")
    end
  end
end
