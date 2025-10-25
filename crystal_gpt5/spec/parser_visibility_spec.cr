require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 37: Visibility modifiers (PRODUCTION-READY)" do
    it "parses private method" do
      source = <<-CRYSTAL
      class MyClass
        private def secret_method
          puts "secret"
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(1)

      method_node = arena[class_body[0]]
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method_node.def_name.not_nil!).should eq("secret_method")
      method_node.def_visibility.should eq(CrystalGPT5::Compiler::Frontend::Visibility::Private)
    end

    it "parses protected method" do
      source = <<-CRYSTAL
      class MyClass
        protected def helper_method
          puts "helper"
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

      String.new(method_node.def_name.not_nil!).should eq("helper_method")
      method_node.def_visibility.should eq(CrystalGPT5::Compiler::Frontend::Visibility::Protected)
    end

    it "parses public method (default)" do
      source = <<-CRYSTAL
      class MyClass
        def public_method
          puts "public"
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

      String.new(method_node.def_name.not_nil!).should eq("public_method")
      method_node.def_visibility.should be_nil  # nil = public (default)
    end

    it "parses mixed visibility methods" do
      source = <<-CRYSTAL
      class MyClass
        def public_method
        end

        private def private_method
        end

        protected def protected_method
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

      # Public method
      public_method = arena[class_body[0]]
      public_method.def_visibility.should be_nil

      # Private method
      private_method = arena[class_body[1]]
      private_method.def_visibility.should eq(CrystalGPT5::Compiler::Frontend::Visibility::Private)

      # Protected method
      protected_method = arena[class_body[2]]
      protected_method.def_visibility.should eq(CrystalGPT5::Compiler::Frontend::Visibility::Protected)
    end

    it "parses private method with parameters" do
      source = <<-CRYSTAL
      class MyClass
        private def calculate(x : Int32, y : Int32) : Int32
          x + y
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

      method_node.def_visibility.should eq(CrystalGPT5::Compiler::Frontend::Visibility::Private)
      params = method_node.def_params.not_nil!
      params.size.should eq(2)
    end

    it "parses private method in module" do
      source = <<-CRYSTAL
      module MyModule
        private def helper
          puts "private helper"
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      module_node = arena[program.roots.first]

      module_body = module_node.module_body.not_nil!
      method_node = arena[module_body[0]]

      method_node.def_visibility.should eq(CrystalGPT5::Compiler::Frontend::Visibility::Private)
    end

    it "parses nested class with visibility" do
      source = <<-CRYSTAL
      class Outer
        class Inner
          private def secret
          end
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      outer_class = arena[program.roots.first]

      outer_body = outer_class.class_body.not_nil!
      inner_class = arena[outer_body[0]]

      inner_body = inner_class.class_body.not_nil!
      method_node = arena[inner_body[0]]

      method_node.def_visibility.should eq(CrystalGPT5::Compiler::Frontend::Visibility::Private)
    end

    it "distinguishes visibility from method body" do
      source = <<-CRYSTAL
      class MyClass
        private def secret_method
          puts "I have a body"
        end

        def public_method
          puts "I also have a body"
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!

      # Private method still has body
      private_method = arena[class_body[0]]
      private_method.def_visibility.should eq(CrystalGPT5::Compiler::Frontend::Visibility::Private)
      private_method.def_body.should_not be_nil
      private_method.def_body.not_nil!.size.should be > 0

      # Public method has body
      public_method = arena[class_body[1]]
      public_method.def_visibility.should be_nil
      public_method.def_body.should_not be_nil
    end

    it "parses private method at top level" do
      source = <<-CRYSTAL
      private def top_level_private
        puts "private at top level"
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      method_node = arena[program.roots.first]

      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      method_node.def_visibility.should eq(CrystalGPT5::Compiler::Frontend::Visibility::Private)
    end
  end
end
