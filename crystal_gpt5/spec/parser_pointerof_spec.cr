require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 42: pointerof (pointer to variable/expression) (PRODUCTION-READY)" do
    it "parses pointerof with type identifier" do
      source = <<-CRYSTAL
      x = pointerof(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value side is pointerof
      pointerof_expr = assign_node.assign_value.not_nil!
      pointerof_node = arena[pointerof_expr]
      pointerof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)

      # Check arguments
      args = pointerof_node.pointerof_args.not_nil!
      args.size.should eq(1)

      # Argument is identifier Int32
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(arg_node.literal.not_nil!).should eq("Int32")
    end

    it "parses pointerof with variable" do
      source = <<-CRYSTAL
      x = 1
      y = pointerof(x)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # Second statement is assignment with pointerof
      assign_node = arena[program.roots[1]]
      pointerof_expr = assign_node.assign_value.not_nil!
      pointerof_node = arena[pointerof_expr]

      pointerof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)

      args = pointerof_node.pointerof_args.not_nil!
      args.size.should eq(1)

      # Argument is identifier x
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(arg_node.literal.not_nil!).should eq("x")
    end

    it "parses pointerof with expression" do
      source = <<-CRYSTAL
      x = pointerof(1 + 2)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      pointerof_expr = assign_node.assign_value.not_nil!
      pointerof_node = arena[pointerof_expr]

      pointerof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)

      args = pointerof_node.pointerof_args.not_nil!
      args.size.should eq(1)

      # Argument is binary expression
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end

    it "parses pointerof with array literal" do
      source = <<-CRYSTAL
      x = pointerof([1, 2, 3])
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      pointerof_expr = assign_node.assign_value.not_nil!
      pointerof_node = arena[pointerof_expr]

      pointerof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)

      args = pointerof_node.pointerof_args.not_nil!
      args.size.should eq(1)

      # Argument is array literal
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)
    end

    it "parses pointerof in method definition" do
      source = <<-CRYSTAL
      def foo
        x = 1
        pointerof(x)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      method_body = method_node.def_body.not_nil!
      method_body.size.should eq(2)

      # Last statement is pointerof
      pointerof_node = arena[method_body[1]]
      pointerof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)
    end

    it "parses pointerof in class" do
      source = <<-CRYSTAL
      class Foo
        def bar
          x = 1
          pointerof(x)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]
      method_body = method_node.def_body.not_nil!

      # Last statement is pointerof
      pointerof_node = arena[method_body[1]]
      pointerof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)
    end

    it "parses nested pointerof" do
      source = <<-CRYSTAL
      x = pointerof(pointerof(Int32))
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      outer_pointerof_expr = assign_node.assign_value.not_nil!
      outer_pointerof = arena[outer_pointerof_expr]

      outer_pointerof.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)

      # Outer pointerof has one argument
      outer_args = outer_pointerof.pointerof_args.not_nil!
      outer_args.size.should eq(1)

      # That argument is also a pointerof
      inner_pointerof = arena[outer_args[0]]
      inner_pointerof.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)

      # Inner pointerof has one argument (Int32)
      inner_args = inner_pointerof.pointerof_args.not_nil!
      inner_args.size.should eq(1)

      identifier_node = arena[inner_args[0]]
      identifier_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
    end

    it "parses pointerof with method call" do
      source = <<-CRYSTAL
      x = pointerof(foo.bar)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      pointerof_expr = assign_node.assign_value.not_nil!
      pointerof_node = arena[pointerof_expr]

      pointerof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)

      args = pointerof_node.pointerof_args.not_nil!
      args.size.should eq(1)

      # Argument is member access (foo.bar)
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
    end

    it "parses pointerof with self" do
      source = <<-CRYSTAL
      class Foo
        def address
          pointerof(self)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]
      method_body = method_node.def_body.not_nil!

      # Method body has pointerof
      pointerof_node = arena[method_body[0]]
      pointerof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Pointerof)

      args = pointerof_node.pointerof_args.not_nil!
      args.size.should eq(1)

      # Argument is self
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Self)
    end
  end
end
