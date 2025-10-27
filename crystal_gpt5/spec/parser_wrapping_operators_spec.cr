require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 89: Wrapping Arithmetic Operators" do
    # ============================================================
    # Binary Wrapping Operators
    # ============================================================

    it "parses wrapping addition (&+)" do
      source = "a &+ b"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("&+")
    end

    it "parses wrapping subtraction (&-)" do
      source = "x &- y"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("&-")
    end

    it "parses wrapping multiplication (&*)" do
      source = "m &* n"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("&*")
    end

    it "parses wrapping exponentiation (&**)" do
      source = "base &** exp"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("&**")
    end

    # ============================================================
    # Precedence Verification
    # ============================================================

    it "respects precedence: &+ same as + (lower than &*)" do
      source = "a &+ b &* c"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should parse as: a &+ (b &* c)
      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("&+")

      # Right side should be &*
      right = arena[binary.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(right.operator.not_nil!).should eq("&*")
    end

    it "respects precedence: &** highest (higher than &*)" do
      source = "a &* b &** c"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should parse as: a &* (b &** c)
      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("&*")

      # Right side should be &**
      right = arena[binary.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(right.operator.not_nil!).should eq("&**")
    end

    # ============================================================
    # Compound Assignment (Desugared)
    # ============================================================

    it "desugars wrapping addition assignment (&+=)" do
      source = "a &+= 5"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should desugar to: a = a &+ 5
      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value should be: a &+ 5
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("&+")
    end

    it "desugars wrapping subtraction assignment (&-=)" do
      source = "x &-= 10"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("&-")
    end

    it "desugars wrapping multiplication assignment (&*=)" do
      source = "m &*= 3"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("&*")
    end

    it "desugars wrapping exponentiation assignment (&**=)" do
      source = "base &**= 2"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("&**")
    end

    # ============================================================
    # Unary Forms
    # ============================================================

    it "parses unary wrapping plus (&+x)" do
      source = "&+value"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unary = arena[program.roots[0]]
      unary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unary)
      String.new(unary.operator.not_nil!).should eq("&+")

      # Operand should be 'value'
      operand = arena[unary.right.not_nil!]
      operand.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
    end

    it "parses unary wrapping minus (&-x)" do
      source = "&-number"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unary = arena[program.roots[0]]
      unary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unary)
      String.new(unary.operator.not_nil!).should eq("&-")

      operand = arena[unary.right.not_nil!]
      operand.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
    end

    # ============================================================
    # Disambiguation Tests (Critical)
    # ============================================================

    it "disambiguates &. (safe navigation) from &+ (wrapping add)" do
      source = "obj&.method"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should parse as safe navigation, NOT &+ followed by .method
      node = arena[program.roots[0]]
      node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::SafeNavigation)
    end

    it "disambiguates && (logical and) from &+ (wrapping add)" do
      source = "a && b"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should parse as logical &&, NOT & followed by &b
      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("&&")
    end

    it "disambiguates &= (bitwise and assign) from &+ (wrapping add)" do
      source = "x &= mask"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should parse as assignment with &= desugared to x = x & mask
      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(value.operator.not_nil!).should eq("&")
    end

    # ============================================================
    # Complex Expression Tests
    # ============================================================

    it "handles mixed wrapping and non-wrapping operators" do
      source = "a + b &* c - d &+ e"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should parse correctly with proper precedence
      root = arena[program.roots[0]]
      root.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      # Complex structure test - just verify it parses without error
    end

    it "handles wrapping operators in method call arguments" do
      source = "foo(a &+ b, x &* y)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Verify arguments contain wrapping operators
      args = call.args.not_nil!
      args.size.should eq(2)

      arg1 = arena[args[0]]
      arg1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(arg1.operator.not_nil!).should eq("&+")

      arg2 = arena[args[1]]
      arg2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(arg2.operator.not_nil!).should eq("&*")
    end

    it "handles wrapping operators in parenthesized expressions" do
      source = "(a &+ b) &* (c &- d)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      binary = arena[program.roots[0]]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("&*")

      # Left should be grouping with &+
      left = arena[binary.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)

      # Right should be grouping with &-
      right = arena[binary.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Grouping)
    end
  end
end
