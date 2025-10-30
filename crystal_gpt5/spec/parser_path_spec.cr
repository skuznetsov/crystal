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
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value is Path node
      path = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Check left side (Foo)
      left = arena[path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(left).not_nil!).should eq("Foo")

      # Check right side (Bar)
      right = arena[path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(right).not_nil!).should eq("Bar")
    end

    it "parses nested path A::B::C" do
      source = "x = A::B::C"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value is Path(Path(A, B), C)
      outer_path = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(outer_path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Left is Path(A, B)
      inner_path = arena[outer_path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(inner_path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Inner path: A::B
      a_node = arena[inner_path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(a_node).not_nil!).should eq("A")

      b_node = arena[inner_path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(b_node).not_nil!).should eq("B")

      # Outer right: C
      c_node = arena[outer_path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(c_node).not_nil!).should eq("C")
    end

    it "parses absolute path ::TopLevel" do
      source = "x = ::TopLevel"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value is Path with nil left
      path = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Left is nil (indicates absolute path)
      path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.should be_nil

      # Right is TopLevel
      right = arena[path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(right).not_nil!).should eq("TopLevel")
    end

    it "parses absolute nested path ::A::B" do
      source = "x = ::A::B"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value is Path(Path(nil, A), B)
      outer_path = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(outer_path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Left is Path(nil, A)
      inner_path = arena[outer_path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(inner_path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      inner_path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.should be_nil

      a_node = arena[inner_path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(a_node).not_nil!).should eq("A")

      # Right is B
      b_node = arena[outer_path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(b_node).not_nil!).should eq("B")
    end

    it "parses path in method call" do
      source = "call(HTTP::Server)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = CrystalGPT5::Compiler::Frontend.node_args(call).not_nil!
      args.size.should eq(1)

      # Argument is path
      path = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      left = arena[path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(left).not_nil!).should eq("HTTP")

      right = arena[path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(right).not_nil!).should eq("Server")
    end

    it "parses path in array literal" do
      source = "[Foo::Bar, Baz::Qux]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(array).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      elements = CrystalGPT5::Compiler::Frontend.node_array_elements(array).not_nil!
      elements.size.should eq(2)

      # First element: Foo::Bar
      path1 = arena[elements[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(path1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Second element: Baz::Qux
      path2 = arena[elements[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(path2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
    end

    it "parses path with multiple segments A::B::C::D" do
      source = "x = A::B::C::D"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Should be Path(Path(Path(A, B), C), D)
      path = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Verify it's a path (detailed checking would be recursive)
      path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.should_not be_nil
      path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.should_not be_nil

      # Right should be D
      right = arena[path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(right).not_nil!).should eq("D")
    end

    it "parses path in assignment with spaces" do
      source = "x = Lib::C::Int"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value is nested path Lib::C::Int
      path = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # This is Path(Path(Lib, C), Int)
      inner = arena[path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(inner).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      # Verify it parses correctly
      path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.should_not be_nil
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
      path1 = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign1).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(path1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      path1.as(CrystalGPT5::Compiler::Frontend::PathNode).left.should_not be_nil

      # Second: ::TopLevel
      assign2 = arena[program.roots[1]]
      path2 = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign2).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(path2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      path2.as(CrystalGPT5::Compiler::Frontend::PathNode).left.should be_nil  # Absolute path

      # Third: A::B::C
      assign3 = arena[program.roots[2]]
      path3 = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign3).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(path3).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      path3.as(CrystalGPT5::Compiler::Frontend::PathNode).left.should_not be_nil
    end

    it "distinguishes path from method call" do
      source = "x = Foo::bar"  # Path, not method call

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Value should be Path, not Call
      path = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)
      CrystalGPT5::Compiler::Frontend.node_kind(path).should_not eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses path with spaces around ::" do
      source = "x = Foo :: Bar"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]

      # Should still parse as path
      path = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(path).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Path)

      left = arena[path.as(CrystalGPT5::Compiler::Frontend::PathNode).left.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(left).not_nil!).should eq("Foo")

      right = arena[path.as(CrystalGPT5::Compiler::Frontend::PathNode).right.not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(right).not_nil!).should eq("Bar")
    end
  end
end
