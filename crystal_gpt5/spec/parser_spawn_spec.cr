require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 84: Spawn keyword (fiber concurrency)" do
    it "parses spawn do...end block form" do
      source = <<-CRYSTAL
      spawn do
        puts("hello")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      spawn_node = arena[program.roots[0]]
      spawn_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)

      # Block form should have spawn_body
      body = spawn_node.spawn_body.not_nil!
      body.size.should eq(1)

      # No spawn_expression in block form
      spawn_node.spawn_expression.should be_nil
    end

    it "parses spawn expression form" do
      source = "spawn process_task()"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      spawn_node = arena[program.roots[0]]
      spawn_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)

      # Expression form should have spawn_expression
      expr = spawn_node.spawn_expression.not_nil!
      expr_node = arena[expr]
      expr_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # No spawn_body in expression form
      spawn_node.spawn_body.should be_nil
    end

    it "parses spawn block with multiple statements" do
      source = <<-CRYSTAL
      spawn do
        x = compute()
        y = transform(x)
        output(y)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      spawn_node = arena[program.roots[0]]
      spawn_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)

      body = spawn_node.spawn_body.not_nil!
      body.size.should eq(3)
    end

    it "parses spawn inside method definition" do
      source = <<-CRYSTAL
      def async_operation
        spawn do
          perform_work()
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_def = arena[program.roots[0]]
      method_def.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)

      # Method body should contain spawn
      body_exprs = method_def.def_body.not_nil!
      body_exprs.size.should eq(1)

      spawn_node = arena[body_exprs[0]]
      spawn_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)
    end

    it "parses spawn with assignment result" do
      source = "result = spawn worker.process()"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign = arena[program.roots[0]]
      assign.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Assignment value should be spawn
      value = arena[assign.assign_value.not_nil!]
      value.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)
    end

    it "parses nested spawn blocks" do
      source = <<-CRYSTAL
      spawn do
        spawn do
          inner_work()
        end
        outer_work()
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      outer_spawn = arena[program.roots[0]]
      outer_spawn.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)

      outer_body = outer_spawn.spawn_body.not_nil!
      outer_body.size.should eq(2)

      # First statement should be inner spawn
      inner_spawn = arena[outer_body[0]]
      inner_spawn.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)
    end

    it "parses spawn block with control flow" do
      source = <<-CRYSTAL
      spawn do
        if condition
          action()
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      spawn_node = arena[program.roots[0]]
      spawn_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)

      body = spawn_node.spawn_body.not_nil!
      body.size.should eq(1)

      # Body should contain if statement
      if_stmt = arena[body[0]]
      if_stmt.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::If)
    end

    it "parses empty spawn block" do
      source = <<-CRYSTAL
      spawn do
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      spawn_node = arena[program.roots[0]]
      spawn_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)

      # Empty body
      body = spawn_node.spawn_body.not_nil!
      body.size.should eq(0)
    end

    it "parses spawn with complex expression" do
      source = "spawn server.handle_request(client.connection, timeout: 30)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      spawn_node = arena[program.roots[0]]
      spawn_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)

      # Should have expression (method call with receiver and arguments)
      expr = spawn_node.spawn_expression.not_nil!
      expr_node = arena[expr]
      expr_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses multiple spawn statements" do
      source = <<-CRYSTAL
      spawn worker1.start()
      spawn worker2.start()
      spawn do
        worker3.start()
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # All three should be spawn nodes
      spawn1 = arena[program.roots[0]]
      spawn1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)

      spawn2 = arena[program.roots[1]]
      spawn2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)

      spawn3 = arena[program.roots[2]]
      spawn3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Spawn)
    end
  end
end
