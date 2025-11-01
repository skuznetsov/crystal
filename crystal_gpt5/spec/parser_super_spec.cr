require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 39: super keyword (PRODUCTION-READY)" do
    it "parses super without parentheses (implicit args)" do
      source = <<-CRYSTAL
      class Child < Parent
        def foo
          super
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      method_node = arena[class_body[0]]

      method_body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      super_node = arena[method_body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(super_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Super)
      CrystalGPT5::Compiler::Frontend.node_super_args(super_node).should be_nil  # nil = implicit args
    end

    it "parses super with empty parentheses (explicit no args)" do
      source = <<-CRYSTAL
      class Child < Parent
        def foo
          super()
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      method_node = arena[class_body[0]]

      method_body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      super_node = arena[method_body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(super_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Super)
      args = CrystalGPT5::Compiler::Frontend.node_super_args(super_node).not_nil!
      args.size.should eq(0)  # Empty array = explicit no args
    end

    it "parses super with single argument" do
      source = <<-CRYSTAL
      class Child < Parent
        def foo(x)
          super(x + 1)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      method_node = arena[class_body[0]]

      method_body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      super_node = arena[method_body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(super_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Super)
      args = CrystalGPT5::Compiler::Frontend.node_super_args(super_node).not_nil!
      args.size.should eq(1)

      # Check argument is a binary expression (x + 1)
      arg_node = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(arg_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
    end

    it "parses super with multiple arguments" do
      source = <<-CRYSTAL
      class Child < Parent
        def foo(x, y)
          super(x, y + 1)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      method_node = arena[class_body[0]]

      method_body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      super_node = arena[method_body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(super_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Super)
      args = CrystalGPT5::Compiler::Frontend.node_super_args(super_node).not_nil!
      args.size.should eq(2)
    end

    it "parses super with postfix if modifier" do
      source = <<-CRYSTAL
      class Child < Parent
        def foo(x)
          super if x > 0
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      method_node = arena[class_body[0]]

      method_body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      if_node = arena[method_body[0]]

      # Should be an If node (postfix if)
      CrystalGPT5::Compiler::Frontend.node_kind(if_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::If)

      # Then branch should contain super
      if_then = CrystalGPT5::Compiler::Frontend.node_if_then(if_node).not_nil!
      super_node = arena[if_then[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(super_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Super)
    end

    it "parses super in multiple methods" do
      source = <<-CRYSTAL
      class Child < Parent
        def foo
          super
        end

        def bar(x)
          super(x)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      class_body.size.should eq(2)

      # First method: super without args
      method1 = arena[class_body[0]]
      body1 = CrystalGPT5::Compiler::Frontend.node_def_body(method1).not_nil!
      super1 = arena[body1[0]]
      CrystalGPT5::Compiler::Frontend.node_super_args(super1).should be_nil

      # Second method: super with args
      method2 = arena[class_body[1]]
      body2 = CrystalGPT5::Compiler::Frontend.node_def_body(method2).not_nil!
      super2 = arena[body2[0]]
      args = CrystalGPT5::Compiler::Frontend.node_super_args(super2).not_nil!
      args.size.should eq(1)
    end

    it "parses super before other statements" do
      source = <<-CRYSTAL
      class Child < Parent
        def foo
          super
          puts "after super"
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      method_node = arena[class_body[0]]

      method_body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      method_body.size.should be >= 2

      # First statement is super
      super_node = arena[method_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(super_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Super)

      # Find the method call (might not be immediately after due to parsing)
      # Just verify super is first and there are other statements
      method_body.size.should be > 1
    end

    it "parses super with complex expressions as arguments" do
      source = <<-CRYSTAL
      class Child < Parent
        def foo(x, y)
          super(x * 2 + 1, y > 0 ? y : 0)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      method_node = arena[class_body[0]]

      method_body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      super_node = arena[method_body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(super_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Super)
      args = CrystalGPT5::Compiler::Frontend.node_super_args(super_node).not_nil!
      args.size.should eq(2)

      # First arg is binary expression
      arg1 = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(arg1).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)

      # Second arg is ternary expression
      arg2 = arena[args[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(arg2).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Ternary)
    end

    it "distinguishes super(), super and super(args)" do
      source = <<-CRYSTAL
      class Child < Parent
        def foo
          super
        end

        def bar
          super()
        end

        def baz(x)
          super(x)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      class_body.size.should eq(3)

      # Method foo: super (nil = implicit args)
      method_foo = arena[class_body[0]]
      body_foo = CrystalGPT5::Compiler::Frontend.node_def_body(method_foo).not_nil!
      super_foo = arena[body_foo[0]]
      CrystalGPT5::Compiler::Frontend.node_super_args(super_foo).should be_nil

      # Method bar: super() (empty array = explicit no args)
      method_bar = arena[class_body[1]]
      body_bar = CrystalGPT5::Compiler::Frontend.node_def_body(method_bar).not_nil!
      super_bar = arena[body_bar[0]]
      args_bar = CrystalGPT5::Compiler::Frontend.node_super_args(super_bar).not_nil!
      args_bar.size.should eq(0)

      # Method baz: super(x) (array with args)
      method_baz = arena[class_body[2]]
      body_baz = CrystalGPT5::Compiler::Frontend.node_def_body(method_baz).not_nil!
      super_baz = arena[body_baz[0]]
      args_baz = CrystalGPT5::Compiler::Frontend.node_super_args(super_baz).not_nil!
      args_baz.size.should eq(1)
    end
  end
end
