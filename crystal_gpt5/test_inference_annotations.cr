require "./src/compiler/**"

source = <<-CRYSTAL
class Foo
  @x : Int32
  @name : String

  def get_x : Int32
    @x
  end

  def get_name : String
    @name
  end
end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

# Run semantic analysis
analyzer = CrystalGPT5::Compiler::Semantic::Analyzer.new(program)
analyzer.collect_symbols
name_result = analyzer.resolve_names

# Run type inference
engine = CrystalGPT5::Compiler::Semantic::TypeInferenceEngine.new(program, name_result.identifier_symbols, analyzer.global_context.symbol_table)
engine.infer_types

puts "✓ Type inference completed"

# Verify ClassSymbol has type annotations
foo_symbol = analyzer.global_context.symbol_table.lookup("Foo")
if foo_symbol.is_a?(CrystalGPT5::Compiler::Semantic::ClassSymbol)
  puts "✓ Found Foo class symbol"

  x_type = foo_symbol.get_instance_var_type("x")
  name_type = foo_symbol.get_instance_var_type("name")

  puts "  @x annotation: #{x_type.inspect}"
  puts "  @name annotation: #{name_type.inspect}"

  if x_type == "Int32" && name_type == "String"
    puts "✓ Type annotations stored correctly"
  else
    puts "✗ Type annotations incorrect"
  end
else
  puts "✗ Foo symbol not found or not a ClassSymbol"
end
