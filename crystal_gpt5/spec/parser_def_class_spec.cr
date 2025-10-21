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
    def_node.def_params.not_nil!.should eq(["name"])
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
end
