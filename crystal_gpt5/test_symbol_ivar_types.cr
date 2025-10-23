require "./src/compiler/**"

source = <<-CRYSTAL
class Foo
  @x : Int32
  @name : String

  def initialize
    @x = 42
    @name = "test"
  end
end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

symbol_table = CrystalGPT5::Compiler::Semantic::SymbolTable.new(nil)
context = CrystalGPT5::Compiler::Semantic::Context.new(symbol_table)
collector = CrystalGPT5::Compiler::Semantic::SymbolCollector.new(program, context)
collector.collect

# Check that Foo class has instance vars with type annotations
foo_symbol = context.symbol_table.lookup("Foo")
if foo_symbol.is_a?(CrystalGPT5::Compiler::Semantic::ClassSymbol)
  puts "✓ Found Foo class symbol"

  x_type = foo_symbol.get_instance_var_type("x")
  name_type = foo_symbol.get_instance_var_type("name")

  puts "  @x type: #{x_type || "nil"}"
  puts "  @name type: #{name_type || "nil"}"

  if x_type == "Int32"
    puts "✓ @x has correct type annotation (Int32)"
  else
    puts "✗ @x type annotation incorrect (expected Int32, got #{x_type.inspect})"
  end

  if name_type == "String"
    puts "✓ @name has correct type annotation (String)"
  else
    puts "✗ @name type annotation incorrect (expected String, got #{name_type.inspect})"
  end
else
  puts "✗ Foo symbol is not a ClassSymbol"
end
