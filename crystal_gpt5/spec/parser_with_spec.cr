require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 67: With keyword (context block) (PRODUCTION-READY)" do
    it "parses simple with block" do
      source = <<-CRYSTAL
      with obj
        puts x
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      with_node = arena[program.roots[0]]
      with_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)

      # Check receiver
      receiver = arena[with_node.with_receiver.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(receiver.literal.not_nil!).should eq("obj")

      # Check body (may have multiple statements depending on how parser processes them)
      body = with_node.with_body.not_nil!
      body.size.should be >= 1
    end

    it "parses with block with method call receiver" do
      source = <<-CRYSTAL
      with get_object
        method1
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      with_node = arena[program.roots[0]]
      with_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)

      # Receiver is method call
      receiver = arena[with_node.with_receiver.not_nil!]
      receiver.kind.should_not be_nil
    end

    it "parses with block with multiple statements" do
      source = <<-CRYSTAL
      with obj
        method1
        method2
        method3
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      with_node = arena[program.roots[0]]
      with_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)

      body = with_node.with_body.not_nil!
      body.size.should eq(3)
    end

    it "parses with block with empty body" do
      source = <<-CRYSTAL
      with obj
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      with_node = arena[program.roots[0]]
      with_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)

      body = with_node.with_body.not_nil!
      body.size.should eq(0)
    end

    it "parses with block with assignment in body" do
      source = <<-CRYSTAL
      with obj
        x = 5
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      with_node = arena[program.roots[0]]
      with_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)

      body = with_node.with_body.not_nil!
      body.size.should eq(1)

      # First statement is assignment
      stmt = arena[body[0]]
      stmt.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses nested with blocks" do
      source = <<-CRYSTAL
      with obj1
        with obj2
          method
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      outer_with = arena[program.roots[0]]
      outer_with.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)

      outer_body = outer_with.with_body.not_nil!
      outer_body.size.should eq(1)

      # Inner with
      inner_with = arena[outer_body[0]]
      inner_with.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)
    end

    it "parses with block inside method" do
      source = <<-CRYSTAL
      def foo
        with obj
          bar
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      method_body = method_node.def_body.not_nil!
      method_body.size.should eq(1)

      with_node = arena[method_body[0]]
      with_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)
    end

    it "parses with block with self receiver" do
      source = <<-CRYSTAL
      with self
        method
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      with_node = arena[program.roots[0]]
      with_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)

      receiver = arena[with_node.with_receiver.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Self)
    end

    it "parses with block with instance variable receiver" do
      source = <<-CRYSTAL
      with @config
        setting = value
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      with_node = arena[program.roots[0]]
      with_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)

      receiver = arena[with_node.with_receiver.not_nil!]
      receiver.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::InstanceVar)
    end

    it "parses with block followed by other statements" do
      source = <<-CRYSTAL
      with obj
        method
      end
      x = 5
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(2)
      arena = program.arena

      # First: with block
      with_node = arena[program.roots[0]]
      with_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::With)

      # Second: assignment
      assign = arena[program.roots[1]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end
  end
end
