require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 66: Type Declaration (PRODUCTION-READY)" do
    it "parses simple type declaration" do
      source = "x : Int32"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(type_decl).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)

      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(type_decl).not_nil!).should eq("x")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(type_decl).not_nil!).should eq("Int32")
    end

    it "parses type declaration with String type" do
      source = "name : String"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(type_decl).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)

      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(type_decl).not_nil!).should eq("name")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(type_decl).not_nil!).should eq("String")
    end

    it "parses type declaration with custom type" do
      source = "user : User"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(type_decl).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)

      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(type_decl).not_nil!).should eq("user")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(type_decl).not_nil!).should eq("User")
    end

    it "parses multiple type declarations" do
      source = <<-CRYSTAL
      x : Int32
      y : String
      z : Bool
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First declaration
      decl1 = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(decl1).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(decl1).not_nil!).should eq("x")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(decl1).not_nil!).should eq("Int32")

      # Second declaration
      decl2 = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(decl2).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(decl2).not_nil!).should eq("y")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(decl2).not_nil!).should eq("String")

      # Third declaration
      decl3 = arena[program.roots[2]]
      CrystalGPT5::Compiler::Frontend.node_kind(decl3).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(decl3).not_nil!).should eq("z")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(decl3).not_nil!).should eq("Bool")
    end

    it "parses type declaration followed by assignment" do
      source = <<-CRYSTAL
      x : Int32
      x = 5
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First: type declaration
      decl = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(decl).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)

      # Second: assignment
      assign = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Assign)
    end

    it "parses type declaration inside class" do
      source = <<-CRYSTAL
      class Foo
        x : Int32
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(class_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Class)

      body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      body.size.should eq(1)

      decl = arena[body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(decl).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(decl).not_nil!).should eq("x")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(decl).not_nil!).should eq("Int32")
    end

    it "parses type declaration inside method" do
      source = <<-CRYSTAL
      def foo
        x : Int32
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method_node).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Def)

      body = CrystalGPT5::Compiler::Frontend.node_def_body(method_node).not_nil!
      body.size.should eq(1)

      decl = arena[body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(decl).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)
    end

    it "parses type declaration with spaces" do
      source = "x    :    Int32"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(type_decl).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(type_decl).not_nil!).should eq("x")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(type_decl).not_nil!).should eq("Int32")
    end

    it "parses type declaration with Array type" do
      source = "items : Array"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(type_decl).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(type_decl).not_nil!).should eq("items")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(type_decl).not_nil!).should eq("Array")
    end

    it "parses type declaration with Hash type" do
      source = "data : Hash"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(type_decl).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::TypeDeclaration)
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_name(type_decl).not_nil!).should eq("data")
      String.new(CrystalGPT5::Compiler::Frontend.node_type_decl_type(type_decl).not_nil!).should eq("Hash")
    end
  end
end
