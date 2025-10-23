require "./src/compiler/**"

source = <<-CRYSTAL
class Foo
  @x : Int32
  
  def initialize
    @x = 42
  end
end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "Roots: #{program.roots.size}"
class_node = program.arena[program.roots[0]]
puts "Class node kind: #{class_node.kind}"

class_body = class_node.class_body
if class_body
  puts "Class body size: #{class_body.size}"
  class_body.each_with_index do |expr_id, idx|
    node = program.arena[expr_id]
    puts "  Body[#{idx}]: #{node.kind}"
  end
end
