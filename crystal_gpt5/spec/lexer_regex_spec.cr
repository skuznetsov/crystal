require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 57: Regex literals (PRODUCTION-READY)" do
    it "parses simple regex /abc/" do
      source = "r = /abc/"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Value is regex literal
      regex = arena[assign.assign_value.not_nil!]
      regex.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Regex)
      String.new(regex.literal.not_nil!).should eq("abc")
    end

    it "parses regex with digits /\\d+/" do
      source = "r = /\\d+/"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      regex.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Regex)
      String.new(regex.literal.not_nil!).should eq("\\d+")
    end

    it "parses regex with word boundary /\\btest\\b/" do
      source = "r = /\\btest\\b/"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      String.new(regex.literal.not_nil!).should eq("\\btest\\b")
    end

    it "parses regex with escaped slash /a\\/b/" do
      source = "r = /a\\/b/"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      String.new(regex.literal.not_nil!).should eq("a\\/b")
    end

    it "parses regex with i flag /test/i" do
      source = "r = /test/i"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      String.new(regex.literal.not_nil!).should eq("test/i")
    end

    it "parses regex with multiple flags /abc/im" do
      source = "r = /abc/im"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      String.new(regex.literal.not_nil!).should eq("abc/im")
    end

    it "parses regex with m and x flags /pattern/mx" do
      source = "r = /pattern/mx"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      String.new(regex.literal.not_nil!).should eq("pattern/mx")
    end

    it "parses regex in array" do
      source = "[/abc/, /def/]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      array.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      elements = array.array_elements.not_nil!
      elements.size.should eq(2)

      regex1 = arena[elements[0]]
      regex1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Regex)
      String.new(regex1.literal.not_nil!).should eq("abc")

      regex2 = arena[elements[1]]
      regex2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Regex)
      String.new(regex2.literal.not_nil!).should eq("def")
    end

    it "parses regex in method call" do
      source = "match(/pattern/)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      regex = arena[args[0]]
      regex.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Regex)
      String.new(regex.literal.not_nil!).should eq("pattern")
    end

    it "parses regex with character classes /[a-z]+/" do
      source = "r = /[a-z]+/"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      String.new(regex.literal.not_nil!).should eq("[a-z]+")
    end

    it "parses regex with groups /(foo|bar)/" do
      source = "r = /(foo|bar)/"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      String.new(regex.literal.not_nil!).should eq("(foo|bar)")
    end

    it "parses multiple regex with different patterns" do
      source = <<-CRYSTAL
      a = /abc/
      b = /\\d+/
      c = /test/i
      d = /[a-z]/m
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(4)
      arena = program.arena

      # Check all four regex literals
      literals = ["abc", "\\d+", "test/i", "[a-z]/m"]
      (0..3).each do |i|
        assign = arena[program.roots[i]]
        regex = arena[assign.assign_value.not_nil!]
        regex.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Regex)
        String.new(regex.literal.not_nil!).should eq(literals[i])
      end
    end

    it "distinguishes division from regex after number" do
      source = "result = 10 / 2"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      binary = arena[assign.assign_value.not_nil!]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("/")
    end

    it "distinguishes division from regex after identifier" do
      source = "result = x / y"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      binary = arena[assign.assign_value.not_nil!]
      binary.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      String.new(binary.operator.not_nil!).should eq("/")
    end

    it "parses regex after comma in array" do
      source = "[1, /test/]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      elements = array.array_elements.not_nil!
      elements.size.should eq(2)

      # First element is number
      num = arena[elements[0]]
      num.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)

      # Second element is regex
      regex = arena[elements[1]]
      regex.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Regex)
    end

    it "parses regex with backslash escapes /\\n\\t/" do
      source = "r = /\\n\\t/"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      # Escapes are preserved for regex engine
      String.new(regex.literal.not_nil!).should eq("\\n\\t")
    end

    it "parses empty regex //" do
      source = "r = //"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      regex = arena[assign.assign_value.not_nil!]
      regex.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Regex)
      String.new(regex.literal.not_nil!).should eq("")
    end
  end
end
