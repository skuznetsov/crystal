require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 38: lib (C bindings) (PRODUCTION-READY)" do
    it "parses empty lib" do
      source = <<-CRYSTAL
      lib LibC
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      lib_node = arena[program.roots.first]

      lib_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Lib)
      String.new(lib_node.lib_name.not_nil!).should eq("LibC")
      body = lib_node.lib_body
      body.should_not be_nil
      body.not_nil!.size.should eq(0)
    end

    it "parses lib with method definition" do
      source = <<-CRYSTAL
      lib LibC
        def strlen(str : String) : Int32
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      lib_node = arena[program.roots.first]

      String.new(lib_node.lib_name.not_nil!).should eq("LibC")

      lib_body = lib_node.lib_body.not_nil!
      lib_body.size.should eq(1)

      method_node = arena[lib_body[0]]
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method_node.def_name.not_nil!).should eq("strlen")
    end

    it "parses lib with multiple method definitions" do
      source = <<-CRYSTAL
      lib LibC
        def strlen(str : String) : Int32
        end

        def strcmp(str1 : String, str2 : String) : Int32
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      lib_node = arena[program.roots.first]

      lib_body = lib_node.lib_body.not_nil!
      lib_body.size.should eq(2)

      # First method
      method1 = arena[lib_body[0]]
      String.new(method1.def_name.not_nil!).should eq("strlen")

      # Second method
      method2 = arena[lib_body[1]]
      String.new(method2.def_name.not_nil!).should eq("strcmp")
    end

    it "parses nested lib" do
      source = <<-CRYSTAL
      class MyClass
        lib LibC
          def strlen(str : String) : Int32
          end
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

      lib_node = arena[class_body[0]]
      lib_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Lib)
      String.new(lib_node.lib_name.not_nil!).should eq("LibC")
    end

    it "parses lib in module" do
      source = <<-CRYSTAL
      module MyModule
        lib LibC
          def strlen(str : String) : Int32
          end
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      module_node = arena[program.roots.first]

      module_body = module_node.module_body.not_nil!
      module_body.size.should eq(1)

      lib_node = arena[module_body[0]]
      lib_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Lib)
      String.new(lib_node.lib_name.not_nil!).should eq("LibC")
    end

    it "parses lib with struct definition" do
      source = <<-CRYSTAL
      lib LibC
        struct TimeSpec
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      lib_node = arena[program.roots.first]

      lib_body = lib_node.lib_body.not_nil!
      lib_body.size.should eq(1)

      struct_node = arena[lib_body[0]]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)
      String.new(struct_node.class_name.not_nil!).should eq("TimeSpec")
    end

    it "parses lib with type alias" do
      source = <<-CRYSTAL
      lib LibC
        alias SizeT = UInt64
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      lib_node = arena[program.roots.first]

      lib_body = lib_node.lib_body.not_nil!
      lib_body.size.should eq(1)

      alias_node = arena[lib_body[0]]
      alias_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Alias)
      String.new(alias_node.alias_name.not_nil!).should eq("SizeT")
      String.new(alias_node.alias_value.not_nil!).should eq("UInt64")
    end

    it "parses multiple libs" do
      source = <<-CRYSTAL
      lib LibC
        def strlen(str : String) : Int32
        end
      end

      lib LibPthread
        def pthread_create : Int32
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First lib
      lib1 = arena[program.roots[0]]
      lib1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Lib)
      String.new(lib1.lib_name.not_nil!).should eq("LibC")

      # Second lib
      lib2 = arena[program.roots[1]]
      lib2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Lib)
      String.new(lib2.lib_name.not_nil!).should eq("LibPthread")
    end

    it "parses lib with mixed definitions" do
      source = <<-CRYSTAL
      lib LibC
        alias SizeT = UInt64

        struct TimeSpec
        end

        def strlen(str : String) : Int32
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      lib_node = arena[program.roots.first]

      lib_body = lib_node.lib_body.not_nil!
      lib_body.size.should eq(3)

      # Alias
      alias_node = arena[lib_body[0]]
      alias_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Alias)

      # Struct
      struct_node = arena[lib_body[1]]
      struct_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Struct)

      # Method
      method_node = arena[lib_body[2]]
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
    end
  end
end
