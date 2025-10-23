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

  # Run type inference with global symbol table for fallback lookup
  engine = TypeInferenceEngine.new(program, name_result.identifier_symbols, analyzer.global_context.symbol_table)
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

    it "infers Int64 for number literals with _i64 suffix" do
      source = "42_i64"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int64")
    end

    it "infers Float64 for decimal literals" do
      source = "3.14"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Float64")
    end

    it "infers Float64 for integer literals with _f64 suffix" do
      source = "42_f64"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Float64")
    end

    it "infers Int32 for explicit _i32 suffix" do
      source = "100_i32"
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
      engine.diagnostics[0].message.should contain("not defined for")
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

    it "infers union type for if with single elsif" do
      source = <<-CRYSTAL
        if true
          42
        elsif false
          "hello"
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(UnionType)
      union = type.as(UnionType)

      # Then (Int32) + elsif ("String") + implicit else (Nil) = 3 types
      union.types.size.should eq(3)
      type_names = union.types.map(&.to_s).sort
      type_names.should eq(["Int32", "Nil", "String"])
    end

    it "infers union type for if with multiple elsif branches" do
      source = <<-CRYSTAL
        if true
          1
        elsif false
          "two"
        elsif true
          3
        else
          "four"
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(UnionType)
      union = type.as(UnionType)

      # Then (Int32) + elsif1 (String) + elsif2 (Int32) + else (String)
      # After normalization: Int32 | String (duplicates removed)
      union.types.size.should eq(2)
      type_names = union.types.map(&.to_s).sort
      type_names.should eq(["Int32", "String"])
    end

    it "emits error for non-Bool elsif condition" do
      source = <<-CRYSTAL
        if true
          1
        elsif 42
          2
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      engine.diagnostics.size.should eq(1)
      engine.diagnostics[0].message.should contain("Elsif condition must be Bool")
    end
  end

  describe "Phase 4B.2: Inheritance Method Search" do
    it "finds method in superclass" do
      source = <<-CRYSTAL
        class Animal
          def speak : String
            "sound"
          end
        end

        class Dog < Animal
        end

        d = Dog.new
        d.speak()
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Method call should find speak in Animal (superclass)
      # roots[0]=Animal, roots[1]=Dog, roots[2]=assignment, roots[3]=call
      call_id = program.roots[3]
      type = engine.context.get_type(call_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("String")
    end

    it "prefers method in subclass over superclass" do
      source = <<-CRYSTAL
        class Animal
          def speak : String
            "sound"
          end
        end

        class Dog < Animal
          def speak : String
            "bark"
          end
        end

        d = Dog.new
        d.speak()
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Should use Dog's speak, not Animal's
      # roots[0]=Animal, roots[1]=Dog, roots[2]=assignment, roots[3]=call
      call_id = program.roots[3]
      type = engine.context.get_type(call_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("String")

      # No diagnostics (both methods return String)
      engine.diagnostics.size.should eq(0)
    end

    it "searches through multiple inheritance levels" do
      source = <<-CRYSTAL
        class Animal
          def eat : String
            "eating"
          end
        end

        class Mammal < Animal
        end

        class Dog < Mammal
        end

        d = Dog.new
        d.eat()
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Should find eat in Animal (grandparent)
      # roots[0]=Animal, roots[1]=Mammal, roots[2]=Dog, roots[3]=assignment, roots[4]=call
      call_id = program.roots[4]
      type = engine.context.get_type(call_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("String")
    end
  end

  describe "Phase 4B: Method Overload Resolution" do
    it "selects correct overload by parameter count" do
      source = <<-CRYSTAL
        class Calc
          def add(x : Int32) : Int32
            x
          end

          def add(x : Int32, y : Int32) : Int64
            x
          end
        end

        c = Calc.new
        c.add(5)
        c.add(3, 4)
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # First call: add(5) → Int32 (one parameter)
      call1_id = program.roots[2]
      type1 = engine.context.get_type(call1_id)
      type1.should be_a(PrimitiveType)
      type1.as(PrimitiveType).name.should eq("Int32")

      # Second call: add(3, 4) → Int64 (two parameters)
      call2_id = program.roots[3]
      type2 = engine.context.get_type(call2_id)
      type2.should be_a(PrimitiveType)
      type2.as(PrimitiveType).name.should eq("Int64")
    end

    it "matches untyped parameter to any argument" do
      source = <<-CRYSTAL
        class Box
          def store(item) : String
            "stored"
          end
        end

        b = Box.new
        b.store(42)
        b.store("hello")
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Both calls should match (untyped param accepts any type)
      call1_id = program.roots[2]
      type1 = engine.context.get_type(call1_id)
      type1.should be_a(PrimitiveType)
      type1.as(PrimitiveType).name.should eq("String")

      call2_id = program.roots[3]
      type2 = engine.context.get_type(call2_id)
      type2.should be_a(PrimitiveType)
      type2.as(PrimitiveType).name.should eq("String")
    end

    it "requires exact type match for typed parameters" do
      source = <<-CRYSTAL
        class Printer
          def print(x : Int32) : String
            "int"
          end

          def print(x : String) : String
            "string"
          end
        end

        p = Printer.new
        p.print(42)
        p.print("hello")
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Both calls should resolve correctly
      call1_id = program.roots[2]
      type1 = engine.context.get_type(call1_id)
      type1.should be_a(PrimitiveType)
      type1.as(PrimitiveType).name.should eq("String")

      call2_id = program.roots[3]
      type2 = engine.context.get_type(call2_id)
      type2.should be_a(PrimitiveType)
      type2.as(PrimitiveType).name.should eq("String")
    end
  end

  describe "Phase 4A: Method Calls (Simple Name-Based Lookup)" do
    it "infers return type from method with type annotation" do
      source = <<-CRYSTAL
        class Calculator
          def add(x : Int32, y : Int32) : Int32
            x
          end
        end

        calc = Calculator.new
        calc.add(1, 2)
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get the method call expression (last root)
      call_id = program.roots[2]
      type = engine.context.get_type(call_id)

      # Should infer Int32 from return annotation
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers Nil for method without return type annotation" do
      source = <<-CRYSTAL
        class Printer
          def print_msg(msg : String)
            msg
          end
        end

        p = Printer.new
        p.print_msg("hello")
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get the method call expression (last root)
      call_id = program.roots[2]
      type = engine.context.get_type(call_id)

      # Should return Nil when no return annotation
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Nil")
    end

    it "emits error when method not found on class" do
      source = <<-CRYSTAL
        class Empty
        end

        e = Empty.new
        e.missing_method(42)
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Should have diagnostic for method not found
      engine.diagnostics.size.should eq(1)
      engine.diagnostics[0].message.should contain("Method 'missing_method' not found")
    end

    it "handles multiple methods in class" do
      source = <<-CRYSTAL
        class Math
          def add(x : Int32) : Int32
            x
          end

          def multiply(x : Int32) : Int64
            x
          end
        end

        m = Math.new
        m.add(5)
        m.multiply(3)
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Check add call returns Int32
      add_call_id = program.roots[2]
      add_type = engine.context.get_type(add_call_id)
      add_type.should be_a(PrimitiveType)
      add_type.as(PrimitiveType).name.should eq("Int32")

      # Check multiply call returns Int64
      mult_call_id = program.roots[3]
      mult_type = engine.context.get_type(mult_call_id)
      mult_type.should be_a(PrimitiveType)
      mult_type.as(PrimitiveType).name.should eq("Int64")
    end

    it "handles method call on assigned variable" do
      source = <<-CRYSTAL
        class Counter
          def increment : Int32
            1
          end
        end

        c = Counter.new
        result = c.increment
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Assignment should have type of method call (Int32)
      assign_id = program.roots[2]
      type = engine.context.get_type(assign_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end
  end

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

  describe "Phase 4: Variable Assignments" do
    it "infers type from simple assignment" do
      source = "x = 42"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      # Assignment returns the value type
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "uses tracked type for identifier after assignment" do
      source = <<-CRYSTAL
        x = 42
        x
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Check assignment (first root)
      assign_type = engine.context.get_type(program.roots[0])
      assign_type.should be_a(PrimitiveType)
      assign_type.as(PrimitiveType).name.should eq("Int32")

      # Check identifier usage (second root)
      ident_type = engine.context.get_type(program.roots[1])
      ident_type.should be_a(PrimitiveType)
      ident_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers String type from string assignment" do
      source = <<-CRYSTAL
        s = "hello"
        s
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Check identifier has String type
      ident_type = engine.context.get_type(program.roots[1])
      ident_type.should be_a(PrimitiveType)
      ident_type.as(PrimitiveType).name.should eq("String")
    end

    it "infers type from expression assignment" do
      source = <<-CRYSTAL
        y = 1 + 2
        y
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Check identifier has Int32 type from arithmetic
      ident_type = engine.context.get_type(program.roots[1])
      ident_type.should be_a(PrimitiveType)
      ident_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles multiple assignments" do
      source = <<-CRYSTAL
        x = 42
        y = "hello"
        x
        y
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Check x has Int32 type
      x_type = engine.context.get_type(program.roots[2])
      x_type.should be_a(PrimitiveType)
      x_type.as(PrimitiveType).name.should eq("Int32")

      # Check y has String type
      y_type = engine.context.get_type(program.roots[3])
      y_type.should be_a(PrimitiveType)
      y_type.as(PrimitiveType).name.should eq("String")
    end

    it "handles reassignment with different type" do
      source = <<-CRYSTAL
        x = 42
        x = "hello"
        x
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Last assignment wins
      ident_type = engine.context.get_type(program.roots[2])
      ident_type.should be_a(PrimitiveType)
      ident_type.as(PrimitiveType).name.should eq("String")
    end
  end

  describe "Phase 5: Numeric Promotion (Production Fallback)" do
    it "promotes Int32 + Int64 to Int64" do
      source = "42_i32 + 100_i64"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int64")
    end

    it "promotes Int32 + Float64 to Float64" do
      source = "42_i32 + 3.14_f64"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Float64")
    end

    it "promotes Int64 + Float64 to Float64" do
      source = "100_i64 + 2.5_f64"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Float64")
    end

    it "keeps Int32 + Int32 as Int32" do
      source = "42_i32 + 100_i32"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "keeps Int64 + Int64 as Int64" do
      source = "100_i64 + 200_i64"
      program, analyzer, engine = infer_types(source)

      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int64")
    end

    it "promotes in complex expressions" do
      source = "1_i32 + 2_i64 * 3_i32"
      program, analyzer, engine = infer_types(source)

      # 2_i64 * 3_i32 → Int64 (promotion)
      # 1_i32 + Int64 → Int64 (promotion)
      root_id = program.roots[0]
      type = engine.context.get_type(root_id)

      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int64")
    end
  end

  describe "Diagnostic Spans" do
    it "reports actual error location for type mismatch" do
      source = <<-CRYSTAL
        x = 42
        y = "hello" + x
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Should have 1 diagnostic
      engine.diagnostics.size.should eq(1)

      diagnostic = engine.diagnostics[0]
      diagnostic.message.should contain("not defined for")

      # Verify span points to actual error location (line 2)
      diagnostic.primary_span.start_line.should eq(2)

      # Should not be dummy span (0,0)
      diagnostic.primary_span.start_line.should_not eq(0)
      diagnostic.primary_span.start_column.should_not eq(0)
    end

    it "reports correct location for boolean type error" do
      source = <<-CRYSTAL
        if 42
          "oops"
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      engine.diagnostics.size.should eq(1)
      diagnostic = engine.diagnostics[0]

      # Error should point to condition location
      diagnostic.primary_span.start_line.should eq(1)
      diagnostic.primary_span.start_line.should_not eq(0)
    end
  end

  describe "Phase 4B.3: Built-in Methods for Primitive Types" do
    it "resolves Int32#+ as built-in method" do
      source = <<-CRYSTAL
        x = 5
        y = 10
        z = x + y
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # z = x + y should use Int32#+(Int32) : Int32
      assign_id = program.roots[2]
      type = engine.context.get_type(assign_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "resolves Int32#< as built-in method" do
      source = <<-CRYSTAL
        result = 5 < 10
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # 5 < 10 should use Int32#<(Int32) : Bool
      assign_id = program.roots[0]
      type = engine.context.get_type(assign_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Bool")
    end

    it "resolves String#size as built-in method" do
      source = <<-CRYSTAL
        s = "hello"
        len = s.size
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # s.size should use String#size : Int32
      assign_id = program.roots[1]
      type = engine.context.get_type(assign_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "resolves String#+ as built-in method" do
      source = <<-CRYSTAL
        result = "hello" + " world"
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # "hello" + " world" should use String#+(String) : String
      assign_id = program.roots[0]
      type = engine.context.get_type(assign_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("String")
    end

    it "resolves Bool#== as built-in method" do
      source = <<-CRYSTAL
        result = true == false
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # true == false should use Bool#==(Bool) : Bool
      assign_id = program.roots[0]
      type = engine.context.get_type(assign_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Bool")
    end

    it "works with method calls on variables" do
      source = <<-CRYSTAL
        x = 42
        y = 10
        greater = x > y
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # x > y should use Int32#>(Int32) : Bool
      assign_id = program.roots[2]
      type = engine.context.get_type(assign_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Bool")
    end
  end

  describe "Phase 4B.4: Union Type Method Lookup" do
    it "finds method common to all union types" do
      source = <<-CRYSTAL
        x = if true
          42
        else
          "hello"
        end
        result = x == x
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # x : Int32 | String
      # Both Int32 and String have == method → should work
      # result type should be Bool
      result_id = program.roots[1]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Bool")

      # Should have no errors
      engine.diagnostics.size.should eq(0)
    end

    it "emits error when method not in all union types" do
      source = <<-CRYSTAL
        x = if true
          42
        else
          "hello"
        end
        result = x.size
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # x : Int32 | String
      # String has size, but Int32 doesn't → error
      engine.diagnostics.size.should eq(1)
      engine.diagnostics[0].message.should contain("not found")
    end

    it "works with union of three types" do
      source = <<-CRYSTAL
        x = if true
          1
        elsif false
          2
        else
          3
        end
        result = x == 5
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # x : Int32 (normalized from Int32 | Int32 | Int32)
      # Should work because all are Int32
      result_id = program.roots[1]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Bool")
    end

    it "finds method in union with primitives" do
      source = <<-CRYSTAL
        x = if true
          5
        else
          10
        end
        result = x + 3
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # x : Int32 | Int32 → Int32 (normalized)
      # Int32 has + method
      result_id = program.roots[1]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "computes union return type for methods with different return types" do
      source = <<-CRYSTAL
        class A
          def foo : Int32
            42
          end
        end

        class B
          def foo : String
            "hello"
          end
        end

        x = if true
          A.new
        else
          B.new
        end
        result = x.foo
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # x : A | B (InstanceType(A) | InstanceType(B))
      # A.foo : Int32, B.foo : String
      # result : Int32 | String
      result_id = program.roots[3]
      type = engine.context.get_type(result_id)
      type.should be_a(UnionType)

      union = type.as(UnionType)
      union.types.size.should eq(2)

      type_names = union.types.map(&.to_s).sort
      type_names.should eq(["Int32", "String"])
    end

    it "handles union return type when all return same type" do
      source = <<-CRYSTAL
        class A
          def foo : String
            "a"
          end
        end

        class B
          def foo : String
            "b"
          end
        end

        x = if true
          A.new
        else
          B.new
        end
        result = x.foo
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # x : A | B
      # Both return String
      # result : String | String → String (normalized)
      result_id = program.roots[3]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("String")
    end
  end

  describe "Phase 5A: Instance Variables" do
    it "infers type from instance variable assignment" do
      source = <<-CRYSTAL
        @x = 42
        result = @x
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # @x : Int32 (inferred from assignment)
      # result : Int32
      result_id = program.roots[1]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers type from string instance variable" do
      source = <<-CRYSTAL
        @name = "hello"
        result = @name
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # @name : String
      # result : String
      result_id = program.roots[1]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("String")
    end

    it "handles multiple instance variables" do
      source = <<-CRYSTAL
        @x = 42
        @name = "test"
        result_x = @x
        result_name = @name
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # result_x : Int32
      result_x_id = program.roots[2]
      type_x = engine.context.get_type(result_x_id)
      type_x.should be_a(PrimitiveType)
      type_x.as(PrimitiveType).name.should eq("Int32")

      # result_name : String
      result_name_id = program.roots[3]
      type_name = engine.context.get_type(result_name_id)
      type_name.should be_a(PrimitiveType)
      type_name.as(PrimitiveType).name.should eq("String")
    end

    it "returns Nil for uninitialized instance variable" do
      source = <<-CRYSTAL
        result = @uninitialized
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # @uninitialized not assigned → Nil
      result_id = program.roots[0]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Nil")
    end
  end

  describe "Phase 5B: Instance Variables in Method Bodies" do
    it "infers instance variable type from initialize method" do
      source = <<-CRYSTAL
        class Counter
          def initialize
            @count = 0
          end

          def get_count : Int32
            @count
          end
        end

        c = Counter.new
        result = c.get_count
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # result : Int32 (from method return annotation)
      # @count should be Int32 (from initialize assignment)
      result_id = program.roots[2]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles instance variable assigned and read in same method" do
      source = <<-CRYSTAL
        class Foo
          def test : Int32
            @x = 42
            @x
          end
        end

        foo = Foo.new
        result = foo.test
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # @x : Int32 (assigned in test method)
      # result : Int32
      result_id = program.roots[2]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles multiple classes with same instance variable names" do
      source = <<-CRYSTAL
        class Foo
          def initialize
            @x = 42
          end

          def get_x : Int32
            @x
          end
        end

        class Bar
          def initialize
            @x = "hello"
          end

          def get_x : String
            @x
          end
        end

        foo = Foo.new
        bar = Bar.new
        result_foo = foo.get_x
        result_bar = bar.get_x
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # result_foo : Int32 (from Foo.get_x)
      result_foo_id = program.roots[4]
      type_foo = engine.context.get_type(result_foo_id)
      type_foo.should be_a(PrimitiveType)
      type_foo.as(PrimitiveType).name.should eq("Int32")

      # result_bar : String (from Bar.get_x)
      result_bar_id = program.roots[5]
      type_bar = engine.context.get_type(result_bar_id)
      type_bar.should be_a(PrimitiveType)
      type_bar.as(PrimitiveType).name.should eq("String")
    end

    it "handles instance variable modification" do
      source = <<-CRYSTAL
        class Counter
          def initialize
            @count = 0
          end

          def increment : Int32
            @count = @count + 1
            @count
          end
        end

        c = Counter.new
        result = c.increment
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # @count : Int32 (from initialize)
      # @count + 1 : Int32
      # result : Int32
      result_id = program.roots[2]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end
  end

  describe "Phase 5C: Explicit Type Annotations for Instance Variables" do
    it "uses explicit type annotation without assignment" do
      source = <<-CRYSTAL
        class Foo
          @x : Int32

          def get_x : Int32
            @x
          end
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Verify ClassSymbol has type annotation
      foo_symbol = analyzer.global_context.symbol_table.lookup("Foo")
      foo_symbol.should be_a(ClassSymbol)
      foo_symbol.as(ClassSymbol).get_instance_var_type("x").should eq("Int32")
    end

    it "uses explicit type annotation with assignment" do
      source = <<-CRYSTAL
        class Foo
          @x : Int32
          @name : String

          def initialize
            @x = 42
            @name = "test"
          end

          def get_x : Int32
            @x
          end

          def get_name : String
            @name
          end
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Verify both annotations are preserved
      foo_symbol = analyzer.global_context.symbol_table.lookup("Foo")
      foo_symbol.should be_a(ClassSymbol)
      foo_symbol.as(ClassSymbol).get_instance_var_type("x").should eq("Int32")
      foo_symbol.as(ClassSymbol).get_instance_var_type("name").should eq("String")
    end

    it "handles multiple classes with explicit annotations" do
      source = <<-CRYSTAL
        class Foo
          @value : Int32

          def get_value : Int32
            @value
          end
        end

        class Bar
          @value : String

          def get_value : String
            @value
          end
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Verify each class has its own type annotation
      foo_symbol = analyzer.global_context.symbol_table.lookup("Foo")
      foo_symbol.should be_a(ClassSymbol)
      foo_symbol.as(ClassSymbol).get_instance_var_type("value").should eq("Int32")

      bar_symbol = analyzer.global_context.symbol_table.lookup("Bar")
      bar_symbol.should be_a(ClassSymbol)
      bar_symbol.as(ClassSymbol).get_instance_var_type("value").should eq("String")
    end

    it "prioritizes explicit annotation over inferred assignment" do
      source = <<-CRYSTAL
        class Foo
          @x : Int32

          def initialize
            @x = 42
          end

          def get_x : Int32
            @x
          end
        end

        foo = Foo.new
        result = foo.get_x
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # result : Int32 (from method return annotation, which matches @x annotation)
      result_id = program.roots[2]
      type = engine.context.get_type(result_id)
      type.should be_a(PrimitiveType)
      type.as(PrimitiveType).name.should eq("Int32")
    end
  end

  describe "Phase 6: Return Statements" do
    it "infers type for return with value" do
      source = <<-CRYSTAL
        def test : Int32
          return 42
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get return statement from method body
      def_node = program.arena[program.roots[0]]
      body = def_node.def_body
      body.should_not be_nil
      return_expr_id = body.not_nil![0]

      # Return statement should have Int32 type
      return_type = engine.context.get_type(return_expr_id)
      return_type.should be_a(PrimitiveType)
      return_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers Nil for return without value" do
      source = <<-CRYSTAL
        def test : Nil
          return
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get return statement from method body
      def_node = program.arena[program.roots[0]]
      body = def_node.def_body
      body.should_not be_nil
      return_expr_id = body.not_nil![0]

      # Return statement should have Nil type
      return_type = engine.context.get_type(return_expr_id)
      return_type.should be_a(PrimitiveType)
      return_type.as(PrimitiveType).name.should eq("Nil")
    end

    it "handles early return in conditional (postfix if)" do
      source = <<-CRYSTAL
        def test(x : Int32) : String
          return "negative" if x < 0
          "positive"
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get if statement from method body
      def_node = program.arena[program.roots[0]]
      body = def_node.def_body
      body.should_not be_nil
      if_expr_id = body.not_nil![0]
      if_node = program.arena[if_expr_id]

      # Check that then branch is a return statement
      then_branch = if_node.if_then
      then_branch.should_not be_nil
      return_expr_id = then_branch.not_nil![0]
      return_node = program.arena[return_expr_id]
      return_node.kind.should eq(ExpressionNode::Kind::Return)

      # Return statement should have String type
      return_type = engine.context.get_type(return_expr_id)
      return_type.should be_a(PrimitiveType)
      return_type.as(PrimitiveType).name.should eq("String")
    end

    it "handles return in while loop (postfix if)" do
      source = <<-CRYSTAL
        def test : Int32
          x = 0
          while x < 10
            x = x + 1
            return x if x == 5
          end
          x
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get while statement from method body
      def_node = program.arena[program.roots[0]]
      body = def_node.def_body
      body.should_not be_nil
      while_expr_id = body.not_nil![1]  # Second statement (after x = 0)
      while_node = program.arena[while_expr_id]

      # Check that while body contains an if with return
      while_body = while_node.while_body
      while_body.should_not be_nil

      # Find the if statement in the while body
      if_expr_id = while_body.not_nil![1]  # Second statement in while (after x = x + 1)
      if_node = program.arena[if_expr_id]

      # Check return in if then branch
      then_branch = if_node.if_then
      then_branch.should_not be_nil
      return_expr_id = then_branch.not_nil![0]
      return_node = program.arena[return_expr_id]
      return_node.kind.should eq(ExpressionNode::Kind::Return)

      # Return statement should have Int32 type
      return_type = engine.context.get_type(return_expr_id)
      return_type.should be_a(PrimitiveType)
      return_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles multiple return statements (postfix if)" do
      source = <<-CRYSTAL
        def test(x : Int32) : String
          return "zero" if x == 0
          return "one" if x == 1
          "other"
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get method body
      def_node = program.arena[program.roots[0]]
      body = def_node.def_body
      body.should_not be_nil

      # First if with return
      if1_node = program.arena[body.not_nil![0]]
      return1_id = if1_node.if_then.not_nil![0]
      return1_type = engine.context.get_type(return1_id)
      return1_type.should be_a(PrimitiveType)
      return1_type.as(PrimitiveType).name.should eq("String")

      # Second if with return
      if2_node = program.arena[body.not_nil![1]]
      return2_id = if2_node.if_then.not_nil![0]
      return2_type = engine.context.get_type(return2_id)
      return2_type.should be_a(PrimitiveType)
      return2_type.as(PrimitiveType).name.should eq("String")
    end
  end

  describe "Phase 7: Self Keyword" do
    it "infers InstanceType for self in method" do
      source = <<-CRYSTAL
        class Dog
          def get_self
            self
          end
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get self expression from method body
      class_node = program.arena[program.roots[0]]
      def_node = program.arena[class_node.class_body.not_nil![0]]
      self_expr_id = def_node.def_body.not_nil![0]

      # Check self has InstanceType(Dog)
      self_type = engine.context.get_type(self_expr_id)
      self_type.should be_a(InstanceType)
      self_type.as(InstanceType).class_symbol.name.should eq("Dog")
    end

    it "handles self return for method chaining" do
      source = <<-CRYSTAL
        class Builder
          def step1
            self
          end

          def step2
            self
          end
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get both methods
      class_node = program.arena[program.roots[0]]
      class_body = class_node.class_body.not_nil!

      # Check step1 returns self
      def1_node = program.arena[class_body[0]]
      self1_expr_id = def1_node.def_body.not_nil![0]
      self1_type = engine.context.get_type(self1_expr_id)
      self1_type.should be_a(InstanceType)
      self1_type.as(InstanceType).class_symbol.name.should eq("Builder")

      # Check step2 returns self
      def2_node = program.arena[class_body[1]]
      self2_expr_id = def2_node.def_body.not_nil![0]
      self2_type = engine.context.get_type(self2_expr_id)
      self2_type.should be_a(InstanceType)
      self2_type.as(InstanceType).class_symbol.name.should eq("Builder")
    end

    it "handles different self types in different classes" do
      source = <<-CRYSTAL
        class Dog
          def who_am_i
            self
          end
        end

        class Cat
          def who_am_i
            self
          end
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get Dog's self
      dog_class = program.arena[program.roots[0]]
      dog_def = program.arena[dog_class.class_body.not_nil![0]]
      dog_self_id = dog_def.def_body.not_nil![0]
      dog_self_type = engine.context.get_type(dog_self_id)
      dog_self_type.should be_a(InstanceType)
      dog_self_type.as(InstanceType).class_symbol.name.should eq("Dog")

      # Get Cat's self
      cat_class = program.arena[program.roots[1]]
      cat_def = program.arena[cat_class.class_body.not_nil![0]]
      cat_self_id = cat_def.def_body.not_nil![0]
      cat_self_type = engine.context.get_type(cat_self_id)
      cat_self_type.should be_a(InstanceType)
      cat_self_type.as(InstanceType).class_symbol.name.should eq("Cat")
    end

    it "handles self in conditional return" do
      source = <<-CRYSTAL
        class Node
          def conditional_self(flag : Bool)
            return self if flag
            self
          end
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get method body
      class_node = program.arena[program.roots[0]]
      def_node = program.arena[class_node.class_body.not_nil![0]]
      def_body = def_node.def_body.not_nil!

      # First statement is if (with postfix)
      if_node = program.arena[def_body[0]]
      return_node = program.arena[if_node.if_then.not_nil![0]]
      self1_id = return_node.return_value.not_nil!
      self1_type = engine.context.get_type(self1_id)
      self1_type.should be_a(InstanceType)
      self1_type.as(InstanceType).class_symbol.name.should eq("Node")

      # Second statement is bare self
      self2_id = def_body[1]
      self2_type = engine.context.get_type(self2_id)
      self2_type.should be_a(InstanceType)
      self2_type.as(InstanceType).class_symbol.name.should eq("Node")
    end
  end

  # ============================================================
  # PHASE 8: String Interpolation Tests
  # ============================================================

  describe "Phase 8: String Interpolation" do
    it "infers String type for basic interpolation" do
      source = <<-CRYSTAL
        name = "World"
        msg = "Hello, \#{name}!"
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get msg assignment
      msg_assign = program.arena[program.roots[1]]
      interpolated_str_id = msg_assign.assign_value.not_nil!
      interpolated_type = engine.context.get_type(interpolated_str_id)

      interpolated_type.should be_a(PrimitiveType)
      interpolated_type.as(PrimitiveType).name.should eq("String")
    end

    it "infers types for interpolated expressions" do
      source = <<-CRYSTAL
        x = 5
        y = 10
        result = "Sum: \#{x + y}"
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get result assignment
      result_assign = program.arena[program.roots[2]]
      interpolated_str_id = result_assign.assign_value.not_nil!
      interpolated_node = program.arena[interpolated_str_id]

      # Check the interpolated string type
      interpolated_type = engine.context.get_type(interpolated_str_id)
      interpolated_type.should be_a(PrimitiveType)
      interpolated_type.as(PrimitiveType).name.should eq("String")

      # Check the expression inside interpolation (x + y)
      pieces = interpolated_node.string_pieces.not_nil!
      expr_piece = pieces.find { |p| p.kind == StringPiece::Kind::Expression }.not_nil!
      expr_id = expr_piece.expr.not_nil!
      expr_type = engine.context.get_type(expr_id)
      expr_type.should be_a(PrimitiveType)
      expr_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles multiple interpolations" do
      source = <<-CRYSTAL
        a = 1
        b = 2
        c = 3
        text = "Values: \#{a}, \#{b}, \#{c}"
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get text assignment
      text_assign = program.arena[program.roots[3]]
      interpolated_str_id = text_assign.assign_value.not_nil!
      interpolated_node = program.arena[interpolated_str_id]

      # Check overall type
      interpolated_type = engine.context.get_type(interpolated_str_id)
      interpolated_type.should be_a(PrimitiveType)
      interpolated_type.as(PrimitiveType).name.should eq("String")

      # Check that we have text and expression pieces
      pieces = interpolated_node.string_pieces.not_nil!
      # "Values: ", a, ", ", b, ", ", c
      pieces.size.should eq(6)

      # Count expression pieces
      expr_pieces = pieces.select { |p| p.kind == StringPiece::Kind::Expression }
      expr_pieces.size.should eq(3)
    end

    it "handles nested interpolation" do
      source = <<-CRYSTAL
        outer = "outer"
        inner = "The \#{outer} value"
        full = "Full: \#{inner}"
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get full assignment
      full_assign = program.arena[program.roots[2]]
      full_str_id = full_assign.assign_value.not_nil!
      full_type = engine.context.get_type(full_str_id)

      full_type.should be_a(PrimitiveType)
      full_type.as(PrimitiveType).name.should eq("String")

      # Get inner assignment
      inner_assign = program.arena[program.roots[1]]
      inner_str_id = inner_assign.assign_value.not_nil!
      inner_type = engine.context.get_type(inner_str_id)

      inner_type.should be_a(PrimitiveType)
      inner_type.as(PrimitiveType).name.should eq("String")
    end

    it "handles method calls in interpolation" do
      source = <<-CRYSTAL
        class Dog
          def initialize(@name : String)
          end

          def bark
            "Woof!"
          end

          def introduce
            "I am \#{@name} and I say \#{bark}"
          end
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get class node
      class_node = program.arena[program.roots[0]]
      class_body = class_node.class_body.not_nil!

      # Find introduce method (should be third method)
      introduce_def = program.arena[class_body[2]]
      introduce_body = introduce_def.def_body.not_nil!
      interpolated_str_id = introduce_body[0]

      # Check interpolated string type
      interpolated_type = engine.context.get_type(interpolated_str_id)
      interpolated_type.should be_a(PrimitiveType)
      interpolated_type.as(PrimitiveType).name.should eq("String")

      # Check interpolation contains method call
      interpolated_node = program.arena[interpolated_str_id]
      pieces = interpolated_node.string_pieces.not_nil!

      # Should have: "I am ", @name, " and I say ", bark call
      pieces.size.should eq(4)
    end
  end

  # ============================================================
  # PHASE 9: Array Tests
  # ============================================================

  describe "Phase 9: Arrays" do
    it "infers Array(Int32) for integer array" do
      source = <<-CRYSTAL
        arr = [1, 2, 3]
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get array assignment
      arr_assign = program.arena[program.roots[0]]
      array_id = arr_assign.assign_value.not_nil!
      array_type = engine.context.get_type(array_id)

      array_type.should be_a(ArrayType)
      array_type.as(ArrayType).element_type.should be_a(PrimitiveType)
      array_type.as(ArrayType).element_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers Array(String) for string array" do
      source = <<-CRYSTAL
        names = ["Alice", "Bob", "Charlie"]
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      arr_assign = program.arena[program.roots[0]]
      array_id = arr_assign.assign_value.not_nil!
      array_type = engine.context.get_type(array_id)

      array_type.should be_a(ArrayType)
      array_type.as(ArrayType).element_type.as(PrimitiveType).name.should eq("String")
    end

    it "infers union type for heterogeneous array" do
      source = <<-CRYSTAL
        mixed = [1, "hello", true]
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      arr_assign = program.arena[program.roots[0]]
      array_id = arr_assign.assign_value.not_nil!
      array_type = engine.context.get_type(array_id)

      array_type.should be_a(ArrayType)
      element_type = array_type.as(ArrayType).element_type
      element_type.should be_a(UnionType)
    end

    it "handles empty array with 'of Type' syntax" do
      source = <<-CRYSTAL
        empty = [] of Int32
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      arr_assign = program.arena[program.roots[0]]
      array_id = arr_assign.assign_value.not_nil!
      array_type = engine.context.get_type(array_id)

      array_type.should be_a(ArrayType)
      array_type.as(ArrayType).element_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "infers element type from array indexing" do
      source = <<-CRYSTAL
        arr = [1, 2, 3]
        x = arr[0]
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get x assignment
      x_assign = program.arena[program.roots[1]]
      index_expr_id = x_assign.assign_value.not_nil!
      index_type = engine.context.get_type(index_expr_id)

      index_type.should be_a(PrimitiveType)
      index_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles nested arrays" do
      source = <<-CRYSTAL
        nested = [[1, 2], [3, 4]]
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      arr_assign = program.arena[program.roots[0]]
      array_id = arr_assign.assign_value.not_nil!
      array_type = engine.context.get_type(array_id)

      array_type.should be_a(ArrayType)
      inner_type = array_type.as(ArrayType).element_type
      inner_type.should be_a(ArrayType)
      inner_type.as(ArrayType).element_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles array.size method" do
      source = <<-CRYSTAL
        arr = [1, 2, 3]
        len = arr.size
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Get len assignment
      len_assign = program.arena[program.roots[1]]
      size_call_id = len_assign.assign_value.not_nil!
      size_type = engine.context.get_type(size_call_id)

      size_type.should be_a(PrimitiveType)
      size_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles array.empty? method" do
      source = <<-CRYSTAL
        arr = [1, 2, 3]
        is_empty = arr.empty?
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      empty_assign = program.arena[program.roots[1]]
      empty_call_id = empty_assign.assign_value.not_nil!
      empty_type = engine.context.get_type(empty_call_id)

      empty_type.should be_a(PrimitiveType)
      empty_type.as(PrimitiveType).name.should eq("Bool")
    end

    it "handles array.first and array.last" do
      source = <<-CRYSTAL
        arr = [1, 2, 3]
        f = arr.first
        l = arr.last
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      # Check first
      f_assign = program.arena[program.roots[1]]
      first_id = f_assign.assign_value.not_nil!
      first_type = engine.context.get_type(first_id)

      first_type.should be_a(PrimitiveType)
      first_type.as(PrimitiveType).name.should eq("Int32")

      # Check last
      l_assign = program.arena[program.roots[2]]
      last_id = l_assign.assign_value.not_nil!
      last_type = engine.context.get_type(last_id)

      last_type.should be_a(PrimitiveType)
      last_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles array << push operator" do
      source = <<-CRYSTAL
        arr = [1, 2, 3]
        result = arr << 4
      CRYSTAL

      program, analyzer, engine = infer_types(source)

      result_assign = program.arena[program.roots[1]]
      push_id = result_assign.assign_value.not_nil!
      push_type = engine.context.get_type(push_id)

      # << returns the array itself
      push_type.should be_a(ArrayType)
      push_type.as(ArrayType).element_type.as(PrimitiveType).name.should eq("Int32")
    end
  end

  describe "Phase 10: Blocks and Yield" do
    it "handles yield expressions" do
      source = <<-CRYSTAL
        def twice
          yield 1
          yield 2
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)
      # Method should exist and parse correctly
      program.roots.size.should eq(1)

      # Check that yields have Nil type
      def_node = program.arena[program.roots[0]]
      body = def_node.def_body.not_nil!
      yield1 = engine.context.get_type(body[0])
      yield1.as(PrimitiveType).name.should eq("Nil")
    end

    it "handles do/end block syntax" do
      source = <<-CRYSTAL
        def run
          yield 42
        end

        run do |n|
          n * 2
        end
      CRYSTAL

      program, analyzer, engine = infer_types(source)
      # Should parse without errors
      program.roots.size.should eq(2)
    end

    it "handles brace block syntax" do
      source = <<-CRYSTAL
        def run
          yield 5
        end

        run { |x| x + 1 }
      CRYSTAL

      program, analyzer, engine = infer_types(source)
      # Should parse without errors
      program.roots.size.should eq(2)
    end

    it "infers block return type from last expression" do
      source = <<-CRYSTAL
        def transform
          yield 10
        end

        transform { 42 }
      CRYSTAL

      program, analyzer, engine = infer_types(source)
      # Get the call with block
      call_node = program.arena[program.roots[1]]
      block_id = call_node.call_block.not_nil!
      block_type = engine.context.get_type(block_id)

      # Block should return Int32 (from literal 42)
      block_type.as(PrimitiveType).name.should eq("Int32")
    end

    it "handles empty block" do
      source = <<-CRYSTAL
        def run
          yield
        end

        run { }
      CRYSTAL

      program, analyzer, engine = infer_types(source)
      # Should parse without errors
      program.roots.size.should eq(2)

      # Empty block returns Nil
      call_node = program.arena[program.roots[1]]
      block_id = call_node.call_block.not_nil!
      block_type = engine.context.get_type(block_id)
      block_type.as(PrimitiveType).name.should eq("Nil")
    end
  end
end
