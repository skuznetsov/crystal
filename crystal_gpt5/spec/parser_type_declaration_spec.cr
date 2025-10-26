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
      type_decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)

      String.new(type_decl.type_decl_name.not_nil!).should eq("x")
      String.new(type_decl.type_decl_type.not_nil!).should eq("Int32")
    end

    it "parses type declaration with String type" do
      source = "name : String"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      type_decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)

      String.new(type_decl.type_decl_name.not_nil!).should eq("name")
      String.new(type_decl.type_decl_type.not_nil!).should eq("String")
    end

    it "parses type declaration with custom type" do
      source = "user : User"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      type_decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)

      String.new(type_decl.type_decl_name.not_nil!).should eq("user")
      String.new(type_decl.type_decl_type.not_nil!).should eq("User")
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
      decl1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)
      String.new(decl1.type_decl_name.not_nil!).should eq("x")
      String.new(decl1.type_decl_type.not_nil!).should eq("Int32")

      # Second declaration
      decl2 = arena[program.roots[1]]
      decl2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)
      String.new(decl2.type_decl_name.not_nil!).should eq("y")
      String.new(decl2.type_decl_type.not_nil!).should eq("String")

      # Third declaration
      decl3 = arena[program.roots[2]]
      decl3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)
      String.new(decl3.type_decl_name.not_nil!).should eq("z")
      String.new(decl3.type_decl_type.not_nil!).should eq("Bool")
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
      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)

      # Second: assignment
      assign = arena[program.roots[1]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
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
      class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

      body = class_node.class_body.not_nil!
      body.size.should eq(1)

      decl = arena[body[0]]
      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)
      String.new(decl.type_decl_name.not_nil!).should eq("x")
      String.new(decl.type_decl_type.not_nil!).should eq("Int32")
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
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      body = method_node.def_body.not_nil!
      body.size.should eq(1)

      decl = arena[body[0]]
      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)
    end

    it "parses type declaration with spaces" do
      source = "x    :    Int32"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      type_decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)
      String.new(type_decl.type_decl_name.not_nil!).should eq("x")
      String.new(type_decl.type_decl_type.not_nil!).should eq("Int32")
    end

    it "parses type declaration with Array type" do
      source = "items : Array"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      type_decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)
      String.new(type_decl.type_decl_name.not_nil!).should eq("items")
      String.new(type_decl.type_decl_type.not_nil!).should eq("Array")
    end

    it "parses type declaration with Hash type" do
      source = "data : Hash"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      type_decl = arena[program.roots[0]]
      type_decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TypeDeclaration)
      String.new(type_decl.type_decl_name.not_nil!).should eq("data")
      String.new(type_decl.type_decl_type.not_nil!).should eq("Hash")
    end
  end
end
