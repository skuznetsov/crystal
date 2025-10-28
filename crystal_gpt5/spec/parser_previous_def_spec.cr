require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 96: previous_def keyword" do
    it "parses previous_def without parentheses (implicit args)" do
      source = <<-CRYSTAL
      class Foo
        def bar
          previous_def
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]

      method_body = method_node.def_body.not_nil!
      previous_def_node = arena[method_body[0]]

      previous_def_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::PreviousDef)
      previous_def_node.previous_def_args.should be_nil  # nil = implicit args
    end

    it "parses previous_def with empty parentheses (explicit no args)" do
      source = <<-CRYSTAL
      class Foo
        def bar
          previous_def()
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]

      method_body = method_node.def_body.not_nil!
      previous_def_node = arena[method_body[0]]

      previous_def_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::PreviousDef)
      args = previous_def_node.previous_def_args.not_nil!
      args.size.should eq(0)  # Empty array = explicit no args
    end

    it "parses previous_def with single argument" do
      source = <<-CRYSTAL
      class Foo
        def bar(x)
          previous_def(x + 1)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]

      method_body = method_node.def_body.not_nil!
      previous_def_node = arena[method_body[0]]

      previous_def_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::PreviousDef)
      args = previous_def_node.previous_def_args.not_nil!
      args.size.should eq(1)

      # Check argument is a binary expression (x + 1)
      arg_node = arena[args[0]]
      arg_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end

    it "parses previous_def with multiple arguments" do
      source = <<-CRYSTAL
      class Foo
        def bar(x, y)
          previous_def(x, y + 1)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]

      method_body = method_node.def_body.not_nil!
      previous_def_node = arena[method_body[0]]

      previous_def_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::PreviousDef)
      args = previous_def_node.previous_def_args.not_nil!
      args.size.should eq(2)
    end

    it "parses previous_def with postfix if modifier" do
      source = <<-CRYSTAL
      class Foo
        def bar(x)
          previous_def if x > 0
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]

      method_body = method_node.def_body.not_nil!
      if_node = arena[method_body[0]]

      # Should be an If node (postfix if)
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      # Then branch should contain previous_def
      if_then = if_node.if_then.not_nil!
      previous_def_node = arena[if_then[0]]
      previous_def_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::PreviousDef)
    end

    it "parses previous_def in multiple methods" do
      source = <<-CRYSTAL
      class Foo
        def bar
          previous_def
        end

        def baz(x)
          previous_def(x)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(2)

      # First method: previous_def without args
      method1 = arena[class_body[0]]
      body1 = method1.def_body.not_nil!
      previous_def1 = arena[body1[0]]
      previous_def1.previous_def_args.should be_nil

      # Second method: previous_def with args
      method2 = arena[class_body[1]]
      body2 = method2.def_body.not_nil!
      previous_def2 = arena[body2[0]]
      args = previous_def2.previous_def_args.not_nil!
      args.size.should eq(1)
    end

    it "parses previous_def before other statements" do
      source = <<-CRYSTAL
      class Foo
        def bar
          previous_def
          puts "after previous_def"
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]

      method_body = method_node.def_body.not_nil!
      method_body.size.should be >= 2

      # First statement is previous_def
      previous_def_node = arena[method_body[0]]
      previous_def_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::PreviousDef)

      # Verify there are other statements
      method_body.size.should be > 1
    end

    it "parses previous_def with complex expressions as arguments" do
      source = <<-CRYSTAL
      class Foo
        def bar(x, y)
          previous_def(x * 2 + 1, y > 0 ? y : 0)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]

      method_body = method_node.def_body.not_nil!
      previous_def_node = arena[method_body[0]]

      previous_def_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::PreviousDef)
      args = previous_def_node.previous_def_args.not_nil!
      args.size.should eq(2)

      # First arg is binary expression
      arg1 = arena[args[0]]
      arg1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      # Second arg is ternary expression
      arg2 = arena[args[1]]
      arg2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Ternary)
    end

    it "distinguishes previous_def(), previous_def and previous_def(args)" do
      source = <<-CRYSTAL
      class Foo
        def bar
          previous_def
        end

        def baz
          previous_def()
        end

        def qux(x)
          previous_def(x)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(3)

      # Method bar: previous_def (nil = implicit args)
      method_bar = arena[class_body[0]]
      body_bar = method_bar.def_body.not_nil!
      previous_def_bar = arena[body_bar[0]]
      previous_def_bar.previous_def_args.should be_nil

      # Method baz: previous_def() (empty array = explicit no args)
      method_baz = arena[class_body[1]]
      body_baz = method_baz.def_body.not_nil!
      previous_def_baz = arena[body_baz[0]]
      args_baz = previous_def_baz.previous_def_args.not_nil!
      args_baz.size.should eq(0)

      # Method qux: previous_def(x) (array with args)
      method_qux = arena[class_body[2]]
      body_qux = method_qux.def_body.not_nil!
      previous_def_qux = arena[body_qux[0]]
      args_qux = previous_def_qux.previous_def_args.not_nil!
      args_qux.size.should eq(1)
    end
  end
end
