require "./src/compiler/**"

source = <<-CRYSTAL
def test : Int32
  return 42
end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

# Run semantic analysis
symbol_table = CrystalGPT5::Compiler::Semantic::SymbolTable.new(nil)
context = CrystalGPT5::Compiler::Semantic::Context.new(symbol_table)
analyzer = CrystalGPT5::Compiler::Semantic::Analyzer.new(program)
analyzer.collect_symbols
name_result = analyzer.resolve_names

# Run type inference
engine = CrystalGPT5::Compiler::Semantic::TypeInferenceEngine.new(program, name_result.identifier_symbols, analyzer.global_context.symbol_table)
engine.infer_types

puts "✓ Type inference completed"

# Check return statement type
def_node = program.arena[program.roots[0]]
if body = def_node.def_body
  return_expr_id = body[0]
  return_node = program.arena[return_expr_id]

  puts "Return node kind: #{return_node.kind}"
  puts "Has return value: #{!return_node.return_value.nil?}"

  if value_id = return_node.return_value
    value_node = program.arena[value_id]
    puts "Return value kind: #{value_node.kind}"
    puts "Return value: #{String.new(value_node.literal.not_nil!)}"

    value_type = engine.context.get_type(value_id)
    puts "Return value type: #{value_type.class}"
    if value_type.is_a?(CrystalGPT5::Compiler::Semantic::PrimitiveType)
      puts "Value type name: #{value_type.name}"
    end
  end

  return_type = engine.context.get_type(return_expr_id)
  puts "\nReturn statement type: #{return_type.class}"
  if return_type.is_a?(CrystalGPT5::Compiler::Semantic::PrimitiveType)
    puts "Return type name: #{return_type.name}"
    if return_type.name == "Int32"
      puts "✓ Return statement has Int32 type"
    else
      puts "✗ Wrong type: #{return_type.name}"
    end
  else
    puts "✗ Return statement type is not PrimitiveType"
  end
end
