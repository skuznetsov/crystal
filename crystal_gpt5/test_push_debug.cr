require "./src/compiler/**"

source = <<-CRYSTAL
arr = [1, 2, 3]
result = arr << 4
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "=== AST ==="
program.roots.each_with_index do |root_id, idx|
  node = program.arena[root_id]
  puts "Root #{idx}: #{node.kind}"

  if node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Assign
    value_id = node.assign_value
    if value_id
      value_node = program.arena[value_id]
      puts "  Value: #{value_node.kind}"
    else
      puts "  Value: nil!"
    end
  end
end
