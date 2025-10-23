require "./src/compiler/**"

source = <<-CRYSTAL
class Dog
  def get_self
    self
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

# Get the self expression
class_node = program.arena[program.roots[0]]
def_node = program.arena[class_node.class_body.not_nil![0]]
self_expr_id = def_node.def_body.not_nil![0]

# Check type
self_type = engine.context.get_type(self_expr_id)
puts "Self type: #{self_type.class}"

if self_type.is_a?(CrystalGPT5::Compiler::Semantic::InstanceType)
  puts "✓ Self has InstanceType"
  puts "  Class: #{self_type.class_symbol.name}"

  if self_type.class_symbol.name == "Dog"
    puts "✓ Self refers to Dog class"
  else
    puts "✗ Self refers to #{self_type.class_symbol.name}, expected Dog"
  end
else
  puts "✗ Self type is #{self_type.class}, expected InstanceType"
end
