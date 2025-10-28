require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 99: for loop (iteration)" do
    it "parses simple for loop" do
      source = <<-CRYSTAL
      for item in collection
        puts item
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      for_node = arena[program.roots.first]

      for_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::For)
      for_node.for_variable.should_not be_nil
      String.new(for_node.for_variable.not_nil!).should eq("item")

      # Check collection
      collection_id = for_node.for_collection.not_nil!
      collection = arena[collection_id]
      collection.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(collection.literal.not_nil!).should eq("collection")

      # Check body
      body = for_node.for_body.not_nil!
      body.size.should be >= 1
    end

    it "parses for loop with do keyword" do
      source = <<-CRYSTAL
      for x in list do
        puts x
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      for_node = arena[program.roots.first]

      for_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::For)
      String.new(for_node.for_variable.not_nil!).should eq("x")
    end

    it "parses for loop with array literal" do
      source = <<-CRYSTAL
      for n in [1, 2, 3]
        puts n
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      for_node = arena[program.roots.first]

      for_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::For)

      # Collection is array literal
      collection_id = for_node.for_collection.not_nil!
      collection = arena[collection_id]
      collection.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)
    end

    it "parses for loop with range" do
      source = <<-CRYSTAL
      for i in 1..10
        puts i
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      for_node = arena[program.roots.first]

      for_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::For)

      # Collection is range
      collection_id = for_node.for_collection.not_nil!
      collection = arena[collection_id]
      collection.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Range)
    end

    it "parses for loop with multiple statements in body" do
      source = <<-CRYSTAL
      for item in items
        puts item
        total += item
        count += 1
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      for_node = arena[program.roots.first]

      for_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::For)

      # Body has 3 statements
      body = for_node.for_body.not_nil!
      body.size.should be >= 3
    end

    it "parses for loop with method call as collection" do
      source = <<-CRYSTAL
      for value in get_values()
        process value
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      for_node = arena[program.roots.first]

      for_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::For)

      # Collection is method call
      collection_id = for_node.for_collection.not_nil!
      collection = arena[collection_id]
      collection.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses empty for loop" do
      source = <<-CRYSTAL
      for x in collection
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      for_node = arena[program.roots.first]

      for_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::For)

      # Empty body
      body = for_node.for_body.not_nil!
      body.size.should eq(0)
    end

    it "parses nested for loops" do
      source = <<-CRYSTAL
      for i in outer
        for j in inner
          puts i, j
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      outer_for = arena[program.roots.first]

      outer_for.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::For)
      String.new(outer_for.for_variable.not_nil!).should eq("i")

      # Body contains inner for loop
      outer_body = outer_for.for_body.not_nil!
      outer_body.size.should eq(1)

      inner_for = arena[outer_body[0]]
      inner_for.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::For)
      String.new(inner_for.for_variable.not_nil!).should eq("j")
    end

    it "emits error for missing 'in' keyword" do
      source = <<-CRYSTAL
      for item collection
        puts item
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      # Parser should emit error
      parser.diagnostics.size.should be > 0
      diagnostic = parser.diagnostics.first
      diagnostic.message.should contain("unexpected")
    end

    it "emits error for missing variable name" do
      source = <<-CRYSTAL
      for in collection
        puts item
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      # Parser should emit error
      parser.diagnostics.size.should be > 0
      diagnostic = parser.diagnostics.first
      diagnostic.message.should contain("unexpected")
    end
  end
end
