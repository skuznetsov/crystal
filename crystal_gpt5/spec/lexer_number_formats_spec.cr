require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 53: Hexadecimal, Binary, Octal number literals (PRODUCTION-READY)" do
    it "parses hexadecimal literal 0xFF" do
      source = "x = 0xFF"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value is hexadecimal number
      number = arena[assign.assign_value.not_nil!]
      number.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      String.new(number.literal.not_nil!).should eq("0xFF")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I32)
    end

    it "parses hexadecimal with lowercase 0xff" do
      source = "x = 0xff"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      number.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      String.new(number.literal.not_nil!).should eq("0xff")
    end

    it "parses hexadecimal with uppercase X: 0XFF" do
      source = "x = 0XFF"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0XFF")
    end

    it "parses large hexadecimal 0x1A2B3C4D" do
      source = "x = 0x1A2B3C4D"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0x1A2B3C4D")
    end

    it "parses binary literal 0b1010" do
      source = "x = 0b1010"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      number.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      String.new(number.literal.not_nil!).should eq("0b1010")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I32)
    end

    it "parses binary with uppercase B: 0B1111" do
      source = "x = 0B1111"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0B1111")
    end

    it "parses long binary 0b11110000" do
      source = "x = 0b11110000"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0b11110000")
    end

    it "parses octal literal 0o755" do
      source = "x = 0o755"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      number.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      String.new(number.literal.not_nil!).should eq("0o755")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I32)
    end

    it "parses octal with uppercase O: 0O644" do
      source = "x = 0O644"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0O644")
    end

    it "parses hex with _i64 suffix" do
      source = "x = 0xFF_i64"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0xFF_i64")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I64)
    end

    it "parses binary with _i64 suffix" do
      source = "x = 0b1111_i64"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0b1111_i64")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I64)
    end

    it "parses octal with _i32 suffix" do
      source = "x = 0o777_i32"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0o777_i32")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I32)
    end

    it "parses hex in array" do
      source = "[0x10, 0x20, 0x30]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      array.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)
      elements = array.array_elements.not_nil!
      elements.size.should eq(3)

      # Check all three are hex numbers
      (0..2).each do |i|
        element = arena[elements[i]]
        element.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      end
    end

    it "parses binary in method call" do
      source = "puts(0b1010)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      number = arena[args[0]]
      number.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      String.new(number.literal.not_nil!).should eq("0b1010")
    end

    it "parses octal in binary expression" do
      source = "x = 0o10 + 0o20"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      binary = arena[assign.assign_value.not_nil!]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      left = arena[binary.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      String.new(left.literal.not_nil!).should eq("0o10")

      right = arena[binary.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      String.new(right.literal.not_nil!).should eq("0o20")
    end

    it "distinguishes 0 from 0x, 0b, 0o" do
      source = <<-CRYSTAL
      a = 0
      b = 0x0
      c = 0b0
      d = 0o0
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(4)
      arena = program.arena

      # All should be assignments
      literals = ["0", "0x0", "0b0", "0o0"]
      (0..3).each do |i|
        assign = arena[program.roots[i]]
        assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

        number = arena[assign.assign_value.not_nil!]
        number.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
        String.new(number.literal.not_nil!).should eq(literals[i])
      end
    end

    it "parses mixed bases in same expression" do
      source = "result = 0xFF + 0b1111 + 0o77 + 42"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value is complex binary expression with multiple additions
      # Just verify it parses without error
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end
  end
end
