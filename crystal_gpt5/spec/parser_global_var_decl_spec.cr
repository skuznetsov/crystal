require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 77: Global variable type declarations ($var : Type)" do
    it "parses simple global variable declaration" do
      source = "$count : Int32"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      decl = arena[program.roots[0]]
      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::GlobalVarDecl)

      String.new(decl.literal.not_nil!).should eq("$count")
      String.new(decl.ivar_decl_type.not_nil!).should eq("Int32")
    end

    it "parses global variable declaration with String type" do
      source = "$name : String"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      decl = arena[program.roots[0]]
      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::GlobalVarDecl)
      String.new(decl.literal.not_nil!).should eq("$name")
      String.new(decl.ivar_decl_type.not_nil!).should eq("String")
    end

    it "parses multiple global variable declarations" do
      source = <<-CRYSTAL
      $count : Int32
      $name : String
      $flag : Bool
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      decl1 = arena[program.roots[0]]
      decl1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::GlobalVarDecl)
      String.new(decl1.literal.not_nil!).should eq("$count")
      String.new(decl1.ivar_decl_type.not_nil!).should eq("Int32")

      decl2 = arena[program.roots[1]]
      String.new(decl2.literal.not_nil!).should eq("$name")
      String.new(decl2.ivar_decl_type.not_nil!).should eq("String")

      decl3 = arena[program.roots[2]]
      String.new(decl3.literal.not_nil!).should eq("$flag")
      String.new(decl3.ivar_decl_type.not_nil!).should eq("Bool")
    end

    it "parses global variable with underscores" do
      source = "$my_global_var : Int32"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      decl = arena[program.roots[0]]

      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::GlobalVarDecl)
      String.new(decl.literal.not_nil!).should eq("$my_global_var")
    end

    it "parses global variable with custom type" do
      source = "$manager : Manager"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      decl = arena[program.roots[0]]

      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::GlobalVarDecl)
      String.new(decl.literal.not_nil!).should eq("$manager")
      String.new(decl.ivar_decl_type.not_nil!).should eq("Manager")
    end

    it "parses global variable alongside other statements" do
      source = <<-CRYSTAL
      $count : Int32
      x = 10
      $name : String
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      decl1 = arena[program.roots[0]]
      decl1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::GlobalVarDecl)

      assign = arena[program.roots[1]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      decl2 = arena[program.roots[2]]
      decl2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::GlobalVarDecl)
    end

    it "parses global variable with suffix" do
      source = "$debug? : Bool"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      arena = program.arena
      decl = arena[program.roots[0]]

      decl.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::GlobalVarDecl)
      String.new(decl.literal.not_nil!).should eq("$debug?")
      String.new(decl.ivar_decl_type.not_nil!).should eq("Bool")
    end
  end
end
