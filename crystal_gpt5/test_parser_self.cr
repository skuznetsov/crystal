require "./src/compiler/**"

source = <<-CRYSTAL
class Foo
  def get_self
    self
  end
end
CRYSTAL

lexer = CrystalGPT5::Compiler::Frontend::Lexer.new(source)
parser = CrystalGPT5::Compiler::Frontend::Parser.new(lexer)
program = parser.parse_program

puts "=== Parsed successfully ==="

class_node = program.arena[program.roots[0]]
puts "Class: #{class_node.kind}"

if body = class_node.class_body
  def_node = program.arena[body[0]]
  puts "Method: #{def_node.kind}"

  if def_body = def_node.def_body
    puts "Method body size: #{def_body.size}"
    self_node = program.arena[def_body[0]]
    puts "First statement: #{self_node.kind}"

    if self_node.kind == CrystalGPT5::Compiler::Frontend::ExpressionNode::Kind::Self
      puts "✓ Self node created correctly"
    else
      puts "✗ Expected Self node, got #{self_node.kind}"
    end
  end
end
