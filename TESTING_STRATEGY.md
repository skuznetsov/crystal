# CrystalV2 Testing Strategy

## Current Test Coverage

### ✅ Parser Tests (Existing)
- **Location:** `crystal_v2/test/parser_regression_test.cr`
- **Coverage:** 30 tests covering all major constructs
- **Status:** All passing ✅

---

## Testing Strategy: 4-Layer Pyramid

```
         /\
        /  \    Integration Tests (E2E)
       /----\
      /      \  Component Tests (Type Inference, Semantic)
     /--------\
    /          \ Unit Tests (Individual methods)
   /------------\
  /              \ Regression Tests (No breaking changes)
```

---

## Phase 0: Test Infrastructure (1 week)

### Goal: Set up robust test framework

**Tasks:**
1. **Spec Framework Setup** (1 day)
   ```crystal
   # crystal_v2/spec/spec_helper.cr
   require "spec"
   require "../src/**"

   # Custom matchers for AST comparison
   # Performance benchmarking helpers
   # Fixtures for common test cases
   ```

2. **Test Fixtures** (2 days)
   - Create `spec/fixtures/` with sample Crystal files
   - Positive cases (valid code)
   - Negative cases (invalid code with expected errors)
   - Edge cases (tricky syntax, ambiguous parsing)

3. **CI/CD Setup** (2 days)
   - GitHub Actions workflow
   - Run all tests on every commit
   - Performance regression tracking

---

## Layer 1: Unit Tests (Ongoing)

### Parser Unit Tests

**Location:** `crystal_v2/spec/parser/`

#### Literals (`spec/parser/literals_spec.cr`)
```crystal
describe "Parser::Literals" do
  describe "numbers" do
    it "parses integers" do
      result = parse("42")
      result.should be_a(NumberNode)
    end

    it "parses floats" do
      result = parse("3.14")
      # ...
    end

    it "parses hex/bin/octal" do
      parse("0xFF").should eq_number(255)
      parse("0b1010").should eq_number(10)
      parse("0o77").should eq_number(63)
    end

    it "rejects invalid numbers" do
      expect_raises(ParseError) { parse("0x") }
      expect_raises(ParseError) { parse("1.2.3") }
    end
  end

  describe "strings" do
    it "parses simple strings" do
      parse("\"hello\"").should be_string("hello")
    end

    it "handles escapes" do
      parse("\"\\n\\t\\r\"").should be_string("\n\t\r")
    end

    it "handles interpolation" do
      result = parse("\"value: #{x}\"")
      result.should be_a(StringInterpolationNode)
    end

    it "rejects unclosed strings" do
      expect_raises(ParseError) { parse("\"hello") }
    end
  end
end
```

#### Expressions (`spec/parser/expressions_spec.cr`)
```crystal
describe "Parser::Expressions" do
  describe "binary operators" do
    it "respects precedence" do
      # 1 + 2 * 3 => (1 + (2 * 3))
      tree = parse("1 + 2 * 3")
      tree.should be_binary("+",
        left: number(1),
        right: binary("*", number(2), number(3))
      )
    end

    it "handles associativity" do
      # 1 - 2 - 3 => ((1 - 2) - 3) (left-assoc)
      tree = parse("1 - 2 - 3")
      tree.should be_left_associative
    end
  end

  describe "method calls" do
    it "parses receiver.method" do
      tree = parse("obj.foo")
      tree.should be_call("foo", receiver: ident("obj"))
    end

    it "parses with arguments" do
      tree = parse("obj.foo(1, 2)")
      tree.should be_call("foo", args: [number(1), number(2)])
    end
  end
end
```

---

### Type Inference Unit Tests

**Location:** `crystal_v2/spec/type_inference/`

#### Basic Types (`spec/type_inference/basic_types_spec.cr`)
```crystal
describe "TypeInference::BasicTypes" do
  it "infers literal types" do
    infer("42").should eq(Int32)
    infer("3.14").should eq(Float64)
    infer("\"hello\"").should eq(String)
    infer("true").should eq(Bool)
  end

  it "infers variable types from assignment" do
    code = <<-CRYSTAL
      x = 42
      x
    CRYSTAL
    infer(code).should eq(Int32)
  end

  it "infers method return types" do
    code = <<-CRYSTAL
      def foo
        42
      end
      foo
    CRYSTAL
    infer(code).should eq(Int32)
  end
end
```

#### Generic Types (`spec/type_inference/generics_spec.cr`)
```crystal
describe "TypeInference::Generics" do
  it "instantiates generic methods" do
    code = <<-CRYSTAL
      def identity(x : T) forall T
        x
      end
      identity(42)
    CRYSTAL
    infer(code).should eq(Int32)
  end

  it "infers generic types from usage" do
    code = <<-CRYSTAL
      class Box(T)
        def initialize(@value : T); end
        def get; @value; end
      end

      box = Box.new(42)
      box.get
    CRYSTAL
    infer(code).should eq(Int32)
  end

  it "handles multiple type parameters" do
    code = <<-CRYSTAL
      class Pair(A, B)
        def initialize(@a : A, @b : B); end
      end
      Pair.new(1, "hello")
    CRYSTAL
    infer(code).should eq(Pair(Int32, String))
  end

  it "rejects incompatible constraints" do
    code = <<-CRYSTAL
      def foo(x : T) forall T where T < Number
        x * 2
      end
      foo("string")
    CRYSTAL
    expect_raises(TypeMismatch) { infer(code) }
  end
end
```

#### Union Types (`spec/type_inference/unions_spec.cr`)
```crystal
describe "TypeInference::Unions" do
  it "creates unions for if/else" do
    code = <<-CRYSTAL
      if condition
        42
      else
        "hello"
      end
    CRYSTAL
    infer(code).should eq(Int32 | String)
  end

  it "narrows types with is_a?" do
    code = <<-CRYSTAL
      x : Int32 | String = get_value
      if x.is_a?(Int32)
        x + 1  # x is Int32 here
      end
    CRYSTAL

    # In the if branch, x should be Int32 (not union)
    infer_in_branch(code, :if).should eq(Int32)
  end

  it "handles nilable types" do
    code = <<-CRYSTAL
      x : Int32? = nil
      if x
        x + 1  # x is Int32 here (not nilable)
      end
    CRYSTAL

    infer_in_branch(code, :if).should eq(Int32)
  end
end
```

---

## Layer 2: Component Tests

### FileLoader Tests (`spec/file_loader_spec.cr`)

```crystal
describe "FileLoader" do
  describe "single file" do
    it "loads file without requires" do
      loader = FileLoader.new(["/tmp"])
      program = loader.load_with_requires("/tmp/simple.cr")

      program.roots.size.should be > 0
      loader.stats[:files_loaded].should eq(1)
    end
  end

  describe "multi-file" do
    it "follows requires" do
      # Fixture:
      #   /tmp/main.cr:  require "./helper"
      #   /tmp/helper.cr: def helper; end

      loader = FileLoader.new(["/tmp"])
      program = loader.load_with_requires("/tmp/main.cr")

      loader.stats[:files_loaded].should eq(2)
    end

    it "deduplicates requires" do
      # Fixture:
      #   /tmp/a.cr: require "./shared"
      #   /tmp/b.cr: require "./shared"
      #   /tmp/main.cr: require "./a"; require "./b"

      loader = FileLoader.new(["/tmp"])
      program = loader.load_with_requires("/tmp/main.cr")

      loader.stats[:parse_count].should eq(4)  # main, a, b, shared (once!)
    end
  end

  describe "shards" do
    it "loads from lib/" do
      loader = FileLoader.new(["/project/src", "/project/lib/shard/src"])
      program = loader.load_with_requires("/project/src/main.cr")

      # Should load shard files
      loader.stats[:files_loaded].should be > 1
    end
  end

  describe "performance" do
    it "loads large project fast" do
      loader = FileLoader.new(search_paths, parallel: true)

      time = measure do
        loader.load_with_requires("/tmp/kemal/src/kemal.cr")
      end

      time.should be < 500.milliseconds  # Regression check
    end
  end
end
```

---

## Layer 3: Integration Tests (E2E)

### LSP Server Tests (`spec/lsp/`

)

```crystal
describe "LSPServer" do
  describe "didOpen" do
    it "parses document and reports errors" do
      server = LSPServer.new

      server.did_open(uri: "file:///test.cr", text: "def foo; x; end")

      diagnostics = server.get_diagnostics("file:///test.cr")
      diagnostics.should contain_error("undefined variable 'x'")
    end
  end

  describe "hover" do
    it "shows type information" do
      server = LSPServer.new
      server.did_open(uri: "file:///test.cr", text: "x = 42")

      hover = server.hover(uri: "file:///test.cr", line: 0, char: 0)
      hover.should contain("Int32")
    end
  end

  describe "goto definition" do
    it "finds method definition" do
      server = LSPServer.new
      server.did_open(uri: "file:///test.cr", text: <<-CRYSTAL
        def foo; end
        foo
      CRYSTAL)

      location = server.goto_definition(uri: "file:///test.cr", line: 1, char: 0)
      location.line.should eq(0)  # Points to def foo
    end
  end
end
```

---

## Layer 4: Regression Tests

### Parser Regression (`spec/regression/parser_spec.cr`)

```crystal
describe "Parser Regression" do
  # Baseline: parser.cr should always parse to same node count
  it "parses parser.cr consistently" do
    lexer = Lexer.new(File.read("/path/to/parser.cr"))
    parser = Parser.new(lexer)
    program = parser.parse_program

    program.arena.size.should eq(14377)  # Established baseline
  end

  # Test cases from bug reports
  it "handles issue #123: ampersand in block" do
    # Regression test for specific bug
    code = "[1, 2, 3].map(&.to_s)"
    expect_no_error { parse(code) }
  end
end
```

### Type Inference Regression (`spec/regression/inference_spec.cr`)

```crystal
describe "TypeInference Regression" do
  # Test cases from Original Crystal compiler
  it "handles all stdlib type inference tests" do
    # Load test cases from original compiler
    Dir.glob("/crystal/spec/compiler/type_inference/**/*_spec.cr").each do |file|
      context "#{File.basename(file)}" do
        # Run original tests against our inference engine
        # (May need adaptation)
      end
    end
  end
end
```

---

## Test Coverage Goals

### By Phase:

**Phase 1 (LSP MVP):**
- Parser: 95% coverage ✅
- FileLoader: 90% coverage ✅
- LSP Protocol: 80% coverage

**Phase 2 (Type Inference):**
- Type Inference: 85% coverage
- Generic Types: 90% coverage
- Union Types: 85% coverage

**Phase 3 (Semantic Analysis):**
- Symbol Resolution: 85% coverage
- Type Checking: 90% coverage

**Phase 4 (Codegen):**
- IR Generation: 75% coverage
- Optimization: 60% coverage

---

## Continuous Testing

### Pre-commit Hooks
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running fast tests..."
crystal spec --tag quick

if [ $? -ne 0 ]; then
  echo "❌ Quick tests failed. Commit aborted."
  exit 1
fi

echo "✓ All tests passed"
```

### CI/CD Pipeline (GitHub Actions)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Crystal
        uses: crystal-lang/install-crystal@v1
      - name: Run tests
        run: crystal spec
      - name: Check coverage
        run: crystal spec --coverage
      - name: Performance regression
        run: crystal run benchmarks/regression.cr
```

---

## Test Organization

```
crystal_v2/
├── spec/
│   ├── spec_helper.cr           # Shared test utilities
│   ├── fixtures/                # Test data
│   │   ├── valid/               # Valid Crystal code
│   │   ├── invalid/             # Invalid code with expected errors
│   │   └── edge_cases/          # Tricky cases
│   ├── parser/
│   │   ├── literals_spec.cr
│   │   ├── expressions_spec.cr
│   │   ├── statements_spec.cr
│   │   └── declarations_spec.cr
│   ├── type_inference/
│   │   ├── basic_types_spec.cr
│   │   ├── generics_spec.cr
│   │   ├── unions_spec.cr
│   │   └── constraints_spec.cr
│   ├── semantic/
│   │   ├── symbol_resolution_spec.cr
│   │   ├── type_checking_spec.cr
│   │   └── scope_spec.cr
│   ├── file_loader_spec.cr
│   ├── lsp/
│   │   ├── protocol_spec.cr
│   │   ├── features_spec.cr
│   │   └── performance_spec.cr
│   └── regression/
│       ├── parser_regression_spec.cr
│       └── inference_regression_spec.cr
└── test/                        # Integration tests (existing)
    └── parser_regression_test.cr
```

---

## Priority: Immediate Next Steps

### This Week:
1. ✅ Setup spec framework
2. ✅ Migrate existing regression test to spec format
3. ✅ Add 50 parser unit tests (literals + expressions)
4. ✅ Add 20 type inference tests (basic types)

### Next Week:
1. ✅ Add 50 more parser tests (statements + declarations)
2. ✅ Add 30 generic type tests
3. ✅ Add 20 union type tests
4. ✅ Setup CI/CD

**Goal:** 200+ tests before starting LSP implementation!

---

## Test Quality Guidelines

### Good Test Characteristics:
1. **Fast** - Unit tests < 1ms, Component tests < 100ms
2. **Isolated** - Each test independent
3. **Readable** - Clear intent, good naming
4. **Maintainable** - Easy to update when code changes

### Test Naming Convention:
```crystal
describe "ComponentName" do
  describe "#method_name" do
    context "when condition" do
      it "does expected behavior" do
        # Arrange
        input = setup_input

        # Act
        result = method_under_test(input)

        # Assert
        result.should eq(expected)
      end
    end
  end
end
```

---

## Summary

**Current:** 30 regression tests ✅
**Target:** 500+ tests across all layers
**Timeline:** Add 50-100 tests per week

**Priorities:**
1. Parser tests (Week 1-2)
2. Type inference tests (Week 3-5)
3. LSP tests (Week 1-2, ongoing)
4. Regression tests (Ongoing)

This testing strategy ensures we catch bugs early and maintain high code quality throughout development!
