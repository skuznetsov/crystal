require "spec"

require "../../src/compiler/frontend/ast"
require "../../src/compiler/frontend/lexer"
require "../../src/compiler/frontend/parser"
require "../../src/compiler/semantic/symbol_table"
require "../../src/compiler/semantic/symbol"
require "../../src/compiler/semantic/collectors/symbol_collector"
require "../../src/compiler/semantic/resolvers/name_resolver"
require "../../src/compiler/semantic/analyzer"
require "../../src/compiler/semantic/types/type"
require "../../src/compiler/semantic/types/primitive_type"
require "../../src/compiler/semantic/types/class_type"
require "../../src/compiler/semantic/types/union_type"
require "../../src/compiler/semantic/types/type_context"
require "../../src/compiler/semantic/type_inference_engine"

include CrystalGPT5::Compiler::Frontend
include CrystalGPT5::Compiler::Semantic

# Helper: Parse source and run full semantic pipeline
private def infer_types(source : String)
  lexer = Lexer.new(source)
  parser = Parser.new(lexer)
  program = parser.parse_program

  # Run semantic analysis (symbol collection + name resolution)
  analyzer = Analyzer.new(program)
  analyzer.collect_symbols
  name_result = analyzer.resolve_names

  # Run type inference
  engine = TypeInferenceEngine.new(program, name_result.identifier_symbols)
  engine.infer_types

  {program, analyzer, engine}
end

describe TypeInferenceEngine do
  describe "Phase 1: Literals (Current Parser Support)" do
    it "infers Int32 for number literals" do
      source = "42"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers String for string literals" do
      source = "\"hello\""
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("String")
    end

    # TODO: Parser doesn't support bool, nil, if, while yet
    # These will be added when parser is extended
  end

  describe "Phase 2: Binary Operators" do
    it "infers Int32 for addition of numbers" do
      source = "1 + 2"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers Int32 for subtraction of numbers" do
      source = "10 - 3"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers Bool for comparison operators" do
      source = "5 < 10"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Bool")
    end

    it "infers Bool for equality operators" do
      source = "x == y"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Bool")
    end

    it "infers Bool for logical AND" do
      source = "true && false"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Bool")
    end

    it "emits error for invalid operator types" do
      source = "\"hello\" + 42"
      program, analyzer, engine = infer_types(source)

      engine.diagnostics.size.should eq(1)
      engine.diagnostics[0].message.should contain("requires numeric types")
    end
  end

  describe "Phase 3: Control Flow" do
    it "infers union type for if with both branches" do
      source = <<-CRYSTAL
        if true
          42
        else
          "hello"
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(UnionType)
      union = type.as(UnionType)
      union.types.size.should eq(2)

      # Check both Int32 and String are in union
      type_names = union.types.map(&.to_s).sort
      type_names.should eq(["Int32", "String"])
    end

    it "infers union with Nil for if without else" do
      source = <<-CRYSTAL
        if true
          42
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(UnionType)
      union = type.as(UnionType)
      union.types.size.should eq(2)

      # Check Int32 and Nil are in union
      type_names = union.types.map(&.to_s).sort
      type_names.should eq(["Int32", "Nil"])
    end

    it "infers Nil for while loop" do
      source = <<-CRYSTAL
        while true
          42
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Nil")
    end

    it "emits error for non-Bool if condition" do
      source = <<-CRYSTAL
        if 42
          "oops"
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      engine.diagnostics.size.should eq(1)
      engine.diagnostics[0].message.should contain("If condition must be Bool")
    end

    it "emits error for non-Bool while condition" do
      source = <<-CRYSTAL
        while "not bool"
          42
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      engine.diagnostics.size.should eq(1)
      engine.diagnostics[0].message.should contain("While condition must be Bool")
    end
  end

  # TODO: Phase 4 (Method Calls) - waiting for type inference foundation
  # Will add method overload resolution after basic type inference works

  describe "Integration: Complex Expressions (Current Parser)" do
    it "infers nested binary expressions" do
      source = "1 + 2 * 3"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      # Arithmetic operators return Int32
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers comparison of arithmetic expressions" do
      source = "(10 - 5) < (3 * 4)"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      # Comparison operators return Bool
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Bool")
    end
  end
end
