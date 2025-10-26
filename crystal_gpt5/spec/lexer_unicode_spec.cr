require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 58: Unicode escapes (PRODUCTION-READY)" do
    # String literal tests

    it "parses \\uXXXX ASCII in string" do
      source = "s = \"\\u0041\""  # 'A'

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      string_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)
      String.new(string_node.literal.not_nil!).should eq("A")
    end

    it "parses \\uXXXX BMP character in string" do
      source = "s = \"\\u4E00\""  # Chinese character '一'

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("一")
    end

    it "parses \\u{X} variable length in string" do
      source = "s = \"\\u{41}\""  # 'A' with variable length

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("A")
    end

    it "parses \\u{XXXX} emoji in string" do
      source = "s = \"\\u{1F600}\""  # Grinning face emoji 😀

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("😀")
    end

    it "parses multiple Unicode escapes in string" do
      source = "s = \"\\u0041\\u0042\\u0043\""  # "ABC"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("ABC")
    end

    it "parses mixed Unicode and regular text in string" do
      source = "s = \"Hello \\u{1F44B} World\""  # "Hello 👋 World"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("Hello 👋 World")
    end

    it "parses mixed Unicode and escape sequences in string" do
      source = "s = \"\\u0041\\nB\""  # "A\nB"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("A\nB")
    end

    # Character literal tests

    it "parses \\uXXXX ASCII in character" do
      source = "c = '\\u0041'"  # 'A'

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char_node = arena[assign.assign_value.not_nil!]
      char_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Char)
      String.new(char_node.literal.not_nil!).should eq("A")
    end

    it "parses \\uXXXX BMP character in character literal" do
      source = "c = '\\u4E00'"  # Chinese character '一'

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char_node = arena[assign.assign_value.not_nil!]
      String.new(char_node.literal.not_nil!).should eq("一")
    end

    it "parses \\u{X} variable length in character" do
      source = "c = '\\u{42}'"  # 'B' with variable length

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char_node = arena[assign.assign_value.not_nil!]
      String.new(char_node.literal.not_nil!).should eq("B")
    end

    it "parses \\u{XXXX} emoji in character" do
      source = "c = '\\u{1F602}'"  # Face with tears of joy emoji 😂

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      char_node = arena[assign.assign_value.not_nil!]
      String.new(char_node.literal.not_nil!).should eq("😂")
    end

    # UTF-8 encoding tests

    it "parses 2-byte UTF-8 sequence" do
      source = "s = \"\\u00A9\""  # Copyright symbol ©

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("©")
    end

    it "parses 3-byte UTF-8 sequence" do
      source = "s = \"\\u2603\""  # Snowman ☃

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("☃")
    end

    it "parses 4-byte UTF-8 sequence" do
      source = "s = \"\\u{1F44D}\""  # Thumbs up 👍

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      string_node = arena[assign.assign_value.not_nil!]
      String.new(string_node.literal.not_nil!).should eq("👍")
    end

    # Integration tests

    it "parses Unicode in array" do
      source = "[\"\\u0041\", \"\\u{1F600}\"]"  # ["A", "😀"]

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
      String.new(str2.literal.not_nil!).should eq("😀")
    end

    it "parses Unicode in method call" do
      source = "puts(\"\\u{1F389}\")"  # puts("🎉")

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      args = call.args.not_nil!
      args.size.should eq(1)

      string_node = arena[args[0]]
      String.new(string_node.literal.not_nil!).should eq("🎉")
    end

    it "parses multiple statements with Unicode" do
      source = <<-CRYSTAL
      a = "\\u0048ello"
      b = '\\u{1F44B}'
      c = "\\u4E00\\u4E8C\\u4E09"
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First: "Hello"
      assign1 = arena[program.roots[0]]
      str1 = arena[assign1.assign_value.not_nil!]
      String.new(str1.literal.not_nil!).should eq("Hello")

      # Second: '👋'
      assign2 = arena[program.roots[1]]
      char2 = arena[assign2.assign_value.not_nil!]
      String.new(char2.literal.not_nil!).should eq("👋")

      # Third: "一二三"
      assign3 = arena[program.roots[2]]
      str3 = arena[assign3.assign_value.not_nil!]
      String.new(str3.literal.not_nil!).should eq("一二三")
    end
  end
end
