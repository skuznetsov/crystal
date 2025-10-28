require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 97: Union definition (C bindings)" do
    it "parses empty union" do
      source = <<-CRYSTAL
        union IntOrFloat
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      union_node = arena[program.roots.first]
      union_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)

      union_name = String.new(union_node.class_name.not_nil!)
      union_name.should eq("IntOrFloat")

      union_node.class_is_union.should eq(true)

      union_body = union_node.class_body.not_nil!
      union_body.size.should eq(0)
    end

    it "parses union with fields" do
      source = <<-CRYSTAL
        union Value
          @int_val : Int32
          @float_val : Float64
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      union_node = arena[program.roots.first]
      union_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)

      union_body = union_node.class_body.not_nil!
      union_body.size.should eq(2)

      # First field
      field1 = arena[union_body[0]]
      field1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVarDecl)

      # Second field
      field2 = arena[union_body[1]]
      field2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVarDecl)
    end

    it "parses union inside lib block" do
      source = <<-CRYSTAL
        lib C
          union Data
            @i : Int32
            @f : Float64
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      lib_node = arena[program.roots.first]
      lib_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Lib)

      lib_body = lib_node.lib_body.not_nil!
      lib_body.size.should eq(1)

      # Union inside lib
      union_node = arena[lib_body[0]]
      union_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.class_is_union.should eq(true)
    end

    it "parses union with methods" do
      source = <<-CRYSTAL
        union Result
          def get_value
            42
          end
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      union_node = arena[program.roots.first]
      union_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.class_is_union.should eq(true)

      union_body = union_node.class_body.not_nil!
      union_body.size.should eq(1)

      # get_value method
      method = arena[union_body[0]]
      method.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
    end

    it "parses multiple unions" do
      source = <<-CRYSTAL
        union Value1
          @i : Int32
        end

        union Value2
          @f : Float64
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First union
      union1 = arena[program.roots[0]]
      union1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union1.class_is_union.should eq(true)

      # Second union
      union2 = arena[program.roots[1]]
      union2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union2.class_is_union.should eq(true)
    end

    it "parses nested union in module" do
      source = <<-CRYSTAL
        module Container
          union InnerUnion
            @value : Int32
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

      # Nested union
      union_node = arena[module_body[0]]
      union_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.class_is_union.should eq(true)
    end

    it "parses abstract union" do
      source = <<-CRYSTAL
        abstract union BaseUnion
          @val : Int32
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      union_node = arena[program.roots.first]
      union_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.class_is_union.should eq(true)
      union_node.class_is_abstract.should eq(true)
    end

    it "distinguishes between class, struct and union" do
      source = <<-CRYSTAL
        class MyClass
        end

        struct MyStruct
        end

        union MyUnion
        end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First is class
      class_node = arena[program.roots[0]]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)
      class_node.class_is_struct.should be_falsey  # nil or false
      class_node.class_is_union.should be_falsey  # nil or false

      # Second is struct
      struct_node = arena[program.roots[1]]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)
      struct_node.class_is_struct.should eq(true)
      struct_node.class_is_union.should be_falsey  # nil or false

      # Third is union
      union_node = arena[program.roots[2]]
      union_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.class_is_struct.should be_falsey  # nil or false
      union_node.class_is_union.should eq(true)
    end
  end
end
