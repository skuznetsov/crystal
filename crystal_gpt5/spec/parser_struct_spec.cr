require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 32: Struct definition (PRODUCTION-READY)" do
    it "parses empty struct" do
      source = <<-CRYSTAL
        struct Point
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      struct_node = arena[program.roots.first]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)

      struct_name = String.new(struct_node.class_name.not_nil!)
      struct_name.should eq("Point")

      struct_node.class_is_struct.should eq(true)

      struct_body = struct_node.class_body.not_nil!
      struct_body.size.should eq(0)
    end

    it "parses struct with instance variables" do
      source = <<-CRYSTAL
        struct Point
          @x : Int32
          @y : Int32
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      struct_node = arena[program.roots.first]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)

      struct_body = struct_node.class_body.not_nil!
      struct_body.size.should eq(2)

      # First instance variable
      ivar1 = arena[struct_body[0]]
      ivar1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVarDecl)

      # Second instance variable
      ivar2 = arena[struct_body[1]]
      ivar2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVarDecl)
    end

    it "parses struct with methods" do
      source = <<-CRYSTAL
        struct Point
          def initialize(@x, @y)
          end

          def distance
            Math.sqrt(@x * @x + @y * @y)
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      struct_node = arena[program.roots.first]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)
      struct_node.class_is_struct.should eq(true)

      struct_body = struct_node.class_body.not_nil!
      struct_body.size.should eq(2)

      # initialize method
      init_method = arena[struct_body[0]]
      init_method.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      # distance method
      distance_method = arena[struct_body[1]]
      distance_method.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
    end

    it "parses struct with getter/setter" do
      source = <<-CRYSTAL
        struct Person
          getter name : String
          setter age : Int32
          property email : String
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      struct_node = arena[program.roots.first]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)

      struct_body = struct_node.class_body.not_nil!
      struct_body.size.should eq(3)

      # Getter
      getter_node = arena[struct_body[0]]
      getter_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Getter)

      # Setter
      setter_node = arena[struct_body[1]]
      setter_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Setter)

      # Property
      property_node = arena[struct_body[2]]
      property_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Property)
    end

    it "parses struct with superclass" do
      source = <<-CRYSTAL
        struct Rectangle < Shape
          def area
            width * height
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      struct_node = arena[program.roots.first]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)
      struct_node.class_is_struct.should eq(true)

      struct_name = String.new(struct_node.class_name.not_nil!)
      struct_name.should eq("Rectangle")

      super_name = String.new(struct_node.class_super_name.not_nil!)
      super_name.should eq("Shape")
    end

    it "parses nested struct in class" do
      source = <<-CRYSTAL
        class Container
          struct InnerStruct
            getter value : Int32
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      class_node = arena[program.roots.first]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

      class_body = class_node.class_body.not_nil!
      class_body.size.should eq(1)

      # Nested struct
      struct_node = arena[class_body[0]]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)
      struct_node.class_is_struct.should eq(true)
    end

    it "parses struct with include and extend" do
      source = <<-CRYSTAL
        struct Advanced
          include Comparable
          extend ClassMethods

          getter value : Int32
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      struct_node = arena[program.roots.first]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)

      struct_body = struct_node.class_body.not_nil!
      struct_body.size.should eq(3)

      # Include
      include_node = arena[struct_body[0]]
      include_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Include)

      # Extend
      extend_node = arena[struct_body[1]]
      extend_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Extend)

      # Getter
      getter_node = arena[struct_body[2]]
      getter_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Getter)
    end

    it "distinguishes between class and struct" do
      source = <<-CRYSTAL
        class MyClass
        end

        struct MyStruct
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First is class
      class_node = arena[program.roots[0]]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)
      class_node.class_is_struct.should be_falsey  # nil or false

      # Second is struct
      struct_node = arena[program.roots[1]]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)
      struct_node.class_is_struct.should eq(true)
    end
  end
end
