require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 98: out keyword (C bindings output parameter)" do
    it "parses out with identifier" do
      source = "out result"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      out_node = arena[program.roots.first]

      out_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Out)
      out_node.out_identifier.should_not be_nil
      String.new(out_node.out_identifier.not_nil!).should eq("result")
    end

    it "parses out in function call" do
      source = "C.get_value(out new_var)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      call_node = arena[program.roots.first]

      # Should be a call expression
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Check callee (C.get_value)
      callee_id = call_node.callee.not_nil!
      callee = arena[callee_id]
      callee.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)

      # Check argument is out expression
      args = call_node.args.not_nil!
      args.size.should eq(1)

      out_arg = arena[args[0]]
      out_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Out)
      out_arg.out_identifier.should_not be_nil
      String.new(out_arg.out_identifier.not_nil!).should eq("new_var")
    end

    it "parses multiple out parameters" do
      source = "C.get_values(out x, out y, out z)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      call_node = arena[program.roots.first]

      # Check arguments
      args = call_node.args.not_nil!
      args.size.should eq(3)

      # Verify all three out expressions
      ["x", "y", "z"].each_with_index do |name, idx|
        out_arg = arena[args[idx]]
        out_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Out)
        String.new(out_arg.out_identifier.not_nil!).should eq(name)
      end
    end

    it "parses out with different identifier names" do
      source = "out foo_bar_123"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      out_node = arena[program.roots.first]

      out_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Out)
      String.new(out_node.out_identifier.not_nil!).should eq("foo_bar_123")
    end

    it "parses out in lib context" do
      source = <<-CR
        lib C
          fun get_value(out_ptr : Int32*)
        end

        C.get_value(out result)
      CR

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      # Should have 2 root expressions: lib and function call
      program.roots.size.should eq(2)
      arena = program.arena

      # Second root is the function call
      call_node = arena[program.roots[1]]
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Check argument
      args = call_node.args.not_nil!
      args.size.should eq(1)

      out_arg = arena[args[0]]
      out_arg.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Out)
      String.new(out_arg.out_identifier.not_nil!).should eq("result")
    end

    it "parses out mixed with regular arguments" do
      source = "C.process(100, out status, \"hello\", out error_code)"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena
      call_node = arena[program.roots.first]

      # Check arguments
      args = call_node.args.not_nil!
      args.size.should eq(4)

      # First arg: 100 (number)
      arg0 = arena[args[0]]
      arg0.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Number)

      # Second arg: out status
      arg1 = arena[args[1]]
      arg1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Out)
      String.new(arg1.out_identifier.not_nil!).should eq("status")

      # Third arg: "hello" (string)
      arg2 = arena[args[2]]
      arg2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::String)

      # Fourth arg: out error_code
      arg3 = arena[args[3]]
      arg3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Out)
      String.new(arg3.out_identifier.not_nil!).should eq("error_code")
    end

    it "emits error for out without identifier" do
      source = "out"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      # Parser should emit error
      parser.diagnostics.size.should be > 0
      diagnostic = parser.diagnostics.first
      diagnostic.message.should contain("unexpected")
    end

    it "emits error for out followed by non-identifier" do
      source = "out 123"

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      # Parser should emit error
      parser.diagnostics.size.should be > 0
      diagnostic = parser.diagnostics.first
      diagnostic.message.should contain("unexpected")
    end
  end
end
