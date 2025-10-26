require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 70: Named tuple literals {name: \"value\"} (PRODUCTION-READY)" do
    it "parses simple named tuple with one entry" do
      source = "{name: \"Alice\"}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      named_tuple = arena[program.roots[0]]
      named_tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)

      entries = named_tuple.named_tuple_entries.not_nil!
      entries.size.should eq(1)
      entries[0].key.should eq("name")
    end

    it "parses named tuple with multiple entries" do
      source = "{name: \"Alice\", age: 30}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      named_tuple = arena[program.roots[0]]
      named_tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)

      entries = named_tuple.named_tuple_entries.not_nil!
      entries.size.should eq(2)
      entries[0].key.should eq("name")
      entries[1].key.should eq("age")
    end

    it "parses named tuple with trailing comma" do
      source = "{name: \"Bob\", age: 25,}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      named_tuple = arena[program.roots[0]]
      named_tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)

      entries = named_tuple.named_tuple_entries.not_nil!
      entries.size.should eq(2)
    end

    it "parses named tuple with expression values" do
      source = "{x: 1 + 1, y: 2 * 2}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      named_tuple = arena[program.roots[0]]
      named_tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)

      entries = named_tuple.named_tuple_entries.not_nil!
      entries.size.should eq(2)

      # Values are binary expressions
      value1 = arena[entries[0].value]
      value1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
    end

    it "parses named tuple with identifier values" do
      source = "{name: x, age: y}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      named_tuple = arena[program.roots[0]]
      named_tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)

      entries = named_tuple.named_tuple_entries.not_nil!
      entries.size.should eq(2)

      # Values are identifiers
      value1 = arena[entries[0].value]
      value1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
    end

    it "parses nested named tuples" do
      source = "{person: {name: \"Alice\", age: 30}}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      outer = arena[program.roots[0]]
      outer.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)

      entries = outer.named_tuple_entries.not_nil!
      entries.size.should eq(1)
      entries[0].key.should eq("person")

      # Inner is also named tuple
      inner = arena[entries[0].value]
      inner.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)
    end

    it "parses named tuple in assignment" do
      source = "x = {name: \"Alice\", age: 30}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)
    end

    it "parses named tuple in method call" do
      source = "foo({name: \"Alice\"})"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call = arena[program.roots[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      args = call.args.not_nil!
      args.size.should eq(1)

      arg = arena[args[0]]
      arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)
    end

    it "parses named tuple in array literal" do
      source = "[{name: \"Alice\"}, {name: \"Bob\"}]"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      array = arena[program.roots[0]]
      array.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::ArrayLiteral)

      array_elements = array.array_elements.not_nil!
      array_elements.size.should eq(2)

      # Both elements are named tuples
      elem1 = arena[array_elements[0]]
      elem1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)

      elem2 = arena[array_elements[1]]
      elem2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)
    end

    it "disambiguates named tuple from hash (colon vs arrow)" do
      source = "{name: \"Alice\"}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)
    end

    it "disambiguates hash from named tuple (arrow)" do
      source = "{\"name\" => \"Alice\"}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::HashLiteral)
    end

    it "disambiguates tuple from named tuple (comma vs colon)" do
      source = "{1, 2}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::TupleLiteral)
    end

    it "parses empty braces as hash not named tuple" do
      source = "{}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      node = arena[program.roots[0]]
      # Empty {} is hash by default (existing behavior)
      node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::HashLiteral)
    end

    it "parses named tuple with many entries" do
      source = "{a: 1, b: 2, c: 3, d: 4, e: 5}"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      named_tuple = arena[program.roots[0]]
      named_tuple.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::NamedTupleLiteral)

      entries = named_tuple.named_tuple_entries.not_nil!
      entries.size.should eq(5)
      entries[0].key.should eq("a")
      entries[4].key.should eq("e")
    end
  end
end
