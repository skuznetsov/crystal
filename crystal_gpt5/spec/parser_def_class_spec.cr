require "spec"

require "../src/compiler/frontend/parser"

describe CrystalGPT5::Compiler::Frontend::Parser do
  it "parses simple def with params and body" do
    source = <<-CR
      def greet(name)
        name
      end
    CR

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    arena = program.arena
    def_node = arena[program.roots.first]
    def_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
    String.new(def_node.def_name.not_nil!).should eq("greet")
    def_node.def_params.not_nil!.map(&.name).should eq(["name"])
    def_node.def_body.not_nil!.size.should eq(1)
  end

  it "parses simple class with body" do
    source = <<-CR
      class Greeter
        greet(name)
      end
    CR

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    arena = program.arena
    class_node = arena[program.roots.first]
    class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)
    String.new(class_node.class_name.not_nil!).should eq("Greeter")
    class_node.class_body.not_nil!.size.should eq(1)
  end

  # Phase 4A: Parameter type annotations
  it "parses def with single typed parameter" do
    source = <<-CR
      def add_one(x : Int32)
        x
      end
    CR

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    def_node = program.arena[program.roots.first]

    params = def_node.def_params.not_nil!
    params.size.should eq(1)
    params[0].name.should eq("x")
    params[0].type_annotation.should eq("Int32")
  end

  it "parses def with multiple typed parameters" do
    source = <<-CR
      def concat(x : String, y : String)
        x
      end
    CR

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    def_node = program.arena[program.roots.first]

    params = def_node.def_params.not_nil!
    params.size.should eq(2)
    params[0].name.should eq("x")
    params[0].type_annotation.should eq("String")
    params[1].name.should eq("y")
    params[1].type_annotation.should eq("String")
  end

  it "parses def with mixed typed and untyped parameters" do
    source = <<-CR
      def mixed(x, y : Int32, z)
        x
      end
    CR

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    def_node = program.arena[program.roots.first]

    params = def_node.def_params.not_nil!
    params.size.should eq(3)
    params[0].name.should eq("x")
    params[0].type_annotation.should be_nil
    params[1].name.should eq("y")
    params[1].type_annotation.should eq("Int32")
    params[2].name.should eq("z")
    params[2].type_annotation.should be_nil
  end

  it "parses def with no parameters" do
    source = <<-CR
      def get_answer
        42
      end
    CR

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    def_node = program.arena[program.roots.first]

    params = def_node.def_params.not_nil!
    params.size.should eq(0)
  end

  # Phase 4A: Return type annotations
  it "parses def with return type annotation" do
    source = <<-CR
      def get_int : Int32
        42
      end
    CR

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    def_node = program.arena[program.roots.first]

    return_type = def_node.def_return_type
    return_type.should_not be_nil
    String.new(return_type.not_nil!).should eq("Int32")
  end

  it "parses def with params and return type" do
    source = <<-CR
      def add(x : Int32, y : Int32) : Int32
        x
      end
    CR

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    def_node = program.arena[program.roots.first]

    # Check params
    params = def_node.def_params.not_nil!
    params.size.should eq(2)
    params[0].name.should eq("x")
    params[0].type_annotation.should eq("Int32")

    # Check return type
    return_type = def_node.def_return_type
    return_type.should_not be_nil
    String.new(return_type.not_nil!).should eq("Int32")
  end
end
