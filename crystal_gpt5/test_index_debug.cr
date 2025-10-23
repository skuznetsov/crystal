require "./src/compiler/**"

source = <<-CRYSTAL
arr = [1, 2, 3]
x = arr[0]
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

    if value_node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Index
      puts "  Target: #{value_node.left}"
      puts "  Index: #{value_node.args}"
    end
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
x_assign = program.arena[program.roots[1]]
index_expr_id = x_assign.assign_value.not_nil!
index_type = engine.context.get_type(index_expr_id)

puts "index_expr_id: #{index_expr_id.index}"
puts "index_type: #{index_type.inspect}"

# Check array type
arr_assign = program.arena[program.roots[0]]
arr_id = arr_assign.assign_target.not_nil!
arr_type = engine.context.get_type(arr_id)
puts "arr_type: #{arr_type.inspect}"
