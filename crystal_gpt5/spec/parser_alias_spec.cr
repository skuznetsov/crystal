require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 34: Alias definition (PRODUCTION-READY)" do
  it "parses simple type alias" do
    source = "alias MyInt = Int32"
    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    arena = program.arena
    alias_node = arena[program.roots.first]

    alias_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Alias)
    alias_node.alias_name.should_not be_nil
    String.new(alias_node.alias_name.not_nil!).should eq("MyInt")
    alias_node.alias_value.should_not be_nil
    String.new(alias_node.alias_value.not_nil!).should eq("Int32")
  end

  it "parses multiple aliases" do
    source = <<-CRYSTAL
    alias MyInt = Int32
    alias MyString = String
    alias MyFloat = Float64
    CRYSTAL

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(3)
    arena = program.arena

    # First alias
    alias1 = arena[program.roots[0]]
    alias1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Alias)
    String.new(alias1.alias_name.not_nil!).should eq("MyInt")
    String.new(alias1.alias_value.not_nil!).should eq("Int32")

    # Second alias
    alias2 = arena[program.roots[1]]
    String.new(alias2.alias_name.not_nil!).should eq("MyString")
    String.new(alias2.alias_value.not_nil!).should eq("String")

    # Third alias
    alias3 = arena[program.roots[2]]
    String.new(alias3.alias_name.not_nil!).should eq("MyFloat")
    String.new(alias3.alias_value.not_nil!).should eq("Float64")
  end

  it "parses alias in class" do
    source = <<-CRYSTAL
    class MyClass
      alias MyType = String
    end
    CRYSTAL

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    arena = program.arena
    class_node = arena[program.roots.first]
    class_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Class)

    class_body = class_node.class_body.not_nil!
    class_body.size.should eq(1)

    alias_node = arena[class_body[0]]
    alias_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Alias)
    String.new(alias_node.alias_name.not_nil!).should eq("MyType")
    String.new(alias_node.alias_value.not_nil!).should eq("String")
  end

  it "parses alias in module" do
    source = <<-CRYSTAL
    module MyModule
      alias MyType = Int32
    end
    CRYSTAL

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    arena = program.arena
    module_node = arena[program.roots.first]
    module_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Module)

    module_body = module_node.module_body.not_nil!
    module_body.size.should eq(1)

    alias_node = arena[module_body[0]]
    alias_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Alias)
    String.new(alias_node.alias_name.not_nil!).should eq("MyType")
    String.new(alias_node.alias_value.not_nil!).should eq("Int32")
  end

  it "parses complex type aliases" do
    source = <<-CRYSTAL
    alias IntArray = Array
    alias StringHash = Hash
    alias MyCallback = Proc
    CRYSTAL

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(3)
    arena = program.arena

    # First alias
    alias1 = arena[program.roots[0]]
    String.new(alias1.alias_name.not_nil!).should eq("IntArray")
    String.new(alias1.alias_value.not_nil!).should eq("Array")

    # Second alias
    alias2 = arena[program.roots[1]]
    String.new(alias2.alias_name.not_nil!).should eq("StringHash")
    String.new(alias2.alias_value.not_nil!).should eq("Hash")

    # Third alias
    alias3 = arena[program.roots[2]]
    String.new(alias3.alias_name.not_nil!).should eq("MyCallback")
    String.new(alias3.alias_value.not_nil!).should eq("Proc")
  end

  it "parses alias with qualified type name" do
    source = "alias MyType = HTTP"

    parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
    program = parser.parse_program

    program.roots.size.should eq(1)
    arena = program.arena
    alias_node = arena[program.roots.first]

    alias_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Alias)
    String.new(alias_node.alias_name.not_nil!).should eq("MyType")
    String.new(alias_node.alias_value.not_nil!).should eq("HTTP")
  end
  end
end
