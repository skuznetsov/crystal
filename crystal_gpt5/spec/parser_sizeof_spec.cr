require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 41: sizeof (size in bytes) (PRODUCTION-READY)" do
    it "parses sizeof with type identifier" do
      source = <<-CRYSTAL
      x = sizeof(Int32)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value side is sizeof
      sizeof_expr = assign_node.assign_value.not_nil!
      sizeof_node = arena[sizeof_expr]
      sizeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)

      # Check arguments
      args = sizeof_node.sizeof_args.not_nil!
      args.size.should eq(1)

      # Argument is identifier Int32
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(arg_node.literal.not_nil!).should eq("Int32")
    end

    it "parses sizeof with variable" do
      source = <<-CRYSTAL
      x = 1
      y = sizeof(x)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # Second statement is assignment with sizeof
      assign_node = arena[program.roots[1]]
      sizeof_expr = assign_node.assign_value.not_nil!
      sizeof_node = arena[sizeof_expr]

      sizeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)

      args = sizeof_node.sizeof_args.not_nil!
      args.size.should eq(1)

      # Argument is identifier x
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(arg_node.literal.not_nil!).should eq("x")
    end

    it "parses sizeof with expression" do
      source = <<-CRYSTAL
      x = sizeof(1 + 2)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      sizeof_expr = assign_node.assign_value.not_nil!
      sizeof_node = arena[sizeof_expr]

      sizeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)

      args = sizeof_node.sizeof_args.not_nil!
      args.size.should eq(1)

      # Argument is binary expression
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end

    it "parses sizeof with array literal" do
      source = <<-CRYSTAL
      x = sizeof([1, 2, 3])
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      sizeof_expr = assign_node.assign_value.not_nil!
      sizeof_node = arena[sizeof_expr]

      sizeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)

      args = sizeof_node.sizeof_args.not_nil!
      args.size.should eq(1)

      # Argument is array literal
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)
    end

    it "parses sizeof in method definition" do
      source = <<-CRYSTAL
      def foo
        x = 1
        sizeof(x)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      method_body = method_node.def_body.not_nil!
      method_body.size.should eq(2)

      # Last statement is sizeof
      sizeof_node = arena[method_body[1]]
      sizeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)
    end

    it "parses sizeof in class" do
      source = <<-CRYSTAL
      class Foo
        def bar
          x = 1
          sizeof(x)
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

      # Last statement is sizeof
      sizeof_node = arena[method_body[1]]
      sizeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)
    end

    it "parses nested sizeof" do
      source = <<-CRYSTAL
      x = sizeof(sizeof(Int32))
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      outer_sizeof_expr = assign_node.assign_value.not_nil!
      outer_sizeof = arena[outer_sizeof_expr]

      outer_sizeof.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)

      # Outer sizeof has one argument
      outer_args = outer_sizeof.sizeof_args.not_nil!
      outer_args.size.should eq(1)

      # That argument is also a sizeof
      inner_sizeof = arena[outer_args[0]]
      inner_sizeof.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)

      # Inner sizeof has one argument (Int32)
      inner_args = inner_sizeof.sizeof_args.not_nil!
      inner_args.size.should eq(1)

      identifier_node = arena[inner_args[0]]
      identifier_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
    end

    it "parses sizeof with method call" do
      source = <<-CRYSTAL
      x = sizeof(foo.bar)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      sizeof_expr = assign_node.assign_value.not_nil!
      sizeof_node = arena[sizeof_expr]

      sizeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)

      args = sizeof_node.sizeof_args.not_nil!
      args.size.should eq(1)

      # Argument is member access (foo.bar)
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
    end

    it "parses sizeof with self" do
      source = <<-CRYSTAL
      class Foo
        def size
          sizeof(self)
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

      # Method body has sizeof
      sizeof_node = arena[method_body[0]]
      sizeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Sizeof)

      args = sizeof_node.sizeof_args.not_nil!
      args.size.should eq(1)

      # Argument is self
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Self)
    end
  end
end
