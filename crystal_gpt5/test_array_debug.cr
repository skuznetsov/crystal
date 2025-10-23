require "./src/compiler/**"

source = <<-CRYSTAL
arr = [1, 2, 3]
len = arr.size
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "=== AST ==="
program.roots.each_with_index do |root_id, idx|
  node = program.arena[root_id]
  puts "Root #{idx}: #{node.kind}"

  if node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign
    value_id = node.assign_value.not_nil!
    value_node = program.arena[value_id]
    puts "  Value: #{value_node.kind}"
  end
end

# Run semantic analysis
analyzer = CrystalGPT5::Compiler::Semantic::Analyzer.new(program)
analyzer.collect_symbols
name_result = analyzer.resolve_names

# Run type inference
engine = CrystalGPT5::Compiler::Semantic::TypeInferenceEngine.new(program, name_result.identifier_symbols, analyzer.global_context.symbol_table)
engine.infer_types

puts "\n=== Types ==="
len_assign = program.arena[program.roots[1]]
size_call_id = len_assign.assign_value.not_nil!
size_type = engine.context.get_type(size_call_id)

puts "size_call_id: #{size_call_id.index}"
puts "size_type: #{size_type.inspect}"
