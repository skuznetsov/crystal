require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 36: Abstract modifier (PRODUCTION-READY)" do
    it "parses abstract class" do
      source = <<-CRYSTAL
      abstract class Shape
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)
      String.new(class_node.class_name.not_nil!).should eq("Shape")
      class_node.class_is_abstract.should be_truthy
    end

    it "parses abstract struct" do
      source = <<-CRYSTAL
      abstract struct Value
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      struct_node = arena[program.roots.first]

      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)
      String.new(struct_node.class_name.not_nil!).should eq("Value")
      struct_node.class_is_struct.should be_truthy
      struct_node.class_is_abstract.should be_truthy
    end

    it "parses abstract method" do
      source = <<-CRYSTAL
      abstract class Shape
        abstract def area : Float64
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
      String.new(method_node.def_name.not_nil!).should eq("area")
      method_node.def_is_abstract.should be_truthy
      method_node.def_body.should be_nil
    end

    it "parses multiple abstract methods" do
      source = <<-CRYSTAL
      abstract class Shape
        abstract def area : Float64
        abstract def perimeter : Float64
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(2)

      # First abstract method
      method1 = arena[class_body[0]]
      method1.def_is_abstract.should be_truthy
      String.new(method1.def_name.not_nil!).should eq("area")

      # Second abstract method
      method2 = arena[class_body[1]]
      method2.def_is_abstract.should be_truthy
      String.new(method2.def_name.not_nil!).should eq("perimeter")
    end

    it "parses abstract class with concrete methods" do
      source = <<-CRYSTAL
      abstract class Shape
        abstract def area : Float64

        def describe
          puts "I am a shape"
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

      # Abstract method
      abstract_method = arena[class_body[0]]
      abstract_method.def_is_abstract.should be_truthy
      abstract_method.def_body.should be_nil

      # Concrete method
      concrete_method = arena[class_body[1]]
      concrete_method.def_is_abstract.should be_falsey
      concrete_method.def_body.should_not be_nil
    end

    it "distinguishes abstract from non-abstract class" do
      source = <<-CRYSTAL
      abstract class AbstractShape
      end

      class ConcreteShape
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # Abstract class
      abstract_class = arena[program.roots[0]]
      abstract_class.class_is_abstract.should be_truthy

      # Concrete class
      concrete_class = arena[program.roots[1]]
      concrete_class.class_is_abstract.should be_falsey
    end

    it "parses abstract class with inheritance" do
      source = <<-CRYSTAL
      abstract class Animal < LivingThing
        abstract def speak : String
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_node.class_is_abstract.should be_truthy
      String.new(class_node.class_super_name.not_nil!).should eq("LivingThing")
    end

    it "parses nested abstract classes" do
      source = <<-CRYSTAL
      class Outer
        abstract class Inner
          abstract def process
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      outer_class = arena[program.roots.first]

      outer_body = outer_class.class_body.not_nil!
      outer_body.size.should eq(1)

      inner_class = arena[outer_body[0]]
      inner_class.class_is_abstract.should be_truthy
    end

    it "parses abstract method with parameters" do
      source = <<-CRYSTAL
      abstract class Calculator
        abstract def compute(x : Int32, y : Int32) : Int32
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      class_node = arena[program.roots.first]

      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]

      method_node.def_is_abstract.should be_truthy
      params = method_node.def_params.not_nil!
      params.size.should eq(2)
      params[0].name.should eq("x")
      params[1].name.should eq("y")
    end
  end
end
