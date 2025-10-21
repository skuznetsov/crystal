require "spec"
require "./ast_fixtures"

require "../../src/compiler/frontend/ast"

# Demonstration of AST fixtures usage
describe "AstFixtures" do
  it "creates def nodes with parameters" do
    arena = CrystalGPT5::Compiler::Frontend::AstArena.new

    # Create: def greet(name)
    #           name
    #         end
    name_id = AstFixtures.make_identifier(arena, "name")
    def_id = AstFixtures.make_def(arena, "greet", params: ["name"], body: [name_id])

    node = arena[def_id]
    node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
    String.new(node.def_name.not_nil!).should eq("greet")
    node.def_params.should eq(["name"])
    node.def_body.not_nil!.size.should eq(1)
  end

  it "creates class nodes with methods" do
    arena = CrystalGPT5::Compiler::Frontend::AstArena.new

    # Create: class Person
    #           def greet
    #           end
    #         end
    greet_id = AstFixtures.make_def(arena, "greet")
    class_id = AstFixtures.make_class(arena, "Person", body: [greet_id])

    node = arena[class_id]
    node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)
    String.new(node.class_name.not_nil!).should eq("Person")
    node.class_body.not_nil!.size.should eq(1)
  end

  it "creates method calls" do
    arena = CrystalGPT5::Compiler::Frontend::AstArena.new

    # Create: greet("World")
    arg_id = AstFixtures.make_string(arena, "World")
    call_id = AstFixtures.make_call(arena, "greet", args: [arg_id])

    node = arena[call_id]
    node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    node.args.not_nil!.size.should eq(1)
  end

  it "creates nested def in class" do
    arena = CrystalGPT5::Compiler::Frontend::AstArena.new

    # Create: class Greeter
    #           def say_hello
    #             greet("World")
    #           end
    #         end
    arg_id = AstFixtures.make_string(arena, "World")
    call_id = AstFixtures.make_call(arena, "greet", args: [arg_id])
    method_id = AstFixtures.make_def(arena, "say_hello", body: [call_id])
    class_id = AstFixtures.make_class(arena, "Greeter", body: [method_id])

    class_node = arena[class_id]
    class_node.class_body.not_nil!.size.should eq(1)

    method_node = arena[class_node.class_body.not_nil![0]]
    method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
    method_node.def_body.not_nil!.size.should eq(1)
  end
end
