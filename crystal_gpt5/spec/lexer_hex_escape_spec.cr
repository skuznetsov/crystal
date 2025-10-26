require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 59: Hex escape sequences (PRODUCTION-READY)" do
    # String literal tests

    it "parses \\xXX ASCII in string" do
      source = "s = \"\\x41\""  # 'A'

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      string_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
      String.new(string_node.literal.not_nil!).should eq("A")
    end

    it "parses \\xXX control character in string" do
      source = "s = \"\\x0A\""  # newline

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("\n")
    end

    it "parses \\xXX null byte in string" do
      source = "s = \"\\x00\""  # null

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("\0")
    end

    it "parses \\xXX high byte in string" do
      source = "s = \"\\xFF\""  # 255

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      bytes = string_node.literal.not_nil!
      bytes.size.should eq(1)
      bytes[0].should eq(0xFF_u8)
    end

    it "parses multiple \\xXX in string" do
      source = "s = \"\\x41\\x42\\x43\""  # "ABC"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("ABC")
    end

    it "parses mixed hex and regular text in string" do
      source = "s = \"Hello\\x20World\""  # "Hello World"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("Hello World")
    end

    it "parses mixed hex and other escapes in string" do
      source = "s = \"\\x41\\nB\""  # "A\nB"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("A\nB")
    end

    it "parses lowercase hex digits in string" do
      source = "s = \"\\x61\""  # 'a'

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("a")
    end

    # Character literal tests

    it "parses \\xXX ASCII in character" do
      source = "c = '\\x41'"  # 'A'

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char_node = arena[assign.assign_value.not_nil!]
      char_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Char)
      String.new(char_node.literal.not_nil!).should eq("A")
    end

    it "parses \\xXX control character in character literal" do
      source = "c = '\\x09'"  # tab

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char_node = arena[assign.assign_value.not_nil!]
      String.new(char_node.literal.not_nil!).should eq("\t")
    end

    it "parses \\xXX null byte in character" do
      source = "c = '\\x00'"  # null

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char_node = arena[assign.assign_value.not_nil!]
      String.new(char_node.literal.not_nil!).should eq("\0")
    end

    it "parses \\xXX high byte in character" do
      source = "c = '\\xFF'"  # 255

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char_node = arena[assign.assign_value.not_nil!]
      bytes = char_node.literal.not_nil!
      bytes.size.should eq(1)
      bytes[0].should eq(0xFF_u8)
    end

    # Integration tests

    it "parses hex escapes in array" do
      source = "[\"\\x41\", \"\\x42\"]"  # ["A", "B"]

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      elements = array.array_elements.not_nil!
      elements.size.should eq(2)

      str1 = arena[elements[0]]
      String.new(str1.literal.not_nil!).should eq("A")

      str2 = arena[elements[1]]
      String.new(str2.literal.not_nil!).should eq("B")
    end

    it "parses hex escapes in method call" do
      source = "puts(\"\\x48ello\")"  # puts("Hello")

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      args = call.args.not_nil!
      args.size.should eq(1)

      string_node = arena[args[0]]
      String.new(string_node.literal.not_nil!).should eq("Hello")
    end

    it "parses multiple statements with hex escapes" do
      source = <<-CRYSTAL
      a = "\\x48ello"
      b = '\\x41'
      c = "\\x31\\x32\\x33"
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First: "Hello"
      assign1 = arena[program.roots[0]]
      str1 = arena[assign1.assign_value.not_nil!]
      String.new(str1.literal.not_nil!).should eq("Hello")

      # Second: 'A'
      assign2 = arena[program.roots[1]]
      char2 = arena[assign2.assign_value.not_nil!]
      String.new(char2.literal.not_nil!).should eq("A")

      # Third: "123"
      assign3 = arena[program.roots[2]]
      str3 = arena[assign3.assign_value.not_nil!]
      String.new(str3.literal.not_nil!).should eq("123")
    end
  end
end
