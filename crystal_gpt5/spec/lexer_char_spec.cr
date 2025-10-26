require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 56: Character literals (PRODUCTION-READY)" do
    it "parses simple character 'a'" do
      source = "c = 'a'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value is character literal
      char = arena[assign.assign_value.not_nil!]
      char.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Char)
      String.new(char.literal.not_nil!).should eq("a")
    end

    it "parses character 'b'" do
      source = "c = 'b'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq("b")
    end

    it "parses character with \\n newline escape" do
      source = "c = '\\n'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      char.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Char)
      String.new(char.literal.not_nil!).should eq("\n")
    end

    it "parses character with \\t tab escape" do
      source = "c = '\\t'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq("\t")
    end

    it "parses character with \\r carriage return escape" do
      source = "c = '\\r'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq("\r")
    end

    it "parses character with \\\\ backslash escape" do
      source = "c = '\\\\'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq("\\")
    end

    it "parses character with \\' quote escape" do
      source = "c = '\\''"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq("'")
    end

    it "parses character with \\0 null escape" do
      source = "c = '\\0'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq("\0")
    end

    it "parses uppercase character 'A'" do
      source = "c = 'A'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq("A")
    end

    it "parses digit character '5'" do
      source = "c = '5'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq("5")
    end

    it "parses special character '@'" do
      source = "c = '@'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq("@")
    end

    it "parses space character ' '" do
      source = "c = ' '"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char = arena[assign.assign_value.not_nil!]
      String.new(char.literal.not_nil!).should eq(" ")
    end

    it "parses characters in array" do
      source = "['a', 'b', 'c']"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      array.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      elements = array.array_elements.not_nil!
      elements.size.should eq(3)

      # Check all three are characters
      char1 = arena[elements[0]]
      char1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Char)
      String.new(char1.literal.not_nil!).should eq("a")

      char2 = arena[elements[1]]
      String.new(char2.literal.not_nil!).should eq("b")

      char3 = arena[elements[2]]
      String.new(char3.literal.not_nil!).should eq("c")
    end

    it "parses character in method call" do
      source = "puts('x')"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      char = arena[args[0]]
      char.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Char)
      String.new(char.literal.not_nil!).should eq("x")
    end

    it "parses multiple characters with different escapes" do
      source = <<-CRYSTAL
      a = 'a'
      b = '\\n'
      c = '\\\\'
      d = '\\t'
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(4)
      arena = program.arena

      # Check all four assignments
      literals = ["a", "\n", "\\", "\t"]
      (0..3).each do |i|
        assign = arena[program.roots[i]]
        char = arena[assign.assign_value.not_nil!]
        char.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Char)
        String.new(char.literal.not_nil!).should eq(literals[i])
      end
    end

    it "parses character in binary expression" do
      source = "result = 'a' == 'b'"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      binary = arena[assign.assign_value.not_nil!]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)

      left = arena[binary.left.not_nil!]
      left.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Char)
      String.new(left.literal.not_nil!).should eq("a")

      right = arena[binary.right.not_nil!]
      right.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Char)
      String.new(right.literal.not_nil!).should eq("b")
    end

    it "parses all supported escape sequences" do
      source = <<-CRYSTAL
      a = '\\n'
      b = '\\t'
      c = '\\r'
      d = '\\\\'
      e = '\\''
      f = '\\0'
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(6)
      arena = program.arena

      # Check all six escape sequences
      literals = ["\n", "\t", "\r", "\\", "'", "\0"]
      (0..5).each do |i|
        assign = arena[program.roots[i]]
        char = arena[assign.assign_value.not_nil!]
        String.new(char.literal.not_nil!).should eq(literals[i])
      end
    end
  end
end
