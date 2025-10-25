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
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method_node.def_name.not_nil!).should eq("empty?")
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
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method_node.def_name.not_nil!).should eq("save!")
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
      id_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(id_node.literal.not_nil!).should eq("empty?")
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
      id_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(id_node.literal.not_nil!).should eq("save!")
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
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Call has callee (Identifier with name)
      callee = arena[call_node.callee.not_nil!]
      callee.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(callee.literal.not_nil!).should eq("save!")
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
      class_body = class_node.class_body.not_nil!
      method_node = arena[class_body[0]]

      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method_node.def_name.not_nil!).should eq("empty?")
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
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method_node.def_name.not_nil!).should eq("update!")

      params = method_node.def_params.not_nil!
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
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Call has callee (member access to obj.nil?)
      callee = arena[call_node.callee.not_nil!]
      callee.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(callee.member.not_nil!).should eq("nil?")
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
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Call has callee (member access to user.save!)
      callee = arena[call_node.callee.not_nil!]
      callee.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(callee.member.not_nil!).should eq("save!")
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
      to_s_call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Callee is member access to .to_s
      to_s_member = arena[to_s_call.callee.not_nil!]
      to_s_member.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(to_s_member.member.not_nil!).should eq("to_s")

      # Left of to_s member access is call to valid?
      valid_call = arena[to_s_member.left.not_nil!]
      valid_call.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Callee is member access to .valid?
      valid_member = arena[valid_call.callee.not_nil!]
      valid_member.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::MemberAccess)
      String.new(valid_member.member.not_nil!).should eq("valid?")
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
      method_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method_node.def_name.not_nil!).should eq("empty?")

      return_type = method_node.def_return_type
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
      method1.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method1.def_name.not_nil!).should eq("valid?")

      # Second method: save!
      method2 = arena[program.roots[1]]
      method2.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method2.def_name.not_nil!).should eq("save!")

      # Third method: process (no suffix)
      method3 = arena[program.roots[2]]
      method3.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Def)
      String.new(method3.def_name.not_nil!).should eq("process")
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
      call_node.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Call)

      # Call has callee (Identifier with name)
      callee = arena[call_node.callee.not_nil!]
      callee.kind.should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Identifier)
      String.new(callee.literal.not_nil!).should eq("delete!")

      args = call_node.args.not_nil!
      args.size.should eq(2)
    end
  end
end
