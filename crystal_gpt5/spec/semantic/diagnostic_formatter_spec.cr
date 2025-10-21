require "spec"
require "../../src/compiler/semantic/diagnostic"
require "../../src/compiler/semantic/diagnostic_formatter"
require "../../src/compiler/frontend/span"

describe CrystalGPT5::Compiler::Semantic::DiagnosticFormatter do
  it "formats error with single-line primary span" do
      source = "x = foo + bar"
      # "foo" spans from offset 4-7 (columns 5-8)
      # In source: "x = foo" where 'f'=pos 4, 'o'=pos 5, 'o'=pos 6, ' '=pos 7
      diagnostic = CrystalGPT5::Compiler::Semantic::Diagnostic.new(
        CrystalGPT5::Compiler::Semantic::DiagnosticLevel::Error,
        "E2001",
        "undefined local variable or method 'foo'",
        CrystalGPT5::Compiler::Frontend::Span.new(4, 7, 1, 5, 1, 8)  # start_offset, end_offset, start_line, start_column, end_line, end_column
      )

      output = CrystalGPT5::Compiler::Semantic::DiagnosticFormatter.format(source, diagnostic)
      output.should contain("error[E2001]: undefined local variable or method 'foo'")
      output.should contain("  --> 1:5")
      output.should contain("   1 | x = foo + bar")
      output.should contain("     |     ^^^")  # Underline indented to column 5
    end

    it "formats warning with primary and secondary spans" do
      source = <<-CR
      name = "outer"
      def greet
        name = "inner"
      end
      CR

      primary = CrystalGPT5::Compiler::Frontend::Span.new(0, 0, 3, 5, 3, 8)     # 'name' on line 3
      secondary = CrystalGPT5::Compiler::Frontend::Span.new(0, 0, 1, 3, 1, 6)  # 'name' on line 1

      diagnostic = CrystalGPT5::Compiler::Semantic::Diagnostic.new(
        CrystalGPT5::Compiler::Semantic::DiagnosticLevel::Warning,
        "W2001",
        "variable 'name' shadows outer scope variable",
        primary,
        [CrystalGPT5::Compiler::Semantic::SecondarySpan.new(secondary, "outer scope definition here")]
      )

      output = CrystalGPT5::Compiler::Semantic::DiagnosticFormatter.format(source, diagnostic)
      output.should contain("warning[W2001]: variable 'name' shadows outer scope variable")
      output.should contain("  --> 3:5")
      output.should contain("   3 |   name = \"inner\"")
      output.should contain("note: outer scope definition here")
      output.should contain("  --> 1:3")
      output.should contain("   1 | name = \"outer\"")
    end

    it "formats error with duplicate definition (two secondary spans)" do
      source = <<-CR
      class Foo
        def bar; end
      end
      class Foo
        def bar; end
      end
      CR

      # Primary: second 'bar' definition
      primary = CrystalGPT5::Compiler::Frontend::Span.new(0, 0, 5, 7, 5, 9)

      # Secondary 1: first 'bar' definition
      sec1 = CrystalGPT5::Compiler::Frontend::Span.new(0, 0, 2, 7, 2, 9)

      # Secondary 2: class Foo context
      sec2 = CrystalGPT5::Compiler::Frontend::Span.new(0, 0, 4, 1, 4, 9)

      diagnostic = CrystalGPT5::Compiler::Semantic::Diagnostic.new(
        CrystalGPT5::Compiler::Semantic::DiagnosticLevel::Error,
        "E2002",
        "duplicate definition of method 'bar'",
        primary,
        [
          CrystalGPT5::Compiler::Semantic::SecondarySpan.new(sec1, "previous definition here"),
          CrystalGPT5::Compiler::Semantic::SecondarySpan.new(sec2, "in reopened class 'Foo'"),
        ]
      )

      output = CrystalGPT5::Compiler::Semantic::DiagnosticFormatter.format(source, diagnostic)
      output.should contain("error[E2002]: duplicate definition of method 'bar'")
      output.should contain("  --> 5:7")
      output.should contain("note: previous definition here")
      output.should contain("  --> 2:7")
      output.should contain("note: in reopened class 'Foo'")
      output.should contain("  --> 4:1")
    end

    it "formats diagnostic without source (location only)" do
      diagnostic = CrystalGPT5::Compiler::Semantic::Diagnostic.new(
        CrystalGPT5::Compiler::Semantic::DiagnosticLevel::Info,
        "I1001",
        "informational message",
        CrystalGPT5::Compiler::Frontend::Span.new(0, 0, 10, 5, 10, 10)
      )

      output = CrystalGPT5::Compiler::Semantic::DiagnosticFormatter.format(nil, diagnostic)
      output.should contain("info[I1001]: informational message")
      output.should contain("  --> 10:5")
      output.should_not contain("|")  # No snippet without source
    end

    it "handles multi-line spans" do
      source = <<-CR
      def compute(
        x,
        y
      )
      end
      CR

      # Span covering lines 1-4 (entire signature)
      diagnostic = CrystalGPT5::Compiler::Semantic::Diagnostic.new(
        CrystalGPT5::Compiler::Semantic::DiagnosticLevel::Error,
        "E2003",
        "method signature too complex",
        CrystalGPT5::Compiler::Frontend::Span.new(0, 0, 1, 1, 4, 1)
      )

      output = CrystalGPT5::Compiler::Semantic::DiagnosticFormatter.format(source, diagnostic)
      output.should contain("error[E2003]: method signature too complex")
      output.should contain("  --> 1:1")
      output.should contain("   1 | def compute(")
      output.should contain("   2 |   x,")
      output.should contain("   3 |   y")
      output.should contain("   4 | )")
      # Should have underlines on all 4 lines
      output.should contain("     | ^")
    end
end
