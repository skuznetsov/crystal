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
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Assign)

      # Value is hexadecimal number
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Number)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0xFF")
      CrystalGPT5::Compiler::Frontend.node_number_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I32)
    end

    it "parses hexadecimal with lowercase 0xff" do
      source = "x = 0xff"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Number)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0xff")
    end

    it "parses hexadecimal with uppercase X: 0XFF" do
      source = "x = 0XFF"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0XFF")
    end

    it "parses large hexadecimal 0x1A2B3C4D" do
      source = "x = 0x1A2B3C4D"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0x1A2B3C4D")
    end

    it "parses binary literal 0b1010" do
      source = "x = 0b1010"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Number)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0b1010")
      CrystalGPT5::Compiler::Frontend.node_number_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I32)
    end

    it "parses binary with uppercase B: 0B1111" do
      source = "x = 0B1111"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0B1111")
    end

    it "parses long binary 0b11110000" do
      source = "x = 0b11110000"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0b11110000")
    end

    it "parses octal literal 0o755" do
      source = "x = 0o755"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Number)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0o755")
      CrystalGPT5::Compiler::Frontend.node_number_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I32)
    end

    it "parses octal with uppercase O: 0O644" do
      source = "x = 0O644"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0O644")
    end

    it "parses hex with _i64 suffix" do
      source = "x = 0xFF_i64"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0xFF_i64")
      CrystalGPT5::Compiler::Frontend.node_number_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I64)
    end

    it "parses binary with _i64 suffix" do
      source = "x = 0b1111_i64"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0b1111_i64")
      CrystalGPT5::Compiler::Frontend.node_number_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I64)
    end

    it "parses octal with _i32 suffix" do
      source = "x = 0o777_i32"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0o777_i32")
      CrystalGPT5::Compiler::Frontend.node_number_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I32)
    end

    it "parses hex in array" do
      source = "[0x10, 0x20, 0x30]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(array).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::ArrayLiteral)
      elements = CrystalGPT5::Compiler::Frontend.node_array_elements(array).not_nil!
      elements.size.should eq(3)

      # Check all three are hex numbers
      (0..2).each do |i|
        element = arena[elements[i]]
        CrystalGPT5::Compiler::Frontend.node_kind(element).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Number)
      end
    end

    it "parses binary in method call" do
      source = "puts(0b1010)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Call)

      args = CrystalGPT5::Compiler::Frontend.node_args(call).not_nil!
      args.size.should eq(1)

      number = arena[args[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Number)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq("0b1010")
    end

    it "parses octal in binary expression" do
      source = "x = 0o10 + 0o20"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      binary = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(binary).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)

      left = arena[CrystalGPT5::Compiler::Frontend.node_left(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(left).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Number)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(left).not_nil!).should eq("0o10")

      right = arena[CrystalGPT5::Compiler::Frontend.node_right(binary).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(right).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Number)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(right).not_nil!).should eq("0o20")
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
        CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Assign)

        number = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
        CrystalGPT5::Compiler::Frontend.node_kind(number).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Number)
        String.new(CrystalGPT5::Compiler::Frontend.node_literal(number).not_nil!).should eq(literals[i])
      end
    end

    it "parses mixed bases in same expression" do
      source = "result = 0xFF + 0b1111 + 0o77 + 42"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(assign).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Assign)

      # Value is complex binary expression with multiple additions
      # Just verify it parses without error
      value = arena[CrystalGPT5::Compiler::Frontend.node_assign_value(assign).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(value).should eq(CrystalGPT5::Compiler::Frontend::NodeKind::Binary)
    end
  end
end
