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
end
