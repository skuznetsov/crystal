require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 40: typeof (type introspection) (PRODUCTION-READY)" do
    it "parses typeof with single argument" do
      source = <<-CRYSTAL
      x = 1
      y = typeof(x)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # Second statement is assignment with typeof
      assign_node = arena[program.roots[1]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value side is typeof
      typeof_expr = assign_node.assign_value.not_nil!
      typeof_node = arena[typeof_expr]
      typeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)

      # Check arguments
      args = typeof_node.typeof_args.not_nil!
      args.size.should eq(1)

      # Argument is identifier x
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(arg_node.literal.not_nil!).should eq("x")
    end

    it "parses typeof with multiple arguments (union type)" do
      source = <<-CRYSTAL
      x = typeof(1, "hello", true)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      typeof_expr = assign_node.assign_value.not_nil!
      typeof_node = arena[typeof_expr]

      typeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)

      # Check we have 3 arguments
      args = typeof_node.typeof_args.not_nil!
      args.size.should eq(3)

      # First arg: number
      arg1 = arena[args[0]]
      arg1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)

      # Second arg: string
      arg2 = arena[args[1]]
      arg2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)

      # Third arg: boolean
      arg3 = arena[args[2]]
      arg3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Bool)
    end

    it "parses typeof with expression argument" do
      source = <<-CRYSTAL
      x = typeof(1 + 2)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      typeof_expr = assign_node.assign_value.not_nil!
      typeof_node = arena[typeof_expr]

      typeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)

      args = typeof_node.typeof_args.not_nil!
      args.size.should eq(1)

      # Argument is binary expression (1 + 2)
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end

    it "parses typeof with method call argument" do
      source = <<-CRYSTAL
      x = typeof(foo.bar)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      typeof_expr = assign_node.assign_value.not_nil!
      typeof_node = arena[typeof_expr]

      typeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)

      args = typeof_node.typeof_args.not_nil!
      args.size.should eq(1)

      # Argument is member access (foo.bar)
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
    end

    it "parses typeof in method definition" do
      source = <<-CRYSTAL
      def foo
        x = 1
        typeof(x)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      method_body = method_node.def_body.not_nil!
      method_body.size.should eq(2)

      # Last statement is typeof
      typeof_node = arena[method_body[1]]
      typeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)
    end

    it "parses nested typeof" do
      source = <<-CRYSTAL
      x = typeof(typeof(1))
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      outer_typeof_expr = assign_node.assign_value.not_nil!
      outer_typeof = arena[outer_typeof_expr]

      outer_typeof.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)

      # Outer typeof has one argument
      outer_args = outer_typeof.typeof_args.not_nil!
      outer_args.size.should eq(1)

      # That argument is also a typeof
      inner_typeof = arena[outer_args[0]]
      inner_typeof.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)

      # Inner typeof has one argument (number 1)
      inner_args = inner_typeof.typeof_args.not_nil!
      inner_args.size.should eq(1)

      number_node = arena[inner_args[0]]
      number_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
    end

    it "parses typeof with array literal" do
      source = <<-CRYSTAL
      x = typeof([1, 2, 3])
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      typeof_expr = assign_node.assign_value.not_nil!
      typeof_node = arena[typeof_expr]

      typeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)

      args = typeof_node.typeof_args.not_nil!
      args.size.should eq(1)

      # Argument is array literal
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)
    end

    it "parses typeof in class" do
      source = <<-CRYSTAL
      class Foo
        def bar
          x = 1
          typeof(x)
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

      # Last statement is typeof
      typeof_node = arena[method_body[1]]
      typeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)
    end

    it "parses typeof with complex union type" do
      source = <<-CRYSTAL
      x = typeof(1, "str", 3.14, true, nil)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      typeof_expr = assign_node.assign_value.not_nil!
      typeof_node = arena[typeof_expr]

      typeof_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Typeof)

      args = typeof_node.typeof_args.not_nil!
      args.size.should eq(5)

      # Verify each argument type
      arena[args[0]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      arena[args[1]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
      arena[args[2]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      arena[args[3]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Bool)
      arena[args[4]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Nil)
    end
  end
end
