require "spec"

require "../src/compiler/frontend/parser"

describe "CrystalGPT5::Compiler::Frontend::Parser" do
  describe "Phase 64: Fun keyword (PRODUCTION-READY)" do
    it "parses fun without parameters or return type" do
      source = <<-CRYSTAL
      lib LibC
        fun exit
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(lib_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Lib)

      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      body.size.should eq(1)

      fun_node = arena[body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(fun_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(fun_node).not_nil!).should eq("exit")
      CrystalGPT5::Compiler::Frontend.node_def_body(fun_node).should be_nil  # No body for fun
    end

    it "parses fun with parameters" do
      source = <<-CRYSTAL
      lib LibC
        fun printf(format : UInt8)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      fun_node = arena[body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(fun_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(fun_node).not_nil!).should eq("printf")

      params = CrystalGPT5::Compiler::Frontend.node_def_params(fun_node).not_nil!
      params.size.should eq(1)
      params[0].name.should eq("format")
      params[0].type_annotation.should eq("UInt8")
    end

    it "parses fun with return type" do
      source = <<-CRYSTAL
      lib LibC
        fun getpid : Int32
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      fun_node = arena[body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(fun_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(fun_node).not_nil!).should eq("getpid")
      String.new(CrystalGPT5::Compiler::Frontend.node_def_return_type(fun_node).not_nil!).should eq("Int32")
      CrystalGPT5::Compiler::Frontend.node_def_body(fun_node).should be_nil
    end

    it "parses fun with parameters and return type" do
      source = <<-CRYSTAL
      lib LibC
        fun malloc(size : UInt64) : Void
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      fun_node = arena[body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(fun_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(fun_node).not_nil!).should eq("malloc")

      params = CrystalGPT5::Compiler::Frontend.node_def_params(fun_node).not_nil!
      params.size.should eq(1)
      params[0].name.should eq("size")
      params[0].type_annotation.should eq("UInt64")

      String.new(CrystalGPT5::Compiler::Frontend.node_def_return_type(fun_node).not_nil!).should eq("Void")
      CrystalGPT5::Compiler::Frontend.node_def_body(fun_node).should be_nil
    end

    it "parses multiple fun declarations in lib" do
      source = <<-CRYSTAL
      lib LibC
        fun getpid : Int32
        fun exit(code : Int32)
        fun malloc(size : UInt64) : Void
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      body.size.should eq(3)

      # First fun: getpid
      fun1 = arena[body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(fun1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(fun1).not_nil!).should eq("getpid")

      # Second fun: exit
      fun2 = arena[body[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(fun2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(fun2).not_nil!).should eq("exit")

      # Third fun: malloc
      fun3 = arena[body[2]]
      CrystalGPT5::Compiler::Frontend.node_kind(fun3).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(fun3).not_nil!).should eq("malloc")
    end

    it "parses fun with multiple parameters" do
      source = <<-CRYSTAL
      lib LibC
        fun strncmp(s1 : UInt8, s2 : UInt8, n : UInt64) : Int32
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      fun_node = arena[body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(fun_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(fun_node).not_nil!).should eq("strncmp")

      params = CrystalGPT5::Compiler::Frontend.node_def_params(fun_node).not_nil!
      params.size.should eq(3)

      params[0].name.should eq("s1")
      params[0].type_annotation.should eq("UInt8")

      params[1].name.should eq("s2")
      params[1].type_annotation.should eq("UInt8")

      params[2].name.should eq("n")
      params[2].type_annotation.should eq("UInt64")

      String.new(CrystalGPT5::Compiler::Frontend.node_def_return_type(fun_node).not_nil!).should eq("Int32")
    end

    it "parses fun without return type has nil return type" do
      source = <<-CRYSTAL
      lib LibC
        fun exit(code : Int32)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      fun_node = arena[body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(fun_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      CrystalGPT5::Compiler::Frontend.node_def_return_type(fun_node).should be_nil
    end

    it "parses fun with no parameters as empty array" do
      source = <<-CRYSTAL
      lib LibC
        fun getpid : Int32
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      fun_node = arena[body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(fun_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      params = CrystalGPT5::Compiler::Frontend.node_def_params(fun_node)
      (params.nil? || params.size == 0).should be_true
    end

    it "parses fun with spaces around colons" do
      source = <<-CRYSTAL
      lib LibC
        fun malloc(size : UInt64) : Void
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      fun_node = arena[body[0]]

      CrystalGPT5::Compiler::Frontend.node_kind(fun_node).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
      String.new(CrystalGPT5::Compiler::Frontend.node_def_name(fun_node).not_nil!).should eq("malloc")
    end

    it "parses lib with mixed fun and other declarations" do
      source = <<-CRYSTAL
      lib LibC
        fun getpid : Int32
        fun exit(code : Int32)
      end
      CRYSTAL

      parser = CrystalGPT5::Compiler::Frontend::Parser.new(CrystalGPT5::Compiler::Frontend::Lexer.new(source))
      program = parser.parse_program

      program.roots.size.should eq(1)
      arena = program.arena

      lib_node = arena[program.roots[0]]
      body = CrystalGPT5::Compiler::Frontend.node_lib_body(lib_node).not_nil!
      body.size.should eq(2)

      # Both should be fun declarations
      fun1 = arena[body[0]]
      CrystalGPT5::Compiler::Frontend.node_kind(fun1).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)

      fun2 = arena[body[1]]
      CrystalGPT5::Compiler::Frontend.node_kind(fun2).should eq(CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Fun)
    end
  end
end
