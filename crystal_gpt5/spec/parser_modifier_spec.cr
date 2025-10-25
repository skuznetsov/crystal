require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 26: Modifier if/unless" do
    it "parses postfix if modifier with return" do
      source = <<-CRYSTAL
        return 10 if condition
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Root should be an if node
      if_node = arena[program.roots.first]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      # Condition should be identifier "condition"
      condition = arena[if_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)

      # Then body should contain return statement
      then_body = if_node.if_then.not_nil!
      then_body.size.should eq(1)

      return_stmt = arena[then_body[0]]
      return_stmt.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Return)
    end

    it "parses postfix unless modifier with return" do
      source = <<-CRYSTAL
        return 20 unless valid
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Root should be an unless node
      unless_node = arena[program.roots.first]
      unless_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unless)

      # Condition should be identifier "valid"
      condition = arena[unless_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)

      # Then body should contain return statement
      then_body = unless_node.if_then.not_nil!
      then_body.size.should eq(1)

      return_stmt = arena[then_body[0]]
      return_stmt.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Return)
    end

    it "parses postfix if modifier with break" do
      source = <<-CRYSTAL
        break if done
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots.first]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      then_body = if_node.if_then.not_nil!
      then_body.size.should eq(1)

      break_stmt = arena[then_body[0]]
      break_stmt.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Break)
    end

    it "parses postfix unless modifier with next" do
      source = <<-CRYSTAL
        next unless ready
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unless_node = arena[program.roots.first]
      unless_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unless)

      then_body = unless_node.if_then.not_nil!
      then_body.size.should eq(1)

      next_stmt = arena[then_body[0]]
      next_stmt.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Next)
    end

    it "parses postfix if modifier with assignment" do
      source = <<-CRYSTAL
        x = 10 if condition
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots.first]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      then_body = if_node.if_then.not_nil!
      then_body.size.should eq(1)

      assign = arena[then_body[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses postfix unless modifier with assignment" do
      source = <<-CRYSTAL
        x = 20 unless initialized
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      unless_node = arena[program.roots.first]
      unless_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Unless)

      then_body = unless_node.if_then.not_nil!
      then_body.size.should eq(1)

      assign = arena[then_body[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses postfix if modifier with method call" do
      source = <<-CRYSTAL
        puts(x) if debug
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots.first]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      then_body = if_node.if_then.not_nil!
      then_body.size.should eq(1)

      call = arena[then_body[0]]
      call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses postfix if with complex condition" do
      source = <<-CRYSTAL
        return if x > 10 && y < 20
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      if_node = arena[program.roots.first]
      if_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)

      # Condition should be binary AND
      condition = arena[if_node.if_condition.not_nil!]
      condition.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Binary)
      condition.operator_string.should eq("&&")
    end

    it "handles statement without modifier" do
      source = <<-CRYSTAL
        x = 10
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Should be plain assignment, not wrapped in if/unless
      assign = arena[program.roots.first]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end
  end
end
