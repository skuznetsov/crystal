require "spec"

require "../src/compiler/frontend/diagnostic_formatter"

alias Span = CrystalGPT5::Compiler::Frontend::Span
alias Diagnostic = CrystalGPT5::Compiler::Frontend::Diagnostic
alias DiagnosticFormatter = CrystalGPT5::Compiler::Frontend::DiagnosticFormatter

describe DiagnosticFormatter do
  it "formats single line diagnostic with underline" do
    source = "foo + bar"
    span = Span.new(0, 0, 1, 5, 1, 8)
    diagnostic = Diagnostic.new("unexpected identifier", span)

    formatted = DiagnosticFormatter.format(source, diagnostic)
    formatted.should eq("1:5-1:8 unexpected identifier\nfoo + bar\n    ^^^")
  end

  it "formats multi-line diagnostic" do
    source = <<-SRC
line1
line2
line3
    SRC

    span = Span.new(0, 0, 2, 1, 3, 3)
    diagnostic = Diagnostic.new("multi-line issue", span)

    formatted = DiagnosticFormatter.format(source, diagnostic)
    formatted.should eq("2:1-3:3 multi-line issue\nline2\nline3\n^^^^^\n^^")
  end

  it "falls back to base string when source unavailable" do
    span = Span.new(0, 0, 1, 1, 1, 1)
    diagnostic = Diagnostic.new("missing context", span)

    formatted = DiagnosticFormatter.format(nil, diagnostic)
    formatted.should eq("1:1-1:1 missing context")
  end
end
