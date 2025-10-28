require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 90A: select/when (concurrent channel operations - parser only)" do
    it "parses basic select with single when branch" do
      source = <<-CRYSTAL
      select
      when channel.receive
        puts("received")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      select_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)

      # Check select has no value (unlike case)
      select_node.select_branches.should_not be_nil
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(1)

      # First branch
      branch = branches[0]
      branch.condition.should_not be_nil
      branch.body.size.should eq(1)
    end

    it "parses select with multiple when branches" do
      source = <<-CRYSTAL
      select
      when ch1.receive
        puts("ch1")
      when ch2.receive
        puts("ch2")
      when ch3.receive
        puts("ch3")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      select_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)

      branches = select_node.select_branches.not_nil!
      branches.size.should eq(3)

      # Each branch has condition and body
      branches.each do |branch|
        branch.condition.should_not be_nil
        branch.body.should_not be_empty
      end
    end

    it "parses select with assignment in when condition" do
      source = <<-CRYSTAL
      select
      when msg = channel.receive
        puts(msg)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(1)

      # Condition should be assignment expression
      condition_node = arena[branches[0].condition]
      condition_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses select with else clause" do
      source = <<-CRYSTAL
      select
      when channel.receive
        puts("received")
      else
        puts("no message")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      select_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)

      branches = select_node.select_branches.not_nil!
      branches.size.should eq(1)

      # Check else clause
      else_body = select_node.select_else
      else_body.should_not be_nil
      else_body.not_nil!.size.should eq(1)
    end

    it "parses select with 'then' keyword after when" do
      source = <<-CRYSTAL
      select
      when channel.receive then puts("received")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(1)
      branches[0].body.size.should eq(1)
    end

    it "parses select with method call in condition (send)" do
      source = <<-CRYSTAL
      select
      when channel.send(value)
        puts("sent")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(1)

      # Condition should be method call (send)
      condition_node = arena[branches[0].condition]
      condition_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses select with timeout condition" do
      source = <<-CRYSTAL
      select
      when timeout(5.seconds)
        puts("timeout")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(1)

      # Condition should be method call (timeout)
      condition_node = arena[branches[0].condition]
      condition_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)
    end

    it "parses select inside method definition" do
      source = <<-CRYSTAL
      def wait_for_message
        select
        when msg = channel.receive
          puts(msg)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      method_body = method_node.def_body.not_nil!
      method_body.size.should eq(1)

      # Method body contains select
      select_node = arena[method_body[0]]
      select_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)
    end

    it "parses select inside class" do
      source = <<-CRYSTAL
      class Worker
        def run
          select
          when job = jobs.receive
            process(job)
          end
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]
      method_body = method_node.def_body.not_nil!

      # Method body contains select
      select_node = arena[method_body[0]]
      select_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)
    end

    it "parses select with multiple statements in when body" do
      source = <<-CRYSTAL
      select
      when msg = channel.receive
        x = process(msg)
        y = validate(x)
        puts(y)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(1)

      # Body should have 3 statements
      branches[0].body.size.should eq(3)
    end

    it "parses select with receive? (nilable receive)" do
      source = <<-CRYSTAL
      select
      when msg = channel.receive?
        puts(msg)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(1)

      # Condition is assignment with receive? call
      condition_node = arena[branches[0].condition]
      condition_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses select with mixed operations" do
      source = <<-CRYSTAL
      select
      when msg = ch1.receive
        puts("received")
      when ch2.send(data)
        puts("sent data")
      when timeout(1.second)
        puts("timeout")
      else
        puts("non-blocking")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(3)

      # Has else clause
      else_body = select_node.select_else
      else_body.should_not be_nil
      else_body.not_nil!.size.should eq(1)
    end

    it "parses nested select statements" do
      source = <<-CRYSTAL
      select
      when msg = channel1.receive
        select
        when ack = channel2.receive
          puts(ack)
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      outer_select = arena[program.roots[0]]
      outer_select.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)

      outer_branches = outer_select.select_branches.not_nil!
      outer_branches.size.should eq(1)

      # Body of outer when contains inner select
      inner_select_id = outer_branches[0].body[0]
      inner_select = arena[inner_select_id]
      inner_select.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)
    end

    it "parses select as expression in assignment" do
      source = <<-CRYSTAL
      result = select
      when value = channel.receive
        value
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      assign_node = arena[program.roots[0]]
      assign_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)

      # Assignment value is select
      select_id = assign_node.assign_value.not_nil!
      select_node = arena[select_id]
      select_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)
    end

    it "parses select with empty when body" do
      source = <<-CRYSTAL
      select
      when channel.receive
      when timeout(1.second)
        puts("timeout")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(2)

      # First branch has empty body
      branches[0].body.should be_empty

      # Second branch has non-empty body
      branches[1].body.size.should eq(1)
    end

    it "parses select with complex channel expression" do
      source = <<-CRYSTAL
      select
      when msg = @channels[index].receive
        handle(msg)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      branches = select_node.select_branches.not_nil!
      branches.size.should eq(1)

      # Condition should be assignment
      condition_node = arena[branches[0].condition]
      condition_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign)
    end

    it "parses select in loop" do
      source = <<-CRYSTAL
      loop do
        select
        when msg = channel.receive
          puts(msg)
        when timeout(1.second)
          break
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      loop_node = arena[program.roots[0]]
      loop_body = loop_node.loop_body.not_nil!

      # Loop body contains select
      select_node = arena[loop_body[0]]
      select_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)
    end

    it "parses select with only else clause (immediate fallback)" do
      source = <<-CRYSTAL
      select
      else
        puts("non-blocking")
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      select_node = arena[program.roots[0]]
      select_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Select)

      # No when branches
      branches = select_node.select_branches
      if branches
        branches.should be_empty
      end

      # Only else clause
      else_body = select_node.select_else
      else_body.should_not be_nil
      else_body.not_nil!.size.should eq(1)
    end
  end
end
