require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 31: Module/Include/Extend (PRODUCTION-READY)" do
    it "parses empty module" do
      source = <<-CRYSTAL
        module Math
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      module_node = arena[program.roots.first]
      module_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Module)

      module_name = String.new(module_node.module_name.not_nil!)
      module_name.should eq("Math")

      module_body = module_node.module_body.not_nil!
      module_body.size.should eq(0)
    end

    it "parses module with method" do
      source = <<-CRYSTAL
        module Math
          def add(a, b)
            a + b
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      module_node = arena[program.roots.first]
      module_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Module)

      module_body = module_node.module_body.not_nil!
      module_body.size.should eq(1)

      method_node = arena[module_body[0]]
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
    end

    it "parses module with nested class" do
      source = <<-CRYSTAL
        module Collections
          class List
            def initialize
            end
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      module_node = arena[program.roots.first]
      module_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Module)

      module_body = module_node.module_body.not_nil!
      module_body.size.should eq(1)

      class_node = arena[module_body[0]]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)
    end

    it "parses module with nested module" do
      source = <<-CRYSTAL
        module Outer
          module Inner
            def helper
            end
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      module_node = arena[program.roots.first]
      module_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Module)

      module_body = module_node.module_body.not_nil!
      module_body.size.should eq(1)

      inner_module = arena[module_body[0]]
      inner_module.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Module)
    end

    it "parses include in class" do
      source = <<-CRYSTAL
        class Person
          include Comparable
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      class_node = arena[program.roots.first]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(1)

      include_node = arena[class_body[0]]
      include_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Include)

      include_name = String.new(include_node.include_name.not_nil!)
      include_name.should eq("Comparable")
    end

    it "parses extend in class" do
      source = <<-CRYSTAL
        class Person
          extend Enumerable
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      class_node = arena[program.roots.first]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(1)

      extend_node = arena[class_body[0]]
      extend_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Extend)

      extend_name = String.new(extend_node.extend_name.not_nil!)
      extend_name.should eq("Enumerable")
    end

    it "parses multiple includes and extends" do
      source = <<-CRYSTAL
        class Person
          include Comparable
          include Serializable
          extend ClassMethods
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      class_node = arena[program.roots.first]
      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(3)

      # First include
      include1 = arena[class_body[0]]
      include1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Include)
      String.new(include1.include_name.not_nil!).should eq("Comparable")

      # Second include
      include2 = arena[class_body[1]]
      include2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Include)
      String.new(include2.include_name.not_nil!).should eq("Serializable")

      # Extend
      extend_node = arena[class_body[2]]
      extend_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Extend)
      String.new(extend_node.extend_name.not_nil!).should eq("ClassMethods")
    end

    it "parses include in module" do
      source = <<-CRYSTAL
        module MyModule
          include BaseModule

          def helper
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      module_node = arena[program.roots.first]
      module_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Module)

      module_body = module_node.module_body.not_nil!
      module_body.size.should eq(2)

      # Include
      include_node = arena[module_body[0]]
      include_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Include)
      String.new(include_node.include_name.not_nil!).should eq("BaseModule")

      # Method
      method_node = arena[module_body[1]]
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
    end

    it "parses class with methods and includes" do
      source = <<-CRYSTAL
        class Calculator
          include Math

          def initialize
          end

          def add(a, b)
            a + b
          end

          extend Helpers
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      class_node = arena[program.roots.first]
      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(4)

      # Include
      arena[class_body[0]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Include)

      # initialize method
      arena[class_body[1]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      # add method
      arena[class_body[2]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      # Extend
      arena[class_body[3]].kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Extend)
    end
  end
end
