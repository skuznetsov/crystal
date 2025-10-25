require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 27: Modifier while/until" do
    it "parses postfix while modifier" do
      source = <<-CRYSTAL
        process() while has_more
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Root should be a while node
      while_node = arena[program.roots.first]
      while_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::While)

      # Condition should be identifier "has_more"
      condition = arena[while_node.while_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      condition.literal_string.should eq("has_more")

      # Body should contain the call
      body = while_node.while_body.not_nil!
      body.size.should eq(1)

      call = arena[body[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses postfix until modifier" do
      source = <<-CRYSTAL
        wait() until ready
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Root should be an until node
      until_node = arena[program.roots.first]
      until_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Until)

      # Condition should be identifier "ready"
      condition = arena[until_node.while_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      condition.literal_string.should eq("ready")

      # Body should contain the call
      body = until_node.while_body.not_nil!
      body.size.should eq(1)

      call = arena[body[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses postfix while with assignment" do
      source = <<-CRYSTAL
        x = x + 1 while x < 10
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      while_node = arena[program.roots.first]
      while_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::While)

      # Body should be assignment
      body = while_node.while_body.not_nil!
      body.size.should eq(1)

      assign = arena[body[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses postfix until with assignment" do
      source = <<-CRYSTAL
        x = x - 1 until x == 0
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      until_node = arena[program.roots.first]
      until_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Until)

      # Body should be assignment
      body = until_node.while_body.not_nil!
      body.size.should eq(1)

      assign = arena[body[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses postfix while with complex condition" do
      source = <<-CRYSTAL
        process() while x > 0 && y < 100
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      while_node = arena[program.roots.first]
      while_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::While)

      # Condition should be binary AND
      condition = arena[while_node.while_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      condition.operator_string.should eq("&&")
    end

    it "handles statement without modifier loop" do
      source = <<-CRYSTAL
        process()
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should be plain call, not wrapped in while/until
      call = arena[program.roots.first]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end
  end
end
