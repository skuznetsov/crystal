require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 77: Class variable type declarations (@@var : Type)" do
    it "parses simple class variable declaration" do
      source = <<-CRYSTAL
      class Foo
        @@count : Int32
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

      body = class_node.class_body.not_nil!
      body.size.should eq(1)

      decl = arena[body[0]]
      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ClassVarDecl)

      String.new(decl.literal.not_nil!).should eq("@@count")
      String.new(decl.ivar_decl_type.not_nil!).should eq("Int32")
    end

    it "parses class variable declaration with String type" do
      source = <<-CRYSTAL
      class Foo
        @@name : String
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      body = class_node.class_body.not_nil!
      decl = arena[body[0]]

      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ClassVarDecl)
      String.new(decl.literal.not_nil!).should eq("@@name")
      String.new(decl.ivar_decl_type.not_nil!).should eq("String")
    end

    it "parses multiple class variable declarations" do
      source = <<-CRYSTAL
      class Foo
        @@count : Int32
        @@name : String
        @@flag : Bool
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      body = class_node.class_body.not_nil!
      body.size.should eq(3)

      decl1 = arena[body[0]]
      decl1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ClassVarDecl)
      String.new(decl1.literal.not_nil!).should eq("@@count")
      String.new(decl1.ivar_decl_type.not_nil!).should eq("Int32")

      decl2 = arena[body[1]]
      String.new(decl2.literal.not_nil!).should eq("@@name")
      String.new(decl2.ivar_decl_type.not_nil!).should eq("String")

      decl3 = arena[body[2]]
      String.new(decl3.literal.not_nil!).should eq("@@flag")
      String.new(decl3.ivar_decl_type.not_nil!).should eq("Bool")
    end

    it "parses class variable with underscores" do
      source = <<-CRYSTAL
      class Foo
        @@my_class_var : Int32
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      class_node = arena[program.roots[0]]
      body = class_node.class_body.not_nil!
      decl = arena[body[0]]

      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ClassVarDecl)
      String.new(decl.literal.not_nil!).should eq("@@my_class_var")
    end

    it "parses class variable with custom type" do
      source = <<-CRYSTAL
      class Foo
        @@manager : Manager
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      class_node = arena[program.roots[0]]
      body = class_node.class_body.not_nil!
      decl = arena[body[0]]

      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ClassVarDecl)
      String.new(decl.literal.not_nil!).should eq("@@manager")
      String.new(decl.ivar_decl_type.not_nil!).should eq("Manager")
    end

    it "parses class variable alongside methods" do
      source = <<-CRYSTAL
      class Foo
        @@count : Int32

        def increment
          @@count = @@count + 1
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      class_node = arena[program.roots[0]]
      body = class_node.class_body.not_nil!
      body.size.should eq(2)

      decl = arena[body[0]]
      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ClassVarDecl)

      method = arena[body[1]]
      method.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
    end

    it "parses class variable alongside instance variables" do
      source = <<-CRYSTAL
      class Foo
        @instance : Int32
        @@class_var : String
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      class_node = arena[program.roots[0]]
      body = class_node.class_body.not_nil!
      body.size.should eq(2)

      ivar = arena[body[0]]
      ivar.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVarDecl)
      String.new(ivar.literal.not_nil!).should eq("@instance")

      cvar = arena[body[1]]
      cvar.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ClassVarDecl)
      String.new(cvar.literal.not_nil!).should eq("@@class_var")
    end
  end
end
