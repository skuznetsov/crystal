require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 43: Method name suffixes (? and !) (PRODUCTION-READY)" do
    it "parses method definition with ? suffix" do
      source = <<-CRYSTAL
      def empty?
        true
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(method_node).not_nil!).should eq("empty?")
    end

    it "parses method definition with ! suffix" do
      source = <<-CRYSTAL
      def save!
        42
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(method_node).not_nil!).should eq("save!")
    end

    it "parses bare method call with ? suffix as identifier" do
      source = <<-CRYSTAL
      empty?
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Bare call parses as Identifier (semantic analysis determines it's a call)
      id_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(id_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(id_node).not_nil!).should eq("empty?")
    end

    it "parses bare method call with ! suffix as identifier" do
      source = <<-CRYSTAL
      save!
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Bare call parses as Identifier (semantic analysis determines it's a call)
      id_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(id_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(id_node).not_nil!).should eq("save!")
    end

    it "parses method call with ! suffix and parentheses" do
      source = <<-CRYSTAL
      save!()
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # With parentheses, parses as Call
      call_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Call has callee (Identifier with name)
      callee = arena[call_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).callee.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(callee).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(callee).not_nil!).should eq("save!")
    end

    it "parses method with ? suffix in class" do
      source = <<-CRYSTAL
      class Array
        def empty?
          size == 0
        end
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      class_node = arena[program.roots[0]]
      class_body = CrystalGPT5::Compiler::Frontend.node_class_body(class_node).not_nil!
      method_node = arena[class_body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(method_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(method_node).not_nil!).should eq("empty?")
    end

    it "parses method with ! suffix and parameters" do
      source = <<-CRYSTAL
      def update!(name, age)
        @name = name
        @age = age
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(method_node).not_nil!).should eq("update!")

      params = CrystalGPT5::Compiler::Frontend.node_def_params(method_node).not_nil!
      params.size.should eq(2)
      params[0].name.should eq("name")
      params[1].name.should eq("age")
    end

    it "parses member access with ? suffix" do
      source = <<-CRYSTAL
      obj.nil?()
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Call has callee (member access to obj.nil?)
      callee = arena[call_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).callee.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(callee).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(callee).not_nil!).should eq("nil?")
    end

    it "parses member access with ! suffix" do
      source = <<-CRYSTAL
      user.save!()
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Call has callee (member access to user.save!)
      callee = arena[call_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).callee.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(callee).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(callee).not_nil!).should eq("save!")
    end

    it "parses chained method calls with suffixes" do
      source = <<-CRYSTAL
      user.valid?().to_s()
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      # Top level is call to to_s
      to_s_call = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(to_s_call).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Callee is member access to .to_s
      to_s_member = arena[to_s_call.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).callee.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(to_s_member).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(to_s_member).not_nil!).should eq("to_s")

      # Left of to_s member access is call to valid?
      valid_call = arena[CrystalGPT5::Compiler::Frontend.node_left(to_s_member).not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(valid_call).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Callee is member access to .valid?
      valid_member = arena[valid_call.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).callee.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(valid_member).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(CrystalGPT5::Compiler::Frontend.node_member(valid_member).not_nil!).should eq("valid?")
    end

    it "parses method with ? suffix and type annotation" do
      source = <<-CRYSTAL
      def empty? : Bool
        true
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      method_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(method_node).not_nil!).should eq("empty?")

      return_type = CrystalGPT5::Compiler::Frontend.node_def_return_type(method_node)
      return_type.should_not be_nil
      String.new(return_type.not_nil!).should eq("Bool")
    end

    it "parses multiple methods with different suffixes" do
      source = <<-CRYSTAL
      def valid?
        true
      end

      def save!
        42
      end

      def process
        1
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(3)
      arena = program.arena

      # First method: valid?
      method1 = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(method1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(method1).not_nil!).should eq("valid?")

      # Second method: save!
      method2 = arena[program.roots[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(method2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(method2).not_nil!).should eq("save!")

      # Third method: process (no suffix)
      method3 = arena[program.roots[2]]
      CrystalGPT5::Compiler::Frontend.node_kind(method3).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(method3).not_nil!).should eq("process")
    end

    it "parses method call with ! suffix and arguments" do
      source = <<-CRYSTAL
      delete!(key, value)
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      call_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(call_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Call has callee (Identifier with name)
      callee = arena[call_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).callee.not_nil!]
      CrystalGPT5::Compiler::Frontend.node_kind(callee).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(CrystalGPT5::Compiler::Frontend.node_literal(callee).not_nil!).should eq("delete!")

      args = call_node.as(CrystalGPT5::Compiler::Frontend::ExpressionNode).args.not_nil!
      args.size.should eq(2)
    end
  end
end
