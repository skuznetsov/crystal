require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 55: Numeric separators (underscores in numbers) (PRODUCTION-READY)" do
    it "parses decimal with thousand separator" do
      source = "x = 1_000"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value is number with separator
      number = arena[assign.assign_value.not_nil!]
      number.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)
      String.new(number.literal.not_nil!).should eq("1_000")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I32)
    end

    it "parses decimal with million separator" do
      source = "x = 1_000_000"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("1_000_000")
    end

    it "parses hex with separators" do
      source = "x = 0xFF_FF"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0xFF_FF")
    end

    it "parses hex with multiple separators" do
      source = "x = 0x1A_2B_3C_4D"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0x1A_2B_3C_4D")
    end

    it "parses binary with separators" do
      source = "x = 0b1111_0000"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0b1111_0000")
    end

    it "parses binary with byte separators" do
      source = "x = 0b1010_1010_0101_0101"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0b1010_1010_0101_0101")
    end

    it "parses octal with separators" do
      source = "x = 0o777_666"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0o777_666")
    end

    it "parses float with separators in integer part" do
      source = "x = 1_234.56"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("1_234.56")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::F64)
    end

    it "parses float with separators in fractional part" do
      source = "x = 3.14_159_265"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("3.14_159_265")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::F64)
    end

    it "parses float with separators in both parts" do
      source = "x = 1_234.567_890"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("1_234.567_890")
    end

    it "parses number with suffix and separators" do
      source = "x = 1_000_000_i64"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("1_000_000_i64")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I64)
    end

    it "parses hex with suffix and separators" do
      source = "x = 0xDEAD_BEEF_i64"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("0xDEAD_BEEF_i64")
      number.number_kind.should eq(CrystalGPT5::Compiler::Frontend::NumberKind::I64)
    end

    it "parses numbers with separators in array" do
      source = "[1_000, 2_000, 3_000]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      array.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      elements = array.array_elements.not_nil!
      elements.size.should eq(3)

      # Check all three have separators
      num1 = arena[elements[0]]
      String.new(num1.literal.not_nil!).should eq("1_000")

      num2 = arena[elements[1]]
      String.new(num2.literal.not_nil!).should eq("2_000")

      num3 = arena[elements[2]]
      String.new(num3.literal.not_nil!).should eq("3_000")
    end

    it "parses number with separators in method call" do
      source = "sleep(1_000)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      number = arena[args[0]]
      String.new(number.literal.not_nil!).should eq("1_000")
    end

    it "parses multiple numbers with different separators" do
      source = <<-CRYSTAL
      a = 1_000
      b = 0xFF_00
      c = 0b1010_0101
      d = 3.14_159
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(4)
      arena = program.arena

      # Check all four have separators
      literals = ["1_000", "0xFF_00", "0b1010_0101", "3.14_159"]
      (0..3).each do |i|
        assign = arena[program.roots[i]]
        number = arena[assign.assign_value.not_nil!]
        String.new(number.literal.not_nil!).should eq(literals[i])
      end
    end

    it "parses number without separator (backward compatibility)" do
      source = "x = 1000"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      number = arena[assign.assign_value.not_nil!]
      String.new(number.literal.not_nil!).should eq("1000")
    end

    it "parses binary expression with separators" do
      source = "x = 1_000 + 2_000"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      binary = arena[assign.assign_value.not_nil!]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      left = arena[binary.left.not_nil!]
      String.new(left.literal.not_nil!).should eq("1_000")

      right = arena[binary.right.not_nil!]
      String.new(right.literal.not_nil!).should eq("2_000")
    end
  end
end
