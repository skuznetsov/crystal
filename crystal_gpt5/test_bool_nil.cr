require "./src/compiler/frontend/lexer"
require "./src/compiler/frontend/parser"

include CrystalGPT5::Compiler::Frontend

# Test Bool literal
source = "true"
lexer = Lexer.new(source)
parser = Parser.new(lexer)
program = parser.parse_program

puts "=== Test: true ==="
puts "Roots: #{program.roots.size}"
root_node = program.arena[program.roots[0]]
puts "Root kind: #{root_node.kind}"
puts "Literal: #{root_node.literal_string}"

# Test Nil literal
source = "nil"
lexer = Lexer.new(source)
parser = Parser.new(lexer)
program = parser.parse_program

puts "\n=== Test: nil ==="
puts "Roots: #{program.roots.size}"
root_node = program.arena[program.roots[0]]
puts "Root kind: #{root_node.kind}"
puts "Literal: #{root_node.literal_string}"
