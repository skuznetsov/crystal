require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"

include CrystalGPT5::Compiler::Frontend

source = "5 < 10"
lexer = Lexer.new(source)
parser = Parser.new(lexer)
program = parser.parse_program

puts "Roots: #{program.roots.size}"
root_node = program.arena[program.roots[0]]
puts "Root kind: #{root_node.kind}"
puts "Operator: #{root_node.operator_string}"

# Check left and right
if left = root_node.left
  left_node = program.arena[left]
  puts "Left kind: #{left_node.kind}, literal: #{left_node.literal_string}"
end

if right = root_node.right
  right_node = program.arena[right]
  puts "Right kind: #{right_node.kind}, literal: #{right_node.literal_string}"
end
