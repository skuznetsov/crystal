require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 63: Path expressions (PRODUCTION-READY)" do
    it "parses simple path Foo::Bar" do
      source = "x = Foo::Bar"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value is Path node
      path = arena[assign.assign_value.not_nil!]
      path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Check left side (Foo)
      left = arena[path.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(left.literal.not_nil!).should eq("Foo")

      # Check right side (Bar)
      right = arena[path.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(right.literal.not_nil!).should eq("Bar")
    end

    it "parses nested path A::B::C" do
      source = "x = A::B::C"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value is Path(Path(A, B), C)
      outer_path = arena[assign.assign_value.not_nil!]
      outer_path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Left is Path(A, B)
      inner_path = arena[outer_path.left.not_nil!]
      inner_path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Inner path: A::B
      a_node = arena[inner_path.left.not_nil!]
      String.new(a_node.literal.not_nil!).should eq("A")

      b_node = arena[inner_path.right.not_nil!]
      String.new(b_node.literal.not_nil!).should eq("B")

      # Outer right: C
      c_node = arena[outer_path.right.not_nil!]
      String.new(c_node.literal.not_nil!).should eq("C")
    end

    it "parses absolute path ::TopLevel" do
      source = "x = ::TopLevel"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value is Path with nil left
      path = arena[assign.assign_value.not_nil!]
      path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Left is nil (indicates absolute path)
      path.left.should be_nil

      # Right is TopLevel
      right = arena[path.right.not_nil!]
      String.new(right.literal.not_nil!).should eq("TopLevel")
    end

    it "parses absolute nested path ::A::B" do
      source = "x = ::A::B"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value is Path(Path(nil, A), B)
      outer_path = arena[assign.assign_value.not_nil!]
      outer_path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Left is Path(nil, A)
      inner_path = arena[outer_path.left.not_nil!]
      inner_path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      inner_path.left.should be_nil

      a_node = arena[inner_path.right.not_nil!]
      String.new(a_node.literal.not_nil!).should eq("A")

      # Right is B
      b_node = arena[outer_path.right.not_nil!]
      String.new(b_node.literal.not_nil!).should eq("B")
    end

    it "parses path in method call" do
      source = "call(HTTP::Server)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      # Argument is path
      path = arena[args[0]]
      path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      left = arena[path.left.not_nil!]
      String.new(left.literal.not_nil!).should eq("HTTP")

      right = arena[path.right.not_nil!]
      String.new(right.literal.not_nil!).should eq("Server")
    end

    it "parses path in array literal" do
      source = "[Foo::Bar, Baz::Qux]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      array.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      elements = array.array_elements.not_nil!
      elements.size.should eq(2)

      # First element: Foo::Bar
      path1 = arena[elements[0]]
      path1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Second element: Baz::Qux
      path2 = arena[elements[1]]
      path2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
    end

    it "parses path with multiple segments A::B::C::D" do
      source = "x = A::B::C::D"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Should be Path(Path(Path(A, B), C), D)
      path = arena[assign.assign_value.not_nil!]
      path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Verify it's a path (detailed checking would be recursive)
      path.left.should_not be_nil
      path.right.should_not be_nil

      # Right should be D
      right = arena[path.right.not_nil!]
      String.new(right.literal.not_nil!).should eq("D")
    end

    it "parses path in assignment with spaces" do
      source = "x = Lib::C::Int"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value is nested path Lib::C::Int
      path = arena[assign.assign_value.not_nil!]
      path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # This is Path(Path(Lib, C), Int)
      inner = arena[path.left.not_nil!]
      inner.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Verify it parses correctly
      path.right.should_not be_nil
    end

    it "parses multiple statements with paths" do
      source = <<-CRYSTAL
      a = Foo::Bar
      b = ::TopLevel
      c = A::B::C
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First: Foo::Bar
      assign1 = arena[program.roots[0]]
      path1 = arena[assign1.assign_value.not_nil!]
      path1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      path1.left.should_not be_nil

      # Second: ::TopLevel
      assign2 = arena[program.roots[1]]
      path2 = arena[assign2.assign_value.not_nil!]
      path2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      path2.left.should be_nil  # Absolute path

      # Third: A::B::C
      assign3 = arena[program.roots[2]]
      path3 = arena[assign3.assign_value.not_nil!]
      path3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      path3.left.should_not be_nil
    end

    it "distinguishes path from method call" do
      source = "x = Foo::bar"  # Path, not method call

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value should be Path, not Call
      path = arena[assign.assign_value.not_nil!]
      path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      path.kind.should_not eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses path with spaces around ::" do
      source = "x = Foo :: Bar"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Should still parse as path
      path = arena[assign.assign_value.not_nil!]
      path.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      left = arena[path.left.not_nil!]
      String.new(left.literal.not_nil!).should eq("Foo")

      right = arena[path.right.not_nil!]
      String.new(right.literal.not_nil!).should eq("Bar")
    end
  end
end
