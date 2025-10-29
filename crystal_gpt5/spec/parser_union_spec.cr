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
      CrystalGPT5::Compiler::Frontend.node_kind(union_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)

      union_name = String.new(CrystalGPT5::Compiler::Frontend.node_class_name(union_node).not_nil!)
      union_name.should eq("IntOrFloat")

      union_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should eq(true)

      union_body = CrystalGPT5::Compiler::Frontend.node_class_body(union_node).not_nil!
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
      CrystalGPT5::Compiler::Frontend.node_kind(union_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)

      union_body = CrystalGPT5::Compiler::Frontend.node_class_body(union_node).not_nil!
      union_body.size.should eq(2)

      # First field
      field1 = arena[union_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(field1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVarDecl)

      # Second field
      field2 = arena[union_body[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(field2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVarDecl)
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
      CrystalGPT5::Compiler::Frontend.node_kind(lib_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Lib)

      lib_body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      lib_body.size.should eq(1)

      # Union inside lib
      union_node = arena[lib_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(union_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should eq(true)
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
      CrystalGPT5::Compiler::Frontend.node_kind(union_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should eq(true)

      union_body = CrystalGPT5::Compiler::Frontend.node_class_body(union_node).not_nil!
      union_body.size.should eq(1)

      # get_value method
      method = arena[union_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
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
      CrystalGPT5::Compiler::Frontend.node_kind(union1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union1.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should eq(true)

      # Second union
      union2 = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(union2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union2.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should eq(true)
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
      CrystalGPT5::Compiler::Frontend.node_kind(module_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Module)

      module_body = CrystalGPT5::Compiler::Frontend.node_module_body(module_node).not_nil!
      module_body.size.should eq(1)

      # Nested union
      union_node = arena[module_body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(union_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should eq(true)
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
      CrystalGPT5::Compiler::Frontend.node_kind(union_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should eq(true)
      CrystalGPT5::Compiler::Frontend.node_class_is_abstract(union_node).should eq(true)
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
      CrystalGPT5::Compiler::Frontend.node_kind(class_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)
      class_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_struct.should be_falsey  # nil or false
      class_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should be_falsey  # nil or false

      # Second is struct
      struct_node = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(struct_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)
      struct_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_struct.should eq(true)
      struct_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should be_falsey  # nil or false

      # Third is union
      union_node = arena[program.roots[2]]
      CrystalGPT5::Compiler::Frontend.node_kind(union_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Union)
      union_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_struct.should be_falsey  # nil or false
      union_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).class_is_union.should eq(true)
    end
  end
end
