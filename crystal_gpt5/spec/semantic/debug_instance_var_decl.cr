require "./spec_helper"

source = <<-CRYSTAL
  class Foo
    @x : Int32

    def get_x : Int32
      @x
    end
  end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
tokens = lexer.tokenize

parser = CrystalGPT5::Compiler::Frontend::Parser.new(tokens)
program = parser.parse_program

analyzer = CrystalGPT5::Compiler::Semantic::SemanticAnalyzer.new(program)
analyzer.analyze

# Check ClassSymbol
foo_symbol = analyzer.global_context.symbol_table.lookup("Foo")
puts "Foo symbol: #{foo_symbol.class}"
if foo_symbol.is_a?(CrystalGPT5::Compiler::Semantic::ClassSymbol)
  x_type = foo_symbol.get_instance_var_type("x")
  puts "x type: #{x_type.inspect}"
  puts "Expected: \"Int32\", Got: #{x_type}"
end
